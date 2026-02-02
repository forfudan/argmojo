"""Defines a CLI command and performs argument parsing."""

from sys import argv

from .arg import Arg
from .result import ParseResult


struct Command(Stringable, Writable):
    """Defines a CLI command with its arguments and handles parsing.

    Example:

    ```mojo
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

    fn add_arg(mut self, var arg: Arg):
        """Registers an argument definition.

        Args:
            arg: The Arg to register.
        """
        self.args.append(arg^)

    fn parse(self) raises -> ParseResult:
        """Parses command-line arguments from `sys.argv()`.

        Returns:
            A ParseResult containing all parsed values.

        Raises:
            Error on invalid or missing arguments.
        """
        var raw_variadic = argv()
        var raw = List[String]()
        for i in range(len(raw_variadic)):
            raw.append(String(raw_variadic[i]))
        return self.parse_args(raw)

    fn parse_args(self, raw_args: List[String]) raises -> ParseResult:
        """Parses the given argument list.

        The first element is expected to be the program name and is skipped.

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

        var i: Int = 1  # skip argv[0]
        var stop_parsing_options = False

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

            # Handle --help / -h
            if arg == "--help" or arg == "-h":
                print(self._generate_help())
                raise Error("Help requested")

            # Handle --version / -V
            if arg == "--version" or arg == "-V":
                print(self.name + " " + self.version)
                raise Error("Version requested")

            # Long option: --key, --key=value, --key value
            if arg.startswith("--"):
                var key = String(arg[2:])
                var value = String("")
                var has_eq = False

                # Check for --key=value format.
                var eq_pos = key.find("=")
                if eq_pos >= 0:
                    value = String(key[eq_pos + 1 :])
                    key = String(key[:eq_pos])
                    has_eq = True

                var matched = self._find_by_long(key)
                if matched.is_flag and not has_eq:
                    result.flags[matched.name] = True
                else:
                    if not has_eq:
                        i += 1
                        if i >= len(raw_args):
                            raise Error(
                                "Option '--" + key + "' requires a value"
                            )
                        value = raw_args[i]
                    result.values[matched.name] = value
                i += 1
                continue

            # Short option: -k, -k value
            if arg.startswith("-") and len(arg) > 1:
                var key = String(arg[1:])
                var matched = self._find_by_short(key)
                if matched.is_flag:
                    result.flags[matched.name] = True
                else:
                    i += 1
                    if i >= len(raw_args):
                        raise Error("Option '-" + key + "' requires a value")
                    result.values[matched.name] = raw_args[i]
                i += 1
                continue

            # Positional argument.
            result.positionals.append(arg)
            i += 1

        # Apply defaults for arguments not provided.
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

        # Validate required arguments.
        for j in range(len(self.args)):
            var a = self.args[j].copy()
            if a.is_required and not result.has(a.name):
                raise Error(
                    "Required argument '" + a.name + "' was not provided"
                )

        return result^

    fn _find_by_long(self, name: String) raises -> Arg:
        """Finds an argument definition by its long name.

        Args:
            name: The long option name (without '--').

        Returns:
            The matching Arg.

        Raises:
            Error if no argument matches.
        """
        for i in range(len(self.args)):
            if self.args[i].long_name == name:
                return self.args[i].copy()
        raise Error("Unknown option '--" + name + "'")

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
        raise Error("Unknown option '-" + name + "'")

    fn _generate_help(self) -> String:
        """Generates a help message from registered arguments.

        Returns:
            A formatted help string.
        """
        var s = String("")
        if self.description:
            s += self.description + "\n\n"
        s += "Usage: " + self.name

        # Show positional args in usage line.
        for i in range(len(self.args)):
            if self.args[i].is_positional:
                if self.args[i].is_required:
                    s += " <" + self.args[i].name + ">"
                else:
                    s += " [" + self.args[i].name + "]"

        s += " [OPTIONS]\n\n"

        # Positional arguments section.
        var has_positional = False
        for i in range(len(self.args)):
            if self.args[i].is_positional:
                has_positional = True
                break

        if has_positional:
            s += "Arguments:\n"
            for i in range(len(self.args)):
                if self.args[i].is_positional:
                    s += "  " + self.args[i].name
                    if self.args[i].help_text:
                        s += "    " + self.args[i].help_text
                    s += "\n"
            s += "\n"

        # Options section.
        s += "Options:\n"
        for i in range(len(self.args)):
            if not self.args[i].is_positional:
                var line = String("  ")
                if self.args[i].short_name:
                    line += "-" + self.args[i].short_name
                    if self.args[i].long_name:
                        line += ", "
                else:
                    line += "    "
                if self.args[i].long_name:
                    line += "--" + self.args[i].long_name
                if self.args[i].help_text:
                    # Simple padding.
                    while len(line) < 24:
                        line += " "
                    line += self.args[i].help_text
                s += line + "\n"

        s += "  -h, --help              Show this help message\n"
        s += "  -V, --version           Show version\n"

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
        writer.write(self.__str__())
