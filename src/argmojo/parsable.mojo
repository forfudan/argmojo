"""Declares the Parsable trait and its reflection-based default methods."""

from std.builtin.constrained import _constrained_field_conforms_to
from std.reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
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

    The default ``__init__`` is provided automatically via reflection,
    and the compiler synthesises the move ``__init__`` from ``Movable``
    conformance, so conforming structs do **not** need to define them.
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

        @staticmethod
        def description() -> String:
            return "My awesome tool."
    ```
    """

    def __init__(out self):
        """Default-initialises all fields via reflection.

        Uses ``__mlir_op.lit.ownership.mark_initialized`` to bypass the
        compiler's definite-assignment check, then placement-news each
        field with ``UnsafePointer.init_pointee_move(type_of(field)())``.
        Otherwise, the user would have to write a custom ``__init__`` that
        manually default-constructs each field.
        """
        # [Mojo Miji]
        # When Mojo compiles this struct, it calculates the full memory layout
        # before compiling the __init__. This means that at this point, the
        # struct's fields are reserved in the memory layout but not yet
        # initialized. We can safely tell the compiler to treat them as
        # initialized so that we can reflect over the fields and initialize them
        # in a loop using unsafe pointer operations.
        __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(self))
        comptime field_count = struct_field_count[Self]()
        comptime field_types = struct_field_types[Self]()
        comptime for i in range(field_count):
            comptime FieldType = field_types[i]
            _constrained_field_conforms_to[
                conforms_to(FieldType, Defaultable & Movable),
                Parent=Self,
                FieldIndex=i,
                ParentConformsTo="Defaultable & Movable",
            ]()
            ref field = trait_downcast[Movable & Defaultable](
                __struct_field_ref(i, self)
            )
            # [Mojo Miji]
            # type_of(field)() calls the default constructor for the field's
            # type, which is an instance of one of the argument wrapper structs.
            UnsafePointer(to=field).init_pointee_move(type_of(field)())

    @staticmethod
    def description() -> String:
        """Returns the command description for --help.

        Returns:
            The description string.
        """
        ...

    @staticmethod
    def version() -> String:
        """Returns the version string for --version.

        Override to change from the default ``"0.1.0"``.

        Returns:
            The version string.
        """
        return String("0.1.0")

    @staticmethod
    def name() -> String:
        """Returns the command name.

        Override to provide a custom command name.
        An empty string (the default) means ``"command"`` is used.

        Returns:
            The command name.
        """
        return String("")

    @staticmethod
    def subcommands() raises -> List[Command]:
        """Returns a list of child subcommands.

        Called automatically by ``to_command()`` to register children.
        Override to declare declarative subcommands:

        ```sh
        @staticmethod
        def subcommands() raises -> List[Command]:
            var subs = List[Command]()
            subs.append(ChildA.to_command())
            subs.append(ChildB.to_command())
            return subs^
        ```

        For builder subcommands or per-child customization, use
        ``to_command()`` in ``main()`` and call ``command.add_subcommand()``
        directly.

        Returns:
            A list of Command instances (empty by default).
        """
        return List[Command]()

    def run(self) raises:
        """Executes this command's logic after parsing.

        Override in leaf commands. The default does nothing.
        """
        pass

    # == Core: one-line parse ==

    @staticmethod
    def parse() raises -> Self:
        """Builds, parses sys.argv(), and returns a populated Self.

        This is the primary entry point for pure-declarative usage.

        Returns:
            A populated instance of Self.
        """
        var command = Self.to_command()
        var result = command.parse()
        return Self.from_parse_result(result)

    @staticmethod
    def parse_arguments(arguments: List[String]) raises -> Self:
        """Builds, parses the given argument list, and returns a populated Self.

        Useful for testing without touching sys.argv().

        Args:
            arguments: The raw argument strings (including program name at index 0).

        Returns:
            A populated instance of Self.
        """
        var command = Self.to_command()
        var result = command.parse_arguments(arguments)
        return Self.from_parse_result(result)

    # == Hybrid: to_command → customise → parse_from_command ==

    @staticmethod
    def to_command() raises -> Command:
        """Reflects over Self's fields, registers them, and returns a configured Command.

        Iterates Self's fields via reflection and registers
        ArgumentLike-conforming ones as Arguments on the Command.
        Automatically calls ``subcommands()`` to register child commands.
        Users can modify the returned Command with builder methods
        before calling ``parse_from_command()`` or ``parse_full_from_command()``.

        Returns:
            A fully configured Command.
        """
        var cmd_name = String(Self.name())
        if not cmd_name:
            cmd_name = String("command")
        var command = Command(
            cmd_name,
            String(Self.description()),
            version=String(Self.version()),
        )

        # Register fields into Command via reflection
        # Each field is expected to be an argument wrapper type
        # (e.g. Option, Flag, Positional, Count) that conforms to ArgumentLike.
        # They will be converted into Argument type and added to the Command.

        # Comptime calculation of field count, types, and names
        var instance = Self()
        comptime field_count = struct_field_count[Self]()
        comptime field_types = struct_field_types[Self]()
        comptime field_names = struct_field_names[Self]()

        # Runtime duplicate detection
        # [Mojo Miji]
        # Cross-field duplicate detection (same name, long flag, or
        # short flag) cannot be checked at compile time because Mojo's
        # parametric StringLiteral[value] type prevents trait-level access
        # to wrapper parameters through erased types. Instead, this is
        # enforced at runtime: Command.add_argument() raises on duplicate
        # name, --long, alias, or -short flags, so duplicates are
        # surfaced the moment to_command() is called.
        # TODO: Revisit when Mojo supports accessing parametric values
        # through trait-erased types.

        # Per-field validations (short flag length, default-in-choices,
        # range consistency) are checked inside each wrapper's
        # add_to_command() method.

        # Register fields
        comptime for field_index in range(field_count):
            comptime field_type = field_types[field_index]
            comptime if conforms_to(field_type, ArgumentLike):
                ref field = __struct_field_ref(field_index, instance)
                comptime field_name = field_names[field_index]
                trait_downcast[ArgumentLike](field).add_to_command(
                    String(field_name), command
                )

        var subs = Self.subcommands()
        while len(subs) > 0:
            command.add_subcommand(subs.pop(0))
        return command^

    @staticmethod
    def parse_from_command(var command: Command) raises -> Self:
        """Parses using a pre-configured Command and returns a populated Self.

        Use after ``to_command()`` + builder customisations.

        Args:
            command: A Command (typically from ``to_command()``).

        Returns:
            A populated instance of Self.
        """
        var result = command.parse()
        return Self.from_parse_result(result)

    # == Dual return ==

    @staticmethod
    def parse_full() raises -> Tuple[Self, ParseResult]:
        """Builds, parses argv, and returns both Self and raw ParseResult.

        Use when you need both typed fields and subcommand dispatch.

        Returns:
            A tuple of (populated Self, raw ParseResult).
        """
        var command = Self.to_command()
        var result = command.parse()
        var arguments = Self.from_parse_result(result)
        return Tuple[Self, ParseResult](arguments^, result^)

    @staticmethod
    def parse_full_from_command(
        var command: Command,
    ) raises -> Tuple[Self, ParseResult]:
        """Parses using a pre-configured Command and returns both Self and ParseResult.

        Essential for subcommand dispatch: the typed Self gives
        root-level flags, ParseResult gives subcommand name + fields.

        Args:
            command: A Command (typically from ``to_command()``).

        Returns:
            A tuple of (populated Self, raw ParseResult).
        """
        var result = command.parse()
        var arguments = Self.from_parse_result(result)
        return Tuple[Self, ParseResult](arguments^, result^)

    # == Subcommand write-back ==

    @staticmethod
    def from_parse_result(result: ParseResult) raises -> Self:
        """Populates Self from an existing ParseResult (no parsing).

        Useful for subcommand dispatch — after the parent parses,
        extract child fields from the subcommand result.

        Args:
            result: The ParseResult containing parsed values.

        Returns:
            A populated instance of Self.
        """
        var out = Self()
        comptime field_count = struct_field_count[Self]()
        comptime field_types = struct_field_types[Self]()
        comptime field_names = struct_field_names[Self]()

        comptime for field_index in range(field_count):
            comptime field_type = field_types[field_index]
            comptime if conforms_to(field_type, ArgumentLike):
                ref field = __struct_field_ref(field_index, out)
                comptime field_name = field_names[field_index]
                trait_downcast[ArgumentLike](field).read_from_result(
                    String(field_name), result
                )

        return out^
