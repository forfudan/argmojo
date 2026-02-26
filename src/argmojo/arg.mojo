"""Defines a single command-line argument."""


struct Arg(Copyable, Movable, Stringable, Writable):
    """Defines a command-line argument with its metadata and constraints.

    Use the builder pattern to configure the argument and add it to a Command.

    Examples:

    ```mojo
    from argmojo import Command, Arg

    # Boolean flag  →  result.get_flag("verbose")
    _ = Arg("verbose", help="...").long("verbose").short("v").flag()

    # Key-value option  →  result.get_string("output")
    _ = Arg("output", help="...").long("output").short("o")

    # Key-value with default  →  result.get_string("format")
    _ = Arg("format", help="...").long("format").default("json")

    # Restrict to a set of values
    _ = Arg("level", help="...").long("level").choices(["debug","info","warn"])

    # Positional (matched by order)  →  result.get_string("path")
    _ = Arg("path", help="...").positional().required()
    _ = Arg("dest", help="...").positional().default(".")

    # Count flag  (-vvv → 3)  →  result.get_count("verbose")
    _ = Arg("verbose", help="...").long("verbose").short("v").count()

    # Negatable flag  (--color / --no-color)  →  result.get_flag("color")
    _ = Arg("color", help="...").long("color").flag().negatable()

    # Append / collect  (--tag x --tag y → ["x","y"])  →  result.get_list("tag")
    _ = Arg("tag", help="...").long("tag").short("t").append()

    # Value delimiter  (--env a,b,c → ["a","b","c"])  →  result.get_list("env")
    _ = Arg("env", help="...").long("env").delimiter(",")

    # Multi-value  (--point 1 2 → ["1","2"])  →  result.get_list("point")
    _ = Arg("point", help="...").long("point").nargs(2)

    # Numeric range validation  →  result.get_int("port")
    _ = Arg("port", help="...").long("port").range(1, 65535)

    # Key-value map  (--def k=v --def k2=v2)  →  result.get_map("def")
    _ = Arg("def", help="...").long("define").short("D").map_option()

    # Aliases  (--colour and --color both work)
    _ = Arg("colour", help="...").long("colour").aliases(["color"])

    # Deprecated argument  (still works but prints a warning to stderr)
    _ = Arg("old", help="...").long("old-flag").deprecated("Use --new-flag instead")

    # Display helpers
    _ = Arg("file", help="...").long("file").metavar("PATH")  # help: --file PATH
    _ = Arg("internal", help="...").long("internal").hidden()  # hidden from help
    ```
    """

    var name: String
    """Internal name used to retrieve this argument's value from ParseResult."""
    var help_text: String
    """Help text displayed in usage information."""
    var long_name: String
    """Long option name (e.g., 'output' for --output). Empty if not set."""
    var short_name: String
    """Short option name (e.g., 'o' for -o). Empty if not set."""
    var is_flag: Bool
    """If True, this argument is a boolean flag that takes no value."""
    var is_required: Bool
    """If True, parsing fails when this argument is not provided."""
    var is_positional: Bool
    """If True, this argument is matched by position rather than by name."""
    var default_value: String
    """Default value used when the argument is not provided."""
    var has_default: Bool
    """Whether a default value has been set."""
    var choice_values: List[String]
    """Allowed values for this argument. Empty means any value is accepted."""
    var metavar_name: String
    """Display name for the value in help text (e.g., 'FILE' for --output FILE)."""
    var is_hidden: Bool
    """If True, this argument is not shown in help output."""
    var is_count: Bool
    """If True, each occurrence increments a counter (e.g., -vvv → 3)."""
    var is_negatable: Bool
    """If True, this flag also accepts --no-X to set it to False."""
    var is_append: Bool
    """If True, repeated uses collect values into a list (e.g., --tag x --tag y)."""
    var delimiter_char: String
    """If non-empty, each value is split by this delimiter into multiple list entries."""
    var nargs_count: Int
    """Number of values to consume per occurrence (0 means single-value mode)."""
    var range_min: Int
    """Minimum allowed value (inclusive) for numeric range validation."""
    var range_max: Int
    """Maximum allowed value (inclusive) for numeric range validation."""
    var has_range: Bool
    """Whether numeric range validation is active."""
    var is_map: Bool
    """If True, each value is parsed as key=value and stored in a Dict."""
    var alias_names: List[String]
    """Alternative long names that resolve to this argument."""
    var deprecated_msg: String
    """If non-empty, this argument is deprecated; the string is the warning message."""

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
        self.long_name = ""
        self.short_name = ""
        self.is_flag = False
        self.is_required = False
        self.is_positional = False
        self.default_value = ""
        self.has_default = False
        self.choice_values = List[String]()
        self.metavar_name = ""
        self.is_hidden = False
        self.is_count = False
        self.is_negatable = False
        self.is_append = False
        self.delimiter_char = ""
        self.nargs_count = 0
        self.range_min = 0
        self.range_max = 0
        self.has_range = False
        self.is_map = False
        self.alias_names = List[String]()
        self.deprecated_msg = ""

    fn __copyinit__(out self, copy: Self):
        """Creates a copy of this argument.

        Args:
            copy: The Arg to copy from.
        """
        self.name = copy.name
        self.help_text = copy.help_text
        self.long_name = copy.long_name
        self.short_name = copy.short_name
        self.is_flag = copy.is_flag
        self.is_required = copy.is_required
        self.is_positional = copy.is_positional
        self.default_value = copy.default_value
        self.has_default = copy.has_default
        self.choice_values = List[String]()
        for i in range(len(copy.choice_values)):
            self.choice_values.append(copy.choice_values[i])
        self.metavar_name = copy.metavar_name
        self.is_hidden = copy.is_hidden
        self.is_count = copy.is_count
        self.is_negatable = copy.is_negatable
        self.is_append = copy.is_append
        self.delimiter_char = copy.delimiter_char
        self.nargs_count = copy.nargs_count
        self.range_min = copy.range_min
        self.range_max = copy.range_max
        self.has_range = copy.has_range
        self.is_map = copy.is_map
        self.alias_names = List[String]()
        for i in range(len(copy.alias_names)):
            self.alias_names.append(copy.alias_names[i])
        self.deprecated_msg = copy.deprecated_msg

    fn __moveinit__(out self, deinit move: Self):
        """Moves the value from another Arg.

        Args:
            move: The Arg to move from.
        """
        self.name = move.name^
        self.help_text = move.help_text^
        self.long_name = move.long_name^
        self.short_name = move.short_name^
        self.is_flag = move.is_flag
        self.is_required = move.is_required
        self.is_positional = move.is_positional
        self.default_value = move.default_value^
        self.has_default = move.has_default
        self.choice_values = move.choice_values^
        self.metavar_name = move.metavar_name^
        self.is_hidden = move.is_hidden
        self.is_count = move.is_count
        self.is_negatable = move.is_negatable
        self.is_append = move.is_append
        self.delimiter_char = move.delimiter_char^
        self.nargs_count = move.nargs_count
        self.range_min = move.range_min
        self.range_max = move.range_max
        self.has_range = move.has_range
        self.is_map = move.is_map
        self.alias_names = move.alias_names^
        self.deprecated_msg = move.deprecated_msg^

    # ===------------------------------------------------------------------=== #
    # Builder methods for configuring the argument
    # ===------------------------------------------------------------------=== #

    fn long(var self, name: String) -> Self:
        """Sets the long option name (e.g., 'lingming' for --lingming).

        Args:
            name: The long option name without the '--' prefix.

        Returns:
            Self with the long name set.
        """
        self.long_name = name
        return self^

    fn short(var self, name: String) -> Self:
        """Sets the short option name (e.g., 'l' for -l).

        Args:
            name: A single character for the short option without '-' prefix.

        Returns:
            Self with the short name set.
        """
        self.short_name = name
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
        self.is_flag = True
        return self^

    fn required(var self) -> Self:
        """Marks this argument as required.

        Returns:
            Self marked as required.

        Notes:
            Required arguments must be provided in the input; otherwise, parsing
            will fail.
        """
        self.is_required = True
        return self^

    fn positional(var self) -> Self:
        """Marks this argument as a positional argument.

        Returns:
            Self marked as positional.
        """
        self.is_positional = True
        return self^

    fn takes_value(var self) -> Self:
        """Marks this argument as taking a value (not a flag).

        This is the default behavior; use this for clarity when needed.

        Returns:
            Self with is_flag set to False.
        """
        self.is_flag = False
        return self^

    fn default(var self, value: String) -> Self:
        """Sets a default value for this argument.

        Args:
            value: The default value.

        Returns:
            Self with the default value set.
        """
        self.default_value = value
        self.has_default = True
        return self^

    fn choices(var self, var values: List[String]) -> Self:
        """Restricts the allowed values for this argument.

        Args:
            values: The list of allowed values.

        Returns:
            Self with the choices set.
        """
        self.choice_values = values^
        return self^

    fn metavar(var self, name: String) -> Self:
        """Sets the display name for the value in help text.

        For example, `.metavar("FILE")` causes help to show `--output FILE`
        instead of `--output OUTPUT`.

        Args:
            name: The display name.

        Returns:
            Self with the metavar set.
        """
        self.metavar_name = name
        return self^

    fn hidden(var self) -> Self:
        """Marks this argument as hidden (not shown in help output).

        Returns:
            Self marked as hidden.
        """
        self.is_hidden = True
        return self^

    fn count(var self) -> Self:
        """Marks this argument as a counter flag.

        Each occurrence increments a counter. For example, `-vvv` sets
        the count to 3. Use `get_count()` on ParseResult to retrieve.

        Returns:
            Self marked as a counter.
        """
        self.is_count = True
        self.is_flag = True
        return self^

    fn negatable(var self) -> Self:
        """Marks this flag as negatable.

        A negatable flag accepts both `--X` (sets True) and `--no-X`
        (sets False). For example, `.long("color").flag().negatable()`
        accepts `--color` and `--no-color`.

        Returns:
            Self marked as negatable.
        """
        self.is_negatable = True
        return self^

    fn append(var self) -> Self:
        """Marks this argument as an append/collect option.

        Each occurrence adds its value to a list. For example,
        `--tag x --tag y` collects `["x", "y"]`. Use `get_list()`
        on ParseResult to retrieve the collected values.

        Returns:
            Self marked as append.
        """
        self.is_append = True
        return self^

    # TODO: Allow auto-translating full-width punctuation to ASCII for delimiter.
    # For example
    # "，" → ","
    # "；" → ";"
    # "：" → ":"
    fn delimiter(var self, sep: String) -> Self:
        """Sets a value delimiter for splitting a single value into multiple.

        When set, each provided value is split by the delimiter, and each
        piece is added to the list individually.  Implies `.append()`.
        For example, `.delimiter(",")` causes `--tag a,b,c` to produce
        `["a", "b", "c"]`.

        Args:
            sep: The delimiter string (e.g., ",").

        Returns:
            Self with the delimiter and append mode set.
        """
        self.delimiter_char = sep
        self.is_append = True
        return self^

    fn nargs(var self, n: Int) -> Self:
        """Sets the number of values consumed per occurrence.

        When set, each use of the option consumes exactly ``n``
        consecutive arguments.  For example, ``.nargs(2)`` on
        ``--point`` causes ``--point 1 2`` to collect ``["1", "2"]``.
        Implies ``.append()`` so values are stored in
        ``ParseResult.lists``.

        Args:
            n: Number of values to consume (must be ≥ 2).

        Returns:
            Self with nargs and append mode set.
        """
        self.nargs_count = n
        self.is_append = True
        return self^

    fn range(var self, min_val: Int, max_val: Int) -> Self:
        """Sets numeric range validation for this argument.

        When set, the parsed value must be an integer within
        ``[min_val, max_val]`` (inclusive).  Validation occurs
        after parsing, during the validation phase.

        Args:
            min_val: Minimum allowed value (inclusive).
            max_val: Maximum allowed value (inclusive).

        Returns:
            Self with range validation enabled.
        """
        self.range_min = min_val
        self.range_max = max_val
        self.has_range = True
        return self^

    fn map_option(var self) -> Self:
        """Marks this argument as a key-value map option.

        Each value must be in ``key=value`` format.  Values are
        stored in ``ParseResult.maps`` and retrieved with
        ``get_map()``.  Implies ``.append()`` for repeated uses.

        For example, ``--define DEBUG=1 --define VERSION=2`` produces
        ``{"DEBUG": "1", "VERSION": "2"}``.

        Returns:
            Self marked as a map option.
        """
        self.is_map = True
        self.is_append = True
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
        self.alias_names = names^
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
        self.deprecated_msg = message
        return self^

    # ===------------------------------------------------------------------=== #
    # String representation methods
    # ===------------------------------------------------------------------=== #

    fn __str__(self) -> String:
        """Returns a string representation of this argument definition."""
        var s = String("Arg(name='") + self.name + "'"
        if self.long_name:
            s += ", long='--" + self.long_name + "'"
        if self.short_name:
            s += ", short='-" + self.short_name + "'"
        if self.is_flag:
            s += ", flag"
        if self.is_positional:
            s += ", positional"
        if self.is_required:
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
        writer.write("Arg(name='")
        writer.write(self.name)
        writer.write("'")
        if self.long_name:
            writer.write(", long='--")
            writer.write(self.long_name)
            writer.write("'")
        if self.short_name:
            writer.write(", short='-")
            writer.write(self.short_name)
            writer.write("'")
        if self.is_flag:
            writer.write(", flag")
        if self.is_positional:
            writer.write(", positional")
        if self.is_required:
            writer.write(", required")
        writer.write(")")
