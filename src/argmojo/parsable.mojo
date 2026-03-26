"""Declares the Parsable trait and the arg_defaults helper."""


trait Parsable(Defaultable, Movable):
    """Marker trait for structs that can be parsed from CLI arguments.

    User structs conforming to this trait can be used with
    ``Parser[T]`` for fully typed, declarative CLI parsing.

    Examples:

    ```mojo
    from argmojo.parsable import Parsable, arg_defaults
    from argmojo.argument_wrappers import Option, Flag

    struct MyArgs(Parsable):
        var output: Option[String, long="output", short="o",
                           help="Output file"]
        var verbose: Flag[short="v", help="Enable verbose output"]

        def __init__(out self):
            self = arg_defaults[Self]()

        @staticmethod
        def description() -> String:
            return "My awesome tool."
    ```
    """

    @staticmethod
    def description() -> String:
        """Return the command description for --help.

        Returns:
            The description string.
        """
        ...

    @staticmethod
    def version() -> String:
        """Return the version string for --version.

        Override to change from the default ``"0.1.0"``.

        Returns:
            The version string.
        """
        return String("0.1.0")

    @staticmethod
    def name() -> String:
        """Return the command name.

        Override to change from the default (lowercased struct name).
        An empty string means "use the lowercased struct name".

        Returns:
            The command name.
        """
        return String("")


def arg_defaults[T: Parsable]() -> T:
    """Create a default-initialised instance of T.

    All wrapper types (``Positional``, ``Option``, ``Flag``, ``Count``)
    implement ``Defaultable``, so ``T()`` initialises every field to its
    type-specific default (empty string, 0, False, etc.).

    Use this in your struct's ``__init__``.

    Parameters:
        T: A struct conforming to ``Parsable``.

    Returns:
        A default-initialised instance of T.
    """
    return T()
