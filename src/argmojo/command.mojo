"""Defines a CLI command and performs argument parsing."""

from std.os import getenv
from std.os.path import exists as _path_exists
from std.sys import argv, exit, stderr

from .argument import Argument
from .parse_result import ParseResult
from .utils import (
    _RESET,
    _BOLD_UL,
    _DEFAULT_HEADER_COLOR,
    _DEFAULT_ARG_COLOR,
    _DEFAULT_WARN_COLOR,
    _DEFAULT_ERROR_COLOR,
    _correct_cjk_punctuation,
    _disable_echo,
    _display_width,
    _read_password_asterisk,
    _restore_echo,
    _fullwidth_to_halfwidth,
    _has_fullwidth_chars,
    _looks_like_number,
    _resolve_color,
    _split_on_fullwidth_spaces,
    _suggest_similar,
)


# ---------- module-level file reader (workaround for Mojo compiler issue) ----
# Placing `open()` inside a method of a struct that contains `List[Self]` causes
# the compiler to deadlock when built with `-D ASSERT=warn` or `-D ASSERT=all`.
# Moving the I/O into a free function avoids the trigger.
def _read_file_content(filepath: String) raises -> String:
    """Reads and returns the entire contents of *filepath*."""
    with open(filepath, "r") as f:
        return f.read()


def _expand_response_files(
    raw_args: List[String],
    prefix: String,
    max_depth: Int,
    cmd_name: String,
) raises -> List[String]:
    """Expands response-file tokens in the argument list.

    Free function (not a Command method) to work around a Mojo compiler
    deadlock when ``open()`` or complex I/O appears inside a method of a
    struct that contains ``List[Self]`` and is compiled with
    ``-D ASSERT=all``.
    """
    var expanded = List[String]()
    var plen = len(prefix)

    for idx in range(len(raw_args)):
        var token = raw_args[idx]

        # Preserve argv[0] (program name) verbatim — never expand it.
        if idx == 0:
            expanded.append(token)
            continue

        # Check for escape: doubled prefix → literal.
        if (
            len(token) > plen * 2 - 1
            and String(token[byte = : plen * 2]) == prefix + prefix
        ):
            expanded.append(String(token[byte=plen:]))
            continue

        if len(token) > plen and String(token[byte=:plen]) == prefix:
            var filepath = String(token[byte=plen:])
            _read_response_file(
                filepath, expanded, 0, prefix, max_depth, cmd_name
            )
        else:
            expanded.append(token)
    return expanded^


def _read_response_file(
    filepath: String,
    mut out_args: List[String],
    depth: Int,
    prefix: String,
    max_depth: Int,
    cmd_name: String,
) raises:
    """Reads a single response file and appends its arguments.

    Free function (not a Command method) — see ``_expand_response_files``
    docstring for rationale.
    """
    if depth >= max_depth:
        var msg = (
            "Response file nesting too deep (max "
            + String(max_depth)
            + "): "
            + filepath
        )
        print("error: " + cmd_name + ": " + msg, file=stderr)
        raise Error(msg)

    if not _path_exists(filepath):
        var msg = "Response file not found: " + filepath
        print("error: " + cmd_name + ": " + msg, file=stderr)
        raise Error(msg)

    var plen = len(prefix)
    var content = _read_file_content(filepath)

    var lines = content.split("\n")
    for li in range(len(lines)):
        var line = String(String(lines[li]).strip())

        if len(line) == 0 or line.startswith("#"):
            continue

        # Escape: doubled prefix → literal.
        if (
            len(line) > plen * 2 - 1
            and String(line[byte = : plen * 2]) == prefix + prefix
        ):
            out_args.append(String(line[byte=plen:]))
            continue

        # Recursive response file.
        if len(line) > plen and String(line[byte=:plen]) == prefix:
            var nested_path = String(line[byte=plen:])
            _read_response_file(
                nested_path, out_args, depth + 1, prefix, max_depth, cmd_name
            )
        else:
            out_args.append(line)


struct Command(Copyable, Movable, Writable):
    """Defines a CLI command prototype with its arguments and handles parsing.

    Examples:

    ```mojo
    from argmojo import Command, Argument
    var command = Command("myapp", "A sample application")
    command.add_argument(Argument("verbose", help="Enable verbose output").long["verbose"]().short["v"]().flag())
    var result = command.parse()
    ```
    """

    # === Public fields ===
    var name: String
    """The command name (typically the program name)."""
    var description: String
    """A short description of the command, shown in help text."""
    var version: String
    """Version string for --version output."""
    var args: List[Argument]
    """Registered argument definitions."""
    var subcommands: List[Command]
    """Registered subcommand definitions. Each is a full Command instance."""

    # === Private fields — Group constraints ===
    var _exclusive_groups: List[List[String]]
    """Groups of mutually exclusive argument names."""
    var _required_groups: List[List[String]]
    """Groups of arguments that must be provided together."""
    var _one_required_groups: List[List[String]]
    """Groups where at least one argument must be provided."""
    var _conditional_reqs: List[List[String]]
    """Pairs [target, condition]: target is required when condition is present."""
    var _implications: List[List[String]]
    """Pairs [trigger, implied]: when trigger is set, implied is auto-set."""

    # === Private fields — Subcommand behavior ===
    var _is_help_subcommand: Bool
    """True for the auto-inserted 'help' pseudo-subcommand.
    Never set this manually; use ``add_subcommand()`` to register subcommands and
    ``disable_help_subcommand()`` to opt out.
    """
    var _help_subcommand_enabled: Bool
    """When True (default), auto-insert a 'help' subcommand on first 
    ``add_subcommand()`` call."""
    var _command_aliases: List[String]
    """Alternate names for this command when used as a subcommand.
    Add entries via ``command_aliases()``.  Aliases are matched during
    subcommand dispatch and appear inline next to the primary name in
    help (e.g., "clone, cl"), but are not shown as separate entries."""
    var _is_hidden: Bool
    """When True, this command is excluded from help output, shell
    completions, and 'available commands' error lists, but remains
    dispatchable by exact name or alias.  Set via ``hidden()``."""

    # === Private fields — Parser behavior ===
    var _help_on_no_arguments: Bool
    """When True, show help and exit if no arguments are provided."""
    var _allow_negative_numbers: Bool
    """When True, tokens matching negative-number format (-N, -N.N, -NeX)
    are always treated as positional arguments.
    When False (default), the same treatment applies automatically whenever
    no registered short option uses a digit character (auto-detect).
    Enable explicitly via ``allow_negative_numbers()`` when you have a digit
    short option and still need negative-number literals to pass through."""
    var _allow_negative_expressions: Bool
    """When True, single-hyphen tokens that are not known short options
    are treated as positional arguments.  This handles expressions like
    ``-1/3*pi`` or ``-e`` (when ``-e`` is not a registered short flag).
    Tokens with more than one character after the hyphen are always
    consumed as positionals; single-character tokens (``-x``) are only
    consumed if ``x`` does not match a registered short option."""
    var _allow_positional_with_subcommands: Bool
    """When True, allows mixing positional arguments with subcommands.
    By default (False), registering a positional arg on a Command that already 
    has subcommands (or vice versa) raises an Error at registration time.
    Call ``allow_positional_with_subcommands()`` to opt in explicitly."""
    var _response_file_prefix: String
    """Character prefix that marks a response-file token (e.g. ``@``).
    When a token starts with this prefix, the remainder is treated as a
    file path.  Each line of the file is inserted as a separate argument.
    Set via ``response_file_prefix()``.  Empty string means disabled."""
    var _response_file_max_depth: Int
    """Maximum nesting depth for recursive response-file expansion.
    Prevents infinite loops when file A references file B and vice versa."""
    var _disable_fullwidth_correction: Bool
    """When True, disable automatic full-width → half-width character
    correction on option tokens.  By default (False), tokens starting
    with ``-`` that contain fullwidth ASCII characters (``U+FF01``–
    ``U+FF5E``) or fullwidth spaces (``U+3000``) are auto-corrected
    with a warning.  Call ``disable_fullwidth_correction()`` to opt out."""
    var _disable_punctuation_correction: Bool
    """When True, disable CJK punctuation detection in error recovery.
    By default (False), when an unknown option is encountered, common
    CJK punctuation (e.g. em-dash ``U+2014``) is substituted before
    running Levenshtein typo suggestion.  Call
    ``disable_punctuation_correction()`` to opt out."""

    # === Private fields — Interactive & confirmation ===
    var _confirmation_enabled: Bool
    """When True, the command prompts the user for confirmation before
    returning the parse result.  If ``--yes`` / ``-y`` is provided on
    the command line, the prompt is skipped.  Enable via
    ``confirmation_option()``."""
    var _confirmation_prompt: String
    """The prompt text shown when asking for confirmation.
    Empty until ``confirmation_option()`` is called."""

    # === Private fields — Help & display ===
    var _header_color: String
    """ANSI code for section headers (Usage, Arguments, Options)."""
    var _arg_color: String
    """ANSI code for option / argument names."""
    var _warn_color: String
    """ANSI code for deprecation warning messages (default: orange)."""
    var _error_color: String
    """ANSI code for parse error messages (default: red)."""
    var _custom_usage: String
    """When non-empty, replaces the auto-generated usage line.
    Set via ``usage("...")``."""
    var _tips: List[String]
    """User-defined tips shown at the bottom of the help message.
    Add entries via ``add_tip()``.  Each tip is printed on its own line
    prefixed with the same bold ``Tip:`` label as the built-in hint."""

    # === Private fields — Shell completions ===
    var _completions_enabled: Bool
    """When True (default), a built-in completion trigger is active.
    Call ``disable_default_completions()`` to opt out entirely."""
    var _completions_name: String
    """The name used for the built-in completion trigger.
    Defaults to ``"completions"`` → ``--completions <shell>``.
    Change via ``completions_name()``."""
    var _completions_is_subcommand: Bool
    """When True, the completion trigger is a subcommand instead of an
    option.  Default False → ``--completions``.  Call
    ``completions_as_subcommand()`` to switch to ``myapp completions bash``."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    def __init__(
        out self,
        name: String,
        description: String = "",
        version: String = "0.1.0",
    ):
        """Creates a new Command.

        Args:
            name: The command name.
            description: A short description for help text.
            version: Version string.
        """
        self.name = name
        self.description = description
        self.version = version
        self.args = List[Argument]()
        self.subcommands = List[Command]()
        # ── Group constraints ──
        self._exclusive_groups = List[List[String]]()
        self._required_groups = List[List[String]]()
        self._one_required_groups = List[List[String]]()
        self._conditional_reqs = List[List[String]]()
        self._implications = List[List[String]]()
        # ── Subcommand behavior ──
        self._is_help_subcommand = False
        self._help_subcommand_enabled = True
        self._command_aliases = List[String]()
        self._is_hidden = False
        # ── Parser behavior ──
        self._help_on_no_arguments = False
        self._allow_negative_numbers = False
        self._allow_negative_expressions = False
        self._allow_positional_with_subcommands = False
        self._response_file_prefix = String("")
        self._response_file_max_depth = 10
        self._disable_fullwidth_correction = False
        self._disable_punctuation_correction = False
        # ── Interactive & confirmation ──
        self._confirmation_enabled = False
        self._confirmation_prompt = String("")
        # ── Help & display ──
        self._header_color = _DEFAULT_HEADER_COLOR
        self._arg_color = _DEFAULT_ARG_COLOR
        self._warn_color = _DEFAULT_WARN_COLOR
        self._error_color = _DEFAULT_ERROR_COLOR
        self._custom_usage = String("")
        self._tips = List[String]()
        # ── Shell completions ──
        self._completions_enabled = True
        self._completions_name = String("completions")
        self._completions_is_subcommand = False

    def __init__(out self, *, deinit take: Self):
        """Moves a Command, transferring ownership of all fields.

        Args:
            take: The Command to move from.
        """
        self.name = take.name^
        self.description = take.description^
        self.version = take.version^
        self.args = take.args^
        self.subcommands = take.subcommands^
        # ── Group constraints ──
        self._exclusive_groups = take._exclusive_groups^
        self._required_groups = take._required_groups^
        self._one_required_groups = take._one_required_groups^
        self._conditional_reqs = take._conditional_reqs^
        self._implications = take._implications^
        # ── Subcommand behavior ──
        self._is_help_subcommand = take._is_help_subcommand
        self._help_subcommand_enabled = take._help_subcommand_enabled
        self._command_aliases = take._command_aliases^
        self._is_hidden = take._is_hidden
        # ── Parser behavior ──
        self._help_on_no_arguments = take._help_on_no_arguments
        self._allow_negative_numbers = take._allow_negative_numbers
        self._allow_negative_expressions = take._allow_negative_expressions
        self._allow_positional_with_subcommands = (
            take._allow_positional_with_subcommands
        )
        self._response_file_prefix = take._response_file_prefix^
        self._response_file_max_depth = take._response_file_max_depth
        self._disable_fullwidth_correction = take._disable_fullwidth_correction
        self._disable_punctuation_correction = (
            take._disable_punctuation_correction
        )
        # ── Interactive & confirmation ──
        self._confirmation_enabled = take._confirmation_enabled
        self._confirmation_prompt = take._confirmation_prompt^
        # ── Help & display ──
        self._header_color = take._header_color^
        self._arg_color = take._arg_color^
        self._warn_color = take._warn_color^
        self._error_color = take._error_color^
        self._custom_usage = take._custom_usage^
        self._tips = take._tips^
        # ── Shell completions ──
        self._completions_enabled = take._completions_enabled
        self._completions_name = take._completions_name^
        self._completions_is_subcommand = take._completions_is_subcommand

    def __init__(out self, *, copy: Self):
        """Creates a deep copy of a Command.

        All field data — including registered args and subcommands — is
        duplicated.  Builder-pattern usage with ``add_subcommand(sub^)``
        moves rather than copies, so this is only triggered when a
        ``Command`` value is assigned via ``=``.

        Args:
            copy: The Command to copy from.
        """
        self.name = copy.name
        self.description = copy.description
        self.version = copy.version
        self.args = copy.args.copy()
        self.subcommands = copy.subcommands.copy()
        # ── Group constraints ──
        self._exclusive_groups = List[List[String]]()
        for i in range(len(copy._exclusive_groups)):
            self._exclusive_groups.append(copy._exclusive_groups[i].copy())
        self._required_groups = List[List[String]]()
        for i in range(len(copy._required_groups)):
            self._required_groups.append(copy._required_groups[i].copy())
        self._one_required_groups = List[List[String]]()
        for i in range(len(copy._one_required_groups)):
            self._one_required_groups.append(
                copy._one_required_groups[i].copy()
            )
        self._conditional_reqs = List[List[String]]()
        for i in range(len(copy._conditional_reqs)):
            self._conditional_reqs.append(copy._conditional_reqs[i].copy())
        self._implications = List[List[String]]()
        for i in range(len(copy._implications)):
            self._implications.append(copy._implications[i].copy())
        # ── Subcommand behavior ──
        self._is_help_subcommand = copy._is_help_subcommand
        self._help_subcommand_enabled = copy._help_subcommand_enabled
        self._command_aliases = copy._command_aliases.copy()
        self._is_hidden = copy._is_hidden
        # ── Parser behavior ──
        self._help_on_no_arguments = copy._help_on_no_arguments
        self._allow_negative_numbers = copy._allow_negative_numbers
        self._allow_negative_expressions = copy._allow_negative_expressions
        self._allow_positional_with_subcommands = (
            copy._allow_positional_with_subcommands
        )
        self._response_file_prefix = copy._response_file_prefix
        self._response_file_max_depth = copy._response_file_max_depth
        self._disable_fullwidth_correction = copy._disable_fullwidth_correction
        self._disable_punctuation_correction = (
            copy._disable_punctuation_correction
        )
        # ── Interactive & confirmation ──
        self._confirmation_enabled = copy._confirmation_enabled
        self._confirmation_prompt = copy._confirmation_prompt
        # ── Help & display ──
        self._header_color = copy._header_color
        self._arg_color = copy._arg_color
        self._warn_color = copy._warn_color
        self._error_color = copy._error_color
        self._custom_usage = copy._custom_usage
        self._tips = copy._tips.copy()
        # ── Shell completions ──
        self._completions_enabled = copy._completions_enabled
        self._completions_name = copy._completions_name
        self._completions_is_subcommand = copy._completions_is_subcommand

    # ===------------------------------------------------------------------=== #
    # Builder methods for configuring the command
    # ===------------------------------------------------------------------=== #

    # ── Registration ──

    def add_argument(mut self, var argument: Argument) raises:
        """Registers an argument definition.

        Raises:
            Error if adding a positional argument to a Command that already
            has subcommands registered (unless
            ``allow_positional_with_subcommands()`` has been called), or if
            the argument's name, long flag, short flag, or any alias
            collides with an already-registered argument.

        Args:
            argument: The Argument to register.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("verbose", help="Enable verbose output"))
        var result = command.parse()
        ```
        """
        # Guard: positional args + subcommands require explicit opt-in.
        if (
            argument._is_positional
            and len(self.subcommands) > 0
            and not self._allow_positional_with_subcommands
        ):
            raise Error(
                "Cannot add positional argument '"
                + argument.name
                + "' to '"
                + self.name
                + "' which already has subcommands. Call"
                " allow_positional_with_subcommands() to opt in"
            )
        # Guard: require_equals / default_if_no_value + multi-value is unsupported.
        if (
            argument._require_equals or argument._has_default_if_no_value
        ) and argument._number_of_values > 0:
            raise Error(
                "Argument '"
                + argument.name
                + "': .require_equals() / .default_if_no_value() cannot be"
                " combined with .number_of_values[N]() (multi-value options)"
            )
        # Guard: remainder must not be combined with long/short (it is positional-only).
        if argument._is_remainder and (
            argument._long_name or argument._short_name
        ):
            raise Error(
                "Argument '"
                + argument.name
                + "': .remainder() is for positional arguments only; remove"
                " .long() / .short()"
            )
        # Guard: at most one remainder positional is allowed.
        if argument._is_remainder:
            for _ri in range(len(self.args)):
                if self.args[_ri]._is_remainder:
                    raise Error(
                        "Argument '"
                        + argument.name
                        + "': only one .remainder() positional is allowed"
                        " (already set on '"
                        + self.args[_ri].name
                        + "')"
                    )
        # Guard: no positional may be added after a remainder.
        if argument._is_positional and not argument._is_remainder:
            for _ri in range(len(self.args)):
                if self.args[_ri]._is_remainder:
                    raise Error(
                        "Argument '"
                        + argument.name
                        + "': cannot add a positional argument after"
                        " a .remainder() positional ('"
                        + self.args[_ri].name
                        + "')"
                    )
        # Guard: .prompt() conflicts with help_on_no_arguments().
        if argument._prompt and self._help_on_no_arguments:
            raise Error(
                "Argument '"
                + argument.name
                + "': .prompt() cannot be used on a command with"
                " help_on_no_arguments() — when no arguments are"
                " provided, help is shown and prompting never runs."
                " Remove help_on_no_arguments() or .prompt()"
            )
        # Guard: .password() only makes sense on value-taking arguments.
        if argument._hide_input and (argument._is_flag or argument._is_count):
            raise Error(
                "Argument '"
                + argument.name
                + "': .password() cannot be used on a flag or count"
                " argument — it only applies to value-taking arguments"
            )
        # Guard: duplicate internal name.
        for _di in range(len(self.args)):
            if self.args[_di].name == argument.name:
                raise Error(
                    "Argument '"
                    + argument.name
                    + "': duplicate name — an argument with the same"
                    " name is already registered on '"
                    + self.name
                    + "'"
                )
        # Guard: duplicate long name (including alias collisions).
        if argument._long_name:
            for _di in range(len(self.args)):
                if (
                    self.args[_di]._long_name
                    and self.args[_di]._long_name == argument._long_name
                ):
                    raise Error(
                        "Argument '"
                        + argument.name
                        + "': duplicate long flag '--"
                        + argument._long_name
                        + "' — already used by argument '"
                        + self.args[_di].name
                        + "' on '"
                        + self.name
                        + "'"
                    )
                # Check new argument's long name against existing aliases.
                for _ai in range(len(self.args[_di]._alias_names)):
                    if self.args[_di]._alias_names[_ai] == argument._long_name:
                        raise Error(
                            "Argument '"
                            + argument.name
                            + "': long flag '--"
                            + argument._long_name
                            + "' collides with alias of argument '"
                            + self.args[_di].name
                            + "' on '"
                            + self.name
                            + "'"
                        )
        # Guard: new argument's aliases against existing long names and aliases.
        for _ni in range(len(argument._alias_names)):
            for _di in range(len(self.args)):
                if (
                    self.args[_di]._long_name
                    and self.args[_di]._long_name == argument._alias_names[_ni]
                ):
                    raise Error(
                        "Argument '"
                        + argument.name
                        + "': alias '--"
                        + argument._alias_names[_ni]
                        + "' collides with long flag of argument '"
                        + self.args[_di].name
                        + "' on '"
                        + self.name
                        + "'"
                    )
                for _ai in range(len(self.args[_di]._alias_names)):
                    if (
                        self.args[_di]._alias_names[_ai]
                        == argument._alias_names[_ni]
                    ):
                        raise Error(
                            "Argument '"
                            + argument.name
                            + "': alias '--"
                            + argument._alias_names[_ni]
                            + "' collides with alias of argument '"
                            + self.args[_di].name
                            + "' on '"
                            + self.name
                            + "'"
                        )
        # Guard: duplicate short name.
        if argument._short_name:
            for _di in range(len(self.args)):
                if (
                    self.args[_di]._short_name
                    and self.args[_di]._short_name == argument._short_name
                ):
                    raise Error(
                        "Argument '"
                        + argument.name
                        + "': duplicate short flag '-"
                        + argument._short_name
                        + "' — already used by argument '"
                        + self.args[_di].name
                        + "' on '"
                        + self.name
                        + "'"
                    )
        self.args.append(argument^)

    def add_subcommand(mut self, var sub: Command) raises:
        """Registers a subcommand.

        A subcommand is a full ``Command`` instance that handles a specific verb
        (e.g. ``app search …``, ``app init …``).  After parsing, the selected
        subcommand name is stored in ``result.subcommand`` and its own parsed
        values are available via ``result.get_subcommand_result()``.

        Args:
            sub: The subcommand ``Command`` to register.

        Raises:
            Error if a persistent argument on this command shares a ``long_name``
            or ``short_name`` with any local argument on ``sub``.

        Examples:

        ```mojo
        from argmojo import Command, Argument

        var app = Command("app", "My CLI tool", version="0.3.0")

        var search = Command("search", "Search for patterns")
        search.add_argument(Argument("pattern", help="Search pattern").required().positional())

        var init = Command("init", "Initialize a new project")
        init.add_argument(Argument("name", help="Project name").required().positional())

        app.add_subcommand(search^)
        app.add_subcommand(init^)
        ```
        """
        # Guard: subcommands + positional args require explicit opt-in.
        if not self._allow_positional_with_subcommands:
            for _pi in range(len(self.args)):
                if self.args[_pi]._is_positional:
                    raise Error(
                        "Cannot add subcommand '"
                        + sub.name
                        + "' to '"
                        + self.name
                        + "' which already has positional argument '"
                        + self.args[_pi].name
                        + "'. Call"
                        " allow_positional_with_subcommands() to opt in"
                    )
        # Conflict check: persistent parent args must not share names with
        # any local arg in the child — that would make the option ambiguous
        # after injection.
        for pi in range(len(self.args)):
            if not self.args[pi]._is_persistent:
                continue
            var pa = self.args[pi].copy()
            for ci in range(len(sub.args)):
                var ca = sub.args[ci].copy()
                if (
                    pa._long_name
                    and ca._long_name
                    and pa._long_name == ca._long_name
                ):
                    raise Error(
                        "Persistent flag '--"
                        + pa._long_name
                        + "' on '"
                        + self.name
                        + "' conflicts with '--"
                        + ca._long_name
                        + "' on subcommand '"
                        + sub.name
                        + "'"
                    )
                if (
                    pa._short_name
                    and ca._short_name
                    and pa._short_name == ca._short_name
                ):
                    raise Error(
                        "Persistent flag '-"
                        + pa._short_name
                        + "' on '"
                        + self.name
                        + "' conflicts with '-"
                        + ca._short_name
                        + "' on subcommand '"
                        + sub.name
                        + "'"
                    )
        # Auto-register the 'help' subcommand as the first entry once.
        # This keeps help discoverable at a fixed position (index 0) while
        # user-defined subcommands remain in registration order after it.
        # Disabled via disable_help_subcommand(); guard prevents duplicates.
        if self._help_subcommand_enabled and self._find_subcommand("help") < 0:
            var h = Command("help", "Show help for a subcommand")
            h._is_help_subcommand = True
            self.subcommands.append(h^)
        self.subcommands.append(sub^)

    def add_parent(mut self, parent: Command) raises:
        """Inherits argument definitions and group constraints from a parent.

        All arguments registered on ``parent`` are copied into this command,
        and all group constraints (mutually exclusive, required together,
        one-required, conditional requirements, implications) are inherited.

        This is equivalent to Python argparse's ``parents`` parameter — it
        lets you share a common set of ``Argument`` definitions across
        multiple ``Command`` instances without repeating them.

        The parent should **not** have ``--help`` / ``-h`` registered as a
        user argument (the built-in help is always present), but any other
        argument is fine.  All validation guards in ``add_argument()`` run
        on each inherited argument as usual.

        Args:
            parent: The Command whose arguments and constraints to inherit.

        Raises:
            Error if any inherited argument violates registration guards.

        Examples:

        ```mojo
        from argmojo import Command, Argument

        var shared = Command("_shared")
        shared.add_argument(
            Argument("verbose", help="Enable verbose output")
            .long["verbose"]()
            .short["v"]()
            .flag()
        )
        shared.add_argument(
            Argument("format", help="Output format")
            .long["format"]()
            .short["f"]()
            .choice["json"]()
            .choice["yaml"]()
        )

        var cmd_a = Command("cmd_a", "First command")
        cmd_a.add_parent(shared)

        var cmd_b = Command("cmd_b", "Second command")
        cmd_b.add_parent(shared)
        ```
        """
        # Stage args with rollback: if any add_argument() raises (e.g.
        # name/short/long conflict), undo partially-added args so that
        # self is not left in a half-inherited state.
        var orig_len = len(self.args)
        try:
            for i in range(len(parent.args)):
                self.add_argument(parent.args[i].copy())
        except e:
            while len(self.args) > orig_len:
                _ = self.args.pop()
            raise e^
        # All args inherited successfully; copy constraint groups.
        for i in range(len(parent._exclusive_groups)):
            self._exclusive_groups.append(parent._exclusive_groups[i].copy())
        for i in range(len(parent._required_groups)):
            self._required_groups.append(parent._required_groups[i].copy())
        for i in range(len(parent._one_required_groups)):
            self._one_required_groups.append(
                parent._one_required_groups[i].copy()
            )
        for i in range(len(parent._conditional_reqs)):
            self._conditional_reqs.append(parent._conditional_reqs[i].copy())
        for i in range(len(parent._implications)):
            self._implications.append(parent._implications[i].copy())

    # ── Group constraints ──

    def mutually_exclusive(mut self, var names: List[String]) raises:
        """Declares a group of mutually exclusive arguments.

        At most one argument from each group may be provided. Parsing
        will fail if more than one is present.

        All names must refer to arguments already registered via
        ``add_argument()``.  An ``Error`` is raised immediately if any
        name is unknown, so that typos are caught during command
        construction rather than at end-user runtime.

        Args:
            names: The internal names of the arguments in the group.

        Raises:
            Error: If any name in the group is not a registered argument.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("json", help="Output as JSON").long["json"]().flag())
        command.add_argument(Argument("yaml", help="Output as YAML").long["yaml"]().flag())
        command.mutually_exclusive(["json", "yaml"])
        ```
        """
        if len(names) == 0:
            raise Error("mutually_exclusive(): 'names' list must not be empty")
        var unique = List[String]()
        for ni in range(len(names)):
            var dup = False
            for ui in range(len(unique)):
                if unique[ui] == names[ni]:
                    dup = True
                    break
            if dup:
                continue  # Proceed to the next name; duplicates are ignored.
            var found = False
            for ai in range(len(self.args)):
                if self.args[ai].name == names[ni]:
                    found = True
                    break
            if not found:
                raise Error(
                    "mutually_exclusive(): unknown argument '" + names[ni] + "'"
                )
            unique.append(names[ni])
        self._exclusive_groups.append(unique^)

    def required_together(mut self, var names: List[String]) raises:
        """Declares a group of arguments that must be provided together.

        If any argument from the group is provided, all others in the
        group must also be provided. Parsing will fail otherwise.

        All names must refer to arguments already registered via
        ``add_argument()``.  An ``Error`` is raised immediately if any
        name is unknown, so that typos are caught during command
        construction rather than at end-user runtime.

        Args:
            names: The internal names of the arguments in the group.

        Raises:
            Error: If any name in the group is not a registered argument.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("username", help="Auth username").long["username"]().short["u"]())
        command.add_argument(Argument("password", help="Auth password").long["password"]().short["p"]())
        command.required_together(["username", "password"])
        ```
        """
        if len(names) == 0:
            raise Error("required_together(): 'names' list must not be empty")
        var unique = List[String]()
        for ni in range(len(names)):
            var dup = False
            for ui in range(len(unique)):
                if unique[ui] == names[ni]:
                    dup = True
                    break
            if dup:
                continue
            var found = False
            for ai in range(len(self.args)):
                if self.args[ai].name == names[ni]:
                    found = True
                    break
            if not found:
                raise Error(
                    "required_together(): unknown argument '" + names[ni] + "'"
                )
            unique.append(names[ni])
        self._required_groups.append(unique^)

    def one_required(mut self, var names: List[String]) raises:
        """Declares a group where at least one argument must be provided.

        Parsing will fail if none of the arguments in the group are
        present on the command line.

        All names must refer to arguments already registered via
        ``add_argument()``.  An ``Error`` is raised immediately if any
        name is unknown, so that typos are caught during command
        construction rather than at end-user runtime.

        Args:
            names: The internal names of the arguments in the group.

        Raises:
            Error: If any name in the group is not a registered argument.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("json", help="Output as JSON").long["json"]().flag())
        command.add_argument(Argument("yaml", help="Output as YAML").long["yaml"]().flag())
        command.one_required(["json", "yaml"])
        ```
        """
        if len(names) == 0:
            raise Error("one_required(): 'names' list must not be empty")
        var unique = List[String]()
        for ni in range(len(names)):
            var dup = False
            for ui in range(len(unique)):
                if unique[ui] == names[ni]:
                    dup = True
                    break
            if dup:
                continue
            var found = False
            for ai in range(len(self.args)):
                if self.args[ai].name == names[ni]:
                    found = True
                    break
            if not found:
                raise Error(
                    "one_required(): unknown argument '" + names[ni] + "'"
                )
            unique.append(names[ni])
        self._one_required_groups.append(unique^)

    def required_if(mut self, target: String, condition: String) raises:
        """Declares that an argument is required when another is present.

        When ``condition`` is provided on the command line, ``target``
        must also be provided.  Parsing will fail otherwise.

        Both ``target`` and ``condition`` must refer to arguments already
        registered via ``add_argument()``.  An ``Error`` is raised
        immediately if either name is unknown, so that typos are caught
        during command construction rather than at end-user runtime.

        Args:
            target: The name of the argument that becomes required.
            condition: The name of the argument that triggers the requirement.

        Raises:
            Error: If either name is not a registered argument.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("save", help="Save results").long["save"]().flag())
        command.add_argument(Argument("output", help="Output path").long["output"]().short["o"]())
        command.required_if("output", "save")
        ```
        """
        if target == condition:
            raise Error(
                "required_if(): target and condition must differ, got '"
                + target
                + "'"
            )
        var checks: List[String] = [target, condition]
        for ci in range(len(checks)):
            var found = False
            for ai in range(len(self.args)):
                if self.args[ai].name == checks[ci]:
                    found = True
                    break
            if not found:
                raise Error(
                    "required_if(): unknown argument '" + checks[ci] + "'"
                )
        var pair: List[String] = [target, condition]
        self._conditional_reqs.append(pair^)

    def implies(mut self, trigger: String, implied: String) raises:
        """Declares that setting one argument automatically sets another.

        When ``trigger`` is present in the parse result, ``implied`` is
        automatically set (as a flag set to ``True``, or a count
        incremented by 1).  Chains are supported: if A implies B and B
        implies C, setting A will also set C.  Circular implications are
        detected at registration time and raise an error.

        Both ``trigger`` and ``implied`` must be registered arguments.
        The ``implied`` argument must be a ``.flag()`` or ``.count()``
        argument — value-taking, positional, append, and map arguments
        are not supported as implication targets.

        Args:
            trigger: The argument whose presence triggers the implication.
            implied: The argument that is automatically set.

        Raises:
            Error if adding this implication would create a cycle, if
            either argument is unknown, or if the implied argument is
            not a flag or count.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("debug", help="Debug mode").long["debug"]().flag())
        command.add_argument(Argument("verbose", help="Verbose output").long["verbose"]().flag())
        command.implies("debug", "verbose")
        # --debug now automatically sets --verbose as well
        ```
        """
        # Validate that both trigger and implied are registered arguments.
        var trigger_found = False
        for i in range(len(self.args)):
            if self.args[i].name == trigger:
                trigger_found = True
                break
        if not trigger_found:
            raise Error("implies(): unknown trigger argument '" + trigger + "'")

        var implied_found = False
        var implied_kind = String("flag")  # "flag" or "count"
        for i in range(len(self.args)):
            if self.args[i].name == implied:
                implied_found = True
                if self.args[i]._is_count:
                    implied_kind = "count"
                elif not self.args[i]._is_flag:
                    raise Error(
                        "implies(): implied argument '"
                        + implied
                        + "' must be a flag() or count()"
                    )
                break
        if not implied_found:
            raise Error("implies(): unknown implied argument '" + implied + "'")

        # Cycle detection: check if `trigger` is reachable from `implied`.
        # If so, adding implied→...→trigger would form a cycle.
        if trigger == implied:
            raise Error(
                "Implication cycle detected: '" + trigger + "' implies itself"
            )
        # DFS from `implied` following existing edges.
        var visited = List[String]()
        var stack = List[String]()
        stack.append(implied)
        while len(stack) > 0:
            var current = stack.pop()
            # Check existing implications where `current` is the trigger.
            for i in range(len(self._implications)):
                if self._implications[i][0] == current:
                    var target = self._implications[i][1]
                    if target == trigger:
                        raise Error(
                            "Implication cycle detected: adding '"
                            + trigger
                            + "' implies '"
                            + implied
                            + "' would create a cycle"
                        )
                    # Only visit each node once.
                    var already = False
                    for v in range(len(visited)):
                        if visited[v] == target:
                            already = True
                            break
                    if not already:
                        visited.append(target)
                        stack.append(target)
        # Store [trigger, implied, kind] triple.  The kind is used by
        # _apply_implications() to set the correct result field without
        # re-scanning self.args at parse time.
        var imp_triple: List[String] = [trigger, implied, implied_kind]
        self._implications.append(imp_triple^)

    # ── Subcommand behavior ──

    def command_aliases(mut self, var names: List[String]):
        """Registers alternate names for this command when used as a subcommand.

        Aliases are matched during subcommand dispatch and included in
        shell completion scripts, but they do **not** appear as separate
        entries in the ``Commands:`` help section.  Instead, aliases are
        shown inline next to the primary name.

        Args:
            names: The list of alias strings.

        Examples:

        ```mojo
        from argmojo import Command
        var clone = Command("clone", "Clone a repository")
        var aliases: List[String] = ["cl"]
        clone.command_aliases(aliases^)
        # Now: mgit cl ... is equivalent to mgit clone ...
        ```
        """
        for i in range(len(names)):
            self._command_aliases.append(names[i])

    def hidden(mut self):
        """Marks this subcommand as hidden.

        A hidden subcommand is excluded from help output, shell completion
        scripts, and the "Available commands" error message, but remains
        dispatchable by exact name or alias.  Useful for internal,
        experimental, or deprecated subcommands.

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "A sample application")
        var debug = Command("debug", "Internal debug command")
        debug.hidden()
        app.add_subcommand(debug^)
        # 'debug' won't appear in --help or completions, but:
        #   app debug ...   still works
        ```
        """
        self._is_hidden = True

    def disable_help_subcommand(mut self):
        """Opts out of the auto-added ``help`` subcommand.

        By default, the first call to ``add_subcommand()`` automatically
        registers a ``help`` subcommand so that ``app help <sub>`` works as
        an alias for ``app <sub> --help``.

        Call this before or after ``add_subcommand()`` to suppress the
        feature — useful when ``"help"`` is a legitimate first positional
        value (e.g. a search pattern or entity name).  After disabling, use
        ``app <sub> --help`` directly.

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("search", "Search engine")
        app.disable_help_subcommand()   # "help" is a valid search query
        # Now: ``search help init``  →  positionals ["help", "init"] on root,
        #    so that you can do something like: search "help" in path "init".
        #    ``search init --help``  →  shows init's help page
        ```
        """
        self._help_subcommand_enabled = False
        # Remove any already-inserted help subcommand.
        var new_subs = List[Command]()
        for i in range(len(self.subcommands)):
            if not self.subcommands[i]._is_help_subcommand:
                new_subs.append(self.subcommands[i].copy())
        self.subcommands = new_subs^

    def allow_positional_with_subcommands(mut self):
        """Allows a Command to have both positional args and subcommands.

        By default, ArgMojo follows the convention of cobra (Go) and clap
        (Rust): a Command with subcommands cannot also have positional
        arguments, because the parser cannot unambiguously distinguish a
        subcommand name from a positional value.

        Call this method **before** registering positional args and
        subcommands to opt in to the mixed mode.  In mixed mode, a token
        that exactly matches a registered subcommand name is dispatched;
        any other token falls through to the positional list.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var app = Command("tool", "Flexible tool")
        app.allow_positional_with_subcommands()
        app.add_argument(Argument("target", help="Default target").positional())
        var sub = Command("build", "Build the project")
        app.add_subcommand(sub^)
        # Now: tool build    → dispatch to 'build' subcommand
        #      tool foo.txt  → positional "foo.txt"
        ```
        """
        self._allow_positional_with_subcommands = True

    # ── Parser behavior ──

    def help_on_no_arguments(mut self) raises:
        """Enables showing help when invoked with no arguments.

        When enabled, calling the command with no arguments (only the
        program name) will print the help message and exit.

        Raises:
            Error if any registered argument has ``.prompt()`` enabled,
            since prompting is unreachable when help is shown on no args.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("file", help="Input file").long["file"]().required())
        command.help_on_no_arguments()
        ```
        """
        # Guard: conflict with .prompt() arguments.
        for _pi in range(len(self.args)):
            if self.args[_pi]._prompt:
                raise Error(
                    "help_on_no_arguments() cannot be used on a command"
                    " that has .prompt() arguments (argument '"
                    + self.args[_pi].name
                    + "'). When no arguments are provided, help is"
                    " shown and prompting never runs. Remove"
                    " help_on_no_arguments() or .prompt()"
                )
        self._help_on_no_arguments = True

    def allow_negative_numbers(mut self):
        """Treats tokens that look like negative numbers as positional arguments.

        By default ArgMojo already auto-detects negative-number tokens
        (``-9``, ``-3.14``, ``-1.5e10``) and passes them through as
        positionals **when no registered short option starts with a digit**.
        Call this method explicitly when you have registered a digit short
        option (e.g., ``-3`` for ``--triple``) and still need negative-number
        literals to be treated as positionals.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("calc", "Calculator")
        command.allow_negative_numbers()
        command.add_argument(Argument("expr", help="Expression").positional().required())
        # Now: calc -10.18  →  positionals = ["-10.18"]
        ```
        """
        self._allow_negative_numbers = True

    def allow_negative_expressions(mut self):
        """Treats single-hyphen tokens as positional arguments when they
        don't conflict with a known short option.

        This is a superset of ``allow_negative_numbers()`` — it also
        handles mathematical expressions like ``-1/3*pi``, ``-sin(2)``,
        or even arbitrary dash-prefixed strings like ``-e`` (when ``-e``
        is not a registered short option).

        Rules:

        - If the first character after the hyphen does **not** match a
          registered short option, the token is consumed as a positional
          (e.g. ``-1/3*pi`` when ``-1`` is not registered).
        - If the first character **does** match a registered short option,
          the token is parsed normally (merged shorts like ``-vp`` or
          attached values like ``-p10`` continue to work).

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("calc", "Expression calculator")
        command.allow_negative_expressions()
        command.add_argument(Argument("expr", help="Expression").positional().required())
        command.add_argument(Argument("precision", help="Decimal places").long["precision"]().short["p"]())
        # Now: calc "-1/3*pi" -p 10  →  expr = "-1/3*pi", precision = "10"
        ```
        """
        self._allow_negative_expressions = True
        self._allow_negative_numbers = True

    # TODO: response_file_prefix[prefix: StringLiteral](mut self) for compile-time checks
    def response_file_prefix(mut self, prefix: String = "@"):
        """Enables response-file expansion for this command.

        Warning: **Temporarily disabled** — the underlying expansion
        logic is compiled out to work around a Mojo compiler deadlock
        triggered by ``-D ASSERT=all``.  Calling this method still
        stores the prefix, but ``parse_arguments()`` will **not**
        expand response-file tokens until the compiler bug is fixed.

        When enabled, any token that starts with the given ``prefix``
        is treated as a response-file reference.  The remainder of
        the token is the file path; each non-empty, non-comment line
        of that file is inserted as a separate argument in place of
        the original token.

        - Blank lines and lines starting with ``#`` are ignored.
        - Leading / trailing whitespace on each line is stripped.
        - Response files may reference other response files (recursive),
          up to the configured nesting depth (set via
          ``response_file_max_depth[depth]()``; default 10).
        - To pass a literal token that starts with the prefix (e.g. an
          email ``@user``), escape it by doubling the prefix: ``@@user``
          is inserted as ``@user``.

        Args:
            prefix: The prefix character(s) that introduce a response
                file (default ``"@"``).

        Examples:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.response_file_prefix()  # uses default '@'
        # Now: myapp @args.txt  reads arguments from args.txt
        ```
        """
        self._response_file_prefix = prefix

    def response_file_max_depth[depth: Int](mut self) where depth > 0:
        """Sets the maximum nesting depth for response-file expansion.

        Warning: **Temporarily disabled** — see
        ``response_file_prefix()`` docstring for details.

        Parameters:
            depth: Maximum recursion depth (default 10).
                Constraints: must be positive.
        """
        self._response_file_max_depth = depth

    def disable_fullwidth_correction(mut self):
        """Disables automatic full-width → half-width character correction.

        By default, ArgMojo detects fullwidth ASCII characters
        (``U+FF01``–``U+FF5E``) and fullwidth spaces (``U+3000``) in
        option tokens (those starting with ``-``) and auto-corrects them
        to their halfwidth equivalents with a warning.  This helps CJK
        users who forget to switch input methods.

        Call this method to disable that correction entirely — useful
        when strict parsing is preferred.

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My CLI")
        app.disable_fullwidth_correction()
        # Now: －－ｖｅｒｂｏｓｅ is NOT corrected → unknown option error
        ```
        """
        self._disable_fullwidth_correction = True

    def disable_punctuation_correction(mut self):
        """Disables CJK punctuation detection in error recovery.

        By default, when an unknown option is encountered, ArgMojo tries
        substituting common CJK punctuation (e.g. em-dash ``——`` →
        ``--``) before running Levenshtein typo suggestion.  This helps
        CJK users who accidentally type Chinese punctuation.

        Call this method to disable that behaviour — useful when strict
        error messages are preferred.

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My CLI")
        app.disable_punctuation_correction()
        # Now: ——verbose will NOT attempt em-dash → hyphen correction
        ```
        """
        self._disable_punctuation_correction = True

    # ── Interactive & confirmation ──

    def confirmation_option(mut self) raises:
        """Adds a ``--yes`` / ``-y`` flag to skip a confirmation prompt.

        When enabled, the command will prompt the user with
        ``"Are you sure? [y/N]: "`` after parsing (and after interactive
        prompting, if any) but before validation.  If the user does not
        answer ``y`` or ``yes``, the command aborts with an error.

        Passing ``--yes`` or ``-y`` on the command line skips the prompt
        entirely.  This is equivalent to Click's ``confirmation_option``
        decorator.

        Raises:
            Error if a ``--yes`` / ``-y`` argument is already registered.

        Examples:

        ```mojo
        from argmojo import Command, Argument

        var cmd = Command("drop", "Drop the database")
        cmd.add_argument(
            Argument("name", help="Database name")
            .positional().required()
        )
        cmd.confirmation_option()
        # Users must pass --yes (or -y) to skip the prompt:
        #   drop mydb --yes
        ```
        """
        # Guard: reject if --yes or -y is already registered.
        for i in range(len(self.args)):
            if self.args[i]._long_name == "yes":
                raise Error(
                    "confirmation_option: a '--yes' argument is already"
                    " registered"
                )
            if self.args[i]._short_name == "y":
                raise Error(
                    "confirmation_option: a '-y' argument is already registered"
                )
        self._confirmation_enabled = True
        self._confirmation_prompt = String("Are you sure?")
        self.add_argument(
            Argument("yes", help="Skip confirmation prompt")
            .long["yes"]()
            .short["y"]()
            .flag()
        )

    def confirmation_option[prompt: StringLiteral](mut self) raises:
        """Adds a ``--yes`` / ``-y`` flag with a custom confirmation prompt.

        Behaves like ``confirmation_option()`` but uses the provided
        ``prompt`` text instead of the default ``"Are you sure?"``.

        Parameters:
            prompt: The custom prompt text to display.

        Raises:
            Error if a ``--yes`` / ``-y`` argument is already registered.

        Examples:

        ```mojo
        from argmojo import Command, Argument

        var cmd = Command("drop", "Drop the database")
        cmd.add_argument(
            Argument("name", help="Database name")
            .positional().required()
        )
        cmd.confirmation_option["Drop the database? This cannot be undone."]()
        ```
        """
        comptime assert (
            len(prompt) > 0
        ), "confirmation_option: prompt text must not be empty"
        self.confirmation_option()
        self._confirmation_prompt = String(prompt)

    # [Mojo Miji]
    # `name` is a type parameter (StringLiteral) rather than a runtime
    # argument so that the colour name is validated at compile time.
    # This ensures developers get a compiler error for invalid colour
    # names during development, instead of end users seeing runtime
    # failures caused by a misspelled or unsupported colour.

    # ── Help & display ──

    def usage(mut self, text: String):
        """Sets a custom usage line, replacing the auto-generated one.

        By default, ArgMojo generates a usage line like::

            Usage: myapp <file> [OPTIONS]

        Call this method to override it with a completely custom string.
        The string should **not** include the ``Usage:`` prefix — it will
        be added automatically.

        Args:
            text: The custom usage text (e.g. ``"myapp [-v | --version]
                [-C <path>] <command> [<args>]"``).

        Examples:

        ```mojo
        from argmojo import Command
        var cmd = Command("git", "The stupid content tracker")
        cmd.usage("git [-v | --version] [-C <path>] <command> [<args>]")
        # --help will show:
        #   Usage: git [-v | --version] [-C <path>] <command> [<args>]
        ```
        """
        self._custom_usage = text

    def add_tip(mut self, tip: String):
        """Adds a custom tip line to the bottom of the help message.

        Each tip is printed on its own line below the built-in ``--``
        separator hint, prefixed with a bold ``Tip:`` label.  Useful for
        documenting shell idioms, environment variables, or any other
        usage notes that don't fit in argument help strings.

        Args:
            tip: The tip text to display.

        Examples:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_tip("Set MYAPP_DEBUG=1 to enable debug logging.")
        command.add_tip("Config file: ~/.config/myapp/config.toml")
        ```
        """
        self._tips.append(tip)

    # TODO: alias_name[name: StringLiteral](mut self) for compile-time checks
    def header_color[name: StringLiteral](mut self):
        """Sets the colour for section headers (Usage, Arguments, Options).

        Headers are always rendered in **bold + underline**; this method
        controls only the foreground colour.

        Accepted colour names: ``RED``, ``GREEN``, ``YELLOW``, ``BLUE``,
        ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``, ``ORANGE``.
        Invalid names are caught at compile time.

        Parameters:
            name: The colour name.

        Examples:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.header_color["YELLOW"]()
        ```
        """
        self._header_color = _resolve_color[name]()

    def arg_color[name: StringLiteral](mut self):
        """Sets the colour for option and argument names in help output.

        Accepted colour names: ``RED``, ``GREEN``, ``YELLOW``, ``BLUE``,
        ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``, ``ORANGE``.
        Invalid names are caught at compile time.

        Parameters:
            name: The colour name.

        Examples:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.arg_color["GREEN"]()
        ```
        """
        self._arg_color = _resolve_color[name]()

    def warn_color[name: StringLiteral](mut self):
        """Sets the colour for deprecation warning messages.

        Accepted colour names: ``RED``, ``GREEN``, ``YELLOW``, ``BLUE``,
        ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``, ``ORANGE``.
        Invalid names are caught at compile time.

        Parameters:
            name: The colour name.

        Examples:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.warn_color["YELLOW"]()
        ```
        """
        self._warn_color = _resolve_color[name]()

    def error_color[name: StringLiteral](mut self):
        """Sets the colour for parse error messages.

        Accepted colour names: ``RED``, ``GREEN``, ``YELLOW``, ``BLUE``,
        ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``, ``ORANGE``.
        Invalid names are caught at compile time.

        Parameters:
            name: The colour name.

        Examples:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.error_color["MAGENTA"]()
        ```
        """
        self._error_color = _resolve_color[name]()

    # ── Shell completions ──

    def disable_default_completions(mut self):
        """Disables the built-in completion trigger entirely.

        By default, every ``Command`` has a built-in ``--completions bash``
        (or ``zsh`` / ``fish``) that prints a shell completion script and
        exits.  Call this method to remove that trigger completely.

        The ``generate_completion()`` method is still available for
        programmatic use — only the automatic trigger is removed.

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My CLI")
        app.disable_default_completions()
        # --completions is now an unknown option
        # but app.generate_completion["bash"]() still works
        ```
        """
        self._completions_enabled = False

    def completions_name(mut self, name: String):
        """Sets the name used for the built-in completion trigger.

        Default is ``"completions"`` → ``--completions <shell>``.
        Change to any name you prefer:

        - ``app.completions_name("autocomp")`` → ``--autocomp bash``
        - ``app.completions_name("generate-completions")`` → ``--generate-completions bash``

        Combine with ``completions_as_subcommand()`` to use as a subcommand:

        - ``app.completions_name("comp")`` + ``app.completions_as_subcommand()``
          → ``myapp comp bash``

        Args:
            name: The new trigger name (without ``--`` prefix).

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My CLI")
        app.completions_name("autocomp")
        # Now: myapp --autocomp bash
        ```
        """
        self._completions_name = name

    def completions_as_subcommand(mut self):
        """Switches the built-in completion trigger from an option to a subcommand.

        Default behaviour: ``myapp --completions bash``
        After calling this: ``myapp completions bash``

        Combine with ``completions_name()`` to customise the subcommand name:

        ```mojo
        from argmojo import Command
        var app = Command("decimo", "CLI calculator based on decimo")
        app.completions_name("comp")
        app.completions_as_subcommand()
        # → myapp comp bash
        ```

        The subcommand is auto-registered when ``parse()`` runs. It does
        **not** appear in help output by default (like the ``help``
        subcommand). The auto-registered subcommand takes one positional
        argument (the shell name) and handles printing + exiting.
        """
        self._completions_is_subcommand = True

    # ===------------------------------------------------------------------=== #
    # Private output helpers
    # ===------------------------------------------------------------------=== #

    @staticmethod
    def _no_color_env() -> Bool:
        """Returns True when the ``NO_COLOR`` environment variable is set.

        Follows the `no-color.org <https://no-color.org/>`_ standard:
        any value (including empty string) counts as "set".  Only a
        genuinely *unset* variable returns ``False``.

        Implementation note: we use a long, printable sentinel as the
        ``getenv`` default.  If the returned value differs from the
        sentinel, ``NO_COLOR`` is set (even to an empty string).  A raw
        null-byte sentinel (``"\x00"``) cannot be used because the Mojo
        compiler on Linux crashes when it encounters one during
        ``mojo package``.

        Returns:
            True if ``NO_COLOR`` is set (to any value), False otherwise.
        """
        comptime _SENTINEL = "__ARGMOJO_NO_COLOR_UNSET_SENTINEL__"
        return getenv("NO_COLOR", _SENTINEL) != _SENTINEL

    def _warn(self, msg: String):
        """Prints a coloured warning message to stderr."""
        if Self._no_color_env():
            print("warning: " + msg, file=stderr)
        else:
            print(self._warn_color + "warning: " + msg + _RESET, file=stderr)

    def _preprocess_cjk_args(self, mut args: List[String]):
        """Applies fullwidth and CJK punctuation auto-correction to *args*.

        Two passes:
        1. Fullwidth → halfwidth (``U+FF01``–``U+FF5E``, ``U+3000``).
        2. CJK punctuation substitution (e.g. em-dash ``U+2014`` → ``-``).

        Each pass is skipped when the corresponding disable flag is set.
        Warnings are emitted for every corrected option token.
        """
        # Pass 1: fullwidth → halfwidth.
        if not self._disable_fullwidth_correction:
            var corrected_args = List[String]()
            corrected_args.append(args[0])  # preserve argv[0]
            for _fw_i in range(1, len(args)):
                var token = args[_fw_i]
                if _has_fullwidth_chars(token):
                    var parts = _split_on_fullwidth_spaces(token)
                    for _fw_j in range(len(parts)):
                        var corrected = parts[_fw_j]
                        if corrected.startswith("-"):
                            self._warn(
                                "detected full-width characters in '"
                                + token
                                + "', auto-corrected to '"
                                + corrected
                                + "'"
                            )
                        corrected_args.append(corrected)
                else:
                    corrected_args.append(token)
            args = corrected_args^

        # Pass 2: CJK punctuation (e.g. em-dash → hyphen-minus).
        if not self._disable_punctuation_correction:
            var punc_args = List[String]()
            punc_args.append(args[0])
            for _pi in range(1, len(args)):
                var token = args[_pi]
                var corrected = _correct_cjk_punctuation(token)
                if corrected != token and corrected.startswith("-"):
                    self._warn(
                        "detected CJK punctuation in '"
                        + token
                        + "', auto-corrected to '"
                        + corrected
                        + "'"
                    )
                    punc_args.append(corrected)
                else:
                    punc_args.append(token)
            args = punc_args^

    def _error(self, msg: String) raises:
        """Prints a coloured error message to stderr then raises.

        All parse-time errors funnel through this method so that callers
        of both ``parse()`` and ``parse_arguments()`` always see coloured output
        while tests can still catch the raised ``Error`` normally.
        The command name is included in the stderr output so that errors
        from subcommands show the full path (e.g. ``app search: ...``).
        """
        if Self._no_color_env():
            print(
                "error: " + self.name + ": " + msg,
                file=stderr,
            )
        else:
            print(
                self._error_color + "error: " + self.name + ": " + msg + _RESET,
                file=stderr,
            )
        raise Error(msg)

    def _error_with_usage(self, msg: String) raises:
        """Prints a coloured error with a usage hint and help tip, then raises.

        Used for validation errors (missing required args, too many positionals)
        where showing the usage line helps the user understand what is expected.
        """
        if Self._no_color_env():
            print(
                "error: " + self.name + ": " + msg,
                file=stderr,
            )
        else:
            print(
                self._error_color + "error: " + self.name + ": " + msg + _RESET,
                file=stderr,
            )
        print(
            "\n" + self._plain_usage(),
            file=stderr,
        )
        print(
            "For more information, try '" + self.name + " --help'.",
            file=stderr,
        )
        raise Error(msg)

    def _plain_usage(self) -> String:
        """Returns a plain-text usage line (no ANSI colours).

        Example output: ``Usage: git clone <repository> [directory] [OPTIONS]``
        """
        if self._custom_usage:
            return String("Usage: ") + self._custom_usage
        var s = String("Usage: ") + self.name
        for i in range(len(self.args)):
            if self.args[i]._is_positional and not self.args[i]._is_hidden:
                var display = self.args[i].name
                if self.args[i]._is_remainder:
                    display += "..."
                if self.args[i]._is_required:
                    s += " <" + display + ">"
                else:
                    s += " [" + display + "]"
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if (
                not self.subcommands[i]._is_help_subcommand
                and not self.subcommands[i]._is_hidden
            ):
                has_subcommands = True
                break
        if has_subcommands:
            s += " <COMMAND>"
        s += " [OPTIONS]"
        return s

    # ===------------------------------------------------------------------=== #
    # Public parse methods
    # ===------------------------------------------------------------------=== #

    def parse(self) raises -> ParseResult:
        """Parses command-line arguments from ``sys.argv()``.

        Errors from parsing (missing/invalid arguments, validation failures)
        are printed in colour to stderr and the process exits with code 2.
        This matches the behaviour of Python's ``argparse``.

        Use ``parse_arguments()`` directly if you want to catch errors yourself.

        Returns:
            A ParseResult containing all parsed values.
        """
        var raw_variadic = argv()
        var raw = List[String]()
        for i in range(len(raw_variadic)):
            raw.append(String(raw_variadic[i]))
        try:
            return self.parse_arguments(raw)
        except:
            # Error message was already printed to stderr by _error().
            exit(2)
            # Unreachable — exit() terminates the process — but the
            # compiler does not model exit() as @noreturn yet.
            return ParseResult()

    def parse_arguments(self, raw_args: List[String]) raises -> ParseResult:
        """Parses the given argument list.

        The first element, e.g., ``argv[0]``, is expected to be the program name
        and is skipped.

        Args:
            raw_args: The raw argument strings (including program name at index 0).

        Returns:
            A ParseResult containing all parsed values.

        Raises:
            Error on invalid or missing arguments.

        Notes:

        The modifier for ``self`` is ``read`` but not ``mut``. This ensures that the
        parsing process does not mutate the Command instance itself, which
        prevents contamination and conflicts between multiple parses, e.g.,
        in testing scenarios, REPL usage, and autocompletion.
        """

        # Here is a high-level outline of the parsing algorithm implemented in
        # ``parse_arguments``:
        #
        # 1. Initialize ParseResult and register positional names.
        # 2. If ``help_on_no_arguments`` is enabled and only argv[0] is present:
        #    print help and exit.
        # 3. Iterate from argv[1] with cursor ``i``:
        #    ├─ If token is "--": enter positional-only mode.
        #    ├─ If in positional-only mode: append token to positionals.
        #    ├─ If token is --help / -h / -?: print help and exit.
        #    ├─ If token is --version / -V: print version and exit.
        #    ├─ If token starts with "--":
        #    │  Parse long option
        #    │   ├─ Support --key=value split.
        #    │   ├─ Support --no-key for negatable flags (with prefix matching).
        #    │   ├─ Resolve by exact long name → exact alias → prefix match.
        #    │   ├─ Emit deprecation warning if the matched arg is deprecated.
        #    │   ├─ Handle count / flag / nargs / map / value-taking variants.
        #    │   └─ For append args, store via delimiter-aware append logic.
        #    ├─ If token starts with "-" and len > 1:
        #    │  Parse short option(s)
        #    │   ├─ Single short: deprecation warning / count / flag / nargs / map / value.
        #    │   └─ Multi-short: merged flags and attached value forms.
        #    └─ Otherwise (bare word):
        #       ├─ Subcommands registered + "help <sub>": print child help & exit.
        #       ├─ Subcommands registered + token matches subcommand name:
        #       │   build child argv, call child.parse_arguments(), store result, break.
        #       └─ Otherwise: treat as positional argument.
        # 4. Apply defaults for missing args (named + positional slots).
        # 5. Validate:
        #    ├─ Required args
        #    ├─ Positional count (too many)
        #    ├─ Mutually-exclusive groups
        #    ├─ Required-together groups
        #    ├─ One-required groups
        #    ├─ Conditional requirements
        #    └─ Numeric range constraints
        # 6. Return ParseResult.

        var result = ParseResult()

        # Expand response files if enabled.
        var args_to_parse = raw_args.copy()
        # NOTE: Response file expansion temporarily disabled to work around
        # Mojo compiler deadlock with -D ASSERT=all.  The module-level
        # _expand_response_files / _read_response_file functions are still
        # available and tested; only the automatic call from parse_arguments
        # is commented out.
        # if len(self._response_file_prefix) > 0:
        #     args_to_parse = _expand_response_files(
        #         raw_args,
        #         self._response_file_prefix,
        #         self._response_file_max_depth,
        #         self.name,
        #     )

        # ── CJK auto-correction (fullwidth + punctuation) ───────────
        self._preprocess_cjk_args(args_to_parse)

        # Register positional argument names in order.
        for i in range(len(self.args)):
            if self.args[i]._is_positional:
                result._positional_names.append(self.args[i].name)

        # Skip argv[0] and start from argv[1].
        var i: Int = 1
        var stop_parsing_options = False

        # Show help when invoked with no arguments (if enabled).
        if self._help_on_no_arguments and len(args_to_parse) <= 1:
            print(self._generate_help())
            exit(0)

        # === PARSING PHASE === #

        # Check if there is a remainder positional and which slot it is.
        var remainder_pos_idx: Int = -1
        for _ri in range(len(self.args)):
            if self.args[_ri]._is_remainder:
                # Find its positional slot index.
                var slot: Int = 0
                for _rj in range(len(self.args)):
                    if self.args[_rj]._is_positional:
                        if self.args[_rj].name == self.args[_ri].name:
                            remainder_pos_idx = slot
                            break
                        slot += 1
                break

        while i < len(args_to_parse):
            var arg = args_to_parse[i]

            # Handle "--" stop marker.
            if arg == "--" and not stop_parsing_options:
                stop_parsing_options = True
                i += 1
                continue

            if stop_parsing_options:
                result._positionals.append(arg)
                i += 1
                continue

            # ── Remainder mode: if the current positional slot is a
            # remainder argument, consume ALL remaining tokens verbatim. ──
            if (
                remainder_pos_idx >= 0
                and len(result._positionals) >= remainder_pos_idx
            ):
                # We've reached or passed the remainder slot — consume everything.
                result._positionals.append(arg)
                i += 1
                continue

            # Handle --help / -h / -?
            if arg == "--help" or arg == "-h" or arg == "-?":
                print(self._generate_help())
                exit(0)

            # Handle --version / -V
            if arg == "--version" or arg == "-V":
                print(self.name + " " + self.version)
                exit(0)

            # Handle --<completions_name> <shell>  (built-in, like --help/--version)
            if (
                self._completions_enabled
                and not self._completions_is_subcommand
                and arg == "--" + self._completions_name
            ):
                if i + 1 < len(args_to_parse):
                    i += 1
                    var shell_arg = args_to_parse[i]
                    try:
                        print(self.generate_completion(shell_arg))
                    except e:
                        self._error(String(e))
                        exit(2)
                    exit(0)
                else:
                    self._error(
                        "--"
                        + self._completions_name
                        + " requires a shell name: bash, zsh, or fish"
                    )
                    exit(2)

            # ── allow_hyphen_values ──────────────────────────────────
            # If the next positional slot accepts dash-prefixed tokens
            # and this token is NOT a known option, consume as positional.
            if arg.startswith("-") and len(arg) > 1:
                var _ahv_consumed = False
                var _ahv_slot = len(result._positionals)
                if _ahv_slot < len(result._positional_names):
                    var _ahv_name = result._positional_names[_ahv_slot]
                    for _ai in range(len(self.args)):
                        if (
                            self.args[_ai].name == _ahv_name
                            and self.args[_ai]._allow_hyphen_values
                        ):
                            if not self._is_known_option(arg):
                                result._positionals.append(arg)
                                i += 1
                                _ahv_consumed = True
                            break
                if _ahv_consumed:
                    continue
            # ────────────────────────────────────────────────────────

            # Long option: --key, --key=value, --key value
            if arg.startswith("--"):
                i = self._parse_long_option(args_to_parse, i, result)
                continue

            # Short option: -k, -k value, -abc (merged flags), -ofile.txt
            if arg.startswith("-") and len(arg) > 1:
                # ── Negative-number detection (argparse-style) ──────────────
                # A token like "-10.18e3" is treated as a positional value when:
                #   (a) allow_negative_numbers() was called explicitly, OR
                #   (b) the token looks numeric AND no registered short option
                #       uses a digit character (auto-detect, no naming clash).
                if _looks_like_number(arg):
                    var has_digit_short = False
                    for _ni in range(len(self.args)):
                        var sn = self.args[_ni]._short_name
                        if sn >= "0" and sn <= "9":
                            has_digit_short = True
                            break
                    if self._allow_negative_numbers or not has_digit_short:
                        result._positionals.append(arg)
                        i += 1
                        continue
                # ────────────────────────────────────────────────────────────
                # ── Negative-expression detection ───────────────────────────
                # A token like "-1/3*pi" is treated as a positional when
                # allow_negative_expressions() was called, but only if
                # the first character does not match a registered short
                # option.  This preserves merged shorts (-vp) and
                # attached values (-p10) that start with a known flag.
                if self._allow_negative_expressions:
                    var _ne_key = String(arg[byte=1:])
                    var _ne_first = String(_ne_key[byte=:1])
                    var _ne_short_conflict = False
                    for _nei in range(len(self.args)):
                        if self.args[_nei]._short_name == _ne_first:
                            _ne_short_conflict = True
                            break
                    if not _ne_short_conflict:
                        result._positionals.append(arg)
                        i += 1
                        continue
                # ────────────────────────────────────────────────────────────
                var key = String(arg[byte=1:])
                if len(key) == 1:
                    i = self._parse_short_single(key, args_to_parse, i, result)
                else:
                    i = self._parse_short_merged(key, args_to_parse, i, result)
                continue

            # Positional argument — check for subcommand dispatch first.
            # Built-in completions subcommand (when in subcommand mode).
            if (
                self._completions_enabled
                and self._completions_is_subcommand
                and arg == self._completions_name
            ):
                if i + 1 < len(args_to_parse):
                    i += 1
                    var shell_arg = args_to_parse[i]
                    try:
                        print(self.generate_completion(shell_arg))
                    except e:
                        self._error(String(e))
                        exit(2)
                    exit(0)
                else:
                    self._error(
                        self._completions_name
                        + " requires a shell name: bash, zsh, or fish"
                    )
                    exit(2)
            if len(self.subcommands) > 0:
                var new_i = self._dispatch_subcommand(
                    arg, args_to_parse, i, result
                )
                if new_i >= 0:
                    i = new_i
                    continue

            result._positionals.append(arg)
            i += 1

        # Apply defaults, propagate implications, prompt for remaining
        # values, re-apply implications (in case prompts triggered new
        # ones), confirm if required, then validate constraints.
        self._apply_defaults(result)
        self._apply_implications(result)
        self._prompt_missing_args(result)
        self._apply_implications(result)
        self._confirm(result)
        self._validate(result)

        return result^

    def parse_known_arguments(
        self, raw_args: List[String]
    ) raises -> ParseResult:
        """Parses known arguments, collecting unrecognised ones.

        Behaves like ``parse_arguments()`` but does **not** error on
        unknown options.  Instead, unrecognised tokens are stored in the
        result and can be retrieved via ``result.get_unknown_args()``.

        This is useful for wrapper CLIs that forward unknown flags to
        another tool, or for incremental/phased parsing.

        Args:
            raw_args: The raw argument strings (including program name at
                index 0).

        Returns:
            A ParseResult whose ``get_unknown_args()`` contains any
            tokens that did not match a registered argument.

        Raises:
            Error on validation failures (required args, groups, etc.)
            — only *unknown-option* errors are suppressed.


        Notes:

        Unknown options using ``=`` syntax (e.g. ``--color=auto``) are
        captured as a single token in the unknown list.  For space-
        separated syntax (``--color auto``), only ``--color`` is
        recorded as unknown; ``auto`` flows to positional arguments
        because the parser cannot determine whether the unknown option
        takes a value.  Prefer ``=`` syntax when forwarding unknown
        options reliably.
        """
        var result = ParseResult()

        var args_to_parse = raw_args.copy()

        # ── CJK auto-correction (fullwidth + punctuation) ───────────
        self._preprocess_cjk_args(args_to_parse)

        # Register positional argument names in order.
        for i in range(len(self.args)):
            if self.args[i]._is_positional:
                result._positional_names.append(self.args[i].name)

        var i: Int = 1
        var stop_parsing_options = False

        if self._help_on_no_arguments and len(args_to_parse) <= 1:
            print(self._generate_help())
            exit(0)

        # Remainder positional detection (same as parse_arguments).
        var remainder_pos_idx: Int = -1
        for _ri in range(len(self.args)):
            if self.args[_ri]._is_remainder:
                var slot: Int = 0
                for _rj in range(len(self.args)):
                    if self.args[_rj]._is_positional:
                        if self.args[_rj].name == self.args[_ri].name:
                            remainder_pos_idx = slot
                            break
                        slot += 1
                break

        while i < len(args_to_parse):
            var arg = args_to_parse[i]

            if arg == "--" and not stop_parsing_options:
                stop_parsing_options = True
                i += 1
                continue

            if stop_parsing_options:
                result._positionals.append(arg)
                i += 1
                continue

            # Remainder mode.
            if (
                remainder_pos_idx >= 0
                and len(result._positionals) >= remainder_pos_idx
            ):
                result._positionals.append(arg)
                i += 1
                continue

            # --help / -h / -?
            if arg == "--help" or arg == "-h" or arg == "-?":
                print(self._generate_help())
                exit(0)

            # --version / -V
            if arg == "--version" or arg == "-V":
                print(self.name + " " + self.version)
                exit(0)

            # Completions (long-option form).
            if (
                self._completions_enabled
                and not self._completions_is_subcommand
                and arg == "--" + self._completions_name
            ):
                if i + 1 < len(args_to_parse):
                    i += 1
                    var shell_arg = args_to_parse[i]
                    try:
                        print(self.generate_completion(shell_arg))
                    except e:
                        self._error(String(e))
                        exit(2)
                    exit(0)
                else:
                    self._error(
                        "--"
                        + self._completions_name
                        + " requires a shell name: bash, zsh, or fish"
                    )
                    exit(2)

            # ── allow_hyphen_values (same logic as parse_arguments) ──
            if arg.startswith("-") and len(arg) > 1:
                var _ahv_consumed = False
                var _ahv_slot = len(result._positionals)
                if _ahv_slot < len(result._positional_names):
                    var _ahv_name = result._positional_names[_ahv_slot]
                    for _ai in range(len(self.args)):
                        if (
                            self.args[_ai].name == _ahv_name
                            and self.args[_ai]._allow_hyphen_values
                        ):
                            if not self._is_known_option(arg):
                                result._positionals.append(arg)
                                i += 1
                                _ahv_consumed = True
                            break
                if _ahv_consumed:
                    continue
            # ────────────────────────────────────────────────────────

            # Long option — try to parse; collect as unknown if it fails.
            if arg.startswith("--"):
                try:
                    i = self._parse_long_option(args_to_parse, i, result)
                except:
                    result._unknown_args.append(arg)
                    i += 1
                continue

            # Short option — try to parse; collect as unknown if it fails.
            if arg.startswith("-") and len(arg) > 1:
                if _looks_like_number(arg):
                    var has_digit_short = False
                    for _ni in range(len(self.args)):
                        var sn = self.args[_ni]._short_name
                        if sn >= "0" and sn <= "9":
                            has_digit_short = True
                            break
                    if self._allow_negative_numbers or not has_digit_short:
                        result._positionals.append(arg)
                        i += 1
                        continue
                # ── Negative-expression detection (same as parse_arguments) ──
                if self._allow_negative_expressions:
                    var _ne_key = String(arg[byte=1:])
                    var _ne_first = String(_ne_key[byte=:1])
                    var _ne_short_conflict = False
                    for _nei in range(len(self.args)):
                        if self.args[_nei]._short_name == _ne_first:
                            _ne_short_conflict = True
                            break
                    if not _ne_short_conflict:
                        result._positionals.append(arg)
                        i += 1
                        continue
                # ─────────────────────────────────────────────────────────────
                try:
                    var key = String(arg[byte=1:])
                    if len(key) == 1:
                        i = self._parse_short_single(
                            key, args_to_parse, i, result
                        )
                    else:
                        i = self._parse_short_merged(
                            key, args_to_parse, i, result
                        )
                except:
                    result._unknown_args.append(arg)
                    i += 1
                continue

            # Completions subcommand.
            if (
                self._completions_enabled
                and self._completions_is_subcommand
                and arg == self._completions_name
            ):
                if i + 1 < len(args_to_parse):
                    i += 1
                    var shell_arg = args_to_parse[i]
                    try:
                        print(self.generate_completion(shell_arg))
                    except e:
                        self._error(String(e))
                        exit(2)
                    exit(0)
                else:
                    self._error(
                        self._completions_name
                        + " requires a shell name: bash, zsh, or fish"
                    )
                    exit(2)

            # Subcommand dispatch.
            if len(self.subcommands) > 0:
                var new_i = self._dispatch_subcommand(
                    arg, args_to_parse, i, result
                )
                if new_i >= 0:
                    i = new_i
                    continue

            result._positionals.append(arg)
            i += 1

        self._apply_defaults(result)
        self._apply_implications(result)
        self._validate(result)

        return result^

    # ===------------------------------------------------------------------=== #
    # Parsing sub-methods (extracted from parse_arguments for readability)
    # ===------------------------------------------------------------------=== #

    def _parse_long_option(
        self, raw_args: List[String], start: Int, mut result: ParseResult
    ) raises -> Int:
        """Parses a long option token (``--key``, ``--key=value``, ``--no-X``).

        Handles exact match, prefix matching, negation (``--no-X``),
        count flags, boolean flags, nargs, value-taking options,
        append/collect, map, delimiter splitting, and deprecation
        warnings.

        Args:
            raw_args: The full argument list.
            start: Index of the current ``--key`` token.
            result: The ParseResult to store into.

        Returns:
            The index of the next token to process.
        """
        var i = start
        var arg = raw_args[i]
        var key = String(arg[byte=2:])  # strip leading "--"
        var value = String("")
        var has_eq = False

        # Check for --key=value format.
        var eq_pos = key.find("=")
        if eq_pos >= 0:
            # Split into key and value parts.
            value = String(key[byte = eq_pos + 1 :])
            key = String(key[byte=:eq_pos])
            has_eq = True

        # Check for --no-X negation pattern (with prefix matching).
        var is_negation = False
        if key.startswith("no-") and not has_eq:
            var base_key = String(key[byte=3:])
            # Exact match first.
            for idx in range(len(self.args)):
                if (
                    self.args[idx]._long_name == base_key
                    and self.args[idx]._is_negatable
                ):
                    is_negation = True
                    key = base_key
                    break
            # Prefix match if no exact match found.
            if not is_negation:
                var neg_candidates = List[String]()
                var neg_idx: Int = -1
                for idx in range(len(self.args)):
                    if (
                        self.args[idx]._long_name
                        and self.args[idx]._long_name.startswith(base_key)
                        and self.args[idx]._is_negatable
                    ):
                        neg_candidates.append(self.args[idx]._long_name)
                        neg_idx = idx
                if len(neg_candidates) == 1:
                    is_negation = True
                    key = self.args[neg_idx]._long_name
                elif len(neg_candidates) > 1:
                    var opts = String("")
                    for j in range(len(neg_candidates)):
                        if j > 0:
                            opts += ", "
                        opts += "'--no-" + neg_candidates[j] + "'"
                    self._error(
                        "Ambiguous option '--no-"
                        + base_key
                        + "' could match: "
                        + opts
                    )

        var matched: Argument = self._find_by_long(key)
        # Emit deprecation warning if applicable.
        if matched._deprecated_msg:
            self._warn(
                "'--" + key + "' is deprecated: " + matched._deprecated_msg
            )
        if is_negation:
            result._flags[matched.name] = False
        elif matched._is_count and not has_eq:
            # Count flag: increment counter.
            var cur: Int = 0
            try:
                cur = result._counts[matched.name]
            except:
                pass
            result._counts[matched.name] = cur + 1
        elif matched._is_flag and not has_eq:
            result._flags[matched.name] = True
        elif matched._number_of_values > 0:
            # nargs: consume exactly N values.
            if has_eq:
                self._error(
                    "Option '--"
                    + key
                    + "' takes "
                    + String(matched._number_of_values)
                    + " values; '=' syntax is not supported"
                )
            if matched.name not in result._lists:
                result._lists[matched.name] = List[String]()
            for _n in range(matched._number_of_values):
                i += 1
                if i >= len(raw_args):
                    self._error(
                        "Option '--"
                        + key
                        + "' requires "
                        + String(matched._number_of_values)
                        + " values"
                    )
                self._validate_choices(matched, raw_args[i])
                result._lists[matched.name].append(raw_args[i])
        else:
            if not has_eq:
                if matched._require_equals:
                    if matched._has_default_if_no_value:
                        # No '=' given — use default-if-no-value.
                        value = matched._default_if_no_value
                    else:
                        self._error(
                            "Option '--"
                            + key
                            + "' requires '=' syntax (use --"
                            + key
                            + "=VALUE)"
                        )
                else:
                    i += 1
                    if i >= len(raw_args):
                        self._error("Option '--" + key + "' requires a value")
                    value = raw_args[i]
            if matched._is_map:
                self._store_map_value(matched, value, result)
            elif matched._is_append:
                self._store_append_value(matched, value, result)
            else:
                self._validate_choices(matched, value)
                result._values[matched.name] = value
        i += 1
        return i

    def _parse_short_single(
        self,
        key: String,
        raw_args: List[String],
        start: Int,
        mut result: ParseResult,
    ) raises -> Int:
        """Parses a single-character short option (``-k``, ``-k value``).

        Args:
            key: The short option character (without ``-``).
            raw_args: The full argument list.
            start: Index of the current ``-k`` token.
            result: The ParseResult to store into.

        Returns:
            The index of the next token to process.
        """
        var i = start
        var matched = self._find_by_short(key)
        # Emit deprecation warning if applicable.
        if matched._deprecated_msg:
            self._warn(
                "'-" + key + "' is deprecated: " + matched._deprecated_msg
            )
        if matched._is_count:
            var cur: Int = 0
            try:
                cur = result._counts[matched.name]
            except:
                pass
            result._counts[matched.name] = cur + 1
        elif matched._is_flag:
            result._flags[matched.name] = True
        elif matched._number_of_values > 0:
            # nargs: consume exactly N values.
            if matched.name not in result._lists:
                result._lists[matched.name] = List[String]()
            for _n in range(matched._number_of_values):
                i += 1
                if i >= len(raw_args):
                    self._error(
                        "Option '-"
                        + key
                        + "' requires "
                        + String(matched._number_of_values)
                        + " values"
                    )
                self._validate_choices(matched, raw_args[i])
                result._lists[matched.name].append(raw_args[i])
        else:
            if matched._has_default_if_no_value:
                # No value given — use default-if-no-value.
                var val = matched._default_if_no_value
                if matched._is_map:
                    self._store_map_value(matched, val, result)
                elif matched._is_append:
                    self._store_append_value(matched, val, result)
                else:
                    self._validate_choices(matched, val)
                    result._values[matched.name] = val
            else:
                i += 1
                if i >= len(raw_args):
                    self._error("Option '-" + key + "' requires a value")
                var val = raw_args[i]
                if matched._is_map:
                    self._store_map_value(matched, val, result)
                elif matched._is_append:
                    self._store_append_value(matched, val, result)
                else:
                    self._validate_choices(matched, val)
                    result._values[matched.name] = val
        i += 1
        return i

    def _parse_short_merged(
        self,
        key: String,
        raw_args: List[String],
        start: Int,
        mut result: ParseResult,
    ) raises -> Int:
        """Parses merged short flags or an attached short value.

        Merged flags: ``-abc`` expands to ``-a -b -c``.
        Attached value: ``-ofile.txt`` means ``-o file.txt``.

        The first character determines the strategy: if it is a flag,
        the entire string is treated as merged flags (with the last
        character potentially taking a value).  Otherwise the rest of
        the string is the attached value.

        Args:
            key: The characters after ``-`` (e.g., ``"abc"`` from ``-abc``).
            raw_args: The full argument list.
            start: Index of the current token.
            result: The ParseResult to store into.

        Returns:
            The index of the next token to process.
        """
        var i = start
        var first_char = String(key[byte=0:1])
        var first_match = self._find_by_short(first_char)

        if first_match._is_flag:
            # First char is a flag — treat entire string as merged
            # flags, except the last char which may take a value.
            var j: Int = 0
            while j < len(key):
                var ch = String(key[byte = j : j + 1])
                var m = self._find_by_short(ch)
                # Emit deprecation warning if applicable.
                if m._deprecated_msg:
                    self._warn(
                        "'-" + ch + "' is deprecated: " + m._deprecated_msg
                    )
                if m._is_count:
                    var cur: Int = 0
                    try:
                        cur = result._counts[m.name]
                    except:
                        pass
                    result._counts[m.name] = cur + 1
                    j += 1
                elif m._is_flag:
                    result._flags[m.name] = True
                    j += 1
                elif m._number_of_values > 0:
                    # nargs in merged flags: rest of string is
                    # ignored; consume N values from argv.
                    if m.name not in result._lists:
                        result._lists[m.name] = List[String]()
                    for _n in range(m._number_of_values):
                        i += 1
                        if i >= len(raw_args):
                            self._error(
                                "Option '-"
                                + ch
                                + "' requires "
                                + String(m._number_of_values)
                                + " values"
                            )
                        self._validate_choices(m, raw_args[i])
                        result._lists[m.name].append(raw_args[i])
                    j = len(key)  # break
                else:
                    # This char takes a value — rest of string is
                    # the value.
                    var val = String(key[byte = j + 1 :])
                    if len(val) == 0:
                        if m._has_default_if_no_value:
                            # No value given — use default-if-no-value,
                            # don't consume next token.
                            val = m._default_if_no_value
                        else:
                            i += 1
                            if i >= len(raw_args):
                                self._error(
                                    "Option '-" + ch + "' requires a value"
                                )
                            val = raw_args[i]
                    if m._is_map:
                        self._store_map_value(m, val, result)
                    elif m._is_append:
                        self._store_append_value(m, val, result)
                    else:
                        self._validate_choices(m, val)
                        result._values[m.name] = val
                    j = len(key)  # break
        else:
            # First char takes a value — rest of string is the
            # attached value (e.g., -ofile.txt).
            # Emit deprecation warning if applicable.
            if first_match._deprecated_msg:
                self._warn(
                    "'-"
                    + first_char
                    + "' is deprecated: "
                    + first_match._deprecated_msg
                )
            if first_match._number_of_values > 0:
                # nargs: consume N values from argv (ignore attached).
                if first_match.name not in result._lists:
                    result._lists[first_match.name] = List[String]()
                for _n in range(first_match._number_of_values):
                    i += 1
                    if i >= len(raw_args):
                        self._error(
                            "Option '-"
                            + first_char
                            + "' requires "
                            + String(first_match._number_of_values)
                            + " values"
                        )
                    self._validate_choices(first_match, raw_args[i])
                    result._lists[first_match.name].append(raw_args[i])
            elif first_match._is_map:
                var val = String(key[byte=1:])
                self._store_map_value(first_match, val, result)
            elif first_match._is_append:
                var val = String(key[byte=1:])
                self._store_append_value(first_match, val, result)
            else:
                var val = String(key[byte=1:])
                self._validate_choices(first_match, val)
                result._values[first_match.name] = val
        i += 1
        return i

    def _dispatch_subcommand(
        self,
        arg: String,
        raw_args: List[String],
        i: Int,
        mut result: ParseResult,
    ) raises -> Int:
        """Attempts to dispatch to a matching subcommand.

        If a subcommand matches, it builds a child argv, injects
        persistent args, parses via the child's ``parse_arguments()``,
        and performs bidirectional sync of persistent values.

        Args:
            arg: The current token (potential subcommand name).
            raw_args: The full argument list.
            i: Index of the current token.
            result: The ParseResult to store into.

        Returns:
            The index of the next token to process if a subcommand was
            dispatched (typically ``len(raw_args)``), or ``-1`` if no
            subcommand matched and the caller should fall through to
            positional argument handling.
        """
        # Exact subcommand (name or alias) match → dispatch.
        var sub_idx = self._find_subcommand(arg)
        if sub_idx >= 0:
            # Resolve canonical name (alias → real name).
            var canon = self.subcommands[sub_idx].name
            # Build child argv: ["parent sub", remaining tokens...].
            var child_argv = List[String]()
            child_argv.append(self.name + " " + canon)
            for k in range(i + 1, len(raw_args)):
                child_argv.append(raw_args[k])
            # Auto-registered 'help' subcommand: display sibling help.
            if self.subcommands[sub_idx]._is_help_subcommand:
                if len(child_argv) > 1:
                    var target_idx = self._find_subcommand(child_argv[1])
                    if (
                        target_idx >= 0
                        and not self.subcommands[target_idx]._is_help_subcommand
                    ):
                        print(self.subcommands[target_idx]._generate_help())
                        exit(0)
                # No target, unknown, or self-referential → root help.
                print(self._generate_help())
                exit(0)
            # Build a child copy with persistent args injected so they
            # are recognised wherever the user places them on the line.
            var child_copy = self.subcommands[sub_idx].copy()
            # Set full command path so child help/errors show "app sub".
            child_copy.name = self.name + " " + canon
            for _pi in range(len(self.args)):
                if self.args[_pi]._is_persistent:
                    child_copy.args.append(self.args[_pi].copy())
            var child_result = child_copy.parse_arguments(child_argv)
            # Bubble up persistent values from child to root result so
            # that root_result.get_flag("x") always works regardless of
            # whether the flag appeared before or after the subcommand
            # token. (If root already parsed the flag before reaching
            # the subcommand token, its value takes precedence.)
            # Also push down root-parsed persistent values to child
            # result so that sub_result.get_flag("x") always works too.
            for _pi in range(len(self.args)):
                if not self.args[_pi]._is_persistent:
                    continue
                var _pn = self.args[_pi].name
                # Bubble up: child parsed flag after subcommand token.
                if _pn in child_result._flags and _pn not in result._flags:
                    result._flags[_pn] = child_result._flags[_pn]
                if _pn in child_result._values and _pn not in result._values:
                    result._values[_pn] = child_result._values[_pn]
                if _pn in child_result._counts and _pn not in result._counts:
                    result._counts[_pn] = child_result._counts[_pn]
                # Push down: root parsed flag before subcommand token.
                if _pn in result._flags and _pn not in child_result._flags:
                    child_result._flags[_pn] = result._flags[_pn]
                if _pn in result._values and _pn not in child_result._values:
                    child_result._values[_pn] = result._values[_pn]
                if _pn in result._counts and _pn not in child_result._counts:
                    child_result._counts[_pn] = result._counts[_pn]
            result.subcommand = canon
            result._subcommand_results.append(child_result^)
            # All remaining tokens were consumed by the child.
            return len(raw_args)
        else:
            # No matching subcommand found.  When positionals are
            # not allowed (the usual case), produce a helpful error.
            # When allow_positional_with_subcommands is set, fall
            # through to positional handling below.
            if not self._allow_positional_with_subcommands:
                var avail = String("")
                var first = True
                for _si in range(len(self.subcommands)):
                    if (
                        not self.subcommands[_si]._is_help_subcommand
                        and not self.subcommands[_si]._is_hidden
                    ):
                        if not first:
                            avail += ", "
                        avail += self.subcommands[_si].name
                        # Append aliases to available list.
                        for _ai in range(
                            len(self.subcommands[_si]._command_aliases)
                        ):
                            avail += (
                                ", "
                                + self.subcommands[_si]._command_aliases[_ai]
                            )
                        first = False
                # Try typo suggestion for subcommand names.
                var sub_names = List[String]()
                for _si2 in range(len(self.subcommands)):
                    if (
                        not self.subcommands[_si2]._is_help_subcommand
                        and not self.subcommands[_si2]._is_hidden
                    ):
                        sub_names.append(self.subcommands[_si2].name)
                        for _ai2 in range(
                            len(self.subcommands[_si2]._command_aliases)
                        ):
                            sub_names.append(
                                self.subcommands[_si2]._command_aliases[_ai2]
                            )
                var suggestion = _suggest_similar(arg, sub_names)
                var hint = String("")
                if suggestion != "":
                    hint = ". Did you mean '" + suggestion + "'?"
                self._error(
                    "Unknown command '"
                    + arg
                    + "'. Available commands: "
                    + avail
                    + hint
                )
            return -1

    # ===------------------------------------------------------------------=== #
    # Confirmation prompt
    # ===------------------------------------------------------------------=== #

    def _confirm(self, result: ParseResult) raises:
        """Prompts the user for confirmation if ``confirmation_option()`` is
        enabled and ``--yes`` / ``-y`` was not passed.

        Aborts with an error if the user does not confirm, or if stdin is
        not interactive (e.g. piped / ``/dev/null``).

        Args:
            result: The parse result (read-only; only checks the ``yes``
                flag).

        Raises:
            Error: If the user declines or stdin is unavailable.
        """
        if not self._confirmation_enabled:
            return
        if result.get_flag("yes"):
            return
        var prompt = self._confirmation_prompt + " [y/N]: "
        var value: String
        try:
            value = input(prompt)
        except:
            self._error("Aborted (no interactive input available)")
            return  # unreachable — _error() always raises; keeps the compiler happy
        var lower = value.lower()
        if lower != "y" and lower != "yes":
            self._error("Aborted")

    # ===------------------------------------------------------------------=== #
    # Interactive prompting
    # ===------------------------------------------------------------------=== #

    def _prompt_missing_args(self, mut result: ParseResult) raises:
        """Prompts the user interactively for arguments marked with ``.prompt()``
        that were not provided on the command line.

        Called after the parsing loop but before ``_apply_defaults()``, so
        that user-provided prompt responses take priority and defaults
        fill in only remaining gaps.  For flag arguments, the prompt
        accepts ``y``/``n`` (case-insensitive).  For arguments with
        choices, valid options are shown.  For arguments with a default,
        the default is displayed in parentheses and used when the user
        enters nothing.

        Prompting is skipped entirely when no arguments have
        ``.prompt()`` enabled.  When stdin is not a terminal (e.g.,
        piped input, CI environments, ``/dev/null``), or when ``input()``
        otherwise raises, the exception is caught, prompting stops
        gracefully, and any values collected so far are preserved.

        Args:
            result: The parse result to mutate in-place.

        Raises:
            Error: If validation or conversion of a prompted value fails.
        """
        # Fast path: skip entirely if no args have prompting enabled.
        var has_prompt_args = False
        for j in range(len(self.args)):
            if self.args[j]._prompt:
                has_prompt_args = True
                break
        if not has_prompt_args:
            return

        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if not a._prompt:
                continue
            if result.has(a.name):
                continue

            # ── Build prompt message ─────────────────────────────────
            var msg: String
            if a._prompt_text:
                msg = a._prompt_text
            elif a.help_text:
                msg = a.help_text
            else:
                msg = a.name

            # Show choices if defined.
            if len(a._choice_values) > 0:
                msg += " ["
                for c in range(len(a._choice_values)):
                    if c > 0:
                        msg += "/"
                    msg += a._choice_values[c]
                msg += "]"

            # Show default if available.
            if a._has_default:
                msg += " (" + a._default_value + ")"

            # Flags get a y/n hint.
            if a._is_flag:
                msg += " [y/n]"

            msg += ": "

            # ── Read input ───────────────────────────────────────────
            var value: String
            if a._hide_input:
                if a._show_asterisk:
                    # Asterisk mode: echo '*' for each keystroke.
                    try:
                        value = _read_password_asterisk(msg)
                    except e:
                        return
                else:
                    # Password mode: disable echo, read, re-enable echo,
                    # then print a newline (since the user's Enter is not
                    # echoed either on some terminals).
                    var saved = _disable_echo()
                    var echo_disabled = len(saved) > 0
                    try:
                        value = input(msg)
                    except e:
                        _ = _restore_echo(saved^)
                        return
                    _ = _restore_echo(saved^)
                    # Print a newline so the cursor moves to the next line
                    # (the user's Enter was not echoed) — only if echo was
                    # actually disabled.
                    if echo_disabled:
                        print()
            else:
                try:
                    value = input(msg)
                except e:
                    # EOF or stdin error — stop prompting entirely.
                    # This handles non-interactive / piped usage gracefully.
                    return

            if len(value) == 0:
                # Empty input — fall through to _apply_defaults.
                continue
            if a._is_flag:
                var lower = value.lower()
                if (
                    lower == "y"
                    or lower == "yes"
                    or lower == "true"
                    or lower == "1"
                ):
                    result._flags[a.name] = True
                elif (
                    lower == "n"
                    or lower == "no"
                    or lower == "false"
                    or lower == "0"
                ):
                    result._flags[a.name] = False
                else:
                    self._warn(
                        "Invalid input for flag '"
                        + a.name
                        + "': expected y/n, got '"
                        + value
                        + "'"
                    )
            elif a._is_count:
                try:
                    result._counts[a.name] = Int(atol(value))
                except:
                    self._warn(
                        "Invalid count for '" + a.name + "': '" + value + "'"
                    )
            elif a._is_positional:
                # Fill the correct positional slot.
                for k in range(len(result._positional_names)):
                    if result._positional_names[k] == a.name:
                        while len(result._positionals) <= k:
                            result._positionals.append("")
                        result._positionals[k] = value
                        break
            elif a._is_map:
                self._store_map_value(a, value, result)
            elif a._is_append or a._number_of_values > 1:
                self._store_append_value(a, value, result)
            else:
                # Validate choices before storing.
                if len(a._choice_values) > 0:
                    self._validate_choices(a, value)
                result._values[a.name] = value

    # ===------------------------------------------------------------------=== #
    # Defaults & validation helpers (extracted for subcommand reuse)
    # ===------------------------------------------------------------------=== #

    def _apply_defaults(self, mut result: ParseResult):
        """Fills in default values for arguments not provided by the user.

        For positional arguments, defaults are placed into the correct slot.
        For named arguments, the default is stored in ``result._values``.

        Args:
            result: The parse result to mutate in-place.

        Notes:

        This method is made standalone so that subcommands can reuse it.
        """
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a._has_default and not result.has(a.name):
                if a._is_positional:
                    # Fill positional to the right slot.
                    for k in range(len(result._positional_names)):
                        if result._positional_names[k] == a.name:
                            while len(result._positionals) <= k:
                                result._positionals.append("")
                            if not result._positionals[k]:
                                result._positionals[k] = a._default_value
                else:
                    result._values[a.name] = a._default_value

        # Populate remainder-positional lists from collected positionals.
        # A remainder arg at positional slot N collects positionals[N:].
        var pos_slot: Int = 0
        for j in range(len(self.args)):
            if self.args[j]._is_positional:
                if self.args[j]._is_remainder:
                    # Always set the remainder list so callers can reliably
                    # get an empty list when no remainder tokens were present.
                    var lst = List[String]()
                    for k in range(pos_slot, len(result._positionals)):
                        lst.append(result._positionals[k])
                    result._lists[self.args[j].name] = lst^
                    break
                pos_slot += 1

    def _apply_implications(self, mut result: ParseResult):
        """Propagates implication rules on the parse result.

        For each registered ``implies(trigger, implied)`` triple, if
        ``trigger`` is present in ``result``, ``implied`` is automatically
        set.  Uses a fixed-point loop to support chained implications
        (A → B → C).

        The implied-argument kind (``"flag"`` or ``"count"``) is stored at
        registration time, so no argument scan is needed here.

        Args:
            result: The parse result to mutate in-place.
        """
        if len(self._implications) == 0:
            return

        # Fixed-point iteration: keep looping until no new values are set.
        var changed = True
        while changed:
            changed = False
            for i in range(len(self._implications)):
                var trigger = self._implications[i][0]
                var implied = self._implications[i][1]
                var kind = self._implications[i][2]  # "flag" or "count"
                if result.has(trigger) and not result.has(implied):
                    if kind == "count":
                        result._counts[implied] = 1
                    else:
                        result._flags[implied] = True
                    changed = True

    def _validate(self, mut result: ParseResult) raises:
        """Runs all post-parse validation checks on the result.

        Checks (in order):
        1. Required arguments are present.
        2. Positional argument count is not exceeded.
        3. Mutually exclusive groups have at most one member set.
        4. Required-together groups are all-or-nothing.
        5. One-required groups have at least one member set.
        6. Conditional requirements are satisfied.
        7. Count ceilings are enforced (clamp + warn).
        8. Numeric range constraints are met (error or clamp + warn).

        Args:
            result: The parse result to validate (may be mutated by clamping).

        Raises:
            Error if any validation check fails.
        """
        # Validate required arguments.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a._is_required and not result.has(a.name):
                self._error_with_usage(
                    "Required argument '" + a.name + "' was not provided"
                )

        # Validate positional argument count — too many args is an error.
        # Skip this check when a remainder positional is registered (it
        # deliberately collects an unbounded number of tokens).
        var has_remainder = False
        for _ri in range(len(self.args)):
            if self.args[_ri]._is_remainder:
                has_remainder = True
                break
        var expected_count: Int = len(result._positional_names)
        if (
            expected_count > 0
            and len(result._positionals) > expected_count
            and not has_remainder
        ):
            self._error_with_usage(
                "Too many positional arguments: expected "
                + String(expected_count)
                + ", got "
                + String(len(result._positionals))
            )

        # Validate mutually exclusive groups.
        for g in range(len(self._exclusive_groups)):
            var found = List[String]()
            for n in range(len(self._exclusive_groups[g])):
                var arg_name = self._exclusive_groups[g][n]
                if result.has(arg_name):
                    found.append(arg_name)
            if len(found) > 1:
                var names_str = String("")
                for f in range(len(found)):
                    if f > 0:
                        names_str += ", "
                    names_str += self._display_name(found[f])
                self._error("Arguments are mutually exclusive: " + names_str)

        # Validate required-together groups.
        for g in range(len(self._required_groups)):
            var provided = List[String]()
            var missing = List[String]()
            for n in range(len(self._required_groups[g])):
                var arg_name = self._required_groups[g][n]
                if result.has(arg_name):
                    provided.append(arg_name)
                else:
                    missing.append(arg_name)
            if len(provided) > 0 and len(missing) > 0:
                var missing_str = String("")
                for m in range(len(missing)):
                    if m > 0:
                        missing_str += ", "
                    missing_str += self._display_name(missing[m])
                var provided_str = String("")
                for p in range(len(provided)):
                    if p > 0:
                        provided_str += ", "
                    provided_str += self._display_name(provided[p])
                self._error(
                    "Arguments required together: "
                    + missing_str
                    + " required when "
                    + provided_str
                    + " is provided"
                )

        # Validate one-required groups.
        for g in range(len(self._one_required_groups)):
            var found_any = False
            for n in range(len(self._one_required_groups[g])):
                var arg_name = self._one_required_groups[g][n]
                if result.has(arg_name):
                    found_any = True
                    break
            if not found_any:
                var names_str = String("")
                for n in range(len(self._one_required_groups[g])):
                    if n > 0:
                        names_str += ", "
                    names_str += self._display_name(
                        self._one_required_groups[g][n]
                    )
                self._error(
                    "At least one of the following arguments is required: "
                    + names_str
                )

        # Validate conditional requirements.
        for g in range(len(self._conditional_reqs)):
            var target = self._conditional_reqs[g][0]
            var condition = self._conditional_reqs[g][1]
            if result.has(condition) and not result.has(target):
                self._error(
                    "Argument "
                    + self._display_name(target)
                    + " is required when "
                    + self._display_name(condition)
                    + " is provided"
                )

        # Validate count ceilings — clamp and warn.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a._is_count and a._has_count_max:
                var cur: Int
                try:
                    cur = result._counts[a.name]
                except:
                    continue
                if cur > a._count_max:
                    self._warn(
                        self._display_name(a.name)
                        + " count "
                        + String(cur)
                        + " exceeds maximum "
                        + String(a._count_max)
                        + ", capped to "
                        + String(a._count_max)
                    )
                    result._counts[a.name] = a._count_max

        # Validate numeric range constraints.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a._has_range and result.has(a.name):
                var display = self._display_name(a.name)
                # Get the raw string value(s) for this argument.
                if a._is_append:
                    var lst = result.get_list(a.name)
                    for k in range(len(lst)):
                        var v: Int = (
                            0  # _error() raises in except, so 0 is never used
                        )
                        try:
                            v = atol(lst[k])
                        except:
                            self._error(
                                "Expected an integer for "
                                + self._display_name(a.name)
                                + ", got '"
                                + lst[k]
                                + "'"
                            )
                        if v < a._range_min or v > a._range_max:
                            if a._is_clamp:
                                var clamped = v
                                if v < a._range_min:
                                    clamped = a._range_min
                                elif v > a._range_max:
                                    clamped = a._range_max
                                self._warn(
                                    display
                                    + " value "
                                    + String(v)
                                    + " is out of range ["
                                    + String(a._range_min)
                                    + ", "
                                    + String(a._range_max)
                                    + "], clamped to "
                                    + String(clamped)
                                )
                                result._lists[a.name][k] = String(clamped)
                            else:
                                self._error(
                                    "Value "
                                    + String(v)
                                    + " for "
                                    + display
                                    + " is out of range ["
                                    + String(a._range_min)
                                    + ", "
                                    + String(a._range_max)
                                    + "]"
                                )
                else:
                    var raw: String
                    try:
                        raw = result.get_string(a.name)
                    except:
                        continue
                    var v: Int = (
                        0  # _error() raises in except, so 0 is never used
                    )
                    try:
                        v = atol(raw)
                    except:
                        self._error(
                            "Expected an integer for "
                            + self._display_name(a.name)
                            + ", got '"
                            + raw
                            + "'"
                        )
                    if v < a._range_min or v > a._range_max:
                        if a._is_clamp:
                            var clamped = v
                            if v < a._range_min:
                                clamped = a._range_min
                            elif v > a._range_max:
                                clamped = a._range_max
                            self._warn(
                                display
                                + " value "
                                + String(v)
                                + " is out of range ["
                                + String(a._range_min)
                                + ", "
                                + String(a._range_max)
                                + "], clamped to "
                                + String(clamped)
                            )
                            result._values[a.name] = String(clamped)
                            if a._is_positional:
                                for pi in range(len(result._positional_names)):
                                    if result._positional_names[pi] == a.name:
                                        result._positionals[pi] = String(
                                            clamped
                                        )
                                        break
                        else:
                            self._error(
                                "Value "
                                + String(v)
                                + " for "
                                + display
                                + " is out of range ["
                                + String(a._range_min)
                                + ", "
                                + String(a._range_max)
                                + "]"
                            )

    # ===------------------------------------------------------------------=== #
    # Argument lookup helpers
    # ===------------------------------------------------------------------=== #

    def _is_known_option(self, token: String) -> Bool:
        """Check if a dash-prefixed token matches a defined option.

        Used by the ``allow_hyphen_values`` logic to decide whether a
        token should be dispatched to option parsing or consumed as a
        positional value.

        Args:
            token: The raw CLI token (e.g. ``--verbose``, ``-v``).

        Returns:
            True if the token matches a known long/short option.
        """
        if token.startswith("--"):
            var key = String(token[byte=2:])
            var eq = key.find("=")
            if eq >= 0:
                key = String(key[byte=:eq])
            for idx in range(len(self.args)):
                if self.args[idx]._long_name == key:
                    return True
                if self.args[idx]._long_name and self.args[
                    idx
                ]._long_name.startswith(key):
                    return True
                for j in range(len(self.args[idx]._alias_names)):
                    if self.args[idx]._alias_names[j] == key or self.args[
                        idx
                    ]._alias_names[j].startswith(key):
                        return True
            return False
        elif token.startswith("-") and len(token) > 1:
            var ch = String(token[byte=1:2])
            for idx in range(len(self.args)):
                if self.args[idx]._short_name == ch:
                    return True
            return False
        return False

    def _find_by_long(self, name: String) raises -> Argument:
        """Finds an argument definition by its long name, alias, or unambiguous prefix.

        Resolution order:
        1. Exact match on long_name.
        2. Exact match on any alias.
        3. Prefix match on long_name.
        4. Prefix match on aliases.

        Args:
            name: The long option name (without '--'), or an unambiguous prefix.

        Returns:
            The matching Argument.

        Raises:
            Error if no argument matches or the prefix is ambiguous.
        """
        # 1. Exact match on long_name.
        for i in range(len(self.args)):
            if self.args[i]._long_name == name:
                return self.args[i].copy()

        # 2. Exact match on aliases.
        for i in range(len(self.args)):
            for j in range(len(self.args[i]._alias_names)):
                if self.args[i]._alias_names[j] == name:
                    return self.args[i].copy()

        # 3. Prefix match on long_name.
        var candidates = List[String]()
        var candidate_idx: Int = -1
        for i in range(len(self.args)):
            if self.args[i]._long_name and self.args[i]._long_name.startswith(
                name
            ):
                candidates.append(self.args[i]._long_name)
                candidate_idx = i

        # 4. Prefix match on aliases.
        for i in range(len(self.args)):
            for j in range(len(self.args[i]._alias_names)):
                if self.args[i]._alias_names[j].startswith(name):
                    # Avoid duplicate if the same arg already matched via long_name.
                    var already = False
                    for k in range(len(candidates)):
                        if candidates[k] == self.args[i]._long_name:
                            already = True
                            break
                    if not already:
                        candidates.append(self.args[i]._long_name)
                        candidate_idx = i

        if len(candidates) == 1:
            return self.args[candidate_idx].copy()

        if len(candidates) > 1:
            var opts = String("")
            for j in range(len(candidates)):
                if j > 0:
                    opts += ", "
                opts += "'--" + candidates[j] + "'"
            self._error(
                "Ambiguous option '--" + name + "' could match: " + opts
            )

        # Collect all known long names + aliases for typo suggestion.
        var all_longs = List[String]()
        for i in range(len(self.args)):
            if self.args[i]._long_name != "":
                all_longs.append(self.args[i]._long_name)
            for j in range(len(self.args[i]._alias_names)):
                all_longs.append(self.args[i]._alias_names[j])

        # CJK punctuation error recovery: try substituting common CJK
        # punctuation (e.g. em-dash → hyphen) before Levenshtein.
        if not self._disable_punctuation_correction:
            var corrected = _correct_cjk_punctuation(name)
            if corrected != name:
                # Check if the corrected name matches a known option.
                for i in range(len(self.args)):
                    if self.args[i]._long_name == corrected:
                        self._error(
                            "Unknown option '--"
                            + name
                            + "'. Did you mean '--"
                            + corrected
                            + "'? (detected CJK punctuation)"
                        )
                    for j in range(len(self.args[i]._alias_names)):
                        if self.args[i]._alias_names[j] == corrected:
                            self._error(
                                "Unknown option '--"
                                + name
                                + "'. Did you mean '--"
                                + corrected
                                + "'? (detected CJK punctuation)"
                            )

        var suggestion = _suggest_similar(name, all_longs)
        if suggestion != "":
            self._error(
                "Unknown option '--"
                + name
                + "'. Did you mean '--"
                + suggestion
                + "'?"
            )
        self._error("Unknown option '--" + name + "'")
        raise Error(
            "unreachable"
        )  # _error() always raises; satisfies Mojo's return checker

    def _find_by_short(self, name: String) raises -> Argument:
        """Finds an argument definition by its short name.

        Args:
            name: The short option name (without '-').

        Returns:
            The matching Argument.

        Raises:
            Error if no argument matches.
        """
        for i in range(len(self.args)):
            if self.args[i]._short_name == name:
                return self.args[i].copy()
        # Short options are always a single character; any two single-character
        # inputs have Levenshtein distance ≤ 1, so the threshold would always
        # fire and produce meaningless suggestions (e.g. "-z" → "Did you mean
        # '-v'?"). Suggestions are therefore disabled for short options.
        self._error("Unknown option '-" + name + "'")
        raise Error(
            "unreachable"
        )  # _error() always raises; satisfies Mojo's return checker

    def _find_subcommand(self, name: String) -> Int:
        """Returns the index of the registered subcommand matching ``name``.

        Checks primary names first, then aliases.

        Args:
            name: Subcommand name or alias to look up.

        Returns:
            The index into ``self.subcommands``, or ``-1`` if not found.
        """
        # 1. Exact match on primary name.
        for i in range(len(self.subcommands)):
            if self.subcommands[i].name == name:
                return i
        # 2. Match on aliases.
        for i in range(len(self.subcommands)):
            for j in range(len(self.subcommands[i]._command_aliases)):
                if self.subcommands[i]._command_aliases[j] == name:
                    return i
        return -1

    def _display_name(self, name: String) -> String:
        """Returns a user-facing display string for an argument.

        Checks long name first, then short name, then falls back to
        the internal name wrapped in quotes.

        Args:
            name: The internal argument name.

        Returns:
            A string such as ``'--output'``, ``'-o'``, or ``'name'``.
        """
        for i in range(len(self.args)):
            if self.args[i].name == name:
                if self.args[i]._long_name:
                    return "'--" + self.args[i]._long_name + "'"
                elif self.args[i]._short_name:
                    return "'-" + self.args[i]._short_name + "'"
                break
        return "'" + name + "'"

    def _validate_choices(self, arg: Argument, value: String) raises:
        """Validates that the value is in the allowed choices.

        Args:
            arg: The argument definition.
            value: The value to validate.

        Raises:
            Error if the value is not in the allowed choices.
        """
        if len(arg._choice_values) == 0:
            return
        for i in range(len(arg._choice_values)):
            if arg._choice_values[i] == value:
                return
        var allowed = String("")
        for i in range(len(arg._choice_values)):
            if i > 0:
                allowed += ", "
            allowed += "'" + arg._choice_values[i] + "'"
        self._error(
            "Invalid value '"
            + value
            + "' for argument '"
            + arg.name
            + "' (choose from "
            + allowed
            + ")"
        )

    def _store_append_value(
        self, arg: Argument, value: String, mut result: ParseResult
    ) raises:
        """Stores a value for an append-type argument, handling delimiter splitting.

        If the argument has a delimiter set, the value is split by that
        delimiter and each piece is validated and appended individually.
        Otherwise, the whole value is validated and appended as-is.

        Args:
            arg: The argument definition.
            value: The raw value string.
            result: The ParseResult to store into.
        """
        if arg.name not in result._lists:
            result._lists[arg.name] = List[String]()
        if arg._delimiter_char:
            var val = value
            if not self._disable_fullwidth_correction:
                val = _fullwidth_to_halfwidth(value)
            var parts = val.split(arg._delimiter_char)
            for p in range(len(parts)):
                var piece = String(parts[p])
                if piece:  # skip empty pieces from e.g. trailing comma
                    self._validate_choices(arg, piece)
                    result._lists[arg.name].append(piece)
        else:
            self._validate_choices(arg, value)
            result._lists[arg.name].append(value)

    def _store_map_value(
        self, arg: Argument, value: String, mut result: ParseResult
    ) raises:
        """Stores a key=value pair for a map-type argument.

        The value must contain '=' to separate key and value.
        If the argument has a delimiter set, the raw value is first
        split by that delimiter and each piece is parsed as key=value.

        Args:
            arg: The argument definition.
            value: The raw value string (e.g., "key=value").
            result: The ParseResult to store into.
        """
        if arg.name not in result._maps:
            result._maps[arg.name] = Dict[String, String]()
        # Also store in lists for has() detection.
        if arg.name not in result._lists:
            result._lists[arg.name] = List[String]()

        if arg._delimiter_char:
            var val = value
            if not self._disable_fullwidth_correction:
                val = _fullwidth_to_halfwidth(value)
            var parts = val.split(arg._delimiter_char)
            for p in range(len(parts)):
                var piece = String(parts[p])
                if piece:
                    var eq = piece.find("=")
                    if eq < 0:
                        self._error(
                            "Invalid key=value format '"
                            + piece
                            + "' for argument '"
                            + arg.name
                            + "'"
                        )
                    var k = String(piece[byte=:eq])
                    var v = String(piece[byte = eq + 1 :])
                    result._maps[arg.name][k] = v
                    result._lists[arg.name].append(piece)
        else:
            var eq = value.find("=")
            if eq < 0:
                self._error(
                    "Invalid key=value format '"
                    + value
                    + "' for argument '"
                    + arg.name
                    + "'"
                )
            var k = String(value[byte=:eq])
            var v = String(value[byte = eq + 1 :])
            result._maps[arg.name][k] = v
            result._lists[arg.name].append(value)

    def _generate_help(self, color: Bool = True) -> String:
        """Generates a help message from registered arguments.

        Delegates to five sub-methods, one for each section of the help
        output: usage line, positional arguments, options (local and
        global), subcommands, and tips.

        Args:
            color: When True (default), include ANSI colour codes.

        Returns:
            A formatted help string.
        """
        # Resolve colour tokens — empty strings when colour is off.
        # NO_COLOR env var overrides the color parameter.
        var use_color = color and not Self._no_color_env()
        var arg_color = self._arg_color if use_color else ""
        var header_color = (_BOLD_UL + self._header_color) if use_color else ""
        var reset_code = _RESET if use_color else ""

        var s = String("")
        s += self._help_usage_line(arg_color, header_color, reset_code)
        s += self._help_positionals_section(arg_color, header_color, reset_code)
        s += self._help_options_section(arg_color, header_color, reset_code)
        s += self._help_commands_section(arg_color, header_color, reset_code)
        s += self._help_tips_section(header_color, reset_code)
        return s

    def _help_usage_line(
        self,
        arg_color: String,
        header_color: String,
        reset_code: String,
    ) -> String:
        """Generates the description and usage line of help output.

        Args:
            arg_color: ANSI colour code for argument names (empty if colour off).
            header_color: ANSI colour code for section headers (empty if colour off).
            reset_code: ANSI reset code (empty if colour off).

        Returns:
            The description (if any) and usage line string.
        """
        var s = String("")
        if self.description:
            s += self.description + "\n\n"

        # Usage line.
        if self._custom_usage:
            s += header_color + "Usage:" + reset_code + " "
            s += self._custom_usage + "\n\n"
            return s
        s += header_color + "Usage:" + reset_code + " "
        s += arg_color + self.name + reset_code

        # Show positional args in usage line.
        for i in range(len(self.args)):
            if self.args[i]._is_positional and not self.args[i]._is_hidden:
                var display = self.args[i].name
                if self.args[i]._is_remainder:
                    display += "..."
                if self.args[i]._is_required:
                    s += " " + arg_color + "<" + display + ">" + reset_code
                else:
                    s += " " + arg_color + "[" + display + "]" + reset_code

        # Show <COMMAND> placeholder when subcommands are registered.
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if (
                not self.subcommands[i]._is_help_subcommand
                and not self.subcommands[i]._is_hidden
            ):
                has_subcommands = True
                break
        if has_subcommands:
            s += " " + arg_color + "<COMMAND>" + reset_code

        s += " " + arg_color + "[OPTIONS]" + reset_code + "\n\n"
        return s

    def _help_positionals_section(
        self,
        arg_color: String,
        header_color: String,
        reset_code: String,
    ) -> String:
        """Generates the 'Arguments:' section listing positional arguments.

        Uses a two-pass approach: first collects plain and coloured text
        to compute dynamic column padding, then assembles the final lines.

        Args:
            arg_color: ANSI colour code for argument names.
            header_color: ANSI colour code for section headers.
            reset_code: ANSI reset code.

        Returns:
            The positional arguments section, or empty string if none.
        """
        var has_positional = False
        for i in range(len(self.args)):
            if self.args[i]._is_positional and not self.args[i]._is_hidden:
                has_positional = True
                break

        if not has_positional:
            return ""

        # Two-pass for dynamic padding.
        var pos_plains = List[String]()  # plain text for padding calc
        var pos_colors = List[String]()  # coloured text for display
        var pos_helps = List[String]()
        for i in range(len(self.args)):
            if self.args[i]._is_positional and not self.args[i]._is_hidden:
                var name_display = self.args[i].name
                if self.args[i]._is_remainder:
                    name_display += "..."
                var plain = String("  ") + name_display
                var colored = (
                    String("  ") + arg_color + name_display + reset_code
                )
                pos_plains.append(plain)
                pos_colors.append(colored)
                pos_helps.append(self.args[i].help_text)

        var pos_max: Int = 0
        for k in range(len(pos_plains)):
            var w = _display_width(pos_plains[k])
            if w > pos_max:
                pos_max = w
        var pos_pad = pos_max + 4

        var s = header_color + "Arguments:" + reset_code + "\n"
        for k in range(len(pos_plains)):
            var line = pos_colors[k]
            if pos_helps[k]:
                # Pad based on plain-text width.
                var padding = pos_pad - _display_width(pos_plains[k])
                for _p in range(padding):
                    line += " "
                line += pos_helps[k]
            s += line + "\n"
        s += "\n"
        return s

    def _help_options_section(
        self,
        arg_color: String,
        header_color: String,
        reset_code: String,
    ) -> String:
        """Generates the 'Options:', group, and 'Global Options:' sections.

        Separates local options from persistent (global) options and
        displays them under distinct headings.  Options with a ``.group()``
        are shown under their group heading.  Built-in ``--help`` and
        ``--version`` are always appended to the ungrouped local section.

        Args:
            arg_color: ANSI colour code for argument names.
            header_color: ANSI colour code for section headers.
            reset_code: ANSI reset code.

        Returns:
            The options section string.
        """
        var opt_plains = List[String]()
        var opt_colors = List[String]()
        var opt_helps = List[String]()
        var opt_persistent = List[Bool]()
        var opt_groups = List[String]()

        for i in range(len(self.args)):
            if not self.args[i]._is_positional and not self.args[i]._is_hidden:
                var plain = String("  ")
                var colored = String("  ")
                if self.args[i]._short_name:
                    plain += "-" + self.args[i]._short_name
                    colored += (
                        arg_color + "-" + self.args[i]._short_name + reset_code
                    )
                    if self.args[i]._long_name:
                        plain += ", "
                        colored += ", "
                else:
                    plain += "    "
                    colored += "    "
                if self.args[i]._long_name:
                    var long_part = String("--") + self.args[i]._long_name
                    plain += long_part
                    colored += arg_color + long_part + reset_code
                    if self.args[i]._is_negatable:
                        var neg_part = (
                            String(" / --no-") + self.args[i]._long_name
                        )
                        plain += neg_part
                        colored += (
                            " / "
                            + arg_color
                            + "--no-"
                            + self.args[i]._long_name
                            + reset_code
                        )
                    # Show aliases.
                    for j in range(len(self.args[i]._alias_names)):
                        var alias_part = (
                            String(", --") + self.args[i]._alias_names[j]
                        )
                        plain += alias_part
                        colored += (
                            ", "
                            + arg_color
                            + "--"
                            + self.args[i]._alias_names[j]
                            + reset_code
                        )

                # Show value_name or choices for value-taking options.
                if not self.args[i]._is_flag and not self.args[i]._is_count:
                    var ncount = self.args[i]._number_of_values
                    var repeat = ncount if ncount > 0 else 1
                    var append_dots = self.args[i]._is_append and ncount == 0
                    # Determine separator and wrapping for require_equals/default_if_no_value.
                    var sep = String("=") if self.args[
                        i
                    ]._require_equals else String(" ")
                    var open_bracket = String("[") if self.args[
                        i
                    ]._has_default_if_no_value else String("")
                    var close_bracket = String("]") if self.args[
                        i
                    ]._has_default_if_no_value else String("")
                    if self.args[i]._value_name:
                        var raw_mv = self.args[i]._value_name
                        var mv: String
                        if self.args[i]._value_name_wrapped:
                            mv = "<" + raw_mv + ">"
                        else:
                            mv = raw_mv
                        var mv_plain = String("")
                        var mv_colored = String("")
                        for _r in range(repeat - 1):
                            mv_plain += " " + mv
                            mv_colored += " " + arg_color + mv + reset_code
                        # Last (or only) occurrence — attach "..." if append.
                        var last = mv + ("..." if append_dots else "")
                        mv_plain += open_bracket + sep + last + close_bracket
                        mv_colored += (
                            open_bracket
                            + sep
                            + arg_color
                            + last
                            + reset_code
                            + close_bracket
                        )
                        plain += mv_plain
                        colored += mv_colored
                    elif len(self.args[i]._choice_values) > 0:
                        var choices_str = String("{")
                        for j in range(len(self.args[i]._choice_values)):
                            if j > 0:
                                choices_str += ","
                            choices_str += self.args[i]._choice_values[j]
                        choices_str += "}"
                        var suffix = choices_str
                        if append_dots:
                            suffix += "..."
                        plain += open_bracket + sep + suffix + close_bracket
                        colored += (
                            open_bracket
                            + sep
                            + arg_color
                            + suffix
                            + reset_code
                            + close_bracket
                        )
                    else:
                        # Default placeholder: <key=value> for map, <name> otherwise.
                        var tag: String
                        if self.args[i]._is_map:
                            tag = "<key=value>"
                        else:
                            tag = "<" + self.args[i].name + ">"
                        var ph_plain = String("")
                        var ph_colored = String("")
                        for _r in range(repeat - 1):
                            ph_plain += " " + tag
                            ph_colored += " " + arg_color + tag + reset_code
                        # Last (or only) — attach "..." if append.
                        var last = tag + ("..." if append_dots else "")
                        ph_plain += open_bracket + sep + last + close_bracket
                        ph_colored += (
                            open_bracket
                            + sep
                            + arg_color
                            + last
                            + reset_code
                            + close_bracket
                        )
                        plain += ph_plain
                        colored += ph_colored

                opt_plains.append(plain)
                opt_colors.append(colored)
                opt_persistent.append(self.args[i]._is_persistent)
                opt_groups.append(self.args[i]._group)
                # Append deprecation notice to help text if applicable.
                var help = self.args[i].help_text
                if self.args[i]._deprecated_msg:
                    if help:
                        help += " "
                    help += "[deprecated: " + self.args[i]._deprecated_msg + "]"
                opt_helps.append(help)

        # Built-in options (always shown under local ungrouped "Options:" section).
        var help_plain = String("  -h, --help")
        var help_colored = (
            "  "
            + arg_color
            + "-h"
            + reset_code
            + ", "
            + arg_color
            + "--help"
            + reset_code
        )  # Not show -? in help message as it requires quoting in some shells
        var version_plain = String("  -V, --version")
        var version_colored = (
            "  "
            + arg_color
            + "-V"
            + reset_code
            + ", "
            + arg_color
            + "--version"
            + reset_code
        )
        opt_plains.append(help_plain)
        opt_colors.append(help_colored)
        opt_persistent.append(False)
        opt_groups.append(String(""))
        opt_helps.append(String("Show this help message"))
        opt_plains.append(version_plain)
        opt_colors.append(version_colored)
        opt_persistent.append(False)
        opt_groups.append(String(""))
        opt_helps.append(String("Show version"))
        if self._completions_enabled and not self._completions_is_subcommand:
            var comp_plain = String(
                "  --" + self._completions_name + " {bash,zsh,fish}"
            )
            var comp_colored = (
                "  "
                + arg_color
                + "--"
                + self._completions_name
                + reset_code
                + " "
                + arg_color
                + "{bash,zsh,fish}"
                + reset_code
            )
            opt_plains.append(comp_plain)
            opt_colors.append(comp_colored)
            opt_persistent.append(False)
            opt_groups.append(String(""))
            opt_helps.append(String("Generate shell completion script"))

        # Check if there are any persistent (global) options.
        var has_global = False
        for k in range(len(opt_persistent)):
            if opt_persistent[k]:
                has_global = True
                break

        # Collect distinct group names in order of first appearance.
        var group_names = List[String]()
        for k in range(len(opt_groups)):
            if opt_groups[k] and not opt_persistent[k]:
                var found = False
                for g in range(len(group_names)):
                    if group_names[g] == opt_groups[k]:
                        found = True
                        break
                if not found:
                    group_names.append(opt_groups[k])

        # --- Helper: compute max display width for a subset of options ---
        def _section_pad(
            plains: List[String],
            persistent: List[Bool],
            groups: List[String],
            want_persistent: Bool,
            want_group: String,
        ) -> Int:
            var mx: Int = 0
            for idx in range(len(plains)):
                if persistent[idx] != want_persistent:
                    continue
                if groups[idx] != want_group:
                    continue
                var w = _display_width(plains[idx])
                if w > mx:
                    mx = w
            return mx + 4

        # --- Ungrouped local options (Options:) ---
        var ungrouped_pad = _section_pad(
            opt_plains, opt_persistent, opt_groups, False, String("")
        )
        var s = header_color + "Options:" + reset_code + "\n"
        for k in range(len(opt_plains)):
            if not opt_persistent[k] and not opt_groups[k]:
                var line = opt_colors[k]
                if opt_helps[k]:
                    var padding = ungrouped_pad - _display_width(opt_plains[k])
                    for _p in range(padding):
                        line += " "
                    line += opt_helps[k]
                s += line + "\n"

        # --- Grouped local options (one section per group) ---
        for g in range(len(group_names)):
            var gname = group_names[g]
            var gpad = _section_pad(
                opt_plains, opt_persistent, opt_groups, False, gname
            )
            s += "\n" + header_color + gname + ":" + reset_code + "\n"
            for k in range(len(opt_plains)):
                if not opt_persistent[k] and opt_groups[k] == gname:
                    var line = opt_colors[k]
                    if opt_helps[k]:
                        var padding = gpad - _display_width(opt_plains[k])
                        for _p in range(padding):
                            line += " "
                        line += opt_helps[k]
                    s += line + "\n"

        # Global (persistent) options — shown under a separate heading.
        if has_global:
            var global_max: Int = 0
            for k in range(len(opt_plains)):
                if opt_persistent[k]:
                    var w = _display_width(opt_plains[k])
                    if w > global_max:
                        global_max = w
            var global_pad = global_max + 4
            s += "\n" + header_color + "Global Options:" + reset_code + "\n"
            for k in range(len(opt_plains)):
                if opt_persistent[k]:
                    var line = opt_colors[k]
                    if opt_helps[k]:
                        var padding = global_pad - _display_width(opt_plains[k])
                        for _p in range(padding):
                            line += " "
                        line += opt_helps[k]
                    s += line + "\n"

        return s

    def _help_commands_section(
        self,
        arg_color: String,
        header_color: String,
        reset_code: String,
    ) -> String:
        """Generates the 'Commands:' section listing registered subcommands.

        Args:
            arg_color: ANSI colour code for argument names.
            header_color: ANSI colour code for section headers.
            reset_code: ANSI reset code.

        Returns:
            The commands section string, or empty string if no subcommands.
        """
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if (
                not self.subcommands[i]._is_help_subcommand
                and not self.subcommands[i]._is_hidden
            ):
                has_subcommands = True
                break
        # Also count completions subcommand if in subcommand mode.
        if self._completions_enabled and self._completions_is_subcommand:
            has_subcommands = True

        if not has_subcommands:
            return ""

        var cmd_plains = List[String]()
        var cmd_colors = List[String]()
        var cmd_helps = List[String]()
        for i in range(len(self.subcommands)):
            if (
                not self.subcommands[i]._is_help_subcommand
                and not self.subcommands[i]._is_hidden
            ):
                # Build label: "name" or "name, alias1, alias2".
                var label = self.subcommands[i].name
                for _ai in range(len(self.subcommands[i]._command_aliases)):
                    label += ", " + self.subcommands[i]._command_aliases[_ai]
                var plain = String("  ") + label
                var colored = String("  ") + arg_color + label + reset_code
                cmd_plains.append(plain)
                cmd_colors.append(colored)
                cmd_helps.append(self.subcommands[i].description)
        # Append completions subcommand if in subcommand mode.
        if self._completions_enabled and self._completions_is_subcommand:
            var cname = self._completions_name
            var plain = String("  ") + cname
            var colored = String("  ") + arg_color + cname + reset_code
            cmd_plains.append(plain)
            cmd_colors.append(colored)
            cmd_helps.append(
                String("Generate shell completion script (bash, zsh, fish)")
            )
        # Compute padding.
        var cmd_max: Int = 0
        for k in range(len(cmd_plains)):
            var w = _display_width(cmd_plains[k])
            if w > cmd_max:
                cmd_max = w
        var cmd_pad = cmd_max + 4
        var s = "\n" + header_color + "Commands:" + reset_code + "\n"
        for k in range(len(cmd_plains)):
            var line = cmd_colors[k]
            if cmd_helps[k]:
                var padding = cmd_pad - _display_width(cmd_plains[k])
                for _p in range(padding):
                    line += " "
                line += cmd_helps[k]
            s += line + "\n"

        return s

    def _help_tips_section(
        self, header_color: String, reset_code: String
    ) -> String:
        """Generates the 'Tips:' section with hints and user-defined tips.

        Automatically adds a ``--`` separator hint when positional
        arguments are registered.  User-defined tips (added via
        ``add_tip()``) are always included.

        Args:
            header_color: ANSI colour code for section headers.
            reset_code: ANSI reset code (empty if colour off).

        Returns:
            The tips section string, or empty string if no tips.
        """
        var has_positional = False
        for i in range(len(self.args)):
            if self.args[i]._is_positional and not self.args[i]._is_hidden:
                has_positional = True
                break

        # Tip: show '--' separator hint when positional args are registered.
        # When negative numbers are already handled automatically (either via
        # explicit allow_negative_numbers(), allow_negative_expressions(),
        # or auto-detect: no digit short options), the example changes to
        # a generic dash-prefixed value rather than '-10.18'.
        var tip_lines = List[String]()
        if has_positional:
            if self._allow_negative_expressions:
                tip_lines.append(
                    "Use '--' to force option-like tokens into"
                    " positionals:  "
                    + self.name
                    + " -- -p"
                )
            else:
                var neg_auto = self._allow_negative_numbers
                if not neg_auto:
                    var has_digit_short = False
                    for _ti in range(len(self.args)):
                        var sc = self.args[_ti]._short_name
                        if (
                            len(sc) == 1
                            and sc[byte=0:1] >= "0"
                            and sc[byte=0:1] <= "9"
                        ):
                            has_digit_short = True
                            break
                    neg_auto = not has_digit_short
                if neg_auto:
                    tip_lines.append(
                        "Use '--' to pass values starting with '-' as"
                        " positionals:  "
                        + self.name
                        + " -- -my-value"
                    )
                else:
                    tip_lines.append(
                        "Use '--' to pass values that start with '-' (e.g.,"
                        " negative numbers):  "
                        + self.name
                        + " -- -10.18"
                    )

        # User-defined tips — always shown when present.
        for _ti in range(len(self._tips)):
            tip_lines.append(self._tips[_ti])

        if len(tip_lines) == 0:
            return ""

        var s = "\n" + header_color + "Tips:" + reset_code + "\n"
        for _ti in range(len(tip_lines)):
            s += "  " + tip_lines[_ti] + "\n"
        return s

    # ===------------------------------------------------------------------=== #
    # Shell completion generation
    # ===------------------------------------------------------------------=== #

    def generate_completion[shell: StringLiteral](self) -> String:
        """Generates a shell completion script (compile-time validated).

        The shell name is validated at compile time via ``comptime assert``.
        Use this overload when the shell is known at development time.

        Parameters:
            shell: One of ``"bash"``, ``"zsh"``, or ``"fish"``
                   (case-sensitive). Invalid names are caught at compile
                   time.

        Returns:
            The completion script as a string.

        Examples:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My application")
        var script = app.generate_completion["bash"]()
        ```
        """
        comptime assert shell == "fish" or shell == "zsh" or shell == "bash", (
            "Unknown shell '" + shell + "'. Choose from: bash, zsh, fish"
        )

        comptime if shell == "fish":
            return self._completion_fish()
        elif shell == "zsh":
            return self._completion_zsh()
        else:  # shell == "bash"
            return self._completion_bash()

    def generate_completion(self, shell: String) raises -> String:
        """Generates a shell completion script (runtime dispatch).

        The shell name is validated at runtime.  Use this overload when
        the shell name comes from user input (e.g. ``--completions``).

        Args:
            shell: One of ``"bash"``, ``"zsh"``, or ``"fish"``
                   (case-insensitive).

        Returns:
            The completion script as a string.

        Raises:
            Error if *shell* is not recognised.
        """
        var lower = shell.lower()
        if lower == "fish":
            return self._completion_fish()
        if lower == "zsh":
            return self._completion_zsh()
        if lower == "bash":
            return self._completion_bash()
        raise Error(
            "Unknown shell '" + shell + "'. Choose from: bash, zsh, fish"
        )

    def _completion_fish(self) -> String:
        """Generates a Fish shell completion script.

        Each option/subcommand becomes a single ``complete`` line.
        Subcommand-specific completions use
        ``-n '__fish_seen_subcommand_from <sub>'``
        to scope them.

        Returns:
            A complete Fish completion script.
        """
        var s = String("# Fish completions for " + self.name + "\n")
        s += "# Generated by ArgMojo\n\n"

        # Root-level options.
        s += self._fish_options_for(self.name, "")
        # Built-in options.
        s += (
            "complete -c "
            + self.name
            + " -s h -l help -d 'Show this help message'\n"
        )
        s += "complete -c " + self.name + " -s V -l version -d 'Show version'\n"
        if self._completions_enabled and not self._completions_is_subcommand:
            s += (
                "complete -c "
                + self.name
                + " -l "
                + self._completions_name
                + " -r -a 'bash zsh fish'"
                + " -d 'Generate shell completion script'\n"
            )

        # Subcommands.
        var _comp_is_sub = (
            self._completions_enabled and self._completions_is_subcommand
        )
        if len(self.subcommands) > 0 or _comp_is_sub:
            # Condition: no subcommand seen yet.
            var sub_names = String("")
            for i in range(len(self.subcommands)):
                if (
                    not self.subcommands[i]._is_help_subcommand
                    and not self.subcommands[i]._is_hidden
                ):
                    if sub_names:
                        sub_names += " "
                    sub_names += self.subcommands[i].name
                    for _ai in range(len(self.subcommands[i]._command_aliases)):
                        sub_names += (
                            " " + self.subcommands[i]._command_aliases[_ai]
                        )
            if _comp_is_sub:
                if sub_names:
                    sub_names += " "
                sub_names += self._completions_name
            var no_sub_cond = "__fish_seen_subcommand_from " + sub_names

            for i in range(len(self.subcommands)):
                if (
                    self.subcommands[i]._is_help_subcommand
                    or self.subcommands[i]._is_hidden
                ):
                    continue
                var sub = self.subcommands[i].copy()
                # Register the subcommand itself.
                s += (
                    "complete -c "
                    + self.name
                    + " -n 'not "
                    + no_sub_cond
                    + "'"
                    + " -f -a '"
                    + sub.name
                    + "'"
                )
                if sub.description:
                    s += " -d '" + self._fish_escape(sub.description) + "'"
                s += "\n"
                # Register each alias as a completable name.
                for _ai in range(len(sub._command_aliases)):
                    s += (
                        "complete -c "
                        + self.name
                        + " -n 'not "
                        + no_sub_cond
                        + "'"
                        + " -f -a '"
                        + sub._command_aliases[_ai]
                        + "'"
                    )
                    if sub.description:
                        s += " -d '" + self._fish_escape(sub.description) + "'"
                    s += "\n"

                # Subcommand-specific options.
                var sub_cond = "__fish_seen_subcommand_from " + sub.name
                for _ai in range(len(sub._command_aliases)):
                    sub_cond += " " + sub._command_aliases[_ai]
                s += self._fish_options_for(
                    self.name, sub_cond, persistent_only=True
                )
                # Iterate sub.args for subcommand's own arguments.
                for j in range(len(sub.args)):
                    var arg = sub.args[j].copy()
                    if arg._is_hidden or arg._is_positional:
                        continue
                    var line = "complete -c " + self.name
                    line += " -n '" + sub_cond + "'"
                    if arg._short_name:
                        line += " -s " + arg._short_name
                    if arg._long_name:
                        line += " -l " + arg._long_name
                    if not arg._is_flag and not arg._is_count:
                        line += " -r"
                    if len(arg._choice_values) > 0:
                        var choices = String("")
                        for k in range(len(arg._choice_values)):
                            if choices:
                                choices += " "
                            choices += arg._choice_values[k]
                        line += " -a '" + choices + "'"
                    if arg.help_text:
                        line += " -d '" + self._fish_escape(arg.help_text) + "'"
                    s += line + "\n"

            # Completions subcommand entry.
            if _comp_is_sub:
                var cname = self._completions_name
                s += (
                    "complete -c "
                    + self.name
                    + " -n 'not "
                    + no_sub_cond
                    + "'"
                    + " -f -a '"
                    + cname
                    + "'"
                    + " -d 'Generate shell completion script'\n"
                )
                s += (
                    "complete -c "
                    + self.name
                    + " -n '__fish_seen_subcommand_from "
                    + cname
                    + "'"
                    + " -r -a 'bash zsh fish'\n"
                )
        return s

    def _fish_options_for(
        self, cmd_name: String, condition: String, persistent_only: Bool = False
    ) -> String:
        """Generates ``complete`` lines for this command's own arguments.

        Args:
            cmd_name: The top-level command name (for ``complete -c``).
            condition: Fish condition string (empty for root-level).
            persistent_only: When True, only emit persistent arguments.

        Returns:
            Lines of ``complete`` commands for non-hidden, non-positional args.
        """
        var s = String("")
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if arg._is_hidden or arg._is_positional:
                continue
            if persistent_only and not arg._is_persistent:
                continue
            var line = "complete -c " + cmd_name
            if condition:
                line += " -n '" + condition + "'"
            if arg._short_name:
                line += " -s " + arg._short_name
            if arg._long_name:
                line += " -l " + arg._long_name
            if not arg._is_flag and not arg._is_count:
                line += " -r"
            if len(arg._choice_values) > 0:
                var choices = String("")
                for k in range(len(arg._choice_values)):
                    if choices:
                        choices += " "
                    choices += arg._choice_values[k]
                line += " -a '" + choices + "'"
            if arg.help_text:
                line += " -d '" + self._fish_escape(arg.help_text) + "'"
            s += line + "\n"
        return s

    def _fish_escape(self, text: String) -> String:
        """Escapes single quotes in text for Fish shell strings.

        Args:
            text: The text to escape.

        Returns:
            The escaped text with ``'`` replaced by ``\\'``.
        """
        var result = String("")
        for i in range(len(text)):
            var ch = text[byte = i : i + 1]
            if ch == "'":
                result += "\\'"
            else:
                result += ch
        return result

    def _completion_zsh(self) -> String:
        """Generates a Zsh completion script using ``_arguments``.

        Returns:
            A complete Zsh completion script.
        """
        var s = String("#compdef " + self.name + "\n")
        s += "# Zsh completions for " + self.name + "\n"
        s += "# Generated by ArgMojo\n\n"

        # If there are subcommands, generate a dispatcher function.
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if (
                not self.subcommands[i]._is_help_subcommand
                and not self.subcommands[i]._is_hidden
            ):
                has_subcommands = True
                break
        if self._completions_enabled and self._completions_is_subcommand:
            has_subcommands = True

        if has_subcommands:
            s += self._zsh_with_subcommands()
        else:
            s += self._zsh_simple()

        s += "compdef _" + self.name + " " + self.name + "\n"
        return s

    def _zsh_simple(self) -> String:
        """Generates a simple Zsh completion function (no subcommands).

        Returns:
            The function body string.
        """
        var s = String("_" + self.name + "() {\n")
        s += "  _arguments \\\n"
        # User-defined arguments.
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if arg._is_hidden:
                continue
            if arg._is_positional:
                continue
            s += "    " + self._zsh_arg_spec(arg) + " \\\n"
        # Built-in options.
        s += "    '(- *)'{-h,--help}'[Show this help message]' \\\n"
        if self._completions_enabled and not self._completions_is_subcommand:
            s += "    '(- *)'{-V,--version}'[Show version]' \\\n"
            s += (
                "    '--"
                + self._completions_name
                + "[Generate shell completion script]:shell:(bash zsh fish)'\n"
            )
        else:
            s += "    '(- *)'{-V,--version}'[Show version]'\n"
        s += "}\n\n"
        return s

    def _zsh_with_subcommands(self) -> String:
        """Generates a Zsh completion function with subcommand dispatch.

        Returns:
            The function body string with subcommand handling.
        """
        var s = String("_" + self.name + "() {\n")
        s += "  local -a commands\n"
        s += "  commands=(\n"
        for i in range(len(self.subcommands)):
            if (
                self.subcommands[i]._is_help_subcommand
                or self.subcommands[i]._is_hidden
            ):
                continue
            var sub = self.subcommands[i].copy()
            var desc = self._zsh_escape(
                sub.description
            ) if sub.description else ""
            s += "    '" + sub.name + ":" + desc + "'\n"
            # Add aliases as separate entries pointing to same description.
            for _ai in range(len(sub._command_aliases)):
                s += "    '" + sub._command_aliases[_ai] + ":" + desc + "'\n"
        if self._completions_enabled and self._completions_is_subcommand:
            s += (
                "    '"
                + self._completions_name
                + ":Generate shell completion script'\n"
            )
        s += "  )\n\n"

        s += "  _arguments -C \\\n"
        # Root-level options.
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if arg._is_hidden or arg._is_positional:
                continue
            s += "    " + self._zsh_arg_spec(arg) + " \\\n"
        s += "    '(- *)'{-h,--help}'[Show this help message]' \\\n"
        s += "    '(- *)'{-V,--version}'[Show version]' \\\n"
        if self._completions_enabled and not self._completions_is_subcommand:
            s += (
                "    '--"
                + self._completions_name
                + "[Generate shell completion"
                " script]:shell:(bash zsh fish)' \\\n"
            )
        s += "    '1:command:->cmd' \\\n"
        s += "    '*::arg:->args'\n\n"

        s += "  case $state in\n"
        s += "    cmd)\n"
        s += "      _describe -t commands 'command' commands\n"
        s += "      ;;\n"
        s += "    args)\n"
        s += "      case $words[1] in\n"
        for i in range(len(self.subcommands)):
            if (
                self.subcommands[i]._is_help_subcommand
                or self.subcommands[i]._is_hidden
            ):
                continue
            var sub = self.subcommands[i].copy()
            # Build pattern: name|alias1|alias2
            var zsh_pat = sub.name
            for _ai in range(len(sub._command_aliases)):
                zsh_pat += "|" + sub._command_aliases[_ai]
            s += "        " + zsh_pat + ")\n"
            s += "          _arguments \\\n"
            for j in range(len(sub.args)):
                var arg = sub.args[j].copy()
                if arg._is_hidden:
                    continue
                if arg._is_positional:
                    continue
                s += "            " + self._zsh_arg_spec(arg) + " \\\n"
            s += "            '(- *)'{-h,--help}'[Show this help message]'\n"
            s += "          ;;\n"

        if self._completions_enabled and self._completions_is_subcommand:
            s += "        " + self._completions_name + ")\n"
            s += (
                "          _arguments \\\n"
                "            '1:shell:(bash zsh fish)'\n"
            )
            s += "          ;;\n"

        s += "      esac\n"
        s += "      ;;\n"
        s += "  esac\n"
        s += "}\n\n"
        return s

    def _zsh_arg_spec(self, arg: Argument) -> String:
        """Builds a single ``_arguments`` spec string for an argument.

        Args:
            arg: The argument to generate a spec for.

        Returns:
            A ``_arguments``-compatible spec string, e.g.
            ``'--verbose[Enable verbose output]'``.
        """
        var spec = String("")
        var desc = self._zsh_escape(arg.help_text) if arg.help_text else ""

        if arg._short_name and arg._long_name:
            # Grouped short+long form.
            spec += (
                "'(-"
                + arg._short_name
                + " --"
                + arg._long_name
                + ")'"
                + "{-"
                + arg._short_name
                + ",--"
                + arg._long_name
                + "}"
            )
        elif arg._long_name:
            spec += "'--" + arg._long_name
        elif arg._short_name:
            spec += "'-" + arg._short_name

        if arg._short_name and arg._long_name:
            # Description + value spec.
            spec += "'[" + desc + "]"
            if not arg._is_flag and not arg._is_count:
                if len(arg._choice_values) > 0:
                    var choices = String("")
                    for k in range(len(arg._choice_values)):
                        if choices:
                            choices += " "
                        choices += arg._choice_values[k]
                    spec += ":value:(" + choices + ")"
                else:
                    var mv = arg._value_name if arg._value_name else arg.name
                    spec += ":" + mv + ":"
            spec += "'"
        else:
            if not arg._is_flag and not arg._is_count:
                if len(arg._choice_values) > 0:
                    var choices = String("")
                    for k in range(len(arg._choice_values)):
                        if choices:
                            choices += " "
                        choices += arg._choice_values[k]
                    spec += "[" + desc + "]:value:(" + choices + ")'"
                else:
                    var mv = arg._value_name if arg._value_name else arg.name
                    spec += "[" + desc + "]:" + mv + ":'"
            else:
                spec += "[" + desc + "]'"

        return spec

    def _zsh_escape(self, text: String) -> String:
        """Escapes special characters in text for Zsh completion specs.

        Escapes ``[``, ``]``, ``'``, and ``:`` which have special meaning
        in ``_arguments`` spec syntax.

        Args:
            text: The text to escape.

        Returns:
            The escaped text.
        """
        var result = String("")
        for i in range(len(text)):
            var ch = text[byte = i : i + 1]
            if ch == "[" or ch == "]":
                result += "\\" + ch
            elif ch == "'":
                result += "'\"'\"'"
            elif ch == ":":
                result += "\\:"
            else:
                result += ch
        return result

    def _completion_bash(self) -> String:
        """Generates a Bash completion script using ``complete -F``.

        Returns:
            A complete Bash completion script.
        """
        var fn_name = "_" + self.name + "_completion"
        var s = String("# Bash completions for " + self.name + "\n")
        s += "# Generated by ArgMojo\n\n"
        s += fn_name + "() {\n"
        s += '  local cur="${COMP_WORDS[COMP_CWORD]}"\n'
        s += '  local prev="${COMP_WORDS[COMP_CWORD-1]}"\n'

        # Check if there are subcommands.
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if (
                not self.subcommands[i]._is_help_subcommand
                and not self.subcommands[i]._is_hidden
            ):
                has_subcommands = True
                break
        if self._completions_enabled and self._completions_is_subcommand:
            has_subcommands = True

        if has_subcommands:
            s += self._bash_with_subcommands()
        else:
            s += self._bash_simple()

        s += "}\n\n"
        s += "complete -F " + fn_name + " " + self.name + "\n"
        return s

    def _bash_simple(self) -> String:
        """Generates the body of a simple Bash completion function.

        Returns:
            The case/COMPREPLY logic for a command with no subcommands.
        """
        # Collect all option words.
        var words = String("--help --version")
        if self._completions_enabled and not self._completions_is_subcommand:
            words += " --" + self._completions_name
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if arg._is_hidden or arg._is_positional:
                continue
            if arg._long_name:
                words += " --" + arg._long_name
            if arg._short_name:
                words += " -" + arg._short_name

        # Handle value completion for prev.
        var s = self._bash_prev_cases()
        s += '  COMPREPLY=($(compgen -W "' + words + '" -- "$cur"))\n'
        return s

    def _bash_with_subcommands(self) -> String:
        """Generates the body of a Bash completion function with subcommands.

        Uses ``COMP_WORDS`` scanning to detect which subcommand is active,
        then scopes completions accordingly.

        Returns:
            The completion logic body string.
        """
        # Collect subcommand names.
        var sub_names = String("")
        for i in range(len(self.subcommands)):
            if (
                self.subcommands[i]._is_help_subcommand
                or self.subcommands[i]._is_hidden
            ):
                continue
            if sub_names:
                sub_names += " "
            sub_names += self.subcommands[i].name
            for _ai in range(len(self.subcommands[i]._command_aliases)):
                sub_names += " " + self.subcommands[i]._command_aliases[_ai]
        if self._completions_enabled and self._completions_is_subcommand:
            if sub_names:
                sub_names += " "
            sub_names += self._completions_name

        var s = String("")
        # Root-level options.
        var root_words = String("--help --version")
        if self._completions_enabled and not self._completions_is_subcommand:
            root_words += " --" + self._completions_name
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if arg._is_hidden or arg._is_positional:
                continue
            if arg._long_name:
                root_words += " --" + arg._long_name
            if arg._short_name:
                root_words += " -" + arg._short_name

        # Detect subcommand in COMP_WORDS.
        s += "  local subcmd=''\n"
        s += "  for ((i=1; i<COMP_CWORD; i++)); do\n"
        s += "    case ${COMP_WORDS[i]} in\n"
        s += "      " + sub_names.replace(" ", "|") + ")\n"
        s += "        subcmd=${COMP_WORDS[i]}\n"
        s += "        break\n"
        s += "        ;;\n"
        s += "    esac\n"
        s += "  done\n\n"

        s += "  if [[ -z $subcmd ]]; then\n"
        # Root-level $prev choices completion.
        s += self._bash_prev_cases_for_args(self.args, "    ")
        s += (
            '    COMPREPLY=($(compgen -W "'
            + root_words
            + " "
            + sub_names
            + '" -- "$cur"))\n'
        )
        s += "    return\n"
        s += "  fi\n\n"

        s += "  case $subcmd in\n"
        for i in range(len(self.subcommands)):
            if (
                self.subcommands[i]._is_help_subcommand
                or self.subcommands[i]._is_hidden
            ):
                continue
            var sub = self.subcommands[i].copy()
            var sub_words = String("--help")
            for j in range(len(sub.args)):
                var arg = sub.args[j].copy()
                if arg._is_hidden or arg._is_positional:
                    continue
                if arg._long_name:
                    sub_words += " --" + arg._long_name
                if arg._short_name:
                    sub_words += " -" + arg._short_name
            # Build pattern: name|alias1|alias2
            var bash_pat = sub.name
            for _ai in range(len(sub._command_aliases)):
                bash_pat += "|" + sub._command_aliases[_ai]
            s += "    " + bash_pat + ")\n"
            # Subcommand-level $prev choices completion.
            s += self._bash_prev_cases_for_args(sub.args, "      ")
            s += (
                '      COMPREPLY=($(compgen -W "'
                + sub_words
                + '" -- "$cur"))\n'
            )
            s += "      ;;\n"
        if self._completions_enabled and self._completions_is_subcommand:
            s += "    " + self._completions_name + ")\n"
            s += '      COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))\n'
            s += "      ;;\n"
        s += "  esac\n"
        return s

    def _bash_prev_cases(self) -> String:
        """Generates ``case $prev`` blocks for options with choices.

        When the previous word is an option that has a fixed set of
        choices, completes those values.

        Returns:
            A ``case``/``esac`` block string, or empty if no choices.
        """
        var has_choices = (
            self._completions_enabled and not self._completions_is_subcommand
        )
        if not has_choices:
            for i in range(len(self.args)):
                if (
                    not self.args[i]._is_hidden
                    and not self.args[i]._is_positional
                    and len(self.args[i]._choice_values) > 0
                ):
                    has_choices = True
                    break

        if not has_choices:
            return ""

        var s = String("  case $prev in\n")
        if self._completions_enabled and not self._completions_is_subcommand:
            s += "    --" + self._completions_name + ")\n"
            s += '      COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))\n'
            s += "      return\n"
            s += "      ;;\n"
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if (
                arg._is_hidden
                or arg._is_positional
                or len(arg._choice_values) == 0
            ):
                continue
            var pattern = String("")
            if arg._long_name:
                pattern += "--" + arg._long_name
            if arg._short_name:
                if pattern:
                    pattern += "|"
                pattern += "-" + arg._short_name
            var choices = String("")
            for k in range(len(arg._choice_values)):
                if choices:
                    choices += " "
                choices += arg._choice_values[k]
            s += "    " + pattern + ")\n"
            s += '      COMPREPLY=($(compgen -W "' + choices + '" -- "$cur"))\n'
            s += "      return\n"
            s += "      ;;\n"
        s += "  esac\n"
        return s

    def _bash_prev_cases_for_args(
        self, args: List[Argument], indent: String
    ) -> String:
        """Generates ``case $prev`` blocks for a given list of arguments.

        Used by ``_bash_with_subcommands()`` to emit choice-value
        completion for both root-level and subcommand-level options.

        Args:
            args: The argument list to scan for choice-bearing options.
            indent: Whitespace prefix for each emitted line.

        Returns:
            A ``case``/``esac`` block string, or empty if no choices.
        """
        var has_choices = False
        for i in range(len(args)):
            if (
                not args[i]._is_hidden
                and not args[i]._is_positional
                and len(args[i]._choice_values) > 0
            ):
                has_choices = True
                break
        if not has_choices:
            return ""

        var s = indent + "case $prev in\n"
        for i in range(len(args)):
            var arg = args[i].copy()
            if (
                arg._is_hidden
                or arg._is_positional
                or len(arg._choice_values) == 0
            ):
                continue
            var pattern = String("")
            if arg._long_name:
                pattern += "--" + arg._long_name
            if arg._short_name:
                if pattern:
                    pattern += "|"
                pattern += "-" + arg._short_name
            var choices = String("")
            for k in range(len(arg._choice_values)):
                if choices:
                    choices += " "
                choices += arg._choice_values[k]
            s += indent + "  " + pattern + ")\n"
            s += (
                indent
                + '    COMPREPLY=($(compgen -W "'
                + choices
                + '" -- "$cur"))\n'
            )
            s += indent + "    return\n"
            s += indent + "    ;;\n"
        s += indent + "esac\n"
        return s

    def write_to[W: Writer](self, mut writer: W):
        """Writes the string representation to a writer.

        Parameters:
            W: The writer type.

        Args:
            writer: The writer to write to.
        """
        writer.write("Command(name='")
        writer.write(self.name)
        writer.write("', args=")
        writer.write(String(len(self.args)))
        writer.write(")")
