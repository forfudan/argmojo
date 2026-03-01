"""Defines a CLI command and performs argument parsing."""

from sys import argv, exit, stderr

from .argument import Argument
from .parse_result import ParseResult
from .utils import (
    _RESET,
    _BOLD_UL,
    _DEFAULT_HEADER_COLOR,
    _DEFAULT_ARG_COLOR,
    _DEFAULT_WARN_COLOR,
    _DEFAULT_ERROR_COLOR,
    _looks_like_number,
    _resolve_color,
    _suggest_similar,
)


struct Command(Copyable, Movable, Stringable, Writable):
    """Defines a CLI command prototype with its arguments and handles parsing.

    Example:

    ```mojo
    from argmojo import Command, Argument
    var command = Command("myapp", "A sample application")
    command.add_argument(Argument("verbose", help="Enable verbose output").long("verbose").short("v").flag())
    var result = command.parse()
    ```
    """

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
    var _exclusive_groups: List[List[String]]
    """Groups of mutually exclusive argument names."""
    var _required_groups: List[List[String]]
    """Groups of arguments that must be provided together."""
    var _one_required_groups: List[List[String]]
    """Groups where at least one argument must be provided."""
    var _conditional_reqs: List[List[String]]
    """Pairs [target, condition]: target is required when condition is present."""
    var _help_on_no_args: Bool
    """When True, show help and exit if no arguments are provided."""
    var _header_color: String
    """ANSI code for section headers (Usage, Arguments, Options)."""
    var _arg_color: String
    """ANSI code for option / argument names."""
    var _warn_color: String
    """ANSI code for deprecation warning messages (default: orange)."""
    var _error_color: String
    """ANSI code for parse error messages (default: red)."""
    var _is_help_subcommand: Bool
    """True for the auto-inserted 'help' pseudo-subcommand.
    Never set this manually; use `add_subcommand()` to register subcommands and
    `disable_help_subcommand()` to opt out.
    """
    var _help_subcommand_enabled: Bool
    """When True (default), auto-insert a 'help' subcommand on first 
    `add_subcommand()` call."""
    var _allow_negative_numbers: Bool
    """When True, tokens matching negative-number format (-N, -N.N, -NeX)
    are always treated as positional arguments.
    When False (default), the same treatment applies automatically whenever
    no registered short option uses a digit character (auto-detect).
    Enable explicitly via `allow_negative_numbers()` when you have a digit
    short option and still need negative-number literals to pass through."""
    var _allow_positional_with_subcommands: Bool
    """When True, allows mixing positional arguments with subcommands.
    By default (False), registering a positional arg on a Command that already 
    has subcommands (or vice versa) raises an Error at registration time.
    Call `allow_positional_with_subcommands()` to opt in explicitly."""
    var _tips: List[String]
    """User-defined tips shown at the bottom of the help message.
    Add entries via ``add_tip()``.  Each tip is printed on its own line
    prefixed with the same bold ``Tip:`` label as the built-in hint."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(
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
        self._exclusive_groups = List[List[String]]()
        self._required_groups = List[List[String]]()
        self._one_required_groups = List[List[String]]()
        self._conditional_reqs = List[List[String]]()
        self._help_on_no_args = False
        self._is_help_subcommand = False
        self._help_subcommand_enabled = True
        self._allow_negative_numbers = False
        self._allow_positional_with_subcommands = False
        self._tips = List[String]()
        self._header_color = _DEFAULT_HEADER_COLOR
        self._arg_color = _DEFAULT_ARG_COLOR
        self._warn_color = _DEFAULT_WARN_COLOR
        self._error_color = _DEFAULT_ERROR_COLOR

    fn __moveinit__(out self, deinit move: Self):
        """Moves a Command, transferring ownership of all fields.

        Args:
            move: The Command to move from.
        """
        self.name = move.name^
        self.description = move.description^
        self.version = move.version^
        self.args = move.args^
        self.subcommands = move.subcommands^
        self._exclusive_groups = move._exclusive_groups^
        self._required_groups = move._required_groups^
        self._one_required_groups = move._one_required_groups^
        self._conditional_reqs = move._conditional_reqs^
        self._help_on_no_args = move._help_on_no_args
        self._is_help_subcommand = move._is_help_subcommand
        self._help_subcommand_enabled = move._help_subcommand_enabled
        self._allow_negative_numbers = move._allow_negative_numbers
        self._allow_positional_with_subcommands = (
            move._allow_positional_with_subcommands
        )
        self._tips = move._tips^
        self._header_color = move._header_color^
        self._arg_color = move._arg_color^
        self._warn_color = move._warn_color^
        self._error_color = move._error_color^

    fn __copyinit__(out self, copy: Self):
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
        self._help_on_no_args = copy._help_on_no_args
        self._is_help_subcommand = copy._is_help_subcommand
        self._help_subcommand_enabled = copy._help_subcommand_enabled
        self._allow_negative_numbers = copy._allow_negative_numbers
        self._allow_positional_with_subcommands = (
            copy._allow_positional_with_subcommands
        )
        self._tips = copy._tips.copy()
        self._header_color = copy._header_color
        self._arg_color = copy._arg_color
        self._warn_color = copy._warn_color
        self._error_color = copy._error_color

    # ===------------------------------------------------------------------=== #
    # Builder methods for configuring the command
    # ===------------------------------------------------------------------=== #

    fn add_argument(mut self, var argument: Argument) raises:
        """Registers an argument definition.

        Raises:
            Error if adding a positional argument to a Command that already
            has subcommands registered, unless
            ``allow_positional_with_subcommands()`` has been called.

        Args:
            argument: The Argument to register.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("verbose", help="Enable verbose output"))
        var result = command.parse()
        ```
        """
        # Guard: positional args + subcommands require explicit opt-in.
        if (
            argument.is_positional
            and len(self.subcommands) > 0
            and not self._allow_positional_with_subcommands
        ):
            self._error(
                "Cannot add positional argument '"
                + argument.name
                + "' to '"
                + self.name
                + "' which already has subcommands. Call"
                " allow_positional_with_subcommands() to opt in"
            )
        self.args.append(argument^)

    fn add_subcommand(mut self, var sub: Command) raises:
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

        Example:

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
                if self.args[_pi].is_positional:
                    self._error(
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
            if not self.args[pi].is_persistent:
                continue
            var pa = self.args[pi].copy()
            for ci in range(len(sub.args)):
                var ca = sub.args[ci].copy()
                if (
                    pa.long_name
                    and ca.long_name
                    and pa.long_name == ca.long_name
                ):
                    self._error(
                        "Persistent flag '--"
                        + pa.long_name
                        + "' on '"
                        + self.name
                        + "' conflicts with '--"
                        + ca.long_name
                        + "' on subcommand '"
                        + sub.name
                        + "'"
                    )
                if (
                    pa.short_name
                    and ca.short_name
                    and pa.short_name == ca.short_name
                ):
                    self._error(
                        "Persistent flag '-"
                        + pa.short_name
                        + "' on '"
                        + self.name
                        + "' conflicts with '-"
                        + ca.short_name
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

    fn disable_help_subcommand(mut self):
        """Opts out of the auto-added ``help`` subcommand.

        By default, the first call to ``add_subcommand()`` automatically
        registers a ``help`` subcommand so that ``app help <sub>`` works as
        an alias for ``app <sub> --help``.

        Call this before or after ``add_subcommand()`` to suppress the
        feature — useful when ``"help"`` is a legitimate first positional
        value (e.g. a search pattern or entity name).  After disabling, use
        ``app <sub> --help`` directly.

        Example:

        ```mojo
        from argmojo import Command
        var app = Command("search", "Search engine")
        app.disable_help_subcommand()   # "help" is a valid search query
        # Now: `search help init`  →  positionals ["help", "init"] on root,
        #    so that you can do something like: search "help" in path "init".
        #    `search init --help`  →  shows init's help page
        ```
        """
        self._help_subcommand_enabled = False
        # Remove any already-inserted help subcommand.
        var new_subs = List[Command]()
        for i in range(len(self.subcommands)):
            if not self.subcommands[i]._is_help_subcommand:
                new_subs.append(self.subcommands[i].copy())
        self.subcommands = new_subs^

    fn allow_negative_numbers(mut self):
        """Treats tokens that look like negative numbers as positional arguments.

        By default ArgMojo already auto-detects negative-number tokens
        (``-9``, ``-3.14``, ``-1.5e10``) and passes them through as
        positionals **when no registered short option starts with a digit**.
        Call this method explicitly when you have registered a digit short
        option (e.g., ``-3`` for ``--triple``) and still need negative-number
        literals to be treated as positionals.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("calc", "Calculator")
        command.allow_negative_numbers()
        command.add_argument(Argument("expr", help="Expression").positional().required())
        # Now: calc -10.18  →  positionals = ["-10.18"]
        ```
        """
        self._allow_negative_numbers = True

    fn allow_positional_with_subcommands(mut self):
        """Allows a Command to have both positional args and subcommands.

        By default, ArgMojo follows the convention of cobra (Go) and clap
        (Rust): a Command with subcommands cannot also have positional
        arguments, because the parser cannot unambiguously distinguish a
        subcommand name from a positional value.

        Call this method **before** registering positional args and
        subcommands to opt in to the mixed mode.  In mixed mode, a token
        that exactly matches a registered subcommand name is dispatched;
        any other token falls through to the positional list.

        Example:

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

    fn add_tip(mut self, tip: String):
        """Adds a custom tip line to the bottom of the help message.

        Each tip is printed on its own line below the built-in ``--``
        separator hint, prefixed with a bold ``Tip:`` label.  Useful for
        documenting shell idioms, environment variables, or any other
        usage notes that don't fit in argument help strings.

        Args:
            tip: The tip text to display.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_tip("Set MYAPP_DEBUG=1 to enable debug logging.")
        command.add_tip("Config file: ~/.config/myapp/config.toml")
        ```
        """
        self._tips.append(tip)

    fn mutually_exclusive(mut self, var names: List[String]):
        """Declares a group of mutually exclusive arguments.

        At most one argument from each group may be provided. Parsing
        will fail if more than one is present.

        Args:
            names: The internal names of the arguments in the group.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("json", help="Output as JSON").long("json").flag())
        command.add_argument(Argument("yaml", help="Output as YAML").long("yaml").flag())
        var format_excl: List[String] = ["json", "yaml"]
        command.mutually_exclusive(format_excl^)
        ```
        """
        self._exclusive_groups.append(names^)

    fn required_together(mut self, var names: List[String]):
        """Declares a group of arguments that must be provided together.

        If any argument from the group is provided, all others in the
        group must also be provided. Parsing will fail otherwise.

        Args:
            names: The internal names of the arguments in the group.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("username", help="Auth username").long("username").short("u"))
        command.add_argument(Argument("password", help="Auth password").long("password").short("p"))
        var auth_group: List[String] = ["username", "password"]
        command.required_together(auth_group^)
        ```
        """
        self._required_groups.append(names^)

    fn one_required(mut self, var names: List[String]):
        """Declares a group where at least one argument must be provided.

        Parsing will fail if none of the arguments in the group are
        present on the command line.

        Args:
            names: The internal names of the arguments in the group.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("json", help="Output as JSON").long("json").flag())
        command.add_argument(Argument("yaml", help="Output as YAML").long("yaml").flag())
        var format_group: List[String] = ["json", "yaml"]
        command.one_required(format_group^)
        ```
        """
        self._one_required_groups.append(names^)

    fn required_if(mut self, target: String, condition: String):
        """Declares that an argument is required when another is present.

        When ``condition`` is provided on the command line, ``target``
        must also be provided.  Parsing will fail otherwise.

        Args:
            target: The name of the argument that becomes required.
            condition: The name of the argument that triggers the requirement.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("save", help="Save results").long("save").flag())
        command.add_argument(Argument("output", help="Output path").long("output").short("o"))
        command.required_if("output", "save")
        ```
        """
        var pair: List[String] = [target, condition]
        self._conditional_reqs.append(pair^)

    fn help_on_no_args(mut self):
        """Enables showing help when invoked with no arguments.

        When enabled, calling the command with no arguments (only the
        program name) will print the help message and exit.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("file", help="Input file").long("file").required())
        command.help_on_no_args()
        ```
        """
        self._help_on_no_args = True

    fn header_color(mut self, name: String) raises:
        """Sets the colour for section headers (Usage, Arguments, Options).

        Headers are always rendered in **bold + underline**; this method
        controls only the foreground colour.

        Accepted colour names (case-insensitive): ``RED``, ``GREEN``,
        ``YELLOW``, ``BLUE``, ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``,
        ``ORANGE``.

        Args:
            name: The colour name.

        Raises:
            Error if the name is not recognised.

        Example:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.header_color("YELLOW")
        ```
        """
        self._header_color = _resolve_color(name)

    fn arg_color(mut self, name: String) raises:
        """Sets the colour for option and argument names in help output.

        Accepted colour names (case-insensitive): ``RED``, ``GREEN``,
        ``YELLOW``, ``BLUE``, ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``,
        ``ORANGE``.

        Args:
            name: The colour name.

        Raises:
            Error if the name is not recognised.

        Example:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.arg_color("GREEN")
        ```
        """
        self._arg_color = _resolve_color(name)

    fn warn_color(mut self, name: String) raises:
        """Sets the colour for deprecation warning messages.

        Accepted colour names (case-insensitive): ``RED``, ``GREEN``,
        ``YELLOW``, ``BLUE``, ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``,
        ``ORANGE``.

        Args:
            name: The colour name.

        Raises:
            Error if the name is not recognised.

        Example:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.warn_color("YELLOW")  # change from default orange
        ```
        """
        self._warn_color = _resolve_color(name)

    fn error_color(mut self, name: String) raises:
        """Sets the colour for parse error messages.

        Accepted colour names (case-insensitive): ``RED``, ``GREEN``,
        ``YELLOW``, ``BLUE``, ``MAGENTA``, ``PINK``, ``CYAN``, ``WHITE``,
        ``ORANGE``.

        Args:
            name: The colour name.

        Raises:
            Error if the name is not recognised.

        Example:

        ```mojo
        from argmojo import Command
        var command = Command("myapp", "A sample application")
        command.error_color("MAGENTA")  # change from default red
        ```
        """
        self._error_color = _resolve_color(name)

    # Here is a high-level outline of the parsing algorithm implemented in
    # `parse_args`:
    #
    # 1. Initialize ParseResult and register positional names.
    # 2. If `help_on_no_args` is enabled and only argv[0] is present:
    #    print help and exit.
    # 3. Iterate from argv[1] with cursor `i`:
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
    #       │   build child argv, call child.parse_args(), store result, break.
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

    # ===------------------------------------------------------------------=== #
    # Private output helpers
    # ===------------------------------------------------------------------=== #

    fn _warn(self, msg: String):
        """Prints a coloured warning message to stderr."""
        print(self._warn_color + "warning: " + msg + _RESET, file=stderr)

    fn _error(self, msg: String) raises:
        """Prints a coloured error message to stderr then raises.

        All parse-time errors funnel through this method so that callers
        of both ``parse()`` and ``parse_args()`` always see coloured output
        while tests can still catch the raised ``Error`` normally.
        The command name is included in the stderr output so that errors
        from subcommands show the full path (e.g. ``app search: ...``).
        """
        print(
            self._error_color + "error: " + self.name + ": " + msg + _RESET,
            file=stderr,
        )
        raise Error(msg)

    fn _error_with_usage(self, msg: String) raises:
        """Prints a coloured error with a usage hint and help tip, then raises.

        Used for validation errors (missing required args, too many positionals)
        where showing the usage line helps the user understand what is expected.
        """
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

    fn _plain_usage(self) -> String:
        """Returns a plain-text usage line (no ANSI colours).

        Example output: ``Usage: git clone <repository> [directory] [OPTIONS]``
        """
        var s = String("Usage: ") + self.name
        for i in range(len(self.args)):
            if self.args[i].is_positional and not self.args[i].is_hidden:
                if self.args[i].is_required:
                    s += " <" + self.args[i].name + ">"
                else:
                    s += " [" + self.args[i].name + "]"
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if not self.subcommands[i]._is_help_subcommand:
                has_subcommands = True
                break
        if has_subcommands:
            s += " <COMMAND>"
        s += " [OPTIONS]"
        return s

    fn parse(self) raises -> ParseResult:
        """Parses command-line arguments from `sys.argv()`.

        Errors from parsing (missing/invalid arguments, validation failures)
        are printed in colour to stderr and the process exits with code 2.
        This matches the behaviour of Python's ``argparse``.

        Use ``parse_args()`` directly if you want to catch errors yourself.

        Returns:
            A ParseResult containing all parsed values.
        """
        var raw_variadic = argv()
        var raw = List[String]()
        for i in range(len(raw_variadic)):
            raw.append(String(raw_variadic[i]))
        try:
            return self.parse_args(raw)
        except:
            # Error message was already printed to stderr by _error().
            exit(2)
            # Unreachable — exit() terminates the process — but the
            # compiler does not model exit() as @noreturn yet.
            return ParseResult()

    fn parse_args(self, raw_args: List[String]) raises -> ParseResult:
        """Parses the given argument list.

        The first element, e.g., `argv[0]`, is expected to be the program name
        and is skipped.

        Args:
            raw_args: The raw argument strings (including program name at index 0).

        Returns:
            A ParseResult containing all parsed values.

        Raises:
            Error on invalid or missing arguments.

        Notes:

        The modifier for `self` is `read` but not `mut`. This ensures that the
        parsing process does not mutate the Command instance itself, which
        prevents contamination and conflicts between multiple parses, e.g.,
        in testing scenarios, REPL usage, and autocompletion.
        """
        var result = ParseResult()

        # Register positional argument names in order.
        for i in range(len(self.args)):
            if self.args[i].is_positional:
                result._positional_names.append(self.args[i].name)

        # Skip argv[0] and start from argv[1].
        var i: Int = 1
        var stop_parsing_options = False

        # Show help when invoked with no arguments (if enabled).
        if self._help_on_no_args and len(raw_args) <= 1:
            print(self._generate_help())
            exit(0)

        # === PARSING PHASE === #

        while i < len(raw_args):
            var arg = raw_args[i]

            # Handle "--" stop marker.
            if arg == "--" and not stop_parsing_options:
                stop_parsing_options = True
                i += 1
                continue

            if stop_parsing_options:
                result.positionals.append(arg)
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

            # Long option: --key, --key=value, --key value
            if arg.startswith("--"):
                i = self._parse_long_option(raw_args, i, result)
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
                        var sn = self.args[_ni].short_name
                        if sn >= "0" and sn <= "9":
                            has_digit_short = True
                            break
                    if self._allow_negative_numbers or not has_digit_short:
                        result.positionals.append(arg)
                        i += 1
                        continue
                # ────────────────────────────────────────────────────────────
                var key = String(arg[1:])
                if len(key) == 1:
                    i = self._parse_short_single(key, raw_args, i, result)
                else:
                    i = self._parse_short_merged(key, raw_args, i, result)
                continue

            # Positional argument — check for subcommand dispatch first.
            if len(self.subcommands) > 0:
                var new_i = self._dispatch_subcommand(arg, raw_args, i, result)
                if new_i >= 0:
                    i = new_i
                    continue

            result.positionals.append(arg)
            i += 1

        # Apply defaults and validate constraints.
        self._apply_defaults(result)
        self._validate(result)

        return result^

    # ===------------------------------------------------------------------=== #
    # Parsing sub-methods (extracted from parse_args for readability)
    # ===------------------------------------------------------------------=== #

    fn _parse_long_option(
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
        var key = String(arg[2:])  # strip leading "--"
        var value = String("")
        var has_eq = False

        # Check for --key=value format.
        var eq_pos = key.find("=")
        if eq_pos >= 0:
            # Split into key and value parts.
            value = String(key[eq_pos + 1 :])
            key = String(key[:eq_pos])
            has_eq = True

        # Check for --no-X negation pattern (with prefix matching).
        var is_negation = False
        if key.startswith("no-") and not has_eq:
            var base_key = String(key[3:])
            # Exact match first.
            for idx in range(len(self.args)):
                if (
                    self.args[idx].long_name == base_key
                    and self.args[idx].is_negatable
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
                        self.args[idx].long_name
                        and self.args[idx].long_name.startswith(base_key)
                        and self.args[idx].is_negatable
                    ):
                        neg_candidates.append(self.args[idx].long_name)
                        neg_idx = idx
                if len(neg_candidates) == 1:
                    is_negation = True
                    key = self.args[neg_idx].long_name
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
        if matched.deprecated_msg:
            self._warn(
                "'--" + key + "' is deprecated: " + matched.deprecated_msg
            )
        if is_negation:
            result.flags[matched.name] = False
        elif matched.is_count and not has_eq:
            # Count flag: increment counter.
            var cur: Int = 0
            try:
                cur = result.counts[matched.name]
            except:
                pass
            result.counts[matched.name] = cur + 1
        elif matched.is_flag and not has_eq:
            result.flags[matched.name] = True
        elif matched.nargs_count > 0:
            # nargs: consume exactly N values.
            if has_eq:
                self._error(
                    "Option '--"
                    + key
                    + "' takes "
                    + String(matched.nargs_count)
                    + " values; '=' syntax is not supported"
                )
            if matched.name not in result.lists:
                result.lists[matched.name] = List[String]()
            for _n in range(matched.nargs_count):
                i += 1
                if i >= len(raw_args):
                    self._error(
                        "Option '--"
                        + key
                        + "' requires "
                        + String(matched.nargs_count)
                        + " values"
                    )
                self._validate_choices(matched, raw_args[i])
                result.lists[matched.name].append(raw_args[i])
        else:
            if not has_eq:
                i += 1
                if i >= len(raw_args):
                    self._error("Option '--" + key + "' requires a value")
                value = raw_args[i]
            if matched.is_map:
                self._store_map_value(matched, value, result)
            elif matched.is_append:
                self._store_append_value(matched, value, result)
            else:
                self._validate_choices(matched, value)
                result.values[matched.name] = value
        i += 1
        return i

    fn _parse_short_single(
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
        if matched.deprecated_msg:
            self._warn(
                "'-" + key + "' is deprecated: " + matched.deprecated_msg
            )
        if matched.is_count:
            var cur: Int = 0
            try:
                cur = result.counts[matched.name]
            except:
                pass
            result.counts[matched.name] = cur + 1
        elif matched.is_flag:
            result.flags[matched.name] = True
        elif matched.nargs_count > 0:
            # nargs: consume exactly N values.
            if matched.name not in result.lists:
                result.lists[matched.name] = List[String]()
            for _n in range(matched.nargs_count):
                i += 1
                if i >= len(raw_args):
                    self._error(
                        "Option '-"
                        + key
                        + "' requires "
                        + String(matched.nargs_count)
                        + " values"
                    )
                self._validate_choices(matched, raw_args[i])
                result.lists[matched.name].append(raw_args[i])
        else:
            i += 1
            if i >= len(raw_args):
                self._error("Option '-" + key + "' requires a value")
            var val = raw_args[i]
            if matched.is_map:
                self._store_map_value(matched, val, result)
            elif matched.is_append:
                self._store_append_value(matched, val, result)
            else:
                self._validate_choices(matched, val)
                result.values[matched.name] = val
        i += 1
        return i

    fn _parse_short_merged(
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
        var first_char = String(key[0:1])
        var first_match = self._find_by_short(first_char)

        if first_match.is_flag:
            # First char is a flag — treat entire string as merged
            # flags, except the last char which may take a value.
            var j: Int = 0
            while j < len(key):
                var ch = String(key[j : j + 1])
                var m = self._find_by_short(ch)
                # Emit deprecation warning if applicable.
                if m.deprecated_msg:
                    self._warn(
                        "'-" + ch + "' is deprecated: " + m.deprecated_msg
                    )
                if m.is_count:
                    var cur: Int = 0
                    try:
                        cur = result.counts[m.name]
                    except:
                        pass
                    result.counts[m.name] = cur + 1
                    j += 1
                elif m.is_flag:
                    result.flags[m.name] = True
                    j += 1
                elif m.nargs_count > 0:
                    # nargs in merged flags: rest of string is
                    # ignored; consume N values from argv.
                    if m.name not in result.lists:
                        result.lists[m.name] = List[String]()
                    for _n in range(m.nargs_count):
                        i += 1
                        if i >= len(raw_args):
                            self._error(
                                "Option '-"
                                + ch
                                + "' requires "
                                + String(m.nargs_count)
                                + " values"
                            )
                        self._validate_choices(m, raw_args[i])
                        result.lists[m.name].append(raw_args[i])
                    j = len(key)  # break
                else:
                    # This char takes a value — rest of string is
                    # the value.
                    var val = String(key[j + 1 :])
                    if len(val) == 0:
                        i += 1
                        if i >= len(raw_args):
                            self._error("Option '-" + ch + "' requires a value")
                        val = raw_args[i]
                    if m.is_map:
                        self._store_map_value(m, val, result)
                    elif m.is_append:
                        self._store_append_value(m, val, result)
                    else:
                        self._validate_choices(m, val)
                        result.values[m.name] = val
                    j = len(key)  # break
        else:
            # First char takes a value — rest of string is the
            # attached value (e.g., -ofile.txt).
            # Emit deprecation warning if applicable.
            if first_match.deprecated_msg:
                self._warn(
                    "'-"
                    + first_char
                    + "' is deprecated: "
                    + first_match.deprecated_msg
                )
            if first_match.nargs_count > 0:
                # nargs: consume N values from argv (ignore attached).
                if first_match.name not in result.lists:
                    result.lists[first_match.name] = List[String]()
                for _n in range(first_match.nargs_count):
                    i += 1
                    if i >= len(raw_args):
                        self._error(
                            "Option '-"
                            + first_char
                            + "' requires "
                            + String(first_match.nargs_count)
                            + " values"
                        )
                    self._validate_choices(first_match, raw_args[i])
                    result.lists[first_match.name].append(raw_args[i])
            elif first_match.is_map:
                var val = String(key[1:])
                self._store_map_value(first_match, val, result)
            elif first_match.is_append:
                var val = String(key[1:])
                self._store_append_value(first_match, val, result)
            else:
                var val = String(key[1:])
                self._validate_choices(first_match, val)
                result.values[first_match.name] = val
        i += 1
        return i

    fn _dispatch_subcommand(
        self,
        arg: String,
        raw_args: List[String],
        i: Int,
        mut result: ParseResult,
    ) raises -> Int:
        """Attempts to dispatch to a matching subcommand.

        If a subcommand matches, it builds a child argv, injects
        persistent args, parses via the child's ``parse_args()``,
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
        # Exact subcommand name match → dispatch.
        var sub_idx = self._find_subcommand(arg)
        if sub_idx >= 0:
            # Build child argv: ["parent sub", remaining tokens...].
            var child_argv = List[String]()
            child_argv.append(self.name + " " + arg)
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
            child_copy.name = self.name + " " + arg
            for _pi in range(len(self.args)):
                if self.args[_pi].is_persistent:
                    child_copy.args.append(self.args[_pi].copy())
            var child_result = child_copy.parse_args(child_argv)
            # Bubble up persistent values from child to root result so
            # that root_result.get_flag("x") always works regardless of
            # whether the flag appeared before or after the subcommand
            # token. (If root already parsed the flag before reaching
            # the subcommand token, its value takes precedence.)
            # Also push down root-parsed persistent values to child
            # result so that sub_result.get_flag("x") always works too.
            for _pi in range(len(self.args)):
                if not self.args[_pi].is_persistent:
                    continue
                var _pn = self.args[_pi].name
                # Bubble up: child parsed flag after subcommand token.
                if _pn in child_result.flags and _pn not in result.flags:
                    result.flags[_pn] = child_result.flags[_pn]
                if _pn in child_result.values and _pn not in result.values:
                    result.values[_pn] = child_result.values[_pn]
                if _pn in child_result.counts and _pn not in result.counts:
                    result.counts[_pn] = child_result.counts[_pn]
                # Push down: root parsed flag before subcommand token.
                if _pn in result.flags and _pn not in child_result.flags:
                    child_result.flags[_pn] = result.flags[_pn]
                if _pn in result.values and _pn not in child_result.values:
                    child_result.values[_pn] = result.values[_pn]
                if _pn in result.counts and _pn not in child_result.counts:
                    child_result.counts[_pn] = result.counts[_pn]
            result.subcommand = arg
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
                    if not self.subcommands[_si]._is_help_subcommand:
                        if not first:
                            avail += ", "
                        avail += self.subcommands[_si].name
                        first = False
                # Try typo suggestion for subcommand names.
                var sub_names = List[String]()
                for _si2 in range(len(self.subcommands)):
                    if not self.subcommands[_si2]._is_help_subcommand:
                        sub_names.append(self.subcommands[_si2].name)
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
    # Defaults & validation helpers (extracted for subcommand reuse)
    # ===------------------------------------------------------------------=== #

    fn _apply_defaults(self, mut result: ParseResult):
        """Fills in default values for arguments not provided by the user.

        For positional arguments, defaults are placed into the correct slot.
        For named arguments, the default is stored in `result.values`.

        Args:
            result: The parse result to mutate in-place.

        Notes:

        This method is made standalone so that subcommands can reuse it.
        """
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a.has_default and not result.has(a.name):
                if a.is_positional:
                    # Fill positional to the right slot.
                    for k in range(len(result._positional_names)):
                        if result._positional_names[k] == a.name:
                            while len(result.positionals) <= k:
                                result.positionals.append("")
                            if not result.positionals[k]:
                                result.positionals[k] = a.default_value
                else:
                    result.values[a.name] = a.default_value

    fn _validate(self, result: ParseResult) raises:
        """Runs all post-parse validation checks on the result.

        Checks (in order):
        1. Required arguments are present.
        2. Positional argument count is not exceeded.
        3. Mutually exclusive groups have at most one member set.
        4. Required-together groups are all-or-nothing.
        5. One-required groups have at least one member set.
        6. Conditional requirements are satisfied.
        7. Numeric range constraints are met.

        Args:
            result: The parse result to validate.

        Raises:
            Error if any validation check fails.
        """
        # Validate required arguments.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a.is_required and not result.has(a.name):
                self._error_with_usage(
                    "Required argument '" + a.name + "' was not provided"
                )

        # Validate positional argument count — too many args is an error.
        var expected_count: Int = len(result._positional_names)
        if expected_count > 0 and len(result.positionals) > expected_count:
            self._error_with_usage(
                "Too many positional arguments: expected "
                + String(expected_count)
                + ", got "
                + String(len(result.positionals))
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

        # Validate numeric range constraints.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a.has_range and result.has(a.name):
                # Get the raw string value(s) for this argument.
                if a.is_append:
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
                        if v < a.range_min or v > a.range_max:
                            var display = String("'") + a.name + "'"
                            if a.long_name:
                                display = "'--" + a.long_name + "'"
                            self._error(
                                "Value "
                                + String(v)
                                + " for "
                                + display
                                + " is out of range ["
                                + String(a.range_min)
                                + ", "
                                + String(a.range_max)
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
                    if v < a.range_min or v > a.range_max:
                        var display = String("'") + a.name + "'"
                        if a.long_name:
                            display = "'--" + a.long_name + "'"
                        self._error(
                            "Value "
                            + String(v)
                            + " for "
                            + display
                            + " is out of range ["
                            + String(a.range_min)
                            + ", "
                            + String(a.range_max)
                            + "]"
                        )

    # ===------------------------------------------------------------------=== #
    # Argument lookup helpers
    # ===------------------------------------------------------------------=== #

    fn _find_by_long(self, name: String) raises -> Argument:
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
            if self.args[i].long_name == name:
                return self.args[i].copy()

        # 2. Exact match on aliases.
        for i in range(len(self.args)):
            for j in range(len(self.args[i].alias_names)):
                if self.args[i].alias_names[j] == name:
                    return self.args[i].copy()

        # 3. Prefix match on long_name.
        var candidates = List[String]()
        var candidate_idx: Int = -1
        for i in range(len(self.args)):
            if self.args[i].long_name and self.args[i].long_name.startswith(
                name
            ):
                candidates.append(self.args[i].long_name)
                candidate_idx = i

        # 4. Prefix match on aliases.
        for i in range(len(self.args)):
            for j in range(len(self.args[i].alias_names)):
                if self.args[i].alias_names[j].startswith(name):
                    # Avoid duplicate if the same arg already matched via long_name.
                    var already = False
                    for k in range(len(candidates)):
                        if candidates[k] == self.args[i].long_name:
                            already = True
                            break
                    if not already:
                        candidates.append(self.args[i].long_name)
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
            if self.args[i].long_name != "":
                all_longs.append(self.args[i].long_name)
            for j in range(len(self.args[i].alias_names)):
                all_longs.append(self.args[i].alias_names[j])
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

    fn _find_by_short(self, name: String) raises -> Argument:
        """Finds an argument definition by its short name.

        Args:
            name: The short option name (without '-').

        Returns:
            The matching Argument.

        Raises:
            Error if no argument matches.
        """
        for i in range(len(self.args)):
            if self.args[i].short_name == name:
                return self.args[i].copy()
        # Short options are always a single character; any two single-character
        # inputs have Levenshtein distance ≤ 1, so the threshold would always
        # fire and produce meaningless suggestions (e.g. "-z" → "Did you mean
        # '-v'?"). Suggestions are therefore disabled for short options.
        self._error("Unknown option '-" + name + "'")
        raise Error(
            "unreachable"
        )  # _error() always raises; satisfies Mojo's return checker

    fn _find_subcommand(self, name: String) -> Int:
        """Returns the index of the registered subcommand matching ``name``.

        Args:
            name: Subcommand name to look up.

        Returns:
            The index into ``self.subcommands``, or ``-1`` if not found.
        """
        for i in range(len(self.subcommands)):
            if self.subcommands[i].name == name:
                return i
        return -1

    fn _display_name(self, name: String) -> String:
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
                if self.args[i].long_name:
                    return "'--" + self.args[i].long_name + "'"
                elif self.args[i].short_name:
                    return "'-" + self.args[i].short_name + "'"
                break
        return "'" + name + "'"

    fn _validate_choices(self, arg: Argument, value: String) raises:
        """Validates that the value is in the allowed choices.

        Args:
            arg: The argument definition.
            value: The value to validate.

        Raises:
            Error if the value is not in the allowed choices.
        """
        if len(arg.choice_values) == 0:
            return
        for i in range(len(arg.choice_values)):
            if arg.choice_values[i] == value:
                return
        var allowed = String("")
        for i in range(len(arg.choice_values)):
            if i > 0:
                allowed += ", "
            allowed += "'" + arg.choice_values[i] + "'"
        self._error(
            "Invalid value '"
            + value
            + "' for argument '"
            + arg.name
            + "' (choose from "
            + allowed
            + ")"
        )

    fn _store_append_value(
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
        if arg.name not in result.lists:
            result.lists[arg.name] = List[String]()
        if arg.delimiter_char:
            var parts = value.split(arg.delimiter_char)
            for p in range(len(parts)):
                var piece = String(parts[p])
                if piece:  # skip empty pieces from e.g. trailing comma
                    self._validate_choices(arg, piece)
                    result.lists[arg.name].append(piece)
        else:
            self._validate_choices(arg, value)
            result.lists[arg.name].append(value)

    fn _store_map_value(
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
        if arg.name not in result.maps:
            result.maps[arg.name] = Dict[String, String]()
        # Also store in lists for has() detection.
        if arg.name not in result.lists:
            result.lists[arg.name] = List[String]()

        if arg.delimiter_char:
            var parts = value.split(arg.delimiter_char)
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
                    var k = String(piece[:eq])
                    var v = String(piece[eq + 1 :])
                    result.maps[arg.name][k] = v
                    result.lists[arg.name].append(piece)
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
            var k = String(value[:eq])
            var v = String(value[eq + 1 :])
            result.maps[arg.name][k] = v
            result.lists[arg.name].append(value)

    fn _generate_help(self, color: Bool = True) -> String:
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
        var arg_color = self._arg_color if color else ""
        var header_color = (_BOLD_UL + self._header_color) if color else ""
        var reset_code = _RESET if color else ""

        var s = String("")
        s += self._help_usage_line(arg_color, header_color, reset_code)
        s += self._help_positionals_section(arg_color, header_color, reset_code)
        s += self._help_options_section(arg_color, header_color, reset_code)
        s += self._help_commands_section(arg_color, header_color, reset_code)
        s += self._help_tips_section(header_color, reset_code)
        return s

    fn _help_usage_line(
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
        s += header_color + "Usage:" + reset_code + " "
        s += arg_color + self.name + reset_code

        # Show positional args in usage line.
        for i in range(len(self.args)):
            if self.args[i].is_positional and not self.args[i].is_hidden:
                if self.args[i].is_required:
                    s += (
                        " "
                        + arg_color
                        + "<"
                        + self.args[i].name
                        + ">"
                        + reset_code
                    )
                else:
                    s += (
                        " "
                        + arg_color
                        + "["
                        + self.args[i].name
                        + "]"
                        + reset_code
                    )

        # Show <COMMAND> placeholder when subcommands are registered.
        var has_subcommands = False
        for i in range(len(self.subcommands)):
            if not self.subcommands[i]._is_help_subcommand:
                has_subcommands = True
                break
        if has_subcommands:
            s += " " + arg_color + "<COMMAND>" + reset_code

        s += " " + arg_color + "[OPTIONS]" + reset_code + "\n\n"
        return s

    fn _help_positionals_section(
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
            if self.args[i].is_positional and not self.args[i].is_hidden:
                has_positional = True
                break

        if not has_positional:
            return ""

        # Two-pass for dynamic padding.
        var pos_plains = List[String]()  # plain text for padding calc
        var pos_colors = List[String]()  # coloured text for display
        var pos_helps = List[String]()
        for i in range(len(self.args)):
            if self.args[i].is_positional and not self.args[i].is_hidden:
                var plain = String("  ") + self.args[i].name
                var colored = (
                    String("  ") + arg_color + self.args[i].name + reset_code
                )
                pos_plains.append(plain)
                pos_colors.append(colored)
                pos_helps.append(self.args[i].help_text)

        var pos_max: Int = 0
        for k in range(len(pos_plains)):
            if len(pos_plains[k]) > pos_max:
                pos_max = len(pos_plains[k])
        var pos_pad = pos_max + 4

        var s = header_color + "Arguments:" + reset_code + "\n"
        for k in range(len(pos_plains)):
            var line = pos_colors[k]
            if pos_helps[k]:
                # Pad based on plain-text width.
                var padding = pos_pad - len(pos_plains[k])
                for _p in range(padding):
                    line += " "
                line += pos_helps[k]
            s += line + "\n"
        s += "\n"
        return s

    fn _help_options_section(
        self,
        arg_color: String,
        header_color: String,
        reset_code: String,
    ) -> String:
        """Generates the 'Options:' and 'Global Options:' sections.

        Separates local options from persistent (global) options and
        displays them under distinct headings.  Built-in ``--help`` and
        ``--version`` are always appended to the local section.

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

        for i in range(len(self.args)):
            if not self.args[i].is_positional and not self.args[i].is_hidden:
                var plain = String("  ")
                var colored = String("  ")
                if self.args[i].short_name:
                    plain += "-" + self.args[i].short_name
                    colored += (
                        arg_color + "-" + self.args[i].short_name + reset_code
                    )
                    if self.args[i].long_name:
                        plain += ", "
                        colored += ", "
                else:
                    plain += "    "
                    colored += "    "
                if self.args[i].long_name:
                    var long_part = String("--") + self.args[i].long_name
                    plain += long_part
                    colored += arg_color + long_part + reset_code
                    if self.args[i].is_negatable:
                        var neg_part = (
                            String(" / --no-") + self.args[i].long_name
                        )
                        plain += neg_part
                        colored += (
                            " / "
                            + arg_color
                            + "--no-"
                            + self.args[i].long_name
                            + reset_code
                        )
                    # Show aliases.
                    for j in range(len(self.args[i].alias_names)):
                        var alias_part = (
                            String(", --") + self.args[i].alias_names[j]
                        )
                        plain += alias_part
                        colored += (
                            ", "
                            + arg_color
                            + "--"
                            + self.args[i].alias_names[j]
                            + reset_code
                        )

                # Show metavar or choices for value-taking options.
                if not self.args[i].is_flag:
                    var ncount = self.args[i].nargs_count
                    var repeat = ncount if ncount > 0 else 1
                    var append_dots = self.args[i].is_append and ncount == 0
                    if self.args[i].metavar_name:
                        var mv = self.args[i].metavar_name
                        var mv_plain = String("")
                        var mv_colored = String("")
                        for _r in range(repeat - 1):
                            mv_plain += " " + mv
                            mv_colored += " " + arg_color + mv + reset_code
                        # Last (or only) occurrence — attach "..." if append.
                        var last = mv + ("..." if append_dots else "")
                        mv_plain += " " + last
                        mv_colored += " " + arg_color + last + reset_code
                        plain += mv_plain
                        colored += mv_colored
                    elif len(self.args[i].choice_values) > 0:
                        var choices_str = String("{")
                        for j in range(len(self.args[i].choice_values)):
                            if j > 0:
                                choices_str += ","
                            choices_str += self.args[i].choice_values[j]
                        choices_str += "}"
                        var suffix = choices_str
                        if append_dots:
                            suffix += "..."
                        plain += " " + suffix
                        colored += " " + arg_color + suffix + reset_code
                    else:
                        # Default placeholder: <key=value> for map, <name> otherwise.
                        var tag: String
                        if self.args[i].is_map:
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
                        ph_plain += " " + last
                        ph_colored += " " + arg_color + last + reset_code
                        plain += ph_plain
                        colored += ph_colored

                opt_plains.append(plain)
                opt_colors.append(colored)
                opt_persistent.append(self.args[i].is_persistent)
                # Append deprecation notice to help text if applicable.
                var help = self.args[i].help_text
                if self.args[i].deprecated_msg:
                    if help:
                        help += " "
                    help += "[deprecated: " + self.args[i].deprecated_msg + "]"
                opt_helps.append(help)

        # Built-in options (always shown under local "Options:" section).
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
        opt_helps.append(String("Show this help message"))
        opt_plains.append(version_plain)
        opt_colors.append(version_colored)
        opt_persistent.append(False)
        opt_helps.append(String("Show version"))

        # Check if there are any persistent (global) options.
        var has_global = False
        for k in range(len(opt_persistent)):
            if opt_persistent[k]:
                has_global = True
                break

        # Compute padding width for local and global options separately.
        var local_max: Int = 0
        var global_max: Int = 0
        for k in range(len(opt_plains)):
            if opt_persistent[k]:
                if len(opt_plains[k]) > global_max:
                    global_max = len(opt_plains[k])
            else:
                if len(opt_plains[k]) > local_max:
                    local_max = len(opt_plains[k])
        var local_pad = local_max + 4
        var global_pad = global_max + 4

        # Pass 2: assemble padded lines using coloured text.
        # Local options.
        var s = header_color + "Options:" + reset_code + "\n"
        for k in range(len(opt_plains)):
            if not opt_persistent[k]:
                var line = opt_colors[k]
                if opt_helps[k]:
                    var padding = local_pad - len(opt_plains[k])
                    for _p in range(padding):
                        line += " "
                    line += opt_helps[k]
                s += line + "\n"

        # Global (persistent) options — shown under a separate heading.
        if has_global:
            s += "\n" + header_color + "Global Options:" + reset_code + "\n"
            for k in range(len(opt_plains)):
                if opt_persistent[k]:
                    var line = opt_colors[k]
                    if opt_helps[k]:
                        var padding = global_pad - len(opt_plains[k])
                        for _p in range(padding):
                            line += " "
                        line += opt_helps[k]
                    s += line + "\n"

        return s

    fn _help_commands_section(
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
            if not self.subcommands[i]._is_help_subcommand:
                has_subcommands = True
                break

        if not has_subcommands:
            return ""

        var cmd_plains = List[String]()
        var cmd_colors = List[String]()
        var cmd_helps = List[String]()
        for i in range(len(self.subcommands)):
            if not self.subcommands[i]._is_help_subcommand:
                var plain = String("  ") + self.subcommands[i].name
                var colored = (
                    String("  ")
                    + arg_color
                    + self.subcommands[i].name
                    + reset_code
                )
                cmd_plains.append(plain)
                cmd_colors.append(colored)
                cmd_helps.append(self.subcommands[i].description)
        # Compute padding.
        var cmd_max: Int = 0
        for k in range(len(cmd_plains)):
            if len(cmd_plains[k]) > cmd_max:
                cmd_max = len(cmd_plains[k])
        var cmd_pad = cmd_max + 4
        var s = "\n" + header_color + "Commands:" + reset_code + "\n"
        for k in range(len(cmd_plains)):
            var line = cmd_colors[k]
            if cmd_helps[k]:
                var padding = cmd_pad - len(cmd_plains[k])
                for _p in range(padding):
                    line += " "
                line += cmd_helps[k]
            s += line + "\n"

        return s

    fn _help_tips_section(
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
            if self.args[i].is_positional and not self.args[i].is_hidden:
                has_positional = True
                break

        # Tip: show '--' separator hint when positional args are registered.
        # When negative numbers are already handled automatically (either via
        # explicit allow_negative_numbers() or auto-detect: no digit short
        # options), the example changes to a generic dash-prefixed value
        # rather than '-10.18', since that case no longer needs '--'.
        var tip_lines = List[String]()
        if has_positional:
            var neg_auto = self._allow_negative_numbers
            if not neg_auto:
                var has_digit_short = False
                for _ti in range(len(self.args)):
                    var sc = self.args[_ti].short_name
                    if len(sc) == 1 and sc[0:1] >= "0" and sc[0:1] <= "9":
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

    fn print_summary(self, result: ParseResult):
        """Prints a human-readable summary of all parsed arguments.

        Iterates over registered argument definitions and prints each
        argument's display name (``--long`` / ``-s``) alongside its
        parsed value.  Hidden arguments are included only when they
        were actually provided.

        Args:
            result: The ParseResult returned by ``parse()`` or ``parse_args()``.
        """
        print("=== Parsed Arguments ===")

        # Positional arguments.
        for i in range(len(self.args)):
            if self.args[i].is_positional:
                var val = String("(not set)")
                try:
                    val = result.get_string(self.args[i].name)
                except:
                    pass
                print("  " + self.args[i].name + ": " + val)

        # Named arguments — two-pass for dynamic column alignment.
        # First pass: collect display names and value strings.
        var displays = List[String]()
        var value_strs = List[String]()
        for i in range(len(self.args)):
            if self.args[i].is_positional:
                continue
            # Skip hidden args that weren't provided.
            if self.args[i].is_hidden and not result.has(self.args[i].name):
                continue

            var display = String("")
            if self.args[i].short_name:
                display += "-" + self.args[i].short_name
            if self.args[i].long_name:
                if display:
                    display += ", "
                display += "--" + self.args[i].long_name
            displays.append(display)

            var val_str: String
            if self.args[i].is_count:
                val_str = String(result.get_count(self.args[i].name))
            elif self.args[i].is_flag:
                val_str = String(result.get_flag(self.args[i].name))
            elif self.args[i].is_map:
                if self.args[i].name in result.maps:
                    var m = result.get_map(self.args[i].name)
                    var s = String("{")
                    var first = True
                    for entry in m.items():
                        if not first:
                            s += ", "
                        s += entry.key + "=" + entry.value
                        first = False
                    s += "}"
                    val_str = s
                else:
                    val_str = "{}"
            elif self.args[i].is_append:
                var lst = result.get_list(self.args[i].name)
                if len(lst) > 0:
                    var s = String("[")
                    for j in range(len(lst)):
                        if j > 0:
                            s += ", "
                        s += lst[j]
                    s += "]"
                    val_str = s
                else:
                    val_str = "[]"
            else:
                if result.has(self.args[i].name):
                    var s = String("")
                    try:
                        s = result.get_string(self.args[i].name)
                    except:
                        pass
                    val_str = s
                else:
                    val_str = "(not set)"
            value_strs.append(val_str)

        # Compute padding width from the longest display name.
        var max_len: Int = 0
        for k in range(len(displays)):
            if len(displays[k]) > max_len:
                max_len = len(displays[k])
        var pad_width = max_len + 2

        # Second pass: print with aligned columns.
        for k in range(len(displays)):
            var line = "  " + displays[k]
            var padding = pad_width - len(displays[k])
            for _p in range(padding):
                line += " "
            line += value_strs[k]
            print(line)

    fn __str__(self) -> String:
        """Returns a string representation of this command."""
        return (
            "Command(name='"
            + self.name
            + "', args="
            + String(len(self.args))
            + ")"
        )

    fn write_to[W: Writer](self, mut writer: W):
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
