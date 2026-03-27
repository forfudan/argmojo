"""ArgMojo: A command-line argument parser library for Mojo."""

# Builder API
from .argument import Argument, Arg
from .command import Command
from .parse_result import ParseResult

# Declarative API
from .parsable import (
    Parsable,
    to_command,
    parse,
    parse_args,
    parse_split,
    from_command,
    from_command_split,
    from_result,
)
from .argument_wrappers import Option, Flag, Positional, Count, ArgumentLike
