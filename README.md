# ArgMojo

A command-line argument parser library for [Mojo](https://www.modular.com/mojo).

## Overview

ArgMojo provides a builder-pattern API for defining and parsing command-line arguments in Mojo. It supports:

- **Long options**: `--verbose`, `--output file.txt`, `--output=file.txt`
- **Short options**: `-v`, `-o file.txt`
- **Boolean flags**: options that take no value
- **Positional arguments**: matched by position
- **Default values**: fallback when an argument is not provided
- **Required arguments**: validation that mandatory args are present
- **Auto-generated help**: `--help` / `-h` (no need to implement manually)
- **Version display**: `--version` / `-V` (also auto-generated)
- **`--` stop marker**: everything after `--` is treated as positional

---

I created this project to support my experiments with a CLI-based Chinese character search engine in Mojo, as well as a CLI-based calculator for [DeciMojo](https://github.com/forfudan/decimojo). It is inspired by Python's `argparse`, Rust's `clap`, Go's `cobra`, and other popular argument parsing libraries, but designed to fit Mojo's unique features and constraints.

## Installation

ArgMojo requires Mojo >= 0.26.1 and uses [pixi](https://pixi.sh) for environment management.

```bash
git clone https://github.com/forfudan/argmojo.git
cd argmojo
pixi install
```

## Quick Start

```mojo
from argmojo import Arg, Command


fn main() raises:
    var cmd = Command("demo", "A CJK-aware text search tool supporting both Pinyin and Yuhao IME", version="0.1.0")

    # Positional arguments
    # demo "hello" ./src
    cmd.add_arg(
        Arg("pattern", help="Search pattern").positional().required()
    )  
    cmd.add_arg(
        Arg("path", help="Search path").positional().default(".")
    )

    # Options
    cmd.add_arg(
        Arg("ling", help="Use Lingming IME for encoding")
        .long("ling")
        .short("l")
        .flag()
    )
    cmd.add_arg(
        Arg("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
    )
    
    # Parse real argv
    var result = cmd.parse()

    # Print what we got
    print("=== Parsed Arguments ===")
    print("  pattern:     ", result.get_string("pattern"))
    print("  path:        ", result.get_string("path"))
    print("  --ling:      ", result.get_flag("ling"))
    if result.has("max-depth"):
        print("  --max-depth: ", result.get_string("max-depth"))
    else:
        print("  --max-depth:  (not set)")
```

```bash
$ mojo run main.mojo data.csv --verbose -o result.txt
Input: data.csv
Output: result.txt
```

## Development

```bash
# Format code
pixi run format

# Build package
pixi run package

# Run tests
pixi run test

# Clean build artifacts
pixi run clean
```

## Project Structure

```txt
argmojo/
├── docs/                           # Documentation
│   └── argmojo_overall_planning.md
├── src/
│   └── argmojo/                    # Main package
│       ├── __init__.mojo           # Package exports
│       ├── arg.mojo                # Arg struct (argument definition)
│       ├── command.mojo            # Command struct (parsing logic)
│       └── result.mojo             # ParseResult struct (parsed values)
├── tests/
│   └── test_argmojo.mojo          # Tests
├── pixi.toml                       # pixi configuration
├── .gitignore
├── LICENSE
└── README.md
```

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
