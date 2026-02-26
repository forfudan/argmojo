"""Stores parsed argument values."""


struct ParseResult(Copyable, Movable, Stringable, Writable):
    """Stores the results of parsing command-line arguments.

    Provides typed accessors to retrieve argument values by name.
    """

    var flags: Dict[String, Bool]
    """Boolean flag values, keyed by argument name."""
    var values: Dict[String, String]
    """String argument values, keyed by argument name."""
    var positionals: List[String]
    """Positional argument values, in order."""
    var counts: Dict[String, Int]
    """Counter values for count-type arguments (e.g., -vvv → 3)."""
    var lists: Dict[String, List[String]]
    """Collected list values for append-type arguments (e.g., --tag x --tag y)."""
    var maps: Dict[String, Dict[String, String]]
    """Key-value map values for map-type arguments (e.g., --define key=val)."""
    var _positional_names: List[String]
    """Names of positional arguments, in declaration order."""
    var subcommand: String
    """Name of the selected subcommand. Empty string if no subcommand was given."""
    var _subcommand_results: List[ParseResult]
    """Child ParseResult from subcommand parsing. Contains 0 or 1 elements.

    Use ``has_subcommand_result()`` to check presence and
    ``get_subcommand_result()`` to retrieve the value.
    """

    fn __init__(out self):
        """Creates an empty ParseResult."""
        self.flags = Dict[String, Bool]()
        self.values = Dict[String, String]()
        self.positionals = List[String]()
        self.counts = Dict[String, Int]()
        self.lists = Dict[String, List[String]]()
        self.maps = Dict[String, Dict[String, String]]()
        self._positional_names = List[String]()
        self.subcommand = ""
        self._subcommand_results = List[ParseResult]()

    fn __copyinit__(out self, copy: Self):
        """Creates a deep copy of a ParseResult.

        Args:
            copy: The ParseResult to copy from.
        """
        self.flags = copy.flags.copy()
        self.values = copy.values.copy()
        self.positionals = copy.positionals.copy()
        self.counts = copy.counts.copy()
        self.lists = Dict[String, List[String]]()
        for entry in copy.lists.items():
            self.lists[entry.key] = entry.value.copy()
        self.maps = Dict[String, Dict[String, String]]()
        for entry in copy.maps.items():
            self.maps[entry.key] = entry.value.copy()
        self._positional_names = copy._positional_names.copy()
        self.subcommand = copy.subcommand
        self._subcommand_results = copy._subcommand_results.copy()

    fn __moveinit__(out self, deinit move: Self):
        """Moves a ParseResult, transferring all field ownership.

        Args:
            move: The ParseResult to move from.
        """
        self.flags = move.flags^
        self.values = move.values^
        self.positionals = move.positionals^
        self.counts = move.counts^
        self.lists = move.lists^
        self.maps = move.maps^
        self._positional_names = move._positional_names^
        self.subcommand = move.subcommand^
        self._subcommand_results = move._subcommand_results^

    fn get_flag(self, name: String) -> Bool:
        """Gets a boolean flag value. Returns False if not set.

        Args:
            name: The argument name.

        Returns:
            True if the flag was set, False otherwise.
        """
        try:
            return self.flags[name]
        except:
            return False

    fn get_string(self, name: String) raises -> String:
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
            return self.values[name]
        except:
            pass

        # Check positional arguments by name.
        for i in range(len(self._positional_names)):
            if self._positional_names[i] == name:
                if i < len(self.positionals):
                    return self.positionals[i]

        raise Error("Argument '" + name + "' not found")

    fn get_int(self, name: String) raises -> Int:
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

    fn get_count(self, name: String) -> Int:
        """Gets the count for a counter-type argument. Returns 0 if not set.

        Args:
            name: The argument name.

        Returns:
            The number of times the flag was provided.
        """
        try:
            return self.counts[name]
        except:
            return 0

    fn get_list(self, name: String) -> List[String]:
        """Gets the collected list for an append-type argument.

        Returns an empty list if the argument was never provided.

        Args:
            name: The argument name.

        Returns:
            The list of collected values.

        Note:
            For map-type arguments (`.map_option()`), each entry is the
            raw ``key=value`` string (e.g. ``["DEBUG=1", "VERSION=2"]``).
            Use ``get_map()`` instead to retrieve the parsed dict.
        """
        try:
            var result = List[String]()
            var lst = self.lists[name].copy()
            for i in range(len(lst)):
                result.append(String(lst[i]))
            return result^
        except:
            return List[String]()

    fn get_map(self, name: String) -> Dict[String, String]:
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
            var m = self.maps[name].copy()
            for entry in m.items():
                result[entry.key] = entry.value
            return result^
        except:
            return Dict[String, String]()

    fn has(self, name: String) -> Bool:
        """Checks whether an argument was provided.

        Args:
            name: The argument name.

        Returns:
            True if the argument was provided.
        """
        if name in self.flags:
            return True
        if name in self.values:
            return True
        if name in self.counts:
            return True
        if name in self.lists:
            return True
        if name in self.maps:
            return True
        for i in range(len(self._positional_names)):
            if self._positional_names[i] == name:
                return i < len(self.positionals)
        return False

    fn has_subcommand_result(self) -> Bool:
        """Checks whether a subcommand result is present.

        Returns:
            True if a child ``ParseResult`` was stored from subcommand
            parsing, False otherwise.
        """
        return len(self._subcommand_results) > 0

    fn get_subcommand_result(self) raises -> ParseResult:
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

    fn __str__(self) -> String:
        """Return a string representation of the parse result."""
        var s = String("ParseResult(")
        s += "flags=" + String(len(self.flags))
        s += ", values=" + String(len(self.values))
        s += ", positionals=" + String(len(self.positionals))
        if self.subcommand != "":
            s += ", subcommand='" + self.subcommand + "'"
        s += ")"
        return s

    fn write_to[W: Writer](self, mut writer: W):
        """Writes the string representation to a writer.

        Parameters:
            W: The writer type.

        Args:
            writer: The writer to write to.
        """
        writer.write(self.__str__())
