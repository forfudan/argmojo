"""Defines a single command-line argument."""


struct Arg(Copyable, Movable, Stringable, Writable):
    """Defines a command-line argument with its metadata and constraints.

    Use the builder pattern to configure the argument:

    ```mojo
    from argmojo import Arg
    var arg = Arg("output", help="Output file path").long("output").short("o").takes_value()
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

    fn __copyinit__(out self, other: Self):
        """Creates a copy of this argument.

        Args:
            other: The Arg to copy from.
        """
        self.name = other.name
        self.help_text = other.help_text
        self.long_name = other.long_name
        self.short_name = other.short_name
        self.is_flag = other.is_flag
        self.is_required = other.is_required
        self.is_positional = other.is_positional
        self.default_value = other.default_value
        self.has_default = other.has_default
        self.choice_values = List[String]()
        for i in range(len(other.choice_values)):
            self.choice_values.append(other.choice_values[i])
        self.metavar_name = other.metavar_name
        self.is_hidden = other.is_hidden
        self.is_count = other.is_count
        self.is_negatable = other.is_negatable

    fn __moveinit__(out self, deinit other: Self):
        """Moves the value from another Arg.

        Args:
            other: The Arg to move from.
        """
        self.name = other.name^
        self.help_text = other.help_text^
        self.long_name = other.long_name^
        self.short_name = other.short_name^
        self.is_flag = other.is_flag
        self.is_required = other.is_required
        self.is_positional = other.is_positional
        self.default_value = other.default_value^
        self.has_default = other.has_default
        self.choice_values = other.choice_values^
        self.metavar_name = other.metavar_name^
        self.is_hidden = other.is_hidden
        self.is_count = other.is_count
        self.is_negatable = other.is_negatable

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
