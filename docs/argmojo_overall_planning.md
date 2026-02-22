# ArgMojo — Overall Planning

> A command-line argument parser library for Mojo.

## 1. Why ArgMojo?

I created this project to support my experiments with a CLI-based Chinese character search engine in Mojo, as well as a CLI-based calculator for [DeciMojo](https://github.com/forfudan/decimojo).

At the moment, Mojo does not have a mature command-line argument parsing library. This is a fundamental component for any CLI tool, and building it from scratch will benefit my projects and future projects.

## 2. Cross-Language Research Summary

This section summarises the key design patterns and features from well-known arg parsers across multiple languages. The goal is to extract **universally useful ideas** that are feasible in Mojo 0.26.1, and to exclude features that depend on language-specific capabilities (macros, decorators, reflection, closures-as-first-class) that Mojo does not yet provide.

### 2.1 Libraries Surveyed

| Library               | Language     | Style                  | Key Insight for ArgMojo                                                                                                                                                                                                  |
| --------------------- | ------------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **argparse** (stdlib) | Python       | Builder (add_argument) | Comprehensive feature set; nargs, choices, type conversion, subcommands, argument groups, mutually exclusive groups, metavar, suggest_on_error, BooleanOptionalAction                                                    |
| **Click**             | Python       | Decorator-based        | Composable commands, lazy-loaded subcommands, context passing — decorator approach not applicable                                                                                                                        |
| **cobra** + pflag     | Go           | Struct-based builder   | Subcommands with persistent/local flags, flag groups (mutually exclusive, required together, one required), command aliases, Levenshtein-distance suggestions, positional arg validators (ExactArgs, MinimumNArgs, etc.) |
| **clap**              | Rust         | Builder + Derive       | Builder API is the reference model; Derive API uses macros (not available in Mojo)                                                                                                                                       |
| **docopt**            | Python/multi | Usage-string-driven    | Generates parser from help text — elegant but too implicit for a typed language                                                                                                                                          |

### 2.2 Universal Features Worth Adopting

These features appear across 3+ libraries and depend only on string operations and basic data structures:

| Feature                          | argparse | cobra | clap | Priority |
| -------------------------------- | -------- | ----- | ---- | -------- |
| Long/short options with values   | ✓        | ✓     | ✓    | **Done** |
| Positional arguments             | ✓        | ✓     | ✓    | **Done** |
| Boolean flags                    | ✓        | ✓     | ✓    | **Done** |
| Default values                   | ✓        | ✓     | ✓    | **Done** |
| Required argument validation     | ✓        | ✓     | ✓    | **Done** |
| `--` stop marker                 | ✓        | ✓     | ✓    | **Done** |
| Auto `--help` / `-h`             | ✓        | ✓     | ✓    | **Done** |
| Auto `--version` / `-V`          | ✓        | ✓     | ✓    | **Done** |
| Short flag merging (`-abc`)      | ✓        | ✓     | ✓    | **Done** |
| Metavar (display name for value) | ✓        | —     | ✓    | **Done** |
| Positional arg count validation  | —        | ✓     | ✓    | **Done** |
| Choices / enum validation        | ✓        | —     | ✓    | **Done** |
| Mutually exclusive flags         | ✓        | ✓     | ✓    | **Done** |
| Flags required together          | —        | ✓     | —    | **Done** |
| `--no-X` negation flags          | ✓ (3.9)  | —     | ✓    | **Done** |
| Long option prefix matching      | ✓        | —     | —    | Phase 3  |
| Append / collect action          | ✓        | ✓     | ✓    | Phase 3  |
| One-required group               | —        | ✓     | ✓    | Phase 3  |
| Subcommands                      | ✓        | ✓     | ✓    | Phase 4  |
| Suggest on typo (Levenshtein)    | ✓ (3.14) | ✓     | ✓    | Phase 5  |

### 2.3 Features Excluded (Infeasible or Inappropriate)

| Feature                                       | Reason for Exclusion                                      |
| --------------------------------------------- | --------------------------------------------------------- |
| Derive / decorator API                        | Mojo has no macros or decorators                          |
| Shell auto-completion generation              | Requires writing shell scripts; out of scope              |
| Usage-string-driven parsing (docopt style)    | Too implicit; not a good fit for a typed systems language |
| Type-conversion callbacks                     | Use `get_int()` / `get_string()` pattern instead          |
| Config file reading (`fromfile_prefix_chars`) | Out of scope; users can pre-process argv                  |
| Environment variable fallback                 | Can be done externally; not core parser responsibility    |
| Template-customisable help (Go cobra style)   | Mojo has no template engine; help format is hardcoded     |

## 3. Technical Foundations

### 3.1 `sys.argv()` ✓ Available

Mojo provides `sys.argv()` to access command-line arguments:

```mojo
from sys import argv

fn main():
    var args = argv()
    for i in range(len(args)):
        print("arg[", i, "] =", args[i])
```

This gives us the raw list of argument strings, and the remaining task is to implement the parsing logic.

### 3.2 Mojo's string operations ✓ Sufficient

| Operation      | Mojo Support           | Usage               |
| -------------- | ---------------------- | ------------------- |
| Prefix check   | `str.startswith("--")` | Detect option type  |
| String compare | `str == "value"`       | Match names         |
| Substring      | Slicing / `find`       | Split `key=value`   |
| Split          | `str.split("=")`       | Parse equals syntax |
| Concatenation  | `str + str`            | Build help text     |

### 3.3 Mojo's data structures ✓ Sufficient

| Structure                     | Purpose                               |
| ----------------------------- | ------------------------------------- |
| `List[String]`                | Store argument list, positional names |
| `Dict[String, Bool]`          | Flag values                           |
| `Dict[String, String]`        | Named values                          |
| `struct` with builder pattern | Arg, Command, ParseResult types       |

## 4. Current Implementation Status

### 4.1 Repository Structure

```txt
src/argmojo/
├── __init__.mojo        # Package exports (Arg, Command, ParseResult)
├── arg.mojo             # Arg struct — argument definition with builder pattern
├── command.mojo         # Command struct — command definition & parsing
└── result.mojo          # ParseResult struct — parsed values
tests/
└── test_argmojo.mojo    # Unit tests for ArgMojo, ensure robustness
examples/
└── demo.mojo            # Demo CLI tool, compilable to binary
```

### 4.2 What's Already Done ✓

| Feature                                                               | Status | Tests |
| --------------------------------------------------------------------- | ------ | ----- |
| `Arg` struct with builder pattern                                     | ✓      | —     |
| `Command` struct with `add_arg()`                                     | ✓      | —     |
| `ParseResult` with `get_flag()`, `get_string()`, `get_int()`, `has()` | ✓      | ✓     |
| Long flags `--verbose`                                                | ✓      | ✓     |
| Short flags `-v`                                                      | ✓      | ✓     |
| Key-value `--key value`, `--key=value`, `-k value`                    | ✓      | ✓     |
| Positional arguments                                                  | ✓      | ✓     |
| Default values for positional and named args                          | ✓      | ✓     |
| Required argument validation                                          | ✓      | —     |
| `--` stop marker                                                      | ✓      | ✓     |
| Auto `--help` / `-h` with generated help text                         | ✓      | —     |
| Auto `--version` / `-V`                                               | ✓      | —     |
| Demo binary (`mojo build`)                                            | ✓      | —     |
| Short flag merging (`-abc` → `-a -b -c`)                              | ✓      | ✓     |
| Short option with attached value (`-ofile.txt`)                       | ✓      | ✓     |
| Choices validation (`.choices()`)                                     | ✓      | ✓     |
| Metavar (`.metavar("FILE")`)                                          | ✓      | ✓     |
| Hidden arguments (`.hidden()`)                                        | ✓      | ✓     |
| Count action (`-vvv` → 3)                                             | ✓      | ✓     |
| Positional arg count validation                                       | ✓      | ✓     |
| Clean exit for `--help` / `--version`                                 | ✓      | —     |
| Mutually exclusive groups                                             | ✓      | ✓     |
| Required-together groups                                              | ✓      | ✓     |
| Negatable flags (`.negatable()` → `--no-X`)                           | ✓      | ✓     |

### 4.3 API Design (Current)

```mojo
from argmojo import Command, Arg

fn main() raises:
    var cmd = Command("demo", "A CJK-aware text search tool which supports pinyin and Yuhao IME")

    # Positional arguments
    cmd.add_arg(Arg("pattern", help="Search pattern").required().positional())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    # Optional arguments
    cmd.add_arg(Arg("ling", help="Use Yuho Lingming encoding").long("ling").short("l").flag())
    cmd.add_arg(Arg("ignore-case", help="Case insensitive search").long("ignore-case").short("i").flag())
    cmd.add_arg(Arg("max-depth", help="Maximum directory depth").long("max-depth").short("d").takes_value())

    var result = cmd.parse()

    var pattern = result.get_string("pattern")
    var use_ling = result.get_flag("ling")
    var max_depth = result.get_int("max-depth")
```

### 4.4 Command-line syntax supported

```bash
# Long options
--flag              # Boolean flag
--key value         # Key-value (space separated)
--key=value         # Key-value (equals separated)

# Short options
-f                  # Boolean flag
-k value            # Key-value
-abc                # Merged short flags → -a -b -c
-ofile.txt          # Attached short value → -o file.txt
-abofile.txt        # Mixed: -a -b -o file.txt
-vvv                # Count flag → verbose = 3

# Positional arguments
pattern             # By order of add_arg() calls

# Special
--                  # Stop parsing options; rest becomes positional
--help / -h         # Show auto-generated help
--version / -V      # Show version
```

## 5. Development Roadmap

### Phase 1: Skeleton

- [x] Establish module structure
- [x] Implement `Arg` struct and builder methods
- [x] Implement basic `Command` struct
- [x] Iimplement a small demo CLI tool to test the library

### Phase 2: Parsing Enhancements ✓

- [x] **Short flag merging** — `-abc` expands to `-a -b -c` (argparse, cobra, clap all support this)
- [x] **Short option with attached value** — `-ofile.txt` means `-o file.txt` (argparse, clap)
- [x] **Choices validation** — restrict values to a set: `.choices(["debug", "info", "warn", "error"])`
- [x] **Metavar** — display name for values in help: `.metavar("FILE")` → `--output FILE`
- [x] **Positional arg count validation** — fail if too many positional args
- [x] **Hidden arguments** — `.hidden()` to exclude from help output (cobra, clap)
- [x] **`count` action** — `-vvv` → `get_count("verbose") == 3` (argparse `-v` counting)
- [x] **Clean exit for --help/--version** — use `sys.exit(0)` instead of `raise Error`

### Phase 3: Relationships & Validation (for v0.1)

- [x] **Mutually exclusive flags** — `cmd.mutually_exclusive(["json", "yaml", "toml"])`
- [x] **Flags required together** — `cmd.required_together(["username", "password"])`
- [x] **`--no-X` negation** — `--color` / `--no-color` paired flags (argparse BooleanOptionalAction)
- [ ] **Long option prefix matching** — `--verb` auto-resolves to `--verbose` when unambiguous (argparse `allow_abbrev`)
- [ ] **Append / collect action** — `--tag x --tag y` → `["x", "y"]` collects repeated options into a list (argparse `append`, cobra `StringArrayVar`, clap `Append`)
- [ ] **One-required group** — `cmd.one_required(["json", "yaml"])` requires at least one from the group (cobra `MarkFlagsOneRequired`, clap `ArgGroup::required`)
- [ ] **Aliases** for long names — `.aliases(["colour"])` for `--color`
- [ ] **Deprecated arguments** — `.deprecated("Use --format instead")` prints warning (argparse 3.13)

### Phase 4: Subcommands (maybe for v0.2)

- [ ] **Subcommand support** — `app <subcommand> [args]` (cobra, argparse, clap)
- [ ] **Subcommand help** — `app help <subcommand>` or `app <subcommand> --help`
- [ ] **Global vs local flags** — flags that persist through to subcommands (cobra persistent flags)

### Phase 5: Polish (nice-to-have features, may not be implemented soon)

- [ ] **Typo suggestions** — "Unknown option '--vrb', did you mean '--verbose'?" (Levenshtein distance; cobra, argparse 3.14)
- [ ] **Colored error output** — using mist library for ANSI styled errors/help
- [ ] **Argument groups in help** — group related options under headings (argparse add_argument_group)
- [ ] **Usage line customisation** — override the auto-generated usage string

### Explicitly Out of Scope

These will **NOT** be implemented:

- Derive/decorator-based API (no macros in Mojo)
- Shell completion script generation
- Usage-string-driven parsing (docopt style)
- Config file parsing (users can pre-process argv)
- Environment variable fallback
- Template-based help formatting

## 6. Parsing Algorithm

```txt
Input: ["demo", "yuhao", "./src", "--ling", "-i", "--max-depth", "3"]

1. Skip argv[0] (program name)
2. Initialize cursor i = 1
3. Loop:
   ├─ If args[i] == "--":
   │     Everything after is treated as positional arguments, break
   ├─ If args[i] == "--help" or "-h":
   │     Print help and exit
   ├─ If args[i] == "--version" or "-V":
   │     Print version and exit
   ├─ If args[i].startswith("--"):
   │     Parse long option
   │     ├─ If contains "=": split into key=value
   │     ├─ If flag: set to True
   │     └─ Otherwise: take args[i+1] as value, i += 1
   ├─ If args[i].startswith("-") and len > 1:
   │     Parse short option
   │     ├─ If single char and is flag: set flag
   │     ├─ If single char and takes value: take args[i+1]
   │     └─ If multiple chars: expand as merged flags  [Phase 2]
   └─ Otherwise:
         Treat as positional argument
4. Apply defaults for missing arguments
5. Validate: check required arguments, choices, positional count
6. Return ParseResult
```

## 8. Mojo 0.26.1 Notes

Here are some important Mojo-specific patterns used throughout this project. Mojo is rapidly evolving, so these may need to be updated in the future:

| Pattern                | What & Why                                          |
| ---------------------- | --------------------------------------------------- |
| `"""Tests..."""`       | Docstring convention                                |
| `@fieldwise_init`      | Replaces `@value`                                   |
| `var self`             | Used for builder methods instead of `owned self`    |
| `String()`             | Explicit conversion; `str()` is not available       |
| `[a, b, c]` for `List` | List literal syntax instead of variadic constructor |
| `.copy()`              | Explicit copy for non-ImplicitlyCopyable types      |
| `Movable` conformance  | Required for structs stored in containers           |
