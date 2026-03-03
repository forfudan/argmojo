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

    # === Private fields ===
    var _exclusive_groups: List[List[String]]
    """Groups of mutually exclusive argument names."""
    var _required_groups: List[List[String]]
    """Groups of arguments that must be provided together."""
    var _one_required_groups: List[List[String]]
    """Groups where at least one argument must be provided."""
    var _conditional_reqs: List[List[String]]
    """Pairs [target, condition]: target is required when condition is present."""
    var _help_on_no_arguments: Bool
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
    Never set this manually; use ``add_subcommand()`` to register subcommands and
    ``disable_help_subcommand()`` to opt out.
    """
    var _help_subcommand_enabled: Bool
    """When True (default), auto-insert a 'help' subcommand on first 
    ``add_subcommand()`` call."""
    var _allow_negative_numbers: Bool
    """When True, tokens matching negative-number format (-N, -N.N, -NeX)
    are always treated as positional arguments.
    When False (default), the same treatment applies automatically whenever
    no registered short option uses a digit character (auto-detect).
    Enable explicitly via ``allow_negative_numbers()`` when you have a digit
    short option and still need negative-number literals to pass through."""
    var _allow_positional_with_subcommands: Bool
    """When True, allows mixing positional arguments with subcommands.
    By default (False), registering a positional arg on a Command that already 
    has subcommands (or vice versa) raises an Error at registration time.
    Call ``allow_positional_with_subcommands()`` to opt in explicitly."""
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
    var _command_aliases: List[String]
    """Alternate names for this command when used as a subcommand.
    Add entries via ``command_aliases()``.  Aliases are matched during
    subcommand dispatch and appear inline next to the primary name in
    help (e.g., "clone, cl"), but are not shown as separate entries."""
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
        self._help_on_no_arguments = False
        self._is_help_subcommand = False
        self._help_subcommand_enabled = True
        self._allow_negative_numbers = False
        self._allow_positional_with_subcommands = False
        self._completions_enabled = True
        self._completions_name = String("completions")
        self._completions_is_subcommand = False
        self._command_aliases = List[String]()
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
        self._help_on_no_arguments = move._help_on_no_arguments
        self._is_help_subcommand = move._is_help_subcommand
        self._help_subcommand_enabled = move._help_subcommand_enabled
        self._allow_negative_numbers = move._allow_negative_numbers
        self._allow_positional_with_subcommands = (
            move._allow_positional_with_subcommands
        )
        self._completions_enabled = move._completions_enabled
        self._completions_name = move._completions_name^
        self._completions_is_subcommand = move._completions_is_subcommand
        self._command_aliases = move._command_aliases^
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
        self._help_on_no_arguments = copy._help_on_no_arguments
        self._is_help_subcommand = copy._is_help_subcommand
        self._help_subcommand_enabled = copy._help_subcommand_enabled
        self._allow_negative_numbers = copy._allow_negative_numbers
        self._allow_positional_with_subcommands = (
            copy._allow_positional_with_subcommands
        )
        self._completions_enabled = copy._completions_enabled
        self._completions_name = copy._completions_name
        self._completions_is_subcommand = copy._completions_is_subcommand
        self._command_aliases = copy._command_aliases.copy()
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

    fn disable_default_completions(mut self):
        """Disables the built-in completion trigger entirely.

        By default, every ``Command`` has a built-in ``--completions bash``
        (or ``zsh`` / ``fish``) that prints a shell completion script and
        exits.  Call this method to remove that trigger completely.

        The ``generate_completion()`` method is still available for
        programmatic use — only the automatic trigger is removed.

        Example:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My CLI")
        app.disable_default_completions()
        # --completions is now an unknown option
        # but app.generate_completion("bash") still works
        ```
        """
        self._completions_enabled = False

    fn completions_name(mut self, name: String):
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

        Example:

        ```mojo
        from argmojo import Command
        var app = Command("myapp", "My CLI")
        app.completions_name("autocomp")
        # Now: myapp --autocomp bash
        ```
        """
        self._completions_name = name

    fn completions_as_subcommand(mut self):
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

    fn command_aliases(mut self, var names: List[String]):
        """Registers alternate names for this command when used as a subcommand.

        Aliases are matched during subcommand dispatch and included in
        shell completion scripts, but they do **not** appear as separate
        entries in the ``Commands:`` help section.  Instead, aliases are
        shown inline next to the primary name.

        Args:
            names: The list of alias strings.

        Example:

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

    fn help_on_no_arguments(mut self):
        """Enables showing help when invoked with no arguments.

        When enabled, calling the command with no arguments (only the
        program name) will print the help message and exit.

        Example:

        ```mojo
        from argmojo import Command, Argument
        var command = Command("myapp", "A sample application")
        command.add_argument(Argument("file", help="Input file").long("file").required())
        command.help_on_no_arguments()
        ```
        """
        self._help_on_no_arguments = True

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

    # ===------------------------------------------------------------------=== #
    # Private output helpers
    # ===------------------------------------------------------------------=== #

    fn _warn(self, msg: String):
        """Prints a coloured warning message to stderr."""
        print(self._warn_color + "warning: " + msg + _RESET, file=stderr)

    fn _error(self, msg: String) raises:
        """Prints a coloured error message to stderr then raises.

        All parse-time errors funnel through this method so that callers
        of both ``parse()`` and ``parse_arguments()`` always see coloured output
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

    fn parse_arguments(self, raw_args: List[String]) raises -> ParseResult:
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

        # Register positional argument names in order.
        for i in range(len(self.args)):
            if self.args[i].is_positional:
                result._positional_names.append(self.args[i].name)

        # Skip argv[0] and start from argv[1].
        var i: Int = 1
        var stop_parsing_options = False

        # Show help when invoked with no arguments (if enabled).
        if self._help_on_no_arguments and len(raw_args) <= 1:
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
                if i + 1 < len(raw_args):
                    i += 1
                    var shell_arg = raw_args[i]
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
                        result._positionals.append(arg)
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
            # Built-in completions subcommand (when in subcommand mode).
            if (
                self._completions_enabled
                and self._completions_is_subcommand
                and arg == self._completions_name
            ):
                if i + 1 < len(raw_args):
                    i += 1
                    var shell_arg = raw_args[i]
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
                var new_i = self._dispatch_subcommand(arg, raw_args, i, result)
                if new_i >= 0:
                    i = new_i
                    continue

            result._positionals.append(arg)
            i += 1

        # Apply defaults and validate constraints.
        self._apply_defaults(result)
        self._validate(result)

        return result^

    # ===------------------------------------------------------------------=== #
    # Parsing sub-methods (extracted from parse_arguments for readability)
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
            result._flags[matched.name] = False
        elif matched.is_count and not has_eq:
            # Count flag: increment counter.
            var cur: Int = 0
            try:
                cur = result._counts[matched.name]
            except:
                pass
            result._counts[matched.name] = cur + 1
        elif matched.is_flag and not has_eq:
            result._flags[matched.name] = True
        elif matched.num_values > 0:
            # nargs: consume exactly N values.
            if has_eq:
                self._error(
                    "Option '--"
                    + key
                    + "' takes "
                    + String(matched.num_values)
                    + " values; '=' syntax is not supported"
                )
            if matched.name not in result._lists:
                result._lists[matched.name] = List[String]()
            for _n in range(matched.num_values):
                i += 1
                if i >= len(raw_args):
                    self._error(
                        "Option '--"
                        + key
                        + "' requires "
                        + String(matched.num_values)
                        + " values"
                    )
                self._validate_choices(matched, raw_args[i])
                result._lists[matched.name].append(raw_args[i])
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
                result._values[matched.name] = value
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
                cur = result._counts[matched.name]
            except:
                pass
            result._counts[matched.name] = cur + 1
        elif matched.is_flag:
            result._flags[matched.name] = True
        elif matched.num_values > 0:
            # nargs: consume exactly N values.
            if matched.name not in result._lists:
                result._lists[matched.name] = List[String]()
            for _n in range(matched.num_values):
                i += 1
                if i >= len(raw_args):
                    self._error(
                        "Option '-"
                        + key
                        + "' requires "
                        + String(matched.num_values)
                        + " values"
                    )
                self._validate_choices(matched, raw_args[i])
                result._lists[matched.name].append(raw_args[i])
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
                result._values[matched.name] = val
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
                        cur = result._counts[m.name]
                    except:
                        pass
                    result._counts[m.name] = cur + 1
                    j += 1
                elif m.is_flag:
                    result._flags[m.name] = True
                    j += 1
                elif m.num_values > 0:
                    # nargs in merged flags: rest of string is
                    # ignored; consume N values from argv.
                    if m.name not in result._lists:
                        result._lists[m.name] = List[String]()
                    for _n in range(m.num_values):
                        i += 1
                        if i >= len(raw_args):
                            self._error(
                                "Option '-"
                                + ch
                                + "' requires "
                                + String(m.num_values)
                                + " values"
                            )
                        self._validate_choices(m, raw_args[i])
                        result._lists[m.name].append(raw_args[i])
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
                        result._values[m.name] = val
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
            if first_match.num_values > 0:
                # nargs: consume N values from argv (ignore attached).
                if first_match.name not in result._lists:
                    result._lists[first_match.name] = List[String]()
                for _n in range(first_match.num_values):
                    i += 1
                    if i >= len(raw_args):
                        self._error(
                            "Option '-"
                            + first_char
                            + "' requires "
                            + String(first_match.num_values)
                            + " values"
                        )
                    self._validate_choices(first_match, raw_args[i])
                    result._lists[first_match.name].append(raw_args[i])
            elif first_match.is_map:
                var val = String(key[1:])
                self._store_map_value(first_match, val, result)
            elif first_match.is_append:
                var val = String(key[1:])
                self._store_append_value(first_match, val, result)
            else:
                var val = String(key[1:])
                self._validate_choices(first_match, val)
                result._values[first_match.name] = val
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
                if self.args[_pi].is_persistent:
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
                if not self.args[_pi].is_persistent:
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
                    if not self.subcommands[_si]._is_help_subcommand:
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
                    if not self.subcommands[_si2]._is_help_subcommand:
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
    # Defaults & validation helpers (extracted for subcommand reuse)
    # ===------------------------------------------------------------------=== #

    fn _apply_defaults(self, mut result: ParseResult):
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
            if a.has_default and not result.has(a.name):
                if a.is_positional:
                    # Fill positional to the right slot.
                    for k in range(len(result._positional_names)):
                        if result._positional_names[k] == a.name:
                            while len(result._positionals) <= k:
                                result._positionals.append("")
                            if not result._positionals[k]:
                                result._positionals[k] = a.default_value
                else:
                    result._values[a.name] = a.default_value

    fn _validate(self, mut result: ParseResult) raises:
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
            if a.is_required and not result.has(a.name):
                self._error_with_usage(
                    "Required argument '" + a.name + "' was not provided"
                )

        # Validate positional argument count — too many args is an error.
        var expected_count: Int = len(result._positional_names)
        if expected_count > 0 and len(result._positionals) > expected_count:
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
            if a.is_count and a.has_count_max:
                var cur: Int
                try:
                    cur = result._counts[a.name]
                except:
                    continue
                if cur > a.count_max:
                    self._warn(
                        self._display_name(a.name)
                        + " count "
                        + String(cur)
                        + " exceeds maximum "
                        + String(a.count_max)
                        + ", capped to "
                        + String(a.count_max)
                    )
                    result._counts[a.name] = a.count_max

        # Validate numeric range constraints.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a.has_range and result.has(a.name):
                var display = self._display_name(a.name)
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
                            if a.is_clamp:
                                var clamped = v
                                if v < a.range_min:
                                    clamped = a.range_min
                                elif v > a.range_max:
                                    clamped = a.range_max
                                self._warn(
                                    display
                                    + " value "
                                    + String(v)
                                    + " is out of range ["
                                    + String(a.range_min)
                                    + ", "
                                    + String(a.range_max)
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
                        if a.is_clamp:
                            var clamped = v
                            if v < a.range_min:
                                clamped = a.range_min
                            elif v > a.range_max:
                                clamped = a.range_max
                            self._warn(
                                display
                                + " value "
                                + String(v)
                                + " is out of range ["
                                + String(a.range_min)
                                + ", "
                                + String(a.range_max)
                                + "], clamped to "
                                + String(clamped)
                            )
                            result._values[a.name] = String(clamped)
                            if a.is_positional:
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
        if arg.name not in result._lists:
            result._lists[arg.name] = List[String]()
        if arg.delimiter_char:
            var parts = value.split(arg.delimiter_char)
            for p in range(len(parts)):
                var piece = String(parts[p])
                if piece:  # skip empty pieces from e.g. trailing comma
                    self._validate_choices(arg, piece)
                    result._lists[arg.name].append(piece)
        else:
            self._validate_choices(arg, value)
            result._lists[arg.name].append(value)

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
        if arg.name not in result._maps:
            result._maps[arg.name] = Dict[String, String]()
        # Also store in lists for has() detection.
        if arg.name not in result._lists:
            result._lists[arg.name] = List[String]()

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
            var k = String(value[:eq])
            var v = String(value[eq + 1 :])
            result._maps[arg.name][k] = v
            result._lists[arg.name].append(value)

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
                    var ncount = self.args[i].num_values
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
            opt_helps.append(String("Generate shell completion script"))

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
        # Also count completions subcommand if in subcommand mode.
        if self._completions_enabled and self._completions_is_subcommand:
            has_subcommands = True

        if not has_subcommands:
            return ""

        var cmd_plains = List[String]()
        var cmd_colors = List[String]()
        var cmd_helps = List[String]()
        for i in range(len(self.subcommands)):
            if not self.subcommands[i]._is_help_subcommand:
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
            result: The ParseResult returned by ``parse()`` or ``parse_arguments()``.
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
                if self.args[i].name in result._maps:
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

    # ===------------------------------------------------------------------=== #
    # Shell completion generation
    # ===------------------------------------------------------------------=== #

    fn generate_completion(self, shell: String) raises -> String:
        """Generates a shell completion script for this command tree.

        Supports ``bash``, ``zsh``, and ``fish`` shells.  The returned
        string is a complete script that the user can source or redirect
        to a file:

        ```bash
        myapp --completions bash > ~/.bash_completion.d/myapp
        myapp --completions zsh  > ~/.zsh/completions/_myapp
        myapp --completions fish > ~/.config/fish/completions/myapp.fish
        ```

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
        raise Error("Unknown shell '" + shell + "'. Supported: bash, zsh, fish")

    fn _completion_fish(self) -> String:
        """Generates a Fish shell completion script.

        Each option/subcommand becomes a single ``complete`` line.
        Subcommand-specific completions use ``-n '__fish_seen_subcommand_from <sub>'``
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
                if not self.subcommands[i]._is_help_subcommand:
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
                if self.subcommands[i]._is_help_subcommand:
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
                    if arg.is_hidden or arg.is_positional:
                        continue
                    var line = "complete -c " + self.name
                    line += " -n '" + sub_cond + "'"
                    if arg.short_name:
                        line += " -s " + arg.short_name
                    if arg.long_name:
                        line += " -l " + arg.long_name
                    if not arg.is_flag and not arg.is_count:
                        line += " -r"
                    if len(arg.choice_values) > 0:
                        var choices = String("")
                        for k in range(len(arg.choice_values)):
                            if choices:
                                choices += " "
                            choices += arg.choice_values[k]
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

    fn _fish_options_for(
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
            if arg.is_hidden or arg.is_positional:
                continue
            if persistent_only and not arg.is_persistent:
                continue
            var line = "complete -c " + cmd_name
            if condition:
                line += " -n '" + condition + "'"
            if arg.short_name:
                line += " -s " + arg.short_name
            if arg.long_name:
                line += " -l " + arg.long_name
            if not arg.is_flag and not arg.is_count:
                line += " -r"
            if len(arg.choice_values) > 0:
                var choices = String("")
                for k in range(len(arg.choice_values)):
                    if choices:
                        choices += " "
                    choices += arg.choice_values[k]
                line += " -a '" + choices + "'"
            if arg.help_text:
                line += " -d '" + self._fish_escape(arg.help_text) + "'"
            s += line + "\n"
        return s

    fn _fish_escape(self, text: String) -> String:
        """Escapes single quotes in text for Fish shell strings.

        Args:
            text: The text to escape.

        Returns:
            The escaped text with ``'`` replaced by ``\\'``.
        """
        var result = String("")
        for i in range(len(text)):
            var ch = text[i : i + 1]
            if ch == "'":
                result += "\\'"
            else:
                result += ch
        return result

    fn _completion_zsh(self) -> String:
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
            if not self.subcommands[i]._is_help_subcommand:
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

    fn _zsh_simple(self) -> String:
        """Generates a simple Zsh completion function (no subcommands).

        Returns:
            The function body string.
        """
        var s = String("_" + self.name + "() {\n")
        s += "  _arguments \\\n"
        # User-defined arguments.
        for i in range(len(self.args)):
            var arg = self.args[i].copy()
            if arg.is_hidden:
                continue
            if arg.is_positional:
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

    fn _zsh_with_subcommands(self) -> String:
        """Generates a Zsh completion function with subcommand dispatch.

        Returns:
            The function body string with subcommand handling.
        """
        var s = String("_" + self.name + "() {\n")
        s += "  local -a commands\n"
        s += "  commands=(\n"
        for i in range(len(self.subcommands)):
            if self.subcommands[i]._is_help_subcommand:
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
            if arg.is_hidden or arg.is_positional:
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
            if self.subcommands[i]._is_help_subcommand:
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
                if arg.is_hidden:
                    continue
                if arg.is_positional:
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

    fn _zsh_arg_spec(self, arg: Argument) -> String:
        """Builds a single ``_arguments`` spec string for an argument.

        Args:
            arg: The argument to generate a spec for.

        Returns:
            A ``_arguments``-compatible spec string, e.g.
            ``'--verbose[Enable verbose output]'``.
        """
        var spec = String("")
        var desc = self._zsh_escape(arg.help_text) if arg.help_text else ""

        if arg.short_name and arg.long_name:
            # Grouped short+long form.
            spec += (
                "'(-"
                + arg.short_name
                + " --"
                + arg.long_name
                + ")'"
                + "{-"
                + arg.short_name
                + ",--"
                + arg.long_name
                + "}"
            )
        elif arg.long_name:
            spec += "'--" + arg.long_name
        elif arg.short_name:
            spec += "'-" + arg.short_name

        if arg.short_name and arg.long_name:
            # Description + value spec.
            spec += "'[" + desc + "]"
            if not arg.is_flag and not arg.is_count:
                if len(arg.choice_values) > 0:
                    var choices = String("")
                    for k in range(len(arg.choice_values)):
                        if choices:
                            choices += " "
                        choices += arg.choice_values[k]
                    spec += ":value:(" + choices + ")"
                else:
                    var mv = arg.metavar_name if arg.metavar_name else arg.name
                    spec += ":" + mv + ":"
            spec += "'"
        else:
            if not arg.is_flag and not arg.is_count:
                if len(arg.choice_values) > 0:
                    var choices = String("")
                    for k in range(len(arg.choice_values)):
                        if choices:
                            choices += " "
                        choices += arg.choice_values[k]
                    spec += "[" + desc + "]:value:(" + choices + ")'"
                else:
                    var mv = arg.metavar_name if arg.metavar_name else arg.name
                    spec += "[" + desc + "]:" + mv + ":'"
            else:
                spec += "[" + desc + "]'"

        return spec

    fn _zsh_escape(self, text: String) -> String:
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
            var ch = text[i : i + 1]
            if ch == "[" or ch == "]":
                result += "\\" + ch
            elif ch == "'":
                result += "'\"'\"'"
            elif ch == ":":
                result += "\\:"
            else:
                result += ch
        return result

    fn _completion_bash(self) -> String:
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
            if not self.subcommands[i]._is_help_subcommand:
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

    fn _bash_simple(self) -> String:
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
            if arg.is_hidden or arg.is_positional:
                continue
            if arg.long_name:
                words += " --" + arg.long_name
            if arg.short_name:
                words += " -" + arg.short_name

        # Handle value completion for prev.
        var s = self._bash_prev_cases()
        s += '  COMPREPLY=($(compgen -W "' + words + '" -- "$cur"))\n'
        return s

    fn _bash_with_subcommands(self) -> String:
        """Generates the body of a Bash completion function with subcommands.

        Uses ``COMP_WORDS`` scanning to detect which subcommand is active,
        then scopes completions accordingly.

        Returns:
            The completion logic body string.
        """
        # Collect subcommand names.
        var sub_names = String("")
        for i in range(len(self.subcommands)):
            if self.subcommands[i]._is_help_subcommand:
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
            if arg.is_hidden or arg.is_positional:
                continue
            if arg.long_name:
                root_words += " --" + arg.long_name
            if arg.short_name:
                root_words += " -" + arg.short_name

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
            if self.subcommands[i]._is_help_subcommand:
                continue
            var sub = self.subcommands[i].copy()
            var sub_words = String("--help")
            for j in range(len(sub.args)):
                var arg = sub.args[j].copy()
                if arg.is_hidden or arg.is_positional:
                    continue
                if arg.long_name:
                    sub_words += " --" + arg.long_name
                if arg.short_name:
                    sub_words += " -" + arg.short_name
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

    fn _bash_prev_cases(self) -> String:
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
                    not self.args[i].is_hidden
                    and not self.args[i].is_positional
                    and len(self.args[i].choice_values) > 0
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
                arg.is_hidden
                or arg.is_positional
                or len(arg.choice_values) == 0
            ):
                continue
            var pattern = String("")
            if arg.long_name:
                pattern += "--" + arg.long_name
            if arg.short_name:
                if pattern:
                    pattern += "|"
                pattern += "-" + arg.short_name
            var choices = String("")
            for k in range(len(arg.choice_values)):
                if choices:
                    choices += " "
                choices += arg.choice_values[k]
            s += "    " + pattern + ")\n"
            s += '      COMPREPLY=($(compgen -W "' + choices + '" -- "$cur"))\n'
            s += "      return\n"
            s += "      ;;\n"
        s += "  esac\n"
        return s

    fn _bash_prev_cases_for_args(
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
                not args[i].is_hidden
                and not args[i].is_positional
                and len(args[i].choice_values) > 0
            ):
                has_choices = True
                break
        if not has_choices:
            return ""

        var s = indent + "case $prev in\n"
        for i in range(len(args)):
            var arg = args[i].copy()
            if (
                arg.is_hidden
                or arg.is_positional
                or len(arg.choice_values) == 0
            ):
                continue
            var pattern = String("")
            if arg.long_name:
                pattern += "--" + arg.long_name
            if arg.short_name:
                if pattern:
                    pattern += "|"
                pattern += "-" + arg.short_name
            var choices = String("")
            for k in range(len(arg.choice_values)):
                if choices:
                    choices += " "
                choices += arg.choice_values[k]
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
