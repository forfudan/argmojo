"""Declares the Parsable trait, reflection helpers, and convenience functions."""

from std.reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
)

from .argument_wrappers import ArgumentLike
from .command import Command
from .parse_result import ParseResult


trait Parsable(Defaultable, Movable):
    """Trait for structs that can be parsed from CLI arguments.

    Provides default methods for building a Command, parsing argv,
    and populating the struct from a ParseResult — all driven by
    compile-time reflection over wrapper-typed fields (Option, Flag,
    Positional, Count).

    Users only need to provide ``description()`` (required) and
    optionally override ``version()``, ``name()``, and ``subcommands()``.

    Examples:

    ```mojo
    from argmojo.parsable import Parsable
    from argmojo.argument_wrappers import Option, Flag

    struct MyArgs(Parsable):
        var output: Option[String, long="output", short="o",
                           help="Output file"]
        var verbose: Flag[short="v", help="Enable verbose output"]

        def __init__(out self):
            self.output = Option[String, long="output", short="o",
                                 help="Output file"]()
            self.verbose = Flag[short="v", help="Enable verbose output"]()

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

    @staticmethod
    def subcommands(mut cmd: Command) raises:
        """Override to register child subcommands.

        Called automatically by ``to_command()``.  The default does nothing.

        Args:
            cmd: The parent Command to add subcommands to.
        """
        pass

    def run(self) raises:
        """Execute this command's logic after parsing.

        Override in leaf commands. The default does nothing.
        """
        pass


# =======================================================================
# Reflection helpers
# =======================================================================


def _reflect_and_register[T: Parsable](mut cmd: Command) raises:
    """Iterate T's fields via reflection and register ArgumentLike-conforming
    ones as Arguments on cmd.

    Parameters:
        T: A struct conforming to Parsable.

    Args:
        cmd: The Command to register arguments on.
    """
    var instance = T()
    comptime field_count = struct_field_count[T]()
    comptime field_types = struct_field_types[T]()
    comptime field_names = struct_field_names[T]()

    comptime for idx in range(field_count):
        comptime ftype = field_types[idx]
        comptime if conforms_to(ftype, ArgumentLike):
            ref field = __struct_field_ref(idx, instance)
            comptime fname = field_names[idx]
            trait_downcast[ArgumentLike](field).add_to_command(
                String(fname), cmd
            )


def _from_result[T: Parsable](result: ParseResult) raises -> T:
    """Create a T instance and populate ArgumentLike-conforming fields from
    the given ParseResult.

    Parameters:
        T: A struct conforming to Parsable.

    Args:
        result: The ParseResult containing parsed values.

    Returns:
        A populated instance of T.
    """
    var out = T()
    comptime field_count = struct_field_count[T]()
    comptime field_types = struct_field_types[T]()
    comptime field_names = struct_field_names[T]()

    comptime for idx in range(field_count):
        comptime ftype = field_types[idx]
        comptime if conforms_to(ftype, ArgumentLike):
            ref field = __struct_field_ref(idx, out)
            comptime fname = field_names[idx]
            trait_downcast[ArgumentLike](field).read_from_result(
                String(fname), result
            )

    return out^


# =======================================================================
# Parsable convenience functions
# =======================================================================


def to_command[T: Parsable]() raises -> Command:
    """Build a Command from T's metadata and fields.

    Reflects over T's fields, registers them as arguments, and
    calls ``T.subcommands()`` to wire child commands.

    Parameters:
        T: A struct conforming to Parsable.

    Returns:
        A fully configured Command.
    """
    var cmd_name = String(T.name())
    if not cmd_name:
        cmd_name = String("command")
    var cmd = Command(
        cmd_name,
        String(T.description()),
        version=String(T.version()),
    )
    _reflect_and_register[T](cmd)
    T.subcommands(cmd)
    return cmd^


def parse[T: Parsable]() raises -> T:
    """Build, parse argv, and return a populated T.

    This is the primary entry point for pure-declarative usage.

    Parameters:
        T: A struct conforming to Parsable.

    Returns:
        A populated instance of T.
    """
    var cmd = to_command[T]()
    var result = cmd.parse()
    return _from_result[T](result)


def parse_args[T: Parsable](args: List[String]) raises -> T:
    """Build, parse the given argument list, and return a populated T.

    Parameters:
        T: A struct conforming to Parsable.

    Args:
        args: The raw argument strings (including program name at index 0).

    Returns:
        A populated instance of T.
    """
    var cmd = to_command[T]()
    var result = cmd.parse_arguments(args)
    return _from_result[T](result)


def parse_split[T: Parsable]() raises -> Tuple[T, ParseResult]:
    """Build, parse argv, and return both T and raw ParseResult.

    Use when you need both typed fields and subcommand dispatch.

    Parameters:
        T: A struct conforming to Parsable.

    Returns:
        A tuple of (populated T, raw ParseResult).
    """
    var cmd = to_command[T]()
    var result = cmd.parse()
    var args = _from_result[T](result)
    return Tuple[T, ParseResult](args^, result^)


def from_command[T: Parsable](var cmd: Command) raises -> T:
    """Parse using a pre-configured Command and return a populated T.

    Use when you've customised the Command via ``to_command()`` before parsing.

    Parameters:
        T: A struct conforming to Parsable.

    Args:
        cmd: A Command (typically from ``to_command[T]()``).

    Returns:
        A populated instance of T.
    """
    var result = cmd.parse()
    return _from_result[T](result)


def from_command_split[
    T: Parsable
](var cmd: Command) raises -> Tuple[T, ParseResult]:
    """Parse using a pre-configured Command and return both T and ParseResult.

    Parameters:
        T: A struct conforming to Parsable.

    Args:
        cmd: A Command (typically from ``to_command[T]()``).

    Returns:
        A tuple of (populated T, raw ParseResult).
    """
    var result = cmd.parse()
    var args = _from_result[T](result)
    return Tuple[T, ParseResult](args^, result^)


def from_result[T: Parsable](result: ParseResult) raises -> T:
    """Populate T from an existing ParseResult (no parsing).

    Useful for subcommand dispatch — after the parent parses,
    extract child fields from the subcommand result.

    Parameters:
        T: A struct conforming to Parsable.

    Args:
        result: The ParseResult containing parsed values.

    Returns:
        A populated instance of T.
    """
    return _from_result[T](result)
