"""Defines a CLI command and performs argument parsing."""

from sys import argv, exit

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
    var _exclusive_groups: List[List[String]]
    """Groups of mutually exclusive argument names."""
    var _required_groups: List[List[String]]
    """Groups of arguments that must be provided together."""

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
        self._exclusive_groups = List[List[String]]()
        self._required_groups = List[List[String]]()

    fn add_arg(mut self, var arg: Arg):
        """Registers an argument definition.

        Args:
            arg: The Arg to register.
        """
        self.args.append(arg^)

    fn mutually_exclusive(mut self, var names: List[String]):
        """Declares a group of mutually exclusive arguments.

        At most one argument from each group may be provided. Parsing
        will fail if more than one is present.

        Args:
            names: The internal names of the arguments in the group.
        """
        self._exclusive_groups.append(names^)

    fn required_together(mut self, var names: List[String]):
        """Declares a group of arguments that must be provided together.

        If any argument from the group is provided, all others in the
        group must also be provided. Parsing will fail otherwise.

        Args:
            names: The internal names of the arguments in the group.
        """
        self._required_groups.append(names^)

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
                exit(0)

            # Handle --version / -V
            if arg == "--version" or arg == "-V":
                print(self.name + " " + self.version)
                exit(0)

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
                if matched.is_count and not has_eq:
                    # Count flag: increment counter.
                    var cur: Int = 0
                    try:
                        cur = result.counts[matched.name]
                    except:
                        pass
                    result.counts[matched.name] = cur + 1
                elif matched.is_flag and not has_eq:
                    result.flags[matched.name] = True
                else:
                    if not has_eq:
                        i += 1
                        if i >= len(raw_args):
                            raise Error(
                                "Option '--" + key + "' requires a value"
                            )
                        value = raw_args[i]
                    self._validate_choices(matched, value)
                    result.values[matched.name] = value
                i += 1
                continue

            # Short option: -k, -k value, -abc (merged flags), -ofile.txt
            if arg.startswith("-") and len(arg) > 1:
                var key = String(arg[1:])

                # Single-char short option: -f or -k value
                if len(key) == 1:
                    var matched = self._find_by_short(key)
                    if matched.is_count:
                        var cur: Int = 0
                        try:
                            cur = result.counts[matched.name]
                        except:
                            pass
                        result.counts[matched.name] = cur + 1
                    elif matched.is_flag:
                        result.flags[matched.name] = True
                    else:
                        i += 1
                        if i >= len(raw_args):
                            raise Error(
                                "Option '-" + key + "' requires a value"
                            )
                        var val = raw_args[i]
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
                        else:
                            # This char takes a value — rest of string is
                            # the value.
                            var val = String(key[j + 1 :])
                            if len(val) == 0:
                                i += 1
                                if i >= len(raw_args):
                                    raise Error(
                                        "Option '-" + ch + "' requires a value"
                                    )
                                val = raw_args[i]
                            self._validate_choices(m, val)
                            result.values[m.name] = val
                            j = len(key)  # break
                    i += 1
                    continue
                else:
                    # First char takes a value — rest of string is the
                    # attached value (e.g., -ofile.txt).
                    var val = String(key[1:])
                    self._validate_choices(first_match, val)
                    result.values[first_match.name] = val
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

        # Validate positional argument count — too many args is an error.
        var expected_count: Int = len(result._positional_names)
        if expected_count > 0 and len(result.positionals) > expected_count:
            raise Error(
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
                    # Find display name (--long or -short).
                    var display = String("'") + found[f] + String("'")
                    for a in range(len(self.args)):
                        if self.args[a].name == found[f]:
                            if self.args[a].long_name:
                                display = "'--" + self.args[a].long_name + "'"
                            elif self.args[a].short_name:
                                display = "'-" + self.args[a].short_name + "'"
                            break
                    names_str += display
                raise Error(
                    "Arguments are mutually exclusive: " + names_str
                )

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
                # Build display names for the missing args.
                var missing_str = String("")
                for m in range(len(missing)):
                    if m > 0:
                        missing_str += ", "
                    var display = String("'") + missing[m] + String("'")
                    for a in range(len(self.args)):
                        if self.args[a].name == missing[m]:
                            if self.args[a].long_name:
                                display = "'--" + self.args[a].long_name + "'"
                            elif self.args[a].short_name:
                                display = "'-" + self.args[a].short_name + "'"
                            break
                    missing_str += display
                # Build display names for the provided args.
                var provided_str = String("")
                for p in range(len(provided)):
                    if p > 0:
                        provided_str += ", "
                    var display = String("'") + provided[p] + String("'")
                    for a in range(len(self.args)):
                        if self.args[a].name == provided[p]:
                            if self.args[a].long_name:
                                display = "'--" + self.args[a].long_name + "'"
                            elif self.args[a].short_name:
                                display = "'-" + self.args[a].short_name + "'"
                            break
                    provided_str += display
                raise Error(
                    "Arguments required together: "
                    + missing_str
                    + " required when "
                    + provided_str
                    + " is provided"
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
        raise Error(
            "Invalid value '"
            + value
            + "' for argument '"
            + arg.name
            + "' (choose from "
            + allowed
            + ")"
        )

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
            if self.args[i].is_positional and not self.args[i].is_hidden:
                if self.args[i].is_required:
                    s += " <" + self.args[i].name + ">"
                else:
                    s += " [" + self.args[i].name + "]"

        s += " [OPTIONS]\n\n"

        # Positional arguments section.
        var has_positional = False
        for i in range(len(self.args)):
            if self.args[i].is_positional and not self.args[i].is_hidden:
                has_positional = True
                break

        if has_positional:
            s += "Arguments:\n"
            for i in range(len(self.args)):
                if self.args[i].is_positional and not self.args[i].is_hidden:
                    s += "  " + self.args[i].name
                    if self.args[i].help_text:
                        s += "    " + self.args[i].help_text
                    s += "\n"
            s += "\n"

        # Options section.
        s += "Options:\n"
        for i in range(len(self.args)):
            if not self.args[i].is_positional and not self.args[i].is_hidden:
                var line = String("  ")
                if self.args[i].short_name:
                    line += "-" + self.args[i].short_name
                    if self.args[i].long_name:
                        line += ", "
                else:
                    line += "    "
                if self.args[i].long_name:
                    line += "--" + self.args[i].long_name

                # Show metavar or choices for value-taking options.
                if not self.args[i].is_flag:
                    if self.args[i].metavar_name:
                        line += " " + self.args[i].metavar_name
                    elif len(self.args[i].choice_values) > 0:
                        var choices_str = String("{")
                        for j in range(len(self.args[i].choice_values)):
                            if j > 0:
                                choices_str += ","
                            choices_str += self.args[i].choice_values[j]
                        choices_str += "}"
                        line += " " + choices_str
                    else:
                        # Default: uppercase name.
                        line += " <" + self.args[i].name + ">"

                if self.args[i].help_text:
                    # Simple padding.
                    while len(line) < 30:
                        line += " "
                    line += self.args[i].help_text
                s += line + "\n"

        s += "  -h, --help                  Show this help message\n"
        s += "  -V, --version               Show version\n"

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
