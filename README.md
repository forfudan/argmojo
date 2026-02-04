# ArgMojo

A command-line argument parser library for [Mojo](https://www.modular.com/mojo), inspired by Rust's [clap](https://github.com/clap-rs/clap).

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

I created this project to support my experiments with a CLI-based Chinese character search engine in Mojo, as well as a CLI-based calculator for [DeciMojo](https://github.com/forfudan/decimojo).

## Installation

ArgMojo requires Mojo >= 0.26.1 and uses [pixi](https://pixi.sh) for environment management.

```bash
git clone https://github.com/forfudan/argmojo.git
cd argmojo
pixi install
```

## Quick Start

```mojo
from argmojo import Command, Arg

fn main() raises:
    var cmd = Command("myapp", "A sample application", version="1.0.0")

    # Positional arguments
    cmd.add_arg(
        Arg("input", help="Input file").positional().required()
    )

    # Options
    cmd.add_arg(
        Arg("output", help="Output file")
            .long("output").short("o").default("out.txt")
    )

    # Flags
    cmd.add_arg(
        Arg("verbose", help="Enable verbose output")
            .long("verbose").short("v").flag()
    )

    var result = cmd.parse()

    var input_file = result.get_string("input")
    var output_file = result.get_string("output")
    var verbose = result.get_flag("verbose")

    if verbose:
        print("Input:", input_file)
        print("Output:", output_file)
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
