"""Declarative wrapper types for CLI arguments.

Four wrapper structs that encode argument metadata as compile-time
parameters.  Each wraps a runtime ``value`` field and carries all
configuration (long name, short name, help text, choices, ...) in its
type signature so that ``Parser[T]._build()`` can translate them
to builder calls without any runtime metadata tables.

- ``Option[T, ...]``    -- named option (``--output file.txt``, ``-o val``)
- ``Flag[...]``         -- boolean flag (``--verbose``, ``-v``)
- ``Positional[T, ...]``-- positional argument (matched by position)
- ``Count[...]``        -- count flag (``-vvv`` -> 3)
"""


# =======================================================================
# Option
# =======================================================================


struct Option[
    T: Defaultable & Copyable & Movable,
    *,
    # -- Naming --
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    alias_name: StringLiteral = "",
    # -- Argument type --
    negatable: Bool = False,
    # -- Value defaults & validation --
    default: StringLiteral = "",
    required: Bool = False,
    choices: StringLiteral = "",
    range_min: Int = 0,
    range_max: Int = 0,
    has_range: Bool = False,
    clamp: Bool = False,
    # -- Collection modes --
    append: Bool = False,
    delimiter: StringLiteral = "",
    nargs: Int = 0,
    map_option: Bool = False,
    # -- Parsing behaviour --
    require_equals: Bool = False,
    allow_hyphen: Bool = False,
    persistent: Bool = False,
    # -- Display & help --
    value_name: StringLiteral = "",
    hidden: Bool = False,
    deprecated: StringLiteral = "",
    group: StringLiteral = "",
    # -- Interactive prompting --
    prompt: Bool = False,
    prompt_text: StringLiteral = "",
    password: Bool = False,
](Copyable, Movable, Defaultable):
    """A named option that takes a value.

    ``T`` is the value type stored at runtime (``String``, ``Int``,
    ``List[String]``, etc.).  All other parameters are keyword-only
    compile-time metadata consumed by ``Parser[T]._build()``.

    Parameters:
        T: The value type stored at runtime.
        long: Long option name (e.g. ``"output"`` for ``--output``). Empty = auto from field name.
        short: Short option character (e.g. ``"o"`` for ``-o``).
        help: Help text shown in ``--help`` output.
        alias_name: Comma-separated alias long names.
        negatable: If True, generate ``--x`` / ``--no-x`` pair (T must be Bool).
        default: Default value as a string literal.
        required: If True, the option must be provided.
        choices: Comma-separated allowed values.
        range_min: Minimum numeric value (requires ``has_range=True``).
        range_max: Maximum numeric value (requires ``has_range=True``).
        has_range: Enable range validation.
        clamp: Clamp to range instead of raising an error.
        append: Collect repeated occurrences into a list.
        delimiter: Split a single value by this delimiter.
        nargs: Number of values consumed (0 = single).
        map_option: Parse as ``key=value`` map entries.
        require_equals: Require ``--key=value`` syntax.
        allow_hyphen: Allow hyphen-prefixed values.
        persistent: Inherited by subcommands.
        value_name: Display name in help (e.g. ``FILE``).
        hidden: Hide from help output.
        deprecated: Deprecation warning message.
        group: Help group heading.
        prompt: Interactively prompt if missing.
        prompt_text: Custom prompt message.
        password: Mask input when prompting.

    Examples:

    ```mojo
    from argmojo.argument_wrappers import Option

    # Simple string option: --output / -o
    var out: Option[String, long="output", short="o", help="Output path"]

    # Required int option with range validation
    var port: Option[Int, long="port", required=True,
                     has_range=True, range_min=1, range_max=65535]

    # List-collecting option: --tag x --tag y -> ["x", "y"]
    var tags: Option[List[String], long="tag", short="t", append=True]

    # Choices with default
    var fmt: Option[String, long="format", short="f",
                    choices="json,yaml,csv", default="json"]
    ```
    """

    var value: Self.T
    """The runtime value populated by parsing."""

    fn __init__(out self):
        """Default-initialise with ``T()``."""
        self.value = Self.T()

    fn __init__(out self, *, copy: Self):
        """Copy from an existing instance.

        Args:
            copy: The Option to copy from.
        """
        self.value = copy.value.copy()

    fn __init__(out self, *, deinit take: Self):
        """Move from an existing instance.

        Args:
            take: The Option to move from.
        """
        self.value = take.value^


# =======================================================================
# Flag
# =======================================================================


struct Flag[
    *,
    # -- Naming --
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    # -- Argument type --
    negatable: Bool = False,
    # -- Parsing behaviour --
    persistent: Bool = False,
    # -- Display & help --
    hidden: Bool = False,
    deprecated: StringLiteral = "",
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    """A boolean flag (no value; presence means ``True``).

    Provides ``__bool__`` so you can write ``if args.verbose:``
    instead of ``if args.verbose.value:``.

    Parameters:
        long: Long flag name. Empty = auto from field name.
        short: Short flag character.
        help: Help text shown in ``--help`` output.
        negatable: If True, generate ``--flag`` / ``--no-flag`` pair.
        persistent: Inherited by subcommands.
        hidden: Hide from help output.
        deprecated: Deprecation warning message.
        group: Help group heading.

    Examples:

    ```mojo
    from argmojo.argument_wrappers import Flag

    # Simple flag: --verbose / -v
    var verbose: Flag[short="v", help="Enable verbose output"]

    # Negatable flag: --color / --no-color
    var color: Flag[long="color", negatable=True]
    ```
    """

    var value: Bool
    """The runtime value populated by parsing."""

    fn __init__(out self):
        """Default-initialise to ``False``."""
        self.value = False

    fn __init__(out self, val: Bool):
        """Initialise with an explicit value.

        Args:
            val: The initial boolean value.
        """
        self.value = val

    fn __init__(out self, *, copy: Self):
        """Copy from an existing instance.

        Args:
            copy: The Flag to copy from.
        """
        self.value = copy.value

    fn __init__(out self, *, deinit take: Self):
        """Move from an existing instance.

        Args:
            take: The Flag to move from.
        """
        self.value = take.value

    fn __bool__(self) -> Bool:
        """Implicit conversion to ``Bool`` for convenience.

        Allows ``if args.verbose:`` rather than ``if args.verbose.value:``.

        Returns:
            The flag value.
        """
        return self.value


# =======================================================================
# Positional
# =======================================================================


struct Positional[
    T: Defaultable & Copyable & Movable,
    *,
    help: StringLiteral = "",
    # -- Argument type --
    remainder: Bool = False,
    # -- Value defaults & validation --
    default: StringLiteral = "",
    required: Bool = False,
    choices: StringLiteral = "",
    # -- Display & help --
    value_name: StringLiteral = "",
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    """A positional argument (matched by order, not by name).

    Positionals don't have ``--long`` or ``-short`` names.  Use
    ``remainder=True`` on the last positional to consume all remaining
    tokens (like ``--`` in many CLI tools).

    Parameters:
        T: The value type stored at runtime.
        help: Help text shown in ``--help`` output.
        remainder: Consume all remaining tokens.
        default: Default value as a string literal.
        required: If True, the positional must be provided.
        choices: Comma-separated allowed values.
        value_name: Display name in help.
        group: Help group heading.

    Examples:

    ```mojo
    from argmojo.argument_wrappers import Positional

    # Required positional
    var pattern: Positional[String, help="Search pattern", required=True]

    # Optional positional with default
    var path: Positional[String, help="File or directory", default="."]

    # Remainder: consumes everything after the named positionals
    var files: Positional[List[String], help="Input files", remainder=True]
    ```
    """

    var value: Self.T
    """The runtime value populated by parsing."""

    fn __init__(out self):
        """Default-initialise with ``T()``."""
        self.value = Self.T()

    fn __init__(out self, *, copy: Self):
        """Copy from an existing instance.

        Args:
            copy: The Positional to copy from.
        """
        self.value = copy.value.copy()

    fn __init__(out self, *, deinit take: Self):
        """Move from an existing instance.

        Args:
            take: The Positional to move from.
        """
        self.value = take.value^


# =======================================================================
# Count
# =======================================================================


struct Count[
    *,
    # -- Naming --
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    # -- Argument type --
    max: Int = 0,
    # -- Parsing behaviour --
    persistent: Bool = False,
    # -- Display & help --
    hidden: Bool = False,
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    """A count flag (each occurrence increments the value).

    Commonly used for verbosity: ``-v`` -> 1, ``-vv`` -> 2, ``-vvv`` -> 3.
    Set ``max`` to cap the count (0 means no ceiling).

    Parameters:
        long: Long flag name. Empty = auto from field name.
        short: Short flag character.
        help: Help text shown in ``--help`` output.
        persistent: Inherited by subcommands.
        hidden: Hide from help output.
        group: Help group heading.

    Examples:

    ```mojo
    from argmojo.argument_wrappers import Count

    # Verbosity counter: -v, -vv, -vvv (capped at 3)
    var verbose: Count[short="v", help="Increase verbosity", max=3]

    # Uncapped counter
    var debug: Count[long="debug", short="d", help="Debug level"]
    ```
    """

    var value: Int
    """The runtime value populated by parsing."""

    fn __init__(out self):
        """Default-initialise to ``0``."""
        self.value = 0

    fn __init__(out self, val: Int):
        """Initialise with an explicit value.

        Args:
            val: The initial count value.
        """
        self.value = val

    fn __init__(out self, *, copy: Self):
        """Copy from an existing instance.

        Args:
            copy: The Count to copy from.
        """
        self.value = copy.value

    fn __init__(out self, *, deinit take: Self):
        """Move from an existing instance.

        Args:
            take: The Count to move from.
        """
        self.value = take.value
