# ArgMojo

A command-line argument parser library for [Mojo](https://www.modular.com/mojo).

> **A**rguments  
> **R**esolved and  
> **G**rouped into  
> **M**eaningful  
> **O**ptions and  
> **J**oined  
> **O**bjects

## Overview

ArgMojo provides a builder-pattern API for defining and parsing command-line arguments in Mojo. It currently supports:

- **Long options**: `--verbose`, `--output file.txt`, `--output=file.txt`
- **Short options**: `-v`, `-o file.txt`
- **Boolean flags**: options that take no value
- **Positional arguments**: matched by position
- **Default values**: fallback when an argument is not provided
- **Required arguments**: validation that mandatory args are present
- **Auto-generated help**: `--help` / `-h` / `-?` with dynamic column alignment, pixi-style ANSI colours, and customisable header/arg colours
- **Help on no args**: optionally show help when invoked with no arguments
- **Version display**: `--version` / `-V` (also auto-generated)
- **`--` stop marker**: everything after `--` is treated as positional
- **Short flag merging**: `-abc` expands to `-a -b -c`
- **Attached short values**: `-ofile.txt` means `-o file.txt`
- **Choices validation**: restrict values to a set (e.g., `json`, `csv`, `table`)
- **Metavar**: custom display name for values in help text
- **Hidden arguments**: exclude internal args from `--help` output
- **Count flags**: `-vvv` → `get_count("verbose") == 3`
- **Positional arg count validation**: reject extra positional args
- **Negatable flags**: `--color` / `--no-color` paired flags with `.negatable()`
- **Mutually exclusive groups**: prevent conflicting flags (e.g., `--json` vs `--yaml`)
- **Required-together groups**: enforce that related flags are provided together (e.g., `--username` + `--password`)
- **Long option prefix matching**: allow abbreviated options (e.g., `--verb` → `--verbose`). If the prefix is ambiguous (e.g., `--ver` could match both `--verbose` and `--version-info`), an error is raised.
- **Append / collect action**: `--tag x --tag y` collects repeated options into a list with `.append()`
- **One-required groups**: require at least one argument from a group (e.g., must provide `--json` or `--yaml`)
- **Value delimiter**: `--env dev,staging,prod` splits by delimiter into a list with `.delimiter(",")`
- **Multi-value options (nargs)**: `--point 10 20` consumes N consecutive values with `.nargs(N)`

---

I created this project to support my experiments with a CLI-based Chinese character search engine in Mojo, as well as a CLI-based calculator for [DeciMojo](https://github.com/forfudan/decimojo). It is inspired by Python's `argparse`, Rust's `clap`, Go's `cobra`, and other popular argument parsing libraries, but designed to fit Mojo's unique features and constraints.

My goal is to provide a Mojo-idiomatic argument parsing library that can be easily adopted by the growing Mojo community for their CLI applications. **Before Mojo v1.0** (which means it gets stable), my focus is on building core features and ensuring correctness. "Core features" refer to those who appear in `argparse`/`clap`/`cobra` and are commonly used in CLI apps. "Correctness" means that the library should handle edge cases properly, provide clear error messages, and have good test coverage. Some fancy features will depend on my time and interest.

## Installation

ArgMojo requires Mojo == 0.26.1 and uses [pixi](https://pixi.sh) for environment management.

```bash
git clone https://github.com/forfudan/argmojo.git
cd argmojo
pixi install
```

I make the Mojo version strictly 0.26.1 because that's the version I developed and tested on, and Mojo is rapidly evolving. Based on my experience, the library will not work every time there's a new Mojo release.

## Quick Start

Here is a simple example of how to use ArgMojo in a Mojo program. The full example can be found in `examples/demo.mojo`.

```mojo
from argmojo import Arg, Command


fn main() raises:
    var cmd = Command("demo", "A CJK-aware text search tool that supports Pinyin and Yuhao Input Methods (宇浩系列輸入法).", version="0.1.0")

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

    # Negatable flag — --color enables, --no-color disables
    cmd.add_arg(
        Arg("color", help="Enable colored output")
        .long("color").flag().negatable()
    )

    # Multi-value option — consumes exactly 2 values per occurrence
    cmd.add_arg(
        Arg("point", help="X Y coordinate")
        .long("point").short("P").nargs(2).metavar("N")
    )

    # Parse and use
    var result = cmd.parse()
    print("pattern:", result.get_string("pattern"))
    print("verbose:", result.get_count("verbose"))
    print("format: ", result.get_string("format"))
    print("color:  ", result.get_flag("color"))
```

## Usage Examples

For detailed explanations and more examples of every feature, see the **[User Manual](docs/user_manual.md)**.

Build the demo binary first, then try the examples below:

```bash
pixi run build_demo
```

### Basic usage — positional args and flags

```bash
./demo "nihao" ./src --ling --json
```

### Short options and default values

The second positional arg (`path`) defaults to `"."` when omitted:

```bash
./demo "zhongguo" -l --json
```

### Help and version

```bash
./demo --help
./demo -h
./demo '-?'      # -? needs quoting because ? is a shell glob wildcard
./demo --version
```

### Merged short flags

Multiple short flags can be combined in a single `-` token. For example, `-liv` is equivalent to `-l -i -v`:

```bash
./demo "pattern" ./src -liv --json
```

### Attached short values

A short option can receive its value without a space:

```bash
./demo "pattern" --json -d3          # same as -d 3
./demo "pattern" --json -ftable      # same as -f table
```

### Count flags — verbosity

Use `-v` multiple times (merged or repeated) to increase verbosity:

```bash
./demo "pattern" --json -v           # verbose = 1
./demo "pattern" --json -vvv         # verbose = 3
./demo "pattern" --json -v --verbose # verbose = 2  (short + long)
```

### Choices validation

The `--format` option only accepts `json`, `csv`, or `table`:

```bash
./demo "pattern" --json --format json     # OK
./demo "pattern" --json --format xml      # Error: Invalid value 'xml' for argument 'format' (choose from 'json', 'csv', 'table')
```

### Negatable flags

A negatable flag pairs `--X` (sets `True`) with `--no-X` (sets `False`) automatically:

```bash
./demo "pattern" --json --color           # color = True
./demo "pattern" --json --no-color        # color = False
./demo "pattern" --json                   # color = False (default)
```

### Mutually exclusive groups

`--json` and `--yaml` are mutually exclusive — using both is an error:

```bash
./demo "pattern" --json            # OK
./demo "pattern" --yaml            # OK
./demo "pattern" --json --yaml     # Error: Arguments are mutually exclusive: '--json', '--yaml'
```

### `--` stop marker

Everything after `--` is treated as a positional argument, even if it starts with `-`:

```bash
./demo --json --ling -- "--pattern-with-dashes" ./src
```

### Hidden arguments

Some arguments are excluded from `--help` but still work at the command line (useful for debug flags):

```bash
./demo "pattern" --json --debug-index   # Works, but not shown in --help
```

### Required-together groups

`--username` and `--password` must be provided together — using one without the other is an error:

```bash
./demo "pattern" --json --username admin --password secret  # OK
./demo "pattern" --json                                     # OK (neither auth arg is provided)
./demo "pattern" --json --username admin                    # Error: '--password' required when '--username' is provided
```

### Append / collect action

`--tag` can be repeated; values are collected into a list:

```bash
./demo "pattern" --json --tag foo --tag bar -tbaz
# tags = ["foo", "bar", "baz"]
```

### One-required groups

`--json` and `--yaml` form a one-required group — at least one must be provided:

```bash
./demo "pattern" --json            # OK
./demo "pattern" --yaml            # OK
./demo "pattern"                   # Error: At least one of the following arguments is required: '--json', '--yaml'
```

Combined with the mutually exclusive group, this enforces **exactly one** output format.

### Value delimiter

`--env` accepts comma-separated values that are split into a list:

```bash
./demo "pattern" --json --env dev,staging,prod
# envs = ["dev", "staging", "prod"]

./demo "pattern" --json --env dev,staging --env prod
# envs = ["dev", "staging", "prod"]   (values accumulate)
```

### Multi-value options (nargs)

`--point` consumes exactly 2 values per occurrence. Repeating it collects multiple pairs:

```bash
./demo "pattern" --json --point 10 20
# points = [10, 20]

./demo "pattern" --json --point 10 20 --point 30 40
# points = [10, 20, 30, 40]

./demo "pattern" --json -P 5 6
# points = [5, 6]    (short option works too)
```

### A mock example showing how features work together

```bash
./demo yes ./src --verbo --json -t ime --color -li -d 3 --no-color --usern zhu -t search --pas 12345 -t cn --env dev,prod --point 10 20 --formatting csv
```

This will be parsed as:

```bash
Warning: '--formatting' is deprecated: Use --format instead
=== Parsed Arguments ===
  pattern: yes
  path: ./src
  -l, --ling            True
  -i, --ignore-case     True
  -v, --verbose         1
  -d, --max-depth       3
  -f, --format          table
  --color               False
  --json                True
  --yaml                False
  --xml                 False
  -t, --tag             [ime, search, cn]
  -e, --env             [dev, prod]
  -P, --point           [10, 20]
  -u, --username        zhu
  -p, --password        12345
  -S, --save            False
  -O, --output          (not set)
  --port                (not set)
  -D, --define          {}
  --colour              auto
  --formatting          csv
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
│   ├── user_manual.md              # User manual with detailed examples
│   └── argmojo_overall_planning.md
├── src/
│   └── argmojo/                    # Main package
│       ├── __init__.mojo           # Package exports
│       ├── arg.mojo                # Arg struct (argument definition)
│       ├── command.mojo            # Command struct (parsing logic)
│       └── result.mojo             # ParseResult struct (parsed values)
├── tests/
│   └── test_argmojo.mojo           # Tests
├── pixi.toml                       # pixi configuration
├── .gitignore
├── LICENSE
└── README.md
```

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
