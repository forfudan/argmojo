"""Defines a CLI command and performs argument parsing."""

from sys import argv, exit, stderr

from .arg import Arg
from .result import ParseResult

# ── ANSI colour codes ────────────────────────────────────────────────────────
comptime _RESET = "\x1b[0m"
comptime _BOLD_UL = "\x1b[1;4m"  # bold + underline (no colour)

# Bright foreground colours.
comptime _RED = "\x1b[91m"
comptime _GREEN = "\x1b[92m"
comptime _YELLOW = "\x1b[93m"
comptime _BLUE = "\x1b[94m"
comptime _MAGENTA = "\x1b[95m"
comptime _CYAN = "\x1b[96m"
comptime _WHITE = "\x1b[97m"
comptime _ORANGE = "\x1b[33m"  # dark yellow — renders as orange on most terminals

# Default colours.
comptime _DEFAULT_HEADER_COLOR = _YELLOW
comptime _DEFAULT_ARG_COLOR = _MAGENTA
comptime _DEFAULT_WARN_COLOR = _ORANGE
comptime _DEFAULT_ERROR_COLOR = _RED


fn _looks_like_number(token: String) -> Bool:
    """Returns True if *token* is a negative-number literal.

    Recognises the forms ``-N``, ``-N.N``, ``-.N``, ``-NeX``, ``-N.NeX``,
    and the corresponding ``-Ne+X`` / ``-Ne-X`` variants (same grammar as
    Python / argparse numeric detection).
    """
    if len(token) < 2 or token[0:1] != "-":
        return False
    var j = 1
    # Optional leading '.' after minus (e.g. -.5).
    if token[j : j + 1] == ".":
        j += 1
        if j >= len(token) or not (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            return False
    elif not (token[j : j + 1] >= "0" and token[j : j + 1] <= "9"):
        return False
    # Integer digits.
    while j < len(token) and (
        token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
    ):
        j += 1
    # Optional fractional part.
    if j < len(token) and token[j : j + 1] == ".":
        j += 1
        while j < len(token) and (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            j += 1
    # Optional exponent.
    if j < len(token) and (token[j : j + 1] == "e" or token[j : j + 1] == "E"):
        j += 1
        if j < len(token) and (
            token[j : j + 1] == "+" or token[j : j + 1] == "-"
        ):
            j += 1
        if j >= len(token) or not (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            return False
        while j < len(token) and (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            j += 1
    return j == len(token)


fn _is_ascii_digit(ch: String) -> Bool:
    """Returns True if *ch* is a single ASCII digit character ('0'-'9')."""
    return ch >= "0" and ch <= "9"


fn _resolve_color(name: String) raises -> String:
    """Maps a user-facing colour name to its ANSI code.

    Accepted names (case-insensitive): RED, GREEN, YELLOW, BLUE,
    MAGENTA, PINK (alias for MAGENTA), CYAN, WHITE, ORANGE.

    Returns:
        The ANSI escape code for the colour.

    Raises:
        Error if the name is not recognised.
    """
    var upper = name.upper()
    if upper == "RED":
        return _RED
    if upper == "GREEN":
        return _GREEN
    if upper == "YELLOW":
        return _YELLOW
    if upper == "BLUE":
        return _BLUE
    if upper == "MAGENTA" or upper == "PINK":
        return _MAGENTA
    if upper == "CYAN":
        return _CYAN
    if upper == "WHITE":
        return _WHITE
    if upper == "ORANGE":
        return _ORANGE
    raise Error(
        "Unknown colour '"
        + name
        + "'. Choose from: RED, GREEN, YELLOW, BLUE, MAGENTA, PINK, CYAN,"
        " WHITE, ORANGE"
    )


struct Command(Copyable, Movable, Stringable, Writable):
    """Defines a CLI command prototype with its arguments and handles parsing.

    Example:

    ```mojo
    from argmojo import Command, Arg
    var cmd = Command("myapp", "A sample application")
    cmd.add_arg(Arg("verbose", help="Enable verbose output").long("verbose").short("v").flag())
    var result = cmd.parse()
    ```
    """

    var name: String
    """The command name (typically the program name)."""
    var description: String
    """A short description of the command, shown in help text."""
    var version: String
    """Version string for --version output."""
    var args: List[Arg]
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
        self.args = List[Arg]()
        self.subcommands = List[Command]()
        self._exclusive_groups = List[List[String]]()
        self._required_groups = List[List[String]]()
        self._one_required_groups = List[List[String]]()
        self._conditional_reqs = List[List[String]]()
        self._help_on_no_args = False
        self._is_help_subcommand = False
        self._help_subcommand_enabled = True
        self._allow_negative_numbers = False
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
        self._header_color = copy._header_color
        self._arg_color = copy._arg_color
        self._warn_color = copy._warn_color
        self._error_color = copy._error_color

    # ===------------------------------------------------------------------=== #
    # Builder methods for configuring the command
    # ===------------------------------------------------------------------=== #

    fn add_arg(mut self, var arg: Arg):
        """Registers an argument definition.

        Args:
            arg: The Arg to register.

        Example:

        ```mojo
        from argmojo import Command, Arg
        var cmd = Command("myapp", "A sample application")
        cmd.add_arg(Arg("verbose", help="Enable verbose output"))
        var result = cmd.parse()
        ```
        """
        self.args.append(arg^)

    fn add_subcommand(mut self, var sub: Command):
        """Registers a subcommand.

        A subcommand is a full ``Command`` instance that handles a specific verb
        (e.g. ``app search …``, ``app init …``).  After parsing, the selected
        subcommand name is stored in ``result.subcommand`` and its own parsed
        values are available via ``result.get_subcommand_result()``.

        Args:
            sub: The subcommand ``Command`` to register.

        Example:

        ```mojo
        from argmojo import Command, Arg

        var app = Command("app", "My CLI tool", version="0.3.0")

        var search = Command("search", "Search for patterns")
        search.add_arg(Arg("pattern", help="Search pattern").required().positional())

        var init = Command("init", "Initialize a new project")
        init.add_arg(Arg("name", help="Project name").required().positional())

        app.add_subcommand(search^)
        app.add_subcommand(init^)
        ```
        """
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
        from argmojo import Command, Arg
        var cmd = Command("calc", "Calculator")
        cmd.allow_negative_numbers()
        cmd.add_arg(Arg("expr", help="Expression").positional().required())
        # Now: calc -9.5  →  positionals = ["-9.5"]
        ```
        """
        self._allow_negative_numbers = True

    fn mutually_exclusive(mut self, var names: List[String]):
        """Declares a group of mutually exclusive arguments.

        At most one argument from each group may be provided. Parsing
        will fail if more than one is present.

        Args:
            names: The internal names of the arguments in the group.

        Example:

        ```mojo
        from argmojo import Command, Arg
        var cmd = Command("myapp", "A sample application")
        cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
        cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
        var format_excl: List[String] = ["json", "yaml"]
        cmd.mutually_exclusive(format_excl^)
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
        from argmojo import Command, Arg
        var cmd = Command("myapp", "A sample application")
        cmd.add_arg(Arg("username", help="Auth username").long("username").short("u"))
        cmd.add_arg(Arg("password", help="Auth password").long("password").short("p"))
        var auth_group: List[String] = ["username", "password"]
        cmd.required_together(auth_group^)
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
        from argmojo import Command, Arg
        var cmd = Command("myapp", "A sample application")
        cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
        cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
        var format_group: List[String] = ["json", "yaml"]
        cmd.one_required(format_group^)
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
        from argmojo import Command, Arg
        var cmd = Command("myapp", "A sample application")
        cmd.add_arg(Arg("save", help="Save results").long("save").flag())
        cmd.add_arg(Arg("output", help="Output path").long("output").short("o"))
        cmd.required_if("output", "save")
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
        from argmojo import Command, Arg
        var cmd = Command("myapp", "A sample application")
        cmd.add_arg(Arg("file", help="Input file").long("file").required())
        cmd.help_on_no_args()
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
        var cmd = Command("myapp", "A sample application")
        cmd.header_color("YELLOW")
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
        var cmd = Command("myapp", "A sample application")
        cmd.arg_color("GREEN")
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
        var cmd = Command("myapp", "A sample application")
        cmd.warn_color("YELLOW")  # change from default orange
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
        var cmd = Command("myapp", "A sample application")
        cmd.error_color("MAGENTA")  # change from default red
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
        """
        print(self._error_color + "error: " + msg + _RESET, file=stderr)
        raise Error(msg)

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
                                and self.args[idx].long_name.startswith(
                                    base_key
                                )
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

                var matched: Arg = self._find_by_long(key)
                # Emit deprecation warning if applicable.
                if matched.deprecated_msg:
                    self._warn(
                        "'--"
                        + key
                        + "' is deprecated: "
                        + matched.deprecated_msg
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
                            self._error(
                                "Option '--" + key + "' requires a value"
                            )
                        value = raw_args[i]
                    if matched.is_map:
                        self._store_map_value(matched, value, result)
                    elif matched.is_append:
                        self._store_append_value(matched, value, result)
                    else:
                        self._validate_choices(matched, value)
                        result.values[matched.name] = value
                i += 1
                continue

            # Short option: -k, -k value, -abc (merged flags), -ofile.txt
            if arg.startswith("-") and len(arg) > 1:
                # ── Negative-number detection (argparse-style) ──────────────
                # A token like "-9.5e3" is treated as a positional value when:
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

                # Single-char short option: -f or -k value
                if len(key) == 1:
                    var matched = self._find_by_short(key)
                    # Emit deprecation warning if applicable.
                    if matched.deprecated_msg:
                        self._warn(
                            "'-"
                            + key
                            + "' is deprecated: "
                            + matched.deprecated_msg
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
                            self._error(
                                "Option '-" + key + "' requires a value"
                            )
                        var val = raw_args[i]
                        if matched.is_map:
                            self._store_map_value(matched, val, result)
                        elif matched.is_append:
                            self._store_append_value(matched, val, result)
                        else:
                            self._validate_choices(matched, val)
                            result.values[matched.name] = val
                    i += 1
                    continue

                # Multi-char: could be merged flags (-abc) or attached
                # value (-ofile.txt).
                # Strategy: try first char as a short option.
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
                                "'-"
                                + ch
                                + "' is deprecated: "
                                + m.deprecated_msg
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
                                    self._error(
                                        "Option '-" + ch + "' requires a value"
                                    )
                                val = raw_args[i]
                            if m.is_map:
                                self._store_map_value(m, val, result)
                            elif m.is_append:
                                self._store_append_value(m, val, result)
                            else:
                                self._validate_choices(m, val)
                                result.values[m.name] = val
                            j = len(key)  # break
                    i += 1
                    continue
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
                    continue

            # Positional argument — check for subcommand dispatch first.
            if len(self.subcommands) > 0:
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
                            var target_idx = self._find_subcommand(
                                child_argv[1]
                            )
                            if (
                                target_idx >= 0
                                and not self.subcommands[
                                    target_idx
                                ]._is_help_subcommand
                            ):
                                print(
                                    self.subcommands[
                                        target_idx
                                    ]._generate_help()
                                )
                                exit(0)
                        # No target, unknown, or self-referential → root help.
                        print(self._generate_help())
                        exit(0)
                    var child_result = self.subcommands[sub_idx].parse_args(
                        child_argv
                    )
                    result.subcommand = arg
                    result._subcommand_results.append(child_result^)
                    # All remaining tokens were consumed by the child.
                    i = len(raw_args)
                    continue

            result.positionals.append(arg)
            i += 1

        # Apply defaults and validate constraints.
        self._apply_defaults(result)
        self._validate(result)

        return result^

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
                self._error(
                    "Required argument '" + a.name + "' was not provided"
                )

        # Validate positional argument count — too many args is an error.
        var expected_count: Int = len(result._positional_names)
        if expected_count > 0 and len(result.positionals) > expected_count:
            self._error(
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

    fn _find_by_long(self, name: String) raises -> Arg:
        """Finds an argument definition by its long name, alias, or unambiguous prefix.

        Resolution order:
        1. Exact match on long_name.
        2. Exact match on any alias.
        3. Prefix match on long_name.
        4. Prefix match on aliases.

        Args:
            name: The long option name (without '--'), or an unambiguous prefix.

        Returns:
            The matching Arg.

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

        self._error("Unknown option '--" + name + "'")
        raise Error(
            "unreachable"
        )  # _error() always raises; satisfies Mojo's return checker

    fn _find_by_short(self, name: String) raises -> Arg:
        """Finds an argument definition by its short name.

        Args:
            name: The short option name (without '-').

        Returns:
            The matching Arg.

        Raises:
            Error if no argument matches.
        """
        for i in range(len(self.args)):
            if self.args[i].short_name == name:
                return self.args[i].copy()
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

    fn _validate_choices(self, arg: Arg, value: String) raises:
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
        self, arg: Arg, value: String, mut result: ParseResult
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
        self, arg: Arg, value: String, mut result: ParseResult
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

        Args:
            color: When True (default), include ANSI colour codes.

        Returns:
            A formatted help string.
        """
        # Resolve colour tokens — empty strings when colour is off.
        var C = self._arg_color if color else ""
        var H = (_BOLD_UL + self._header_color) if color else ""
        var R = _RESET if color else ""

        var s = String("")
        if self.description:
            s += self.description + "\n\n"

        # Usage line.
        s += H + "Usage:" + R + " "
        s += C + self.name + R

        # Show positional args in usage line.
        for i in range(len(self.args)):
            if self.args[i].is_positional and not self.args[i].is_hidden:
                if self.args[i].is_required:
                    s += " " + C + "<" + self.args[i].name + ">" + R
                else:
                    s += " " + C + "[" + self.args[i].name + "]" + R

        s += " " + C + "[OPTIONS]" + R + "\n\n"

        # Positional arguments section.
        var has_positional = False
        for i in range(len(self.args)):
            if self.args[i].is_positional and not self.args[i].is_hidden:
                has_positional = True
                break

        if has_positional:
            # Two-pass for dynamic padding.
            var pos_plains = List[String]()  # plain text for padding calc
            var pos_colors = List[String]()  # coloured text for display
            var pos_helps = List[String]()
            for i in range(len(self.args)):
                if self.args[i].is_positional and not self.args[i].is_hidden:
                    var plain = String("  ") + self.args[i].name
                    var colored = String("  ") + C + self.args[i].name + R
                    pos_plains.append(plain)
                    pos_colors.append(colored)
                    pos_helps.append(self.args[i].help_text)

            var pos_max: Int = 0
            for k in range(len(pos_plains)):
                if len(pos_plains[k]) > pos_max:
                    pos_max = len(pos_plains[k])
            var pos_pad = pos_max + 4

            s += H + "Arguments:" + R + "\n"
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

        # Options section — two-pass for dynamic padding.
        # Pass 1: build plain + coloured left-hand sides.
        var opt_plains = List[String]()
        var opt_colors = List[String]()
        var opt_helps = List[String]()

        for i in range(len(self.args)):
            if not self.args[i].is_positional and not self.args[i].is_hidden:
                var plain = String("  ")
                var colored = String("  ")
                if self.args[i].short_name:
                    plain += "-" + self.args[i].short_name
                    colored += C + "-" + self.args[i].short_name + R
                    if self.args[i].long_name:
                        plain += ", "
                        colored += ", "
                else:
                    plain += "    "
                    colored += "    "
                if self.args[i].long_name:
                    var long_part = String("--") + self.args[i].long_name
                    plain += long_part
                    colored += C + long_part + R
                    if self.args[i].is_negatable:
                        var neg_part = (
                            String(" / --no-") + self.args[i].long_name
                        )
                        plain += neg_part
                        colored += (
                            " / " + C + "--no-" + self.args[i].long_name + R
                        )
                    # Show aliases.
                    for j in range(len(self.args[i].alias_names)):
                        var alias_part = (
                            String(", --") + self.args[i].alias_names[j]
                        )
                        plain += alias_part
                        colored += (
                            ", " + C + "--" + self.args[i].alias_names[j] + R
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
                            mv_colored += " " + C + mv + R
                        # Last (or only) occurrence — attach "..." if append.
                        var last = mv + ("..." if append_dots else "")
                        mv_plain += " " + last
                        mv_colored += " " + C + last + R
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
                        colored += " " + C + suffix + R
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
                            ph_colored += " " + C + tag + R
                        # Last (or only) — attach "..." if append.
                        var last = tag + ("..." if append_dots else "")
                        ph_plain += " " + last
                        ph_colored += " " + C + last + R
                        plain += ph_plain
                        colored += ph_colored

                opt_plains.append(plain)
                opt_colors.append(colored)
                # Append deprecation notice to help text if applicable.
                var help = self.args[i].help_text
                if self.args[i].deprecated_msg:
                    if help:
                        help += " "
                    help += "[deprecated: " + self.args[i].deprecated_msg + "]"
                opt_helps.append(help)

        # Built-in options.
        var help_plain = String("  -h, --help")
        var help_colored = (
            "  " + C + "-h" + R + ", " + C + "--help" + R
        )  # Not show -? in help message as it requires quoting in some shells
        var version_plain = String("  -V, --version")
        var version_colored = "  " + C + "-V" + R + ", " + C + "--version" + R
        opt_plains.append(help_plain)
        opt_colors.append(help_colored)
        opt_helps.append(String("Show this help message"))
        opt_plains.append(version_plain)
        opt_colors.append(version_colored)
        opt_helps.append(String("Show version"))

        # Determine padding width: max plain-text left-side length + 4.
        var max_left: Int = 0
        for k in range(len(opt_plains)):
            if len(opt_plains[k]) > max_left:
                max_left = len(opt_plains[k])
        var pad_width = max_left + 4

        # Pass 2: assemble padded lines using coloured text.
        s += H + "Options:" + R + "\n"
        for k in range(len(opt_plains)):
            var line = opt_colors[k]
            if opt_helps[k]:
                var padding = pad_width - len(opt_plains[k])
                for _p in range(padding):
                    line += " "
                line += opt_helps[k]
            s += line + "\n"

        # Tip: show '--' separator hint when positional args are registered.
        if has_positional:
            s += (
                "\n"
                + H
                + "Tip:"
                + _RESET
                + " Use '--' to pass values that start with '-' (e.g.,"
                " negative numbers):  "
                + self.name
                + " -- -9.5\n"
            )

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
