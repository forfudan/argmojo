"""Prelude module for ArgMojo.

Usage:

```mojo
from argmojo.prelude import *
```

This imports all public types and traits from ArgMojo for convenience.
"""

# Builder API
from .argument import Argument
from .command import Command
from .parse_result import ParseResult

# Declarative API
from .parsable import Parsable
from .argument_wrappers import ArgumentLike, Option, Flag, Positional, Count
