"""Stores parsed argument values."""


struct ParseResult(Copyable, Movable, Writable):
    """Stores the results of parsing command-line arguments.

    Provides typed accessors to retrieve argument values by name.
    """

    # === Public fields ===
    var subcommand: String
    """Name of the selected subcommand. Empty string if no subcommand was given."""

    # === Private fields ===
    var _flags: Dict[String, Bool]
    """Boolean flag values, keyed by argument name."""
    var _values: Dict[String, String]
    """String argument values, keyed by argument name."""
    var _positionals: List[String]
    """Positional argument values, in order."""
    var _counts: Dict[String, Int]
    """Counter values for count-type arguments (e.g., -vvv → 3)."""
    var _lists: Dict[String, List[String]]
    """Collected list values for append-type arguments (e.g., --tag x --tag y)."""
    var _maps: Dict[String, Dict[String, String]]
    """Key-value map values for map-type arguments (e.g., --define key=val)."""
    var _positional_names: List[String]
    """Names of positional arguments, in declaration order."""
    var _subcommand_results: List[ParseResult]
    """Child ParseResult from subcommand parsing. Contains 0 or 1 elements.
    Use ``has_subcommand_result()`` to check presence and
    ``get_subcommand_result()`` to retrieve the value.
    """
    var _unknown_args: List[String]
    """Unrecognised arguments collected by ``parse_known_arguments()``.
    Empty when using the standard ``parse_arguments()`` method."""

    def __init__(out self):
        """Creates an empty ParseResult."""
        self._flags = Dict[String, Bool]()
        self._values = Dict[String, String]()
        self._positionals = List[String]()
        self._counts = Dict[String, Int]()
        self._lists = Dict[String, List[String]]()
        self._maps = Dict[String, Dict[String, String]]()
        self._positional_names = List[String]()
        self.subcommand = ""
        self._subcommand_results = List[ParseResult]()
        self._unknown_args = List[String]()

    def __init__(out self, *, copy: Self):
        """Creates a deep copy of a ParseResult.

        Args:
            copy: The ParseResult to copy from.
        """
        self._flags = copy._flags.copy()
        self._values = copy._values.copy()
        self._positionals = copy._positionals.copy()
        self._counts = copy._counts.copy()
        self._lists = Dict[String, List[String]]()
        for entry in copy._lists.items():
            self._lists[entry.key] = entry.value.copy()
        self._maps = Dict[String, Dict[String, String]]()
        for entry in copy._maps.items():
            self._maps[entry.key] = entry.value.copy()
        self._positional_names = copy._positional_names.copy()
        self.subcommand = copy.subcommand
        self._subcommand_results = copy._subcommand_results.copy()
        self._unknown_args = copy._unknown_args.copy()

    def __init__(out self, *, deinit take: Self):
        """Moves a ParseResult, transferring all field ownership.

        Args:
            take: The ParseResult to move from.
        """
        self._flags = take._flags^
        self._values = take._values^
        self._positionals = take._positionals^
        self._counts = take._counts^
        self._lists = take._lists^
        self._maps = take._maps^
        self._positional_names = take._positional_names^
        self.subcommand = take.subcommand^
        self._subcommand_results = take._subcommand_results^
        self._unknown_args = take._unknown_args^

    def get_flag(self, name: String) -> Bool:
        """Gets a boolean flag value. Returns False if not set.

        Args:
            name: The argument name.

        Returns:
            True if the flag was set, False otherwise.
        """
        try:
            return self._flags[name]
        except:
            return False

    def get_string(self, name: String) raises -> String:
        """Gets a string argument value.

        Args:
            name: The argument name.

        Returns:
            The string value of the argument.

        Raises:
            Error if the argument was not provided.
        """
        # Check named values first.
        try:
            return self._values[name]
        except:
            pass

        # Check positional arguments by name.
        for i in range(len(self._positional_names)):
            if self._positional_names[i] == name:
                if i < len(self._positionals):
                    return self._positionals[i]

        raise Error("Argument '" + name + "' not found")

    def get_int(self, name: String) raises -> Int:
        """Gets an integer argument value.

        Args:
            name: The argument name.

        Returns:
            The integer value of the argument.

        Raises:
            Error if the argument was not provided or is not a valid integer.
        """
        var s = self.get_string(name)
        return Int(atol(s))

    def get_count(self, name: String) -> Int:
        """Gets the count for a counter-type argument. Returns 0 if not set.

        Args:
            name: The argument name.

        Returns:
            The number of times the flag was provided.
        """
        try:
            return self._counts[name]
        except:
            return 0

    def get_list(self, name: String) -> List[String]:
        """Gets the collected list for an append-type argument.

        Returns an empty list if the argument was never provided.

        Args:
            name: The argument name.

        Returns:
            The list of collected values.

        Note:
            For map-type arguments (``.map_option()``), each entry is the
            raw ``key=value`` string (e.g. ``["DEBUG=1", "VERSION=2"]``).
            Use ``get_map()`` instead to retrieve the parsed dict.
        """
        try:
            var result = List[String]()
            var lst = self._lists[name].copy()
            for i in range(len(lst)):
                result.append(String(lst[i]))
            return result^
        except:
            return List[String]()

    def get_map(self, name: String) -> Dict[String, String]:
        """Gets the key-value map for a map-type argument.

        Returns an empty Dict if the argument was never provided.

        Args:
            name: The argument name.

        Returns:
            The Dict of key-value pairs.
        """
        try:
            # Return a copy of the stored map.
            var result = Dict[String, String]()
            var m = self._maps[name].copy()
            for entry in m.items():
                result[entry.key] = entry.value
            return result^
        except:
            return Dict[String, String]()

    def has(self, name: String) -> Bool:
        """Checks whether an argument was provided.

        Args:
            name: The argument name.

        Returns:
            True if the argument was provided.
        """
        if name in self._flags:
            return True
        if name in self._values:
            return True
        if name in self._counts:
            return True
        if name in self._lists:
            return True
        if name in self._maps:
            return True
        for i in range(len(self._positional_names)):
            if self._positional_names[i] == name:
                return i < len(self._positionals)
        return False

    def has_subcommand_result(self) -> Bool:
        """Checks whether a subcommand result is present.

        Returns:
            True if a child ``ParseResult`` was stored from subcommand
            parsing, False otherwise.
        """
        return len(self._subcommand_results) > 0

    def get_subcommand_result(self) raises -> ParseResult:
        """Returns the child ParseResult produced by subcommand parsing.

        Returns:
            A copy of the child ParseResult.

        Raises:
            Error if no subcommand result is present. Check
            ``has_subcommand_result()`` before calling this method.
        """
        if len(self._subcommand_results) == 0:
            raise Error(
                "No subcommand result available. Did you forget to check"
                " has_subcommand_result()?"
            )
        var r: ParseResult = self._subcommand_results[0].copy()
        return r^

    def get_unknown_args(self) -> List[String]:
        """Returns the list of unrecognised arguments.

        Only populated when the result comes from
        ``Command.parse_known_arguments()``.  Returns an empty list
        when using the standard ``parse_arguments()`` method.

        Returns:
            A copy of the unknown-arguments list.
        """
        return self._unknown_args.copy()

    def print_summary(self, indent: Int = 0):
        """Prints a human-readable summary of all parsed arguments.

        Displays positionals, flags, values, counts, lists, and maps
        stored in this result.  If a subcommand result is present, it
        is printed recursively with increased indentation.

        Args:
            indent: Number of leading spaces for nested output.
        """
        self._print_summary_impl(indent, String(""))

    def _print_summary_impl(self, indent: Int, name: String):
        """Internal implementation that accepts a subcommand name.

        Args:
            indent: Number of leading spaces for nested output.
            name: Subcommand name passed from parent (empty at top level).
        """
        var prefix = String("")
        for _ in range(indent):
            prefix += " "

        if len(name) == 0:
            print(prefix + "=== Parsed Arguments ===")
        else:
            print(prefix + "=== Subcommand: " + name + " ===")

        # Positional arguments.
        for i in range(len(self._positionals)):
            var pos_name: String
            if i < len(self._positional_names):
                pos_name = self._positional_names[i]
            else:
                pos_name = "positional[" + String(i) + "]"
            print(prefix + "  " + pos_name + ": " + self._positionals[i])

        # Collect named entries for aligned printing.
        var names = List[String]()
        var vals = List[String]()

        # Flags.
        for entry in self._flags.items():
            names.append(entry.key)
            vals.append(String(entry.value))

        # Counts.
        for entry in self._counts.items():
            names.append(entry.key)
            vals.append(String(entry.value))

        # String values.
        for entry in self._values.items():
            names.append(entry.key)
            vals.append(entry.value)

        # Lists.
        for entry in self._lists.items():
            # Skip list entries that also appear in _maps (maps store
            # raw key=value strings in _lists for has() detection).
            if entry.key in self._maps:
                continue
            names.append(entry.key)
            var s = String("[")
            for j in range(len(entry.value)):
                if j > 0:
                    s += ", "
                s += entry.value[j]
            s += "]"
            vals.append(s)

        # Maps.
        for entry in self._maps.items():
            names.append(entry.key)
            var s = String("{")
            var first = True
            for kv in entry.value.items():
                if not first:
                    s += ", "
                s += kv.key + "=" + kv.value
                first = False
            s += "}"
            vals.append(s)

        # Compute padding width.
        var max_len: Int = 0
        for k in range(len(names)):
            if len(names[k]) > max_len:
                max_len = len(names[k])
        var pad_width = max_len + 2

        # Print with aligned columns.
        for k in range(len(names)):
            var line = prefix + "  " + names[k]
            var padding = pad_width - len(names[k])
            for _p in range(padding):
                line += " "
            line += vals[k]
            print(line)

        # Unknown args.
        if len(self._unknown_args) > 0:
            var s = prefix + "  (unknown): ["
            for j in range(len(self._unknown_args)):
                if j > 0:
                    s += ", "
                s += self._unknown_args[j]
            s += "]"
            print(s)

        # Recurse into subcommand result.
        if self.has_subcommand_result():
            var sub = self._subcommand_results[0].copy()
            sub._print_summary_impl(indent + 2, self.subcommand)

    def __str__(self) -> String:
        """Return a string representation of the parse result."""
        var s = String("ParseResult(")
        s += "flags=" + String(len(self._flags))
        s += ", values=" + String(len(self._values))
        s += ", positionals=" + String(len(self._positionals))
        if self.subcommand != "":
            s += ", subcommand='" + self.subcommand + "'"
        s += ")"
        return s

    def write_to[W: Writer](self, mut writer: W):
        """Writes the string representation to a writer.

        Parameters:
            W: The writer type.

        Args:
            writer: The writer to write to.
        """
        writer.write(self.__str__())
