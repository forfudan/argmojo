"""Defines a single command-line argument."""

from std.sys import exit, stderr


comptime Arg = Argument
"""Shorthand alias for ``Argument``."""


struct Argument(Copyable, Movable, Writable):
    """A command-line argument with its metadata and constraints.

    Use the builder pattern to configure the argument and add it to a Command.

    Examples:

    ```mojo
    from argmojo import Command, Argument
    # Boolean flag  →  result.get_flag("verbose")
    _ = Argument("verbose", help="...").long["verbose"]().short["v"]().flag()
    # Key-value option  →  result.get_string("output")
    _ = Argument("output", help="...").long["output"]().short["o"]()
    # Key-value with default  →  result.get_string("format")
    _ = Argument("format", help="...").long["format"]().default["json"]()
    # Restrict to a set of values
    _ = Argument("level", help="...").long["level"]().choice["debug"]().choice["info"]().choice["warn"]()
    # Positional (matched by order)  →  result.get_string("path")
    _ = Argument("path", help="...").positional().required()
    _ = Argument("dest", help="...").positional().default["."]()
    # Count flag  (-vvv → 3)  →  result.get_count("verbose")
    _ = Argument("verbose", help="...").long["verbose"]().short["v"]().count()
    # Count flag with ceiling  (-vvvvv capped at 3)
    _ = Argument("verbose", help="...").long["verbose"]().short["v"]().count().max[3]()
    # Negatable flag  (--color / --no-color)  →  result.get_flag("color")
    _ = Argument("color", help="...").long["color"]().flag().negatable()
    # Append / collect  (--tag x --tag y → ["x","y"])  →  result.get_list("tag")
    _ = Argument("tag", help="...").long["tag"]().short["t"]().append()
    # Value delimiter  (--env a,b,c → ["a","b","c"])  →  result.get_list("env")
    _ = Argument("env", help="...").long["env"]().delimiter[","]()
    # Multi-value  (--point 1 2 → ["1","2"])  →  result.get_list("point")
    _ = Argument("point", help="...").long["point"]().number_of_values[2]()
    # Numeric range validation  →  result.get_int("port")
    _ = Argument("port", help="...").long["port"]().range[1, 65535]()
    # Numeric range with clamping  (--level 200 → 100 with warning)
    _ = Argument("level", help="...").long["level"]().range[0, 100]().clamp()
    # Key-value map  (--def k=v --def k2=v2)  →  result.get_map("def")
    _ = Argument("def", help="...").long["define"]().short["D"]().map_option()
    # Aliases  (--colour and --color both work)
    _ = Argument("colour", help="...").long["colour"]().alias_name["color"]()
    # Deprecated argument  (still works but prints a warning to stderr)
    _ = Argument("old", help="...").long["old-flag"]().deprecated["Use --new-flag instead"]()
    # Default-if-no-value  (--compress → "gzip", --compress=bzip2 → "bzip2")
    _ = Argument("compress", help="...").long["compress"]().short["c"]().default_if_no_value["gzip"]()
    # Require equals syntax  (--output=file.txt OK, --output file.txt rejected)
    _ = Argument("output", help="...").long["output"]().require_equals()
    # Display helpers
    _ = Argument("file", help="...").long["file"]().value_name["PATH"]()  # help: --file PATH
    _ = Argument("internal", help="...").long["internal"]().hidden()  # hidden from help
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
    var _value_name: String
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
    var _default_if_no_value: String
    """Value to use when the option appears without an explicit value.
    Only meaningful for value-taking options with ``_has_default_if_no_value`` set."""
    var _has_default_if_no_value: Bool
    """Whether a default-if-no-value has been set via ``.default_if_no_value()``."""
    var _require_equals: Bool
    """If True, this option requires ``--key=value`` syntax;
    ``--key value`` (space-separated) is not allowed."""
    var _is_remainder: Bool
    """If True, this positional argument consumes all remaining tokens
    (including those starting with ``-``).  Implies ``.positional()`` and
    ``.append()``.  Must be the last positional argument."""
    var _allow_hyphen_values: Bool
    """If True, the literal token ``-`` is accepted as a valid value for
    this argument (conventionally meaning stdin/stdout)."""
    var _value_name_wrapped: Bool
    """If True, the value_name is displayed wrapped in angle brackets
    (e.g. ``<FILE>`` instead of ``FILE``).  Defaults to True."""
    var _group: String
    """Help-output group name for this argument.  Arguments with the same
    group name are displayed together under a shared heading.  Empty
    string means ungrouped (shown under the default 'Options:' heading)."""
    var _prompt: Bool
    """If True, the user is interactively prompted for this argument's
    value when it is not provided on the command line."""
    var _prompt_text: String
    """Custom prompt message.  When empty, a default message is built
    from the argument's help text or name."""
    var _hide_input: Bool
    """If True, the user's input is hidden (not echoed) when prompted.
    Useful for passwords and other sensitive values.  Requires a
    terminal; falls back to normal input on non-interactive stdin."""
    var _show_asterisk: Bool
    """If True, each keystroke is echoed as ``*`` instead of being
    completely hidden.  Inspired by sudo-rs.  Only meaningful when
    ``_hide_input`` is also True."""

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    def __init__(out self, name: String, *, help: String = ""):
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
        self._value_name = ""
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
        self._default_if_no_value = ""
        self._has_default_if_no_value = False
        self._require_equals = False
        self._is_remainder = False
        self._allow_hyphen_values = False
        self._value_name_wrapped = True
        self._group = ""
        self._prompt = False
        self._prompt_text = ""
        self._hide_input = False
        self._show_asterisk = False

    def __init__(out self, *, copy: Self):
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
        self._value_name = copy._value_name
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
        self._default_if_no_value = copy._default_if_no_value
        self._has_default_if_no_value = copy._has_default_if_no_value
        self._require_equals = copy._require_equals
        self._is_remainder = copy._is_remainder
        self._allow_hyphen_values = copy._allow_hyphen_values
        self._value_name_wrapped = copy._value_name_wrapped
        self._group = copy._group
        self._prompt = copy._prompt
        self._prompt_text = copy._prompt_text
        self._hide_input = copy._hide_input
        self._show_asterisk = copy._show_asterisk

    def __init__(out self, *, deinit take: Self):
        """Moves the value from another Argument.

        Args:
            take: The Argument to move from.
        """
        self.name = take.name^
        self.help_text = take.help_text^
        self._long_name = take._long_name^
        self._short_name = take._short_name^
        self._is_flag = take._is_flag
        self._is_required = take._is_required
        self._is_positional = take._is_positional
        self._default_value = take._default_value^
        self._has_default = take._has_default
        self._choice_values = take._choice_values^
        self._value_name = take._value_name^
        self._is_hidden = take._is_hidden
        self._is_count = take._is_count
        self._is_negatable = take._is_negatable
        self._is_append = take._is_append
        self._delimiter_char = take._delimiter_char^
        self._number_of_values = take._number_of_values
        self._range_min = take._range_min
        self._range_max = take._range_max
        self._has_range = take._has_range
        self._is_clamp = take._is_clamp
        self._is_map = take._is_map
        self._alias_names = take._alias_names^
        self._deprecated_msg = take._deprecated_msg^
        self._count_max = take._count_max
        self._has_count_max = take._has_count_max
        self._is_persistent = take._is_persistent
        self._default_if_no_value = take._default_if_no_value^
        self._has_default_if_no_value = take._has_default_if_no_value
        self._require_equals = take._require_equals
        self._is_remainder = take._is_remainder
        self._allow_hyphen_values = take._allow_hyphen_values
        self._value_name_wrapped = take._value_name_wrapped
        self._group = take._group^
        self._prompt = take._prompt
        self._prompt_text = take._prompt_text^
        self._hide_input = take._hide_input
        self._show_asterisk = take._show_asterisk

    # ===------------------------------------------------------------------=== #
    # Builder methods for configuring the argument
    # ===------------------------------------------------------------------=== #

    def long[name: StringLiteral](var self) -> Self:
        """Sets the long option name (e.g., 'verbose' for --verbose).

        Parameters:
            name: The long option name without the ``--`` prefix.

        Returns:
            Self with the long name set.

        Constraints:
            The name is validated at compile time:
            - Must not be empty.
            - Must not start with ``-`` (the ``--`` prefix is added automatically).
            - Must not contain ``=`` (conflicts with ``--key=value`` syntax).
        """
        comptime assert len(name) > 0, "long name must not be empty"
        comptime assert not name.startswith(
            "-"
        ), "long name must not start with '-'; omit the '--' prefix"
        comptime assert name.find("=") == -1, (
            "long name must not contain '='; it conflicts with --key=value"
            " syntax"
        )
        self._long_name = name
        return self^

    def short[name: StringLiteral](var self) -> Self:
        """Sets the short option name (e.g., 'l' for -l).

        Parameters:
            name: A single character for the short option without ``-`` prefix.

        Returns:
            Self with the short name set.

        Constraints:
            The name is validated at compile time: it must be exactly one
            character (e.g., ``"v"``, ``"o"``), and must not be ``"-"``
            (which would conflict with the ``--`` end-of-options sentinel).
        """
        comptime assert len(name) == 1, "short name must be exactly 1 character"
        comptime assert name != "-", (
            "short name must not be '-'; it conflicts with the"
            " end-of-options sentinel '--'"
        )
        self._short_name = name
        return self^

    def flag(var self) -> Self:
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

    def required(var self) -> Self:
        """Marks this argument as required.

        Returns:
            Self marked as required.

        Notes:
            Required arguments must be provided in the input; otherwise, parsing
            will fail.
        """
        self._is_required = True
        return self^

    def positional(var self) -> Self:
        """Marks this argument as a positional argument.

        Returns:
            Self marked as positional.
        """
        self._is_positional = True
        return self^

    def takes_value(var self) -> Self:
        """Marks this argument as taking a value (not a flag).

        This is the default behavior; use this for clarity when needed.

        Returns:
            Self with _is_flag set to False.
        """
        self._is_flag = False
        return self^

    def default[value: StringLiteral](var self) -> Self:
        """Sets a default value for this argument.

        Parameters:
            value: The default value.

        Returns:
            Self with the default value set.
        """
        self._default_value = value
        self._has_default = True
        return self^

    def choice[value: StringLiteral](var self) -> Self:
        """Adds an allowed value for this argument.

        Chain multiple calls to build the full set of choices:
        ``.choice["json"]().choice["csv"]().choice["table"]()``.
        Parameters:
            value: An allowed value.

        Returns:
            Self with the choice added.

        Constraints:
            The value must not be empty.
        """
        comptime assert len(value) > 0, "choice value must not be empty"
        self._choice_values.append(value)
        return self^

    def value_name[name: StringLiteral, wrapped: Bool = True](var self) -> Self:
        """Sets the display name for the value in help text.

        When *wrapped* is True (default), the name is displayed inside angle
        brackets: ``--output <FILE>``.  When False, it is displayed bare:
        ``--output FILE``.

        Parameters:
            name: The display name of the value (e.g., "FILE" for --output).
            wrapped: Wrap the display name in ``<>`` (default True).

        Returns:
            Self with the value_name set.

        Constraints:
            The value name must be a non-empty string.
        """
        comptime assert len(name) > 0, "value name must be a non-empty string"
        self._value_name = name
        self._value_name_wrapped = wrapped
        return self^

    def hidden(var self) -> Self:
        """Marks this argument as hidden (not shown in help output).

        Returns:
            Self marked as hidden.
        """
        self._is_hidden = True
        return self^

    def count(var self) -> Self:
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
    def max[ceiling: Int](var self) -> Self where ceiling >= 1:
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

    def negatable(var self) -> Self:
        """Marks this flag as negatable.

        A negatable flag accepts both ``--X`` (sets True) and ``--no-X``
        (sets False). For example, ``.long["color"]().flag().negatable()``
        accepts ``--color`` and ``--no-color``.

        Returns:
            Self marked as negatable.
        """
        self._is_negatable = True
        return self^

    def append(var self) -> Self:
        """Marks this argument as an append/collect option.

        Each occurrence adds its value to a list. For example,
        ``--tag x --tag y`` collects ``["x", "y"]``. Use ``get_list()``
        on ParseResult to retrieve the collected values.

        Returns:
            Self marked as append.
        """
        self._is_append = True
        return self^

    def delimiter[sep: StringLiteral](var self) -> Self:
        """Sets a value delimiter for splitting a single value into multiple.

        When set, each provided value is split by the delimiter, and each
        piece is added to the list individually.  Implies ``.append()``.
        For example, ``.delimiter[","]()`` causes ``--tag a,b,c`` to produce
        ``["a", "b", "c"]``.

        When fullwidth correction is enabled (the default), fullwidth
        equivalents of the delimiter in user input are auto-corrected
        before splitting.  For example, ``a，b，c`` is treated as
        ``a,b,c`` when the delimiter is ``","``.

        Parameters:
            sep: The delimiter character (e.g., ``","``).

        Returns:
            Self with the delimiter and append mode set.

        Constraints:
            The separator is validated at compile time: it must be one of
            ``,`` | ``;`` | ``:`` | ``|``.
        """
        comptime assert (
            sep == "," or sep == ";" or sep == ":" or sep == "|"
        ), "delimiter must be one of: , ; : |"

        self._delimiter_char = sep
        self._is_append = True
        return self^

    def number_of_values[n: Int](var self) -> Self where n >= 2:
        """Sets the number of values consumed per occurrence.

        When set, each use of the option consumes exactly ``n``
        consecutive arguments.  For example, ``.number_of_values[2]()`` on
        ``--point`` causes ``--point 1 2`` to collect ``["1", "2"]``.
        Implies ``.append()`` so values are retrieved with
        ``ParseResult.get_list()``.

        Parameters:
            n: Number of values to consume (must be ≥ 2).

        Returns:
            Self with _number_of_values and append mode set.
        """
        self._number_of_values = n
        self._is_append = True
        return self^

    def range[
        min_val: Int, max_val: Int
    ](var self) -> Self where max_val >= min_val:
        """Sets numeric range validation for this argument.

        When set, the parsed value must be an integer within
        ``[min_val, max_val]`` (inclusive).  Validation occurs
        after parsing, during the validation phase.

        By default, out-of-range values cause an error.  Chain with
        ``.clamp()`` to silently adjust the value (with a warning)
        instead of erroring.

        Parameters:
            min_val: Minimum allowed value (inclusive).
            max_val: Maximum allowed value (inclusive).

        Returns:
            Self with range validation enabled.
        """
        self._range_min = min_val
        self._range_max = max_val
        self._has_range = True
        return self^

    def clamp(var self) -> Self:
        """Enables clamping for numeric range validation.

        When clamping is enabled (used after ``.range[min, max]()``),
        out-of-range values are adjusted to the nearest boundary
        instead of causing an error.  A warning is printed to stderr
        to inform the user of the adjustment.

        For example, ``.range[1, 100]().clamp()`` causes ``--level 200``
        to be silently adjusted to 100 with a warning.

        Must be used after ``.range()``.

        Returns:
            Self with clamping enabled.
        """
        self._is_clamp = True
        return self^

    def map_option(var self) -> Self:
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

    def alias_name[name: StringLiteral](var self) -> Self:
        """Sets an alternative long name for this argument.

        Any alias resolves to this argument during parsing.  For
        example, ``.long["colour"]().alias_name["color"]()`` makes both
        ``--colour`` and ``--color`` accepted.  Chain multiple calls
        for several aliases:
        ``.alias_name["out"]().alias_name["fmt"]()``.

        Parameters:
            name: The alternative long option name (without ``--``).

        Returns:
            Self with the alias registered.

        Constraints:
            The alias is validated at compile time (same rules as
            ``.long[]``): must not be empty, must not start with ``-``,
            and must not contain ``=``.
        """
        comptime assert len(name) > 0, "alias name must not be empty"
        comptime assert not name.startswith(
            "-"
        ), "alias name must not start with '-'; omit the '--' prefix"
        comptime assert name.find("=") == -1, (
            "alias name must not contain '='; it conflicts with"
            " --key=value syntax"
        )
        self._alias_names.append(name)
        return self^

    def deprecated[message: StringLiteral](var self) -> Self:
        """Marks this argument as deprecated.

        When the user provides a deprecated argument, a warning is
        printed to stderr but parsing continues normally.

        Parameters:
            message: The deprecation message (e.g., "Use --format instead").

        Returns:
            Self marked as deprecated.

        Constraints:
            The message must not be empty.
        """
        comptime assert (
            len(message) > 0
        ), "deprecation message must not be empty"
        self._deprecated_msg = message
        return self^

    def persistent(var self) -> Self:
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

    def default_if_no_value[value: StringLiteral](var self) -> Self:
        """Sets a default value for when the option appears without an explicit value.

        When set, the option may appear without a value.  If no value
        is given, this default-if-no-value is used.  If a value is
        provided via ``=`` syntax for long options (``--compress=bzip2``)
        or attached form for short options (``-cbzip2``), that explicit
        value is used instead.

        For long options this implies ``require_equals()``.  A
        space-separated token like ``--compress val`` is not accepted
        as the option's value; in that case ``--compress`` uses its
        default-if-no-value and ``val`` is parsed as a separate
        argument (positional or another option).  To supply an
        explicit value for the option, the user must write
        ``--compress=val``.

        Parameters:
            value: The value to use when no explicit value is given.

        Returns:
            Self with the default-if-no-value set.

        Examples:

        ```mojo
        # --compress        → "gzip"  (default-if-no-value)
        # --compress=bzip2  → "bzip2" (explicit)
        # -c                → "gzip"  (default-if-no-value)
        # -cbzip2           → "bzip2" (attached)

        from argmojo import Argument
        _ = (Argument("compress", help="...")
            .long["compress"]()
            .short["c"]()
            .default_if_no_value["gzip"]())
        ```
        """
        self._default_if_no_value = value
        self._has_default_if_no_value = True
        self._require_equals = True  # implied for long options
        return self^

    def require_equals(var self) -> Self:
        """Requires that values be provided using ``=`` syntax.

        When set, ``--key value`` (space-separated) is rejected;
        only ``--key=value`` is accepted.  This avoids ambiguity
        when values may start with ``-``.

        Can be combined with ``.default_if_no_value()`` so that ``--key``
        without ``=`` uses the default-if-no-value, while ``--key=val``
        uses ``val``.

        Examples::

            # --output=file.txt  → "file.txt" (OK)
            # --output file.txt  → error
            _ = Argument("output", help="...").long["output"]().require_equals()

        Returns:
            Self with require-equals enabled.
        """
        self._require_equals = True
        return self^

    def remainder(var self) -> Self:
        """Marks this positional argument as a remainder collector.

        A remainder argument consumes **all** remaining tokens on the
        command line — including those starting with ``-``.  It is
        equivalent to Python's ``nargs=argparse.REMAINDER``.

        Implies ``.positional()`` and ``.append()`` — values are retrieved
        via ``ParseResult.get_list()``.

        A ``Command`` may have at most one remainder argument, and it
        must be the last positional argument.  Tokens collected by a
        remainder argument are **not** parsed as options; they are stored
        verbatim.

        Examples::

            # myapp build -- -Wall -O2 src/main.c
            # With .remainder(), everything after 'build' goes into rest:
            _ = Argument("rest", help="...").remainder()

            # Or without '--':
            # myapp run script.py --script-flag
            # rest = ["script.py", "--script-flag"]

        Returns:
            Self marked as a remainder positional.
        """
        self._is_remainder = True
        self._is_positional = True
        self._is_append = True
        return self^

    def allow_hyphen_values(var self) -> Self:
        """Allows tokens starting with ``-`` as valid values.

        By default, tokens that start with ``-`` are interpreted as option
        flags.  Call this method to accept such tokens as regular values
        instead, without requiring ``--`` first.  This covers the common
        Unix convention where a bare ``-`` means stdin/stdout, as well as
        any other dash-prefixed literal value.

        Can be used on positional arguments and value-taking options.

        Examples::

            # Positional: myapp -  → positional value is "-"
            _ = Argument("input", help="...").positional().allow_hyphen_values()

            # Option: myapp --file -  → file value is "-"
            _ = Argument("file", help="...").long["file"]().allow_hyphen_values()

        Returns:
            Self with hyphen-value support enabled.
        """
        self._allow_hyphen_values = True
        return self^

    def group[name: StringLiteral](var self) -> Self:
        """Assigns this argument to a named help-output group.

        Arguments sharing the same group name are displayed together
        under a dedicated heading in ``--help`` output (e.g.,
        ``Network:`` or ``Authentication:``).  Ungrouped arguments
        remain under the default ``Options:`` heading.

        Parameters:
            name: The group name (used as the section heading).

        Returns:
            Self with the group set.

        Constraints:
            The group name must not be empty.
        """
        comptime assert len(name) > 0, "group name must not be empty"
        self._group = name
        return self^

    def prompt(var self) -> Self:
        """Enables interactive prompting for this argument.

        When prompting is enabled, the user is interactively asked to
        provide a value if the argument was not supplied on the command
        line.  This works with any argument — required or optional,
        named or positional.

        The prompt message is derived from the argument's help text
        (or name as fallback).  Use ``prompt["custom text"]()`` to
        set a custom prompt message instead.

        For flag arguments, the prompt accepts ``y``/``n`` (case-insensitive).
        For arguments with choices, the valid choices are displayed in
        the prompt.  For arguments with a default, the default is shown
        in parentheses and used when the user enters nothing.

        Returns:
            Self with prompting enabled.

        Examples:

        ```mojo
        from argmojo import Argument
        _ = Argument("name", help="Your name").long["name"]().prompt()
        ```
        """
        self._prompt = True
        return self^

    def prompt[text: StringLiteral](var self) -> Self:
        """Enables interactive prompting with custom text.

        When the argument is not supplied on the command line, the
        custom ``text`` is displayed instead of the default message
        (which is derived from help text or argument name).

        Parameters:
            text: Custom prompt message.

        Returns:
            Self with prompting enabled and custom text set.

        Constraints:
            The prompt text must not be empty.

        Examples:

        ```mojo
        from argmojo import Argument
        _ = Argument("token", help="API token").long["token"]().prompt["Enter your API token"]()
        ```
        """
        comptime assert len(text) > 0, "prompt text must not be empty"
        self._prompt = True
        self._prompt_text = text
        return self^

    def password(var self) -> Self:
        """Marks this argument as a password / sensitive value.

        When combined with ``.prompt()``, the user's input is hidden
        (not echoed to the terminal).  This is equivalent to Click's
        ``hide_input=True``.  Implies ``.prompt()`` if not already set.

        On POSIX systems, terminal echo is disabled via ``tcsetattr(3)``
        while the user types, then re-enabled afterwards.  If stdin is
        not a terminal (e.g., piped input, ``/dev/null``), the call
        falls back to regular ``input()`` — just as ``getpass.getpass``
        does in Python.

        Returns:
            Self with hidden input enabled.

        Examples:

        ```mojo
        from argmojo import Argument
        _ = Argument("token", help="API token").long["token"]().password()
        _ = Argument("pass", help="Password").long["pass"]().prompt["Enter password"]().password()
        ```
        """
        self._hide_input = True
        if not self._prompt:
            self._prompt = True
        return self^

    def password[asterisk: Bool](var self) -> Self:
        """Marks this argument as a password with configurable echo style.

        When ``asterisk`` is True, each keystroke is echoed as ``*``
        (like sudo-rs) instead of being completely hidden.  This gives
        the user visual feedback on how many characters have been typed
        while still concealing the actual value.

        When ``asterisk`` is False, behaves identically to the
        parameterless ``.password()`` (input fully hidden).

        Implies ``.prompt()`` if not already set.

        Parameters:
            asterisk: If True, echo ``*`` for each character.

        Returns:
            Self with hidden/asterisk input enabled.

        Examples:

        ```mojo
        from argmojo import Argument
        # Asterisk feedback (sudo-rs style):
        _ = Argument("pass", help="Password").long["pass"]().password[True]()
        # Fully hidden (same as .password()):
        _ = Argument("pass", help="Password").long["pass"]().password[False]()
        ```
        """
        self._hide_input = True
        self._show_asterisk = asterisk
        if not self._prompt:
            self._prompt = True
        return self^

    # ===------------------------------------------------------------------=== #
    # String representation methods
    # ===------------------------------------------------------------------=== #

    def write_to[W: Writer](self, mut writer: W):
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
