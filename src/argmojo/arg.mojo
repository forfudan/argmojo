"""Defines a single command-line argument."""


@fieldwise_init
struct Arg(Copyable, Movable, Stringable, Writable):
    """Defines a command-line argument with its metadata and constraints.

    Use the builder pattern to configure the argument:

    ```mojo
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
