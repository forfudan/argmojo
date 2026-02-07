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
- **Short flag merging**: `-abc` expands to `-a -b -c`
- **Attached short values**: `-ofile.txt` means `-o file.txt`
- **Choices validation**: restrict values to a set (e.g., `json`, `csv`, `table`)
- **Metavar**: custom display name for values in help text
- **Hidden arguments**: exclude internal args from `--help` output
- **Count flags**: `-vvv` → `get_count("verbose") == 3`
- **Positional arg count validation**: reject extra positional args
- **Mutually exclusive groups**: prevent conflicting flags (e.g., `--json` vs `--yaml`)

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

Here is a simple example of how to use ArgMojo in a Mojo program. The full example can be found in `examples/demo.mojo`.

```mojo
from argmojo import Arg, Command


fn main() raises:
    var cmd = Command("sou", "A CJK-aware text search tool", version="0.1.0")

    # Positional arguments
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    # Boolean flags
    cmd.add_arg(
        Arg("ling", help="Use Lingming IME for encoding")
        .long("ling").short("l").flag()
    )

    # Count flag (verbosity)
    cmd.add_arg(
        Arg("verbose", help="Increase verbosity (-v, -vv, -vvv)")
        .long("verbose").short("v").count()
    )

    # Key-value option with choices and metavar
    var formats: List[String] = ["json", "csv", "table"]
    cmd.add_arg(
        Arg("format", help="Output format")
        .long("format").short("f").choices(formats^).default("table")
    )

    # Mutually exclusive flags
    cmd.add_arg(Arg("color", help="Force colored output").long("color").flag())
    cmd.add_arg(Arg("no-color", help="Disable colored output").long("no-color").flag())
    var excl: List[String] = ["color", "no-color"]
    cmd.mutually_exclusive(excl^)

    # Parse and use
    var result = cmd.parse()
    print("pattern:", result.get_string("pattern"))
    print("verbose:", result.get_count("verbose"))
    print("format: ", result.get_string("format"))
```

## Usage Examples

Build the demo binary first, then try the examples below:

```bash
pixi run build_demo
```

### Basic usage — positional args and flags

```bash
./demo "nihao" ./src --ling
```

### Short options and default values

The second positional arg (`path`) defaults to `"."` when omitted:

```bash
./demo "zhongguo" -l
```

### Help and version

```bash
./demo --help
./demo --version
```

### Merged short flags

Multiple short flags can be combined in a single `-` token. For example, `-liv` is equivalent to `-l -i -v`:

```bash
./demo "pattern" ./src -liv
```

### Attached short values

A short option can receive its value without a space:

```bash
./demo "pattern" -d3          # same as -d 3
./demo "pattern" -ftable      # same as -f table
```

### Count flags — verbosity

Use `-v` multiple times (merged or repeated) to increase verbosity:

```bash
./demo "pattern" -v           # verbose = 1
./demo "pattern" -vvv         # verbose = 3
./demo "pattern" -v --verbose # verbose = 2  (short + long)
```

### Choices validation

The `--format` option only accepts `json`, `csv`, or `table`:

```bash
./demo "pattern" --format json     # OK
./demo "pattern" --format xml      # Error: Invalid value 'xml' for 'format'. Valid choices: json, csv, table
```

### Mutually exclusive groups

`--color` and `--no-color` are mutually exclusive — using both is an error:

```bash
./demo "pattern" --color           # OK
./demo "pattern" --no-color        # OK
./demo "pattern" --color --no-color  # Error: Arguments are mutually exclusive: '--color', '--no-color'
```

### `--` stop marker

Everything after `--` is treated as a positional argument, even if it starts with `-`:

```bash
./demo --ling -- "--pattern-with-dashes" ./src
```

### Hidden arguments

Some arguments are excluded from `--help` but still work at the command line (useful for debug flags):

```bash
./demo "pattern" --debug-index   # Works, but not shown in --help
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
