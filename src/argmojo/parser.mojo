"""Declarative orchestrator that bridges wrapper structs to the builder API.

``Parser[T]`` inspects a ``Parsable`` struct via compile-time
reflection, translates wrapper parameters to ``Command``/``Argument``
builder calls, and populates the struct from ``ParseResult``.

This file is a skeleton — the reflection-based ``_build()`` and
``_from_result()`` methods will be implemented in Phase 1 (continued)
and Phase 2.
"""

from .command import Command
from .parsable import Parsable
from .parse_result import ParseResult


struct Parser[T: Parsable](Movable):
    """Orchestrates declarative CLI parsing for a ``Parsable`` struct.

    Parameters:
        T: A struct conforming to ``Parsable`` whose fields define the CLI schema.

    Examples:

    ```sh
    from argmojo.parser import Parser

    var args = Parser[Grep]().parse()
    print(args.pattern.value)
    ```
    """

    var _command: Command
    """The underlying builder Command, constructed from T's metadata."""

    var _built: Bool
    """Whether _build() has been called."""

    fn __init__(out self):
        """Create a Parser and prepare the underlying Command."""
        self._command = Command(
            String(Self.T.name()), String(Self.T.description())
        )
        self._built = False

    fn __init__(out self, *, deinit take: Self):
        """Move from an existing instance.

        Args:
            take: The Parser to move from.
        """
        self._command = take._command^
        self._built = take._built

    def _build(mut self) raises:
        """Reflect over T's fields and translate to builder calls.

        TODO: Phase 1 implementation — iterate struct_field_names/types,
        match wrapper types, and call add_argument() with the correct
        builder chain for each field.
        """
        if self._built:
            return
        self._built = True
        # Placeholder — will be filled with comptime reflection logic.

    def _from_result(self, result: ParseResult) raises -> Self.T:
        """Populate a T instance from ParseResult.

        TODO: Phase 1 implementation — iterate fields, dispatch on
        wrapper type, and write back typed values.

        Returns:
            A populated instance of T.
        """
        # Placeholder — returns default-initialised T for now.
        return Self.T()

    def to_command(mut self) raises -> ref[self._command] Command:
        """Return a mutable reference to the underlying Command.

        Call this before ``parse()`` to apply builder-level
        customisations (groups, implications, colours, tips, etc.).

        Returns:
            A mutable reference to the underlying Command.

        Examples:

        ```sh
        var parser = Parser[MyArgs]()
        var cmd = parser.to_command()
        cmd.mutually_exclusive(["json", "yaml"])
        var args = parser.parse()
        ```
        """
        self._build()
        return self._command

    def parse(mut self) raises -> Self.T:
        """Build, parse argv, and return a fully populated T.

        This is the primary entry point for pure-declarative usage.

        Returns:
            A populated instance of T.
        """
        self._build()
        var result = self._command.parse()
        return self._from_result(result)

    # NOTE: parse_split is disabled for now — Mojo 0.26.2 cannot construct
    # a Tuple[Self.T, ParseResult] return type when T is trait-constrained.
    # Uncomment once Mojo supports this.
    #
    # def parse_split(mut self) raises -> (Self.T, ParseResult):
    #     """Build, parse argv, and return both T and the raw ParseResult.
    #
    #     Use this when you've added extra arguments via ``to_command()``
    #     that aren't part of T — the typed struct covers declarative
    #     fields, the ParseResult covers everything.
    #
    #     Returns:
    #         A tuple of (populated T, raw ParseResult).
    #     """
    #     self._build()
    #     var result = self._command.parse()
    #     var args = self._from_result(result)
    #     return (args^, result^)
