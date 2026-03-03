"""Defines a single command-line argument."""

from sys import exit, stderr


comptime Arg = Argument
"""Shorthand alias for ``Argument``."""


struct Argument(Copyable, Movable, Stringable, Writable):
    """A command-line argument with its metadata and constraints.

    Use the builder pattern to configure the argument and add it to a Command.

    Examples:

    ```mojo
    from argmojo import Command, Argument
    # Boolean flag  →  result.get_flag("verbose")
    _ = Argument("verbose", help="...").long("verbose").short("v").flag()
    # Key-value option  →  result.get_string("output")
    _ = Argument("output", help="...").long("output").short("o")
    # Key-value with default  →  result.get_string("format")
    _ = Argument("format", help="...").long("format").default("json")
    # Restrict to a set of values
    _ = Argument("level", help="...").long("level").choices(["debug","info","warn"])
    # Positional (matched by order)  →  result.get_string("path")
    _ = Argument("path", help="...").positional().required()
    _ = Argument("dest", help="...").positional().default(".")
    # Count flag  (-vvv → 3)  →  result.get_count("verbose")
    _ = Argument("verbose", help="...").long("verbose").short("v").count()
    # Count flag with ceiling  (-vvvvv capped at 3)
    _ = Argument("verbose", help="...").long("verbose").short("v").count().max[3]()
    # Negatable flag  (--color / --no-color)  →  result.get_flag("color")
    _ = Argument("color", help="...").long("color").flag().negatable()
    # Append / collect  (--tag x --tag y → ["x","y"])  →  result.get_list("tag")
    _ = Argument("tag", help="...").long("tag").short("t").append()
    # Value delimiter  (--env a,b,c → ["a","b","c"])  →  result.get_list("env")
    _ = Argument("env", help="...").long("env").delimiter(",")
    # Multi-value  (--point 1 2 → ["1","2"])  →  result.get_list("point")
    _ = Argument("point", help="...").long("point").number_of_values(2)
    # Numeric range validation  →  result.get_int("port")
    _ = Argument("port", help="...").long("port").range(1, 65535)
    # Numeric range with clamping  (--level 200 → 100 with warning)
    _ = Argument("level", help="...").long("level").range(0, 100).clamp()
    # Key-value map  (--def k=v --def k2=v2)  →  result.get_map("def")
    _ = Argument("def", help="...").long("define").short("D").map_option()
    # Aliases  (--colour and --color both work)
    _ = Argument("colour", help="...").long("colour").aliases(["color"])
    # Deprecated argument  (still works but prints a warning to stderr)
    _ = Argument("old", help="...").long("old-flag").deprecated("Use --new-flag instead")
    # Display helpers
    _ = Argument("file", help="...").long("file").metavar("PATH")  # help: --file PATH
    _ = Argument("internal", help="...").long("internal").hidden()  # hidden from help
    ```
    """

    # === Public fields ===
    var name: String
    """Internal name used to retrieve this argument's value from ParseResult."""
    var help_text: String
    """Help text displayed in usage information."""

    # === Private fields ===
    var _long_name: String
    """Long option name (e.g., 'output' for --output). Empty if not set."""
    var _short_name: String
    """Short option name (e.g., 'o' for -o). Empty if not set."""
    var _is_flag: Bool
    """If True, this argument is a boolean flag that takes no value."""
    var _is_required: Bool
    """If True, parsing fails when this argument is not provided."""
    var _is_positional: Bool
    """If True, this argument is matched by position rather than by name."""
    var _default_value: String
    """Default value used when the argument is not provided."""
    var _has_default: Bool
    """Whether a default value has been set."""
    var _choice_values: List[String]
    """Allowed values for this argument. Empty means any value is accepted."""
    var _metavar: String
    """Display name for the value in help text (e.g., 'FILE' for --output FILE)."""
    var _is_hidden: Bool
    """If True, this argument is not shown in help output."""
    var _is_count: Bool
    """If True, each occurrence increments a counter (e.g., -vvv → 3)."""
    var _is_negatable: Bool
    """If True, this flag also accepts --no-X to set it to False."""
    var _is_append: Bool
    """If True, repeated uses collect values into a list (e.g., --tag x --tag y)."""
    var _delimiter_char: String
    """If non-empty, each value is split by this delimiter into multiple list entries."""
    var _number_of_values: Int
    """Number of values to consume per occurrence (0 means single-value mode)."""
    var _range_min: Int
    """Minimum allowed value (inclusive) for numeric range validation."""
    var _range_max: Int
    """Maximum allowed value (inclusive) for numeric range validation."""
    var _has_range: Bool
    """Whether numeric range validation is active."""
    var _is_clamp: Bool
    """If True, out-of-range values are clamped (adjusted with warning) instead of rejected."""
    var _is_map: Bool
    """If True, each value is parsed as key=value and stored in a Dict."""
    var _alias_names: List[String]
    """Alternative long names that resolve to this argument."""
    var _deprecated_msg: String
    """If non-empty, this argument is deprecated; the string is the warning message."""
    var _count_max: Int
    """Maximum count value (ceiling) for counter flags. 0 means no limit."""
    var _has_count_max: Bool
    """Whether a count ceiling has been set via ``.max()``."""
    var _is_persistent: Bool
    """If True, this argument is automatically inherited by every subcommand.
    Persistent flags/options are injected into child command parsers at
    dispatch time so the user may place them either before or after the
    subcommand token on the command line."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(out self, name: String, *, help: String = ""):
        """Creates a new argument definition.

        Args:
            name: Internal name for this argument.
            help: Help text for display.
        """
        self.name = name
        self.help_text = help
        self._long_name = ""
        self._short_name = ""
        self._is_flag = False
        self._is_required = False
        self._is_positional = False
        self._default_value = ""
        self._has_default = False
        self._choice_values = List[String]()
        self._metavar = ""
        self._is_hidden = False
        self._is_count = False
        self._is_negatable = False
        self._is_append = False
        self._delimiter_char = ""
        self._number_of_values = 0
        self._range_min = 0
        self._range_max = 0
        self._has_range = False
        self._is_clamp = False
        self._is_map = False
        self._alias_names = List[String]()
        self._deprecated_msg = ""
        self._count_max = 0
        self._has_count_max = False
        self._is_persistent = False

    fn __copyinit__(out self, copy: Self):
        """Creates a copy of this argument.

        Args:
            copy: The Argument to copy from.
        """
        self.name = copy.name
        self.help_text = copy.help_text
        self._long_name = copy._long_name
        self._short_name = copy._short_name
        self._is_flag = copy._is_flag
        self._is_required = copy._is_required
        self._is_positional = copy._is_positional
        self._default_value = copy._default_value
        self._has_default = copy._has_default
        self._choice_values = List[String]()
        for i in range(len(copy._choice_values)):
            self._choice_values.append(copy._choice_values[i])
        self._metavar = copy._metavar
        self._is_hidden = copy._is_hidden
        self._is_count = copy._is_count
        self._is_negatable = copy._is_negatable
        self._is_append = copy._is_append
        self._delimiter_char = copy._delimiter_char
        self._number_of_values = copy._number_of_values
        self._range_min = copy._range_min
        self._range_max = copy._range_max
        self._has_range = copy._has_range
        self._is_clamp = copy._is_clamp
        self._is_map = copy._is_map
        self._alias_names = List[String]()
        for i in range(len(copy._alias_names)):
            self._alias_names.append(copy._alias_names[i])
        self._deprecated_msg = copy._deprecated_msg
        self._count_max = copy._count_max
        self._has_count_max = copy._has_count_max
        self._is_persistent = copy._is_persistent

    fn __moveinit__(out self, deinit move: Self):
        """Moves the value from another Argument.

        Args:
            move: The Argument to move from.
        """
        self.name = move.name^
        self.help_text = move.help_text^
        self._long_name = move._long_name^
        self._short_name = move._short_name^
        self._is_flag = move._is_flag
        self._is_required = move._is_required
        self._is_positional = move._is_positional
        self._default_value = move._default_value^
        self._has_default = move._has_default
        self._choice_values = move._choice_values^
        self._metavar = move._metavar^
        self._is_hidden = move._is_hidden
        self._is_count = move._is_count
        self._is_negatable = move._is_negatable
        self._is_append = move._is_append
        self._delimiter_char = move._delimiter_char^
        self._number_of_values = move._number_of_values
        self._range_min = move._range_min
        self._range_max = move._range_max
        self._has_range = move._has_range
        self._is_clamp = move._is_clamp
        self._is_map = move._is_map
        self._alias_names = move._alias_names^
        self._deprecated_msg = move._deprecated_msg^
        self._count_max = move._count_max
        self._has_count_max = move._has_count_max
        self._is_persistent = move._is_persistent

    # ===------------------------------------------------------------------=== #
    # Builder methods for configuring the argument
    # ===------------------------------------------------------------------=== #

    fn long(var self, name: String) -> Self:
        """Sets the long option name (e.g., 'verbose' for --verbose).

        Args:
            name: The long option name without the '--' prefix.

        Returns:
            Self with the long name set.
        """
        self._long_name = name
        return self^

    fn short(var self, name: String) -> Self:
        """Sets the short option name (e.g., 'l' for -l).

        Args:
            name: A single character for the short option without '-' prefix.

        Returns:
            Self with the short name set.
        """
        self._short_name = name
        return self^

    fn flag(var self) -> Self:
        """Marks this argument as a boolean flag (no value needed).

        Returns:
            Self marked as a flag.

        Notes:
            Flags are False by default and become True when present in the input.
            For example --verbose would set a 'verbose' flag to True, while its
            absence leaves it False.
        """
        self._is_flag = True
        return self^

    fn required(var self) -> Self:
        """Marks this argument as required.

        Returns:
            Self marked as required.

        Notes:
            Required arguments must be provided in the input; otherwise, parsing
            will fail.
        """
        self._is_required = True
        return self^

    fn positional(var self) -> Self:
        """Marks this argument as a positional argument.

        Returns:
            Self marked as positional.
        """
        self._is_positional = True
        return self^

    fn takes_value(var self) -> Self:
        """Marks this argument as taking a value (not a flag).

        This is the default behavior; use this for clarity when needed.

        Returns:
            Self with _is_flag set to False.
        """
        self._is_flag = False
        return self^

    fn default(var self, value: String) -> Self:
        """Sets a default value for this argument.

        Args:
            value: The default value.

        Returns:
            Self with the default value set.
        """
        self._default_value = value
        self._has_default = True
        return self^

    fn choices(var self, var values: List[String]) -> Self:
        """Restricts the allowed values for this argument.

        Args:
            values: The list of allowed values.

        Returns:
            Self with the choices set.
        """
        self._choice_values = values^
        return self^

    fn metavar(var self, name: String) -> Self:
        """Sets the display name for the value in help text.

        For example, ``.metavar("FILE")`` causes help to show ``--output FILE``
        instead of ``--output OUTPUT``.

        Args:
            name: The display name.

        Returns:
            Self with the metavar set.
        """
        self._metavar = name
        return self^

    fn hidden(var self) -> Self:
        """Marks this argument as hidden (not shown in help output).

        Returns:
            Self marked as hidden.
        """
        self._is_hidden = True
        return self^

    fn count(var self) -> Self:
        """Marks this argument as a counter flag.

        Each occurrence increments a counter. For example, ``-vvv`` sets
        the count to 3. Use ``get_count()`` on ParseResult to retrieve.

        Chain with ``.max[n]()`` to cap the counter at a ceiling value.

        Returns:
            Self marked as a counter.
        """
        self._is_count = True
        self._is_flag = True
        return self^

    # [Mojo Miji]
    # We set `ceiling` as a parameter, instead of an argument, because we
    # want to check at compile time that it is a positive integer.
    # If we made it an argument, we could not check it at compile time,
    # and the check would be deferred to runtime, which means that the users,
    # rather than developers, may encounter errors about a wrong ceiling value
    # in the terminal when they use the API, no matter they are using it
    # correctly or not. That would be catastrophic.
    fn max[ceiling: Int](var self) -> Self:
        """Sets a ceiling for a counter flag.

        When a counter flag has a ceiling, the count is capped at the
        given value regardless of how many times the flag appears.
        For example, ``.count().max[3]()`` caps ``-vvvvv`` at 3.

        Must be used after ``.count()``.

        Parameters:
            ceiling: The maximum count value (must be ≥ 1).

        Returns:
            Self with the count ceiling set.
        """
        constrained[ceiling >= 1, "max(): ceiling must be >= 1"]()
        if not self._is_count:
            print(
                (
                    "Argument.max(): can only be used after .count(); call"
                    " .count() before .max()."
                ),
                file=stderr,
            )
            exit(1)
        self._count_max = ceiling
        self._has_count_max = True
        return self^

    fn negatable(var self) -> Self:
        """Marks this flag as negatable.

        A negatable flag accepts both ``--X`` (sets True) and ``--no-X``
        (sets False). For example, ``.long("color").flag().negatable()``
        accepts ``--color`` and ``--no-color``.

        Returns:
            Self marked as negatable.
        """
        self._is_negatable = True
        return self^

    fn append(var self) -> Self:
        """Marks this argument as an append/collect option.

        Each occurrence adds its value to a list. For example,
        ``--tag x --tag y`` collects ``["x", "y"]``. Use ``get_list()``
        on ParseResult to retrieve the collected values.

        Returns:
            Self marked as append.
        """
        self._is_append = True
        return self^

    # TODO: Allow auto-translating full-width punctuation to ASCII for delimiter.
    # For example
    # "，" → ","
    # "；" → ";"
    # "：" → ":"
    fn delimiter(var self, sep: String) -> Self:
        """Sets a value delimiter for splitting a single value into multiple.

        When set, each provided value is split by the delimiter, and each
        piece is added to the list individually.  Implies ``.append()``.
        For example, ``.delimiter(",")`` causes ``--tag a,b,c`` to produce
        ``["a", "b", "c"]``.

        Args:
            sep: The delimiter string (e.g., ",").

        Returns:
            Self with the delimiter and append mode set.
        """
        self._delimiter_char = sep
        self._is_append = True
        return self^

    fn number_of_values(var self, n: Int) -> Self:
        """Sets the number of values consumed per occurrence.

        When set, each use of the option consumes exactly ``n``
        consecutive arguments.  For example, ``.number_of_values(2)`` on
        ``--point`` causes ``--point 1 2`` to collect ``["1", "2"]``.
        Implies ``.append()`` so values are retrieved with
        ``ParseResult.get_list()``.

        Args:
            n: Number of values to consume (must be ≥ 2).

        Returns:
            Self with _number_of_values and append mode set.
        """
        self._number_of_values = n
        self._is_append = True
        return self^

    fn range(var self, min_val: Int, max_val: Int) -> Self:
        """Sets numeric range validation for this argument.

        When set, the parsed value must be an integer within
        ``[min_val, max_val]`` (inclusive).  Validation occurs
        after parsing, during the validation phase.

        By default, out-of-range values cause an error.  Chain with
        ``.clamp()`` to silently adjust the value (with a warning)
        instead of erroring.

        Args:
            min_val: Minimum allowed value (inclusive).
            max_val: Maximum allowed value (inclusive).

        Returns:
            Self with range validation enabled.
        """
        self._range_min = min_val
        self._range_max = max_val
        self._has_range = True
        return self^

    fn clamp(var self) -> Self:
        """Enables clamping for numeric range validation.

        When clamping is enabled (used after ``.range(min, max)``),
        out-of-range values are adjusted to the nearest boundary
        instead of causing an error.  A warning is printed to stderr
        to inform the user of the adjustment.

        For example, ``.range(1, 100).clamp()`` causes ``--level 200``
        to be silently adjusted to 100 with a warning.

        Must be used after ``.range()``.

        Returns:
            Self with clamping enabled.
        """
        self._is_clamp = True
        return self^

    fn map_option(var self) -> Self:
        """Marks this argument as a key-value map option.

        Each value must be in ``key=value`` format.  Values are
        retrieved with ``get_map()``.  Implies ``.append()`` for
        repeated uses.

        For example, ``--define DEBUG=1 --define VERSION=2`` produces
        ``{"DEBUG": "1", "VERSION": "2"}``.

        Returns:
            Self marked as a map option.
        """
        self._is_map = True
        self._is_append = True
        return self^

    fn aliases(var self, var names: List[String]) -> Self:
        """Sets alternative long names for this argument.

        Any alias resolves to this argument during parsing.  For
        example, ``.long("colour").aliases(["color"])`` makes both
        ``--colour`` and ``--color`` accepted.

        Args:
            names: The alternative long option names (without ``--``).

        Returns:
            Self with aliases registered.
        """
        self._alias_names = names^
        return self^

    fn deprecated(var self, message: String) -> Self:
        """Marks this argument as deprecated.

        When the user provides a deprecated argument, a warning is
        printed to stderr but parsing continues normally.

        Args:
            message: The deprecation message (e.g., "Use --format instead").

        Returns:
            Self marked as deprecated.
        """
        self._deprecated_msg = message
        return self^

    fn persistent(var self) -> Self:
        """Marks this argument as persistent (inherited by all subcommands).

        A persistent argument defined on a parent command is automatically
        injected into every child command parser at dispatch time.  The
        user may therefore place the option either before or after the
        subcommand token::

            app --verbose search pattern   # --verbose parsed by root
            app search --verbose pattern   # --verbose parsed by child
                                           # (injected) and bubbled up

        In both cases ``root_result.get_flag("verbose")`` returns ``True``.
        The child result also carries the value when the flag appears
        after the subcommand token.

        Persistent arguments may not use the same long or short option
        strings (as configured via ``.long()`` and ``.short()``) as any
        argument that is local to a registered subcommand.  ArgMojo raises
        an error at ``add_subcommand()`` time if a conflict is detected.

        Returns:
            Self marked as persistent.
        """
        self._is_persistent = True
        return self^

    # ===------------------------------------------------------------------=== #
    # String representation methods
    # ===------------------------------------------------------------------=== #

    fn __str__(self) -> String:
        """Returns a string representation of this argument definition."""
        var s = String("Argument(name='") + self.name + "'"
        if self._long_name:
            s += ", long='--" + self._long_name + "'"
        if self._short_name:
            s += ", short='-" + self._short_name + "'"
        if self._is_flag:
            s += ", flag"
        if self._is_positional:
            s += ", positional"
        if self._is_required:
            s += ", required"
        s += ")"
        return s

    fn write_to[W: Writer](self, mut writer: W):
        """Writes the string representation to a writer.

        Parameters:
            W: The writer type.

        Args:
            writer: The writer to write to.
        """
        writer.write("Argument(name='")
        writer.write(self.name)
        writer.write("'")
        if self._long_name:
            writer.write(", long='--")
            writer.write(self._long_name)
            writer.write("'")
        if self._short_name:
            writer.write(", short='-")
            writer.write(self._short_name)
            writer.write("'")
        if self._is_flag:
            writer.write(", flag")
        if self._is_positional:
            writer.write(", positional")
        if self._is_required:
            writer.write(", required")
        writer.write(")")
