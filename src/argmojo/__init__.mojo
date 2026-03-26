"""ArgMojo: A command-line argument parser library for Mojo."""

# Builder API
from .argument import Argument, Arg
from .command import Command
from .parse_result import ParseResult

# Declarative API
from .parsable import Parsable, arg_defaults
from .argument_wrappers import Option, Flag, Positional, Count
from .parser import Parser
