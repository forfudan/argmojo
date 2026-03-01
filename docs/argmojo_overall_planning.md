# ArgMojo — Overall Planning

> A command-line argument parser library for Mojo.

## 1. Why ArgMojo?

I created this project to support my experiments with a CLI-based Chinese character search engine in Mojo, as well as a CLI-based calculator for [Decimo](https://github.com/forfudan/decimo).

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

These features appear across multiple libraries and depend only on string operations and basic data structures.

| Feature                            | argparse | Click | cobra | clap | Other                  | Planned phase |
| ---------------------------------- | -------- | ----- | ----- | ---- | ---------------------- | ------------- |
| Long/short options with values     | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Positional arguments               | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Boolean flags                      | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Default values                     | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Required argument validation       | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| `--` stop marker                   | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Auto `--help` / `-h` / `-?`        | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Auto `--version` / `-V`            | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Short flag merging (`-abc`)        | ✓        | —     | ✓     | ✓    |                        | **Done**      |
| Metavar (display name for value)   | ✓        | —     | —     | ✓    |                        | **Done**      |
| Positional arg count validation    | —        | —     | ✓     | ✓    |                        | **Done**      |
| Choices / enum validation          | ✓        | ✓     | —     | ✓    |                        | **Done**      |
| Mutually exclusive flags           | ✓        | —     | ✓     | ✓    |                        | **Done**      |
| Flags required together            | —        | —     | ✓     | —    |                        | **Done**      |
| `--no-X` negation flags            | ✓ (3.9)  | —     | —     | ✓    |                        | **Done**      |
| Long option prefix matching        | ✓        | —     | —     | —    |                        | **Done**      |
| Append / collect action            | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| One-required group                 | —        | —     | ✓     | ✓    |                        | **Done**      |
| Value delimiter (`--tag a,b,c`)    | —        | —     | ✓     | ✓    |                        | **Done**      |
| Colored help (customisable)        | —        | ✓     | —     | ✓    | pixi                   | **Done**      |
| Colored warning and error messages | -        | ✓     | -     | ✓    |                        | **Done**      |
| nargs (multi-value per option)     | ✓        | ✓     | —     | ✓    |                        | **Done**      |
| Conditional requirement            | —        | —     | ✓     | ✓    |                        | **Done**      |
| Numeric range validation           | —        | —     | —     | —    |                        | **Done**      |
| Key-value map (`-Dkey=val`)        | —        | —     | —     | —    | Java `-D`, Docker `-e` | **Done**      |
| Aliases for long names             | —        | —     | ✓     | ✓    |                        | **Done**      |
| Deprecated arguments               | ✓ (3.13) | —     | ✓     | —    |                        | **Done**      |
| Negative number passthrough        | ✓        | —     | —     | ✓    | Essential for `decimo` | **Done**      |
| Subcommands                        | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| Auto-added `help` subcommand       | —        | —     | ✓     | ✓    | git, cargo, kubectl    | **Done**      |
| Persistent (global) flags          | —        | —     | ✓     | ✓    | git `--no-pager` etc.  | **Done**      |
| Subcommand aliases                 | —        | —     | ✓     | ✓    |                        | Phase 5       |
| Hidden subcommands                 | —        | —     | ✓     | ✓    |                        | Phase 5       |
| `NO_COLOR` env variable            | —        | —     | —     | —    | no-color.org standard  | Phase 5       |
| Response file (`@args.txt`)        | ✓        | —     | —     | —    | javac, MSBuild         | Phase 5       |
| Argument parents (shared args)     | ✓        | —     | —     | —    |                        | Phase 5       |
| Interactive prompting              | —        | ✓     | —     | —    |                        | Phase 5       |
| Password / masked input            | —        | ✓     | —     | —    |                        | Phase 5       |
| Confirmation (`--yes` / `-y`)      | —        | ✓     | —     | —    |                        | Phase 5       |
| Pre/Post run hooks                 | —        | —     | ✓     | —    |                        | Phase 5       |
| REMAINDER nargs                    | ✓        | —     | —     | —    |                        | Phase 5       |
| Partial parsing (known args)       | ✓        | —     | —     | ✓    |                        | Phase 5       |
| Require equals syntax              | —        | —     | —     | ✓    |                        | Phase 5       |
| Default-if-present (const)         | ✓        | —     | —     | ✓    |                        | Phase 5       |
| Suggest on typo (Levenshtein)      | ✓ (3.14) | —     | ✓     | ✓    |                        | **Done**      |
| Mutual implication (`implies`)     | —        | —     | —     | —    | ArgMojo unique feature | Phase 5       |
| Stdin value (`-` convention)       | —        | —     | ✓     | —    | Unix convention        | Phase 5       |
| CJK-aware help formatting          | —        | —     | —     | —    | ArgMojo unique feature | Phase 6       |
| CJK full-to-half-width correction  | —        | —     | —     | —    | ArgMojo unique feature | Phase 6       |
| CJK punctuation detection          | —        | —     | —     | —    | ArgMojo unique feature | Phase 6       |
| Typed retrieval (`get_int()` etc.) | ✓        | ✓     | ✓     | ✓    |                        | **Done**      |
| `Parseable` trait for type params  | —        | —     | —     | ✓    |                        | Phase 7       |
| Derive / struct-based schema       | —        | —     | —     | ✓    | Requires Mojo macros   | Phase unknown |
| Enum → type mapping (real enums)   | —        | —     | —     | ✓    | Requires reflection    | Phase unknown |
| Subcommand variant dispatch        | —        | —     | —     | ✓    | Requires sum types     | Phase unknown |

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
| Path / URL / Duration value types             | Mojo stdlib has no `Path` / `Url` / `Duration` types yet  |

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
| `struct` with builder pattern | Argument, Command, ParseResult types  |

## 4. Current Implementation Status

### 4.1 Repository Structure

```txt
src/argmojo/
├── __init__.mojo               # Package exports (Argument, Command, ParseResult)
├── argument.mojo               # Argument struct — argument definition with builder pattern
├── command.mojo                # Command struct — command definition & parsing
└── parse_result.mojo           # ParseResult struct — parsed values
tests/
├── test_parse.mojo             # Core parsing tests (flags, values, shorts, etc.)
├── test_groups.mojo            # Group constraint tests (exclusive, conditional, etc.)
├── test_collect.mojo           # Collection feature tests (append, delimiter, nargs)
├── test_help.mojo              # Help output tests (formatting, colours, alignment)
├── test_extras.mojo            # Range, map, alias, deprecated tests
├── test_subcommands.mojo       # Subcommand tests (dispatch, help sub, unknown sub, etc.)
├── test_negative_numbers.mojo  # Negative number passthrough tests
└── test_persistent.mojo        # Persistent (global) flag tests
examples/
├── grep.mojo                   # grep-like CLI example (no subcommands)
└── git.mojo                    # git-like CLI example (with subcommands)
```

### 4.2 What's Already Done ✓

| Feature                                                                                            | Status | Tests |
| -------------------------------------------------------------------------------------------------- | ------ | ----- |
| `Argument` struct with builder pattern                                                             | ✓      | —     |
| `Command` struct with `add_argument()`                                                             | ✓      | —     |
| `ParseResult` with `get_flag()`, `get_string()`, `get_int()`, `has()`                              | ✓      | ✓     |
| Long flags `--verbose`                                                                             | ✓      | ✓     |
| Short flags `-v`                                                                                   | ✓      | ✓     |
| Key-value `--key value`, `--key=value`, `-k value`                                                 | ✓      | ✓     |
| Positional arguments                                                                               | ✓      | ✓     |
| Default values for positional and named args                                                       | ✓      | ✓     |
| Required argument validation                                                                       | ✓      | —     |
| `--` stop marker                                                                                   | ✓      | ✓     |
| Auto `--help` / `-h` with generated help text                                                      | ✓      | —     |
| Auto `--version` / `-V`                                                                            | ✓      | —     |
| Demo binary (`mojo build`)                                                                         | ✓      | —     |
| Short flag merging (`-abc` → `-a -b -c`)                                                           | ✓      | ✓     |
| Short option with attached value (`-ofile.txt`)                                                    | ✓      | ✓     |
| Choices validation (`.choices()`)                                                                  | ✓      | ✓     |
| Metavar (`.metavar("FILE")`)                                                                       | ✓      | ✓     |
| Hidden arguments (`.hidden()`)                                                                     | ✓      | ✓     |
| Count action (`-vvv` → 3)                                                                          | ✓      | ✓     |
| Positional arg count validation                                                                    | ✓      | ✓     |
| Clean exit for `--help` / `--version`                                                              | ✓      | —     |
| Mutually exclusive groups                                                                          | ✓      | ✓     |
| Required-together groups                                                                           | ✓      | ✓     |
| Negatable flags (`.negatable()` → `--no-X`)                                                        | ✓      | ✓     |
| Long option prefix matching (`--verb` → `--verbose`)                                               | ✓      | ✓     |
| Append / collect action (`--tag x --tag y` → list)                                                 | ✓      | ✓     |
| One-required groups (`command.one_required(["json", "yaml"])`)                                     | ✓      | ✓     |
| Value delimiter (`.delimiter(",")` → split into list)                                              | ✓      | ✓     |
| Nargs (`.nargs(N)` → consume N values per occurrence)                                              | ✓      | ✓     |
| Conditional requirements (`command.required_if("output", "save")`)                                 | ✓      | ✓     |
| Numeric range validation (`.range(1, 65535)`)                                                      | ✓      | ✓     |
| Key-value map option (`.map_option()` → `Dict[String, String]`)                                    | ✓      | ✓     |
| Aliases (`.aliases(["color"])` for `--colour` / `--color`)                                         | ✓      | ✓     |
| Deprecated arguments (`.deprecated("msg")` → stderr warning)                                       | ✓      | ✓     |
| Negative number passthrough (`-9`, `-3.14`, `-1.5e10` as positionals)                              | ✓      | ✓     |
| Subcommand data model (`add_subcommand()`, dispatch, `help` sub)                                   | ✓      | ✓     |
| Colored warning and error messages (`_warn()`, `_error()`, all errors printed in colour to stderr) | ✓      | ✓     |

### 4.3 API Design (Current)

```mojo
from argmojo import Command, Argument

fn main() raises:
    var command = Command("demo", "A CJK-aware text search tool which supports pinyin and Yuhao IME")

    # Positional arguments
    command.add_argument(Argument("pattern", help="Search pattern").required().positional())
    command.add_argument(Argument("path", help="Search path").positional().default("."))

    # Optional arguments
    command.add_argument(Argument("ling", help="Use Yuhao Lingming encoding").long("ling").short("l").flag())
    command.add_argument(Argument("ignore-case", help="Case insensitive search").long("ignore-case").short("i").flag())
    command.add_argument(Argument("max-depth", help="Maximum directory depth").long("max-depth").short("d").takes_value())

    var result = command.parse()

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
--verb              # Prefix match → --verbose (if unambiguous)

# Short options
-f                  # Boolean flag
-k value            # Key-value
-abc                # Merged short flags → -a -b -c
-ofile.txt          # Attached short value → -o file.txt
-abofile.txt        # Mixed: -a -b -o file.txt
-vvv                # Count flag → verbose = 3

# Positional arguments
pattern             # By order of add_argument() calls

# Special
--                  # Stop parsing options; rest becomes positional
--help / -h         # Show auto-generated help
--version / -V      # Show version
```

### 4.5 Validation & Help Behavior Matrix

Positional arguments and named options are validated **independently** — a command can fail on either or both. The two matrices below show each dimension's behavior separately; the combined scenario table shows practical cross-product outcomes.

#### Per-Dimension Behavior

**Positional arguments:**

| Command config ↓ \ User input → | Enough positionals provided | Not enough positionals provided |
| ------------------------------- | --------------------------- | ------------------------------- |
| **Has required positional(s)**  | ✓ Proceed                   | ✗ Error + usage                 |
| **No required positional(s)**   | ✓ Proceed                   | N/A — always "enough"           |

**Named options:**

| Command config ↓ \ User input → | Enough options provided | Not enough options provided |
| ------------------------------- | ----------------------- | --------------------------- |
| **Has required option(s)**      | ✓ Proceed               | ✗ Error + usage             |
| **No required option(s)**       | ✓ Proceed               | N/A — always "enough"       |

#### Cross-Dimension Matrix (4 × 4)

When rows and columns refer to **different** dimensions (e.g., "has required positionals" × "enough options"), the outcome depends on the *other* dimension — marked ? below.

|                                | Enough pos. args     | Not enough pos. args | Enough options       | Not enough options   |
| ------------------------------ | -------------------- | -------------------- | -------------------- | -------------------- |
| **Has required positional(s)** | ✓ Proceed            | ✗ Error + usage      | ? depends on pos.    | ? depends on pos.    |
| **No required positional(s)**  | ✓ Proceed            | *(N/A)*              | ? always ok for pos. | ? always ok for pos. |
| **Has required option(s)**     | ? depends on opt.    | ? depends on opt.    | ✓ Proceed            | ✗ Error + usage      |
| **No required option(s)**      | ? always ok for opt. | ? always ok for opt. | ✓ Proceed            | *(N/A)*              |

#### Combined Scenario Table

The practical view — both dimensions checked together at parse time:

| Command Profile               | Nothing provided | Pos. ✗ Opt. ✓          | Pos. ✓ Opt. ✗          | All ✓      |
| ----------------------------- | ---------------- | ---------------------- | ---------------------- | ---------- |
| Required pos. + required opt. | ✗ Error + usage  | ✗ Error (missing pos.) | ✗ Error (missing opt.) | ✓ Proceed  |
| Required pos. only            | ✗ Error + usage  | ✗ Error (missing pos.) | ✓ Proceed              | ✓ Proceed  |
| Required opt. only            | ✗ Error + usage  | ✓ Proceed              | ✗ Error (missing opt.) | ✓ Proceed  |
| No requirements               | ✓ Proceed        | ✓ Proceed              | ✓ Proceed              | ✓ Proceed  |
| Has subcommands (group)       | ✓ Proceed *      | —                      | —                      | ✓ Dispatch |

\* Group commands with subcommands typically do nothing useful with no input — `help_on_no_args()` is recommended.

#### Effect of `help_on_no_args()`

| Scenario                          | Default (off)                                                  | With `help_on_no_args()`    |
| --------------------------------- | -------------------------------------------------------------- | --------------------------- |
| Zero args (only program name)     | Validation runs → error if requirements exist; proceed if none | **Show full help** (exit 0) |
| Some args provided (insufficient) | ✗ Error + usage                                                | ✗ Error + usage *(same)*    |
| All requirements satisfied        | ✓ Proceed                                                      | ✓ Proceed *(same)*          |

> **Key:** `help_on_no_args()` only overrides the **zero-argument** case. Once any argument is provided, normal validation takes over regardless.

#### Industry Consensus (clap / cobra / argparse / click / docker / git / kubectl)

1. **Error, not help.** When the user provides a partial or incorrect invocation, the standard is a *short error message* naming the missing argument + a compact *usage line*. Full help is reserved for `--help` or bare group commands. This is the dominant pattern across clap, argparse, click, commander.js, cargo.

2. **No special-casing "zero args" by default.** The vast majority of frameworks do NOT treat "provided nothing" differently from "provided some but not all." clap's `arg_required_else_help(true)` is the only first-class opt-in — ArgMojo's `help_on_no_args()` mirrors this.

3. **Two-tier pattern for subcommands.** Every tool examined follows the same convention:
   - **Group/parent command** with no subcommand given → **show full help** (list available subcommands)
   - **Leaf subcommand** with missing required args → **show error + usage line** (not full help)
   - Rationale: at the group level, the user needs guidance on *what* to do; at the leaf level, they know *what* they want but forgot *how*.

4. **Error batching.** Split across tools — clap and argparse report *all* missing arguments at once; click and commander report the *first* one. ArgMojo currently reports the first missing argument (validation order: required args → positional count → exclusive groups → together groups → one-required → conditional → range).

5. **Exit codes.** POSIX-influenced tools (argparse, clap, click) use exit code **2** for argument parse errors. Go-based tools (cobra, docker, kubectl) use exit code **1**. ArgMojo currently raises an `Error` (caller decides exit code).

6. **Error output format consensus** (clap / argparse / click / cargo):

   ```bash
   error: <command>: <what's wrong>

   Usage: <command> <required> [optional] [OPTIONS]
   For more information, try '<command> --help'.
   ```

   NOT full help with all flags listed (only cobra does that by default, and it provides `SilenceUsage` to opt out).

## 5. Development Roadmap

### Phase 1: Skeleton

- [x] Establish module structure
- [x] Implement `Argument` struct and builder methods
- [x] Implement basic `Command` struct
- [x] Implement a small demo CLI tool to test the library

### Phase 2: Parsing Enhancements ✓

- [x] **Short flag merging** — `-abc` expands to `-a -b -c` (argparse, cobra, clap all support this)
- [x] **Short option with attached value** — `-ofile.txt` means `-o file.txt` (argparse, clap)
- [x] **Choices validation** — restrict values to a set: `.choices(["debug", "info", "warn", "error"])`
- [x] **Metavar** — display name for values in help: `.metavar("FILE")` → `--output FILE`
- [x] **Positional arg count validation** — fail if too many positional args
- [x] **Hidden arguments** — `.hidden()` to exclude from help output (cobra, clap)
- [x] **`count` action** — `-vvv` → `get_count("verbose") == 3` (argparse `-v` counting)
- [x] **Clean exit for --help/--version** — use `sys.exit(0)` instead of `raise Error`

### Phase 3: Relationships & Validation (for v0.2)

- [x] **Mutually exclusive flags** — `command.mutually_exclusive(["json", "yaml", "toml"])`
- [x] **Flags required together** — `command.required_together(["username", "password"])`
- [x] **`--no-X` negation** — `--color` / `--no-color` paired flags (argparse BooleanOptionalAction)
- [x] **Long option prefix matching** — `--verb` auto-resolves to `--verbose` when unambiguous (argparse `allow_abbrev`)
- [x] **Append / collect action** — `--tag x --tag y` → `["x", "y"]` collects repeated options into a list (argparse `append`, cobra `StringArrayVar`, clap `Append`)
- [x] **One-required group** — `command.one_required(["json", "yaml"])` requires at least one from the group (cobra `MarkFlagsOneRequired`, clap `ArgGroup::required`)
- [x] **Value delimiter** — `--tag a,b,c` splits by delimiter into `["a", "b", "c"]` (cobra `StringSliceVar`, clap `value_delimiter`)
- [x] **`-?` help alias** — `-?` accepted as an alias for `-h` / `--help` (common in Windows CLI tools, Java, MySQL, curl)
- [x] **Help on no args** — `command.help_on_no_args()` shows help when invoked with no arguments (like git/docker/cargo)
- [x] **Dynamic help padding** — help column alignment is computed from the longest option line instead of a fixed width
- [x] **colored help output** — ANSI colors (bold+underline headers, colored arg names), with `color=False` opt-out and customisable colors via `header_color()` / `arg_color()`
- [x] **nargs (multi-value)** — `--point 1 2 3` consumes N values for one option (argparse `nargs`, clap `num_args`)
- [x] **Conditional requirement** — `--output` required only when `--save` is present (cobra `MarkFlagRequiredWith`, clap `required_if_eq`)
- [x] **Numeric range validation** — `.range(1, 65535)` validates `--port` value is within range (no major library has this built-in)
- [x] **Key-value map option** — `--define key=value --define k2=v2` → `Dict[String, String]` (Java `-D`, Docker `-e KEY=VAL`)
- [x] **Aliases** for long names — `.aliases(["color"])` for `--colour` / `--color`
- [x] **Deprecated arguments** — `.deprecated("Use --format instead")` prints warning to stderr (argparse 3.13)

### Phase 4: Subcommands (for v0.2 or v0.3 depending on complexity)

Subcommands (`app <subcommand> [args]`) are the first feature that turns ArgMojo from a single-parser into a parser tree. The core insight is that **a subcommand is just another `Command` instance** — it already has `parse_args()`, `_generate_help()`, and all validation logic. No new parser, tokenizer, or separate module files are needed.

#### Architecture: composition inside `Command`

- **No file split.** Core logic stays in `command.mojo`. Mojo has no partial structs, so splitting would force free functions + parameter threading for little gain at ~2250 lines. ANSI colour constants and small utility functions live in `utils.mojo` (internal-only, all symbols `_`-prefixed).
- **No tokenizer.** The single-pass cursor walk (`startswith` checks) is sufficient. Token types are trivially identified inline. The parsing logic in `parse_args()` delegates to four sub-methods (`_parse_long_option`, `_parse_short_single`, `_parse_short_merged`, `_dispatch_subcommand`) for readability, but the overall flow is still a simple cursor walk.
- **Composition-based.** `Command` gains a child command list. When `parse_args()` hits a non-option token matching a registered subcommand, it delegates the remaining argv slice to the child's own `parse_args()`. 100% logic reuse, zero duplication.

#### Pre-requisite refactor (Step 0)

Before adding subcommand routing, clean up `parse_args()` so root and child can each call the same validation/defaults path:

- [x] Extract `_apply_defaults(mut result)` — move the ~20-line defaults block into a private method
- [x] Extract `_validate(result)` — move the ~130-line validation block (required, exclusive, together, one-required, conditional, range) into a private method
- [x] Verify all existing tests still pass after this refactor (143 original + 17 new Step 0 tests = 160 total, all passing)

#### Step 1 — Data model & API surface

- [x] Add `subcommands: List[Command]` field on `Command` (Matryoshka doll :D)
- [x] Add `add_subcommand(mut self, sub: Command)` builder method
- [x] Add `subcommand: String` field on `ParseResult` (name of selected subcommand, empty if none)
- [x] Add `subcommand_result: List[ParseResult]` or similar on `ParseResult` to hold child results

Target API:

```mojo
var app = Command("app", "My CLI tool", version="0.3.0")
app.add_argument(Argument("verbose", help="Verbose output").long("verbose").short("v").flag())

var search = Command("search", "Search for patterns")
search.add_argument(Argument("pattern", help="Search pattern").required().positional())
search.add_argument(Argument("max-depth", help="Max depth").long("max-depth").short("d").takes_value())

var init = Command("init", "Initialize a new project")
init.add_argument(Argument("name", help="Project name").required().positional())

app.add_subcommand(search)
app.add_subcommand(init)

var result = app.parse()
if result.subcommand == "search":
    var sub = result.subcommand_result
    var pattern = sub.get_string("pattern")
```

#### Step 2 — Parse routing (I need to be very careful)

- [x] In `parse_args()`, when the current token is not an option and subcommands are registered, check if it matches a subcommand name
- [x] On match: record `result.subcommand = name`, build child argv (remaining tokens), call `child.parse_args(child_argv)`, store child result
- [x] On no match and subcommands exist: treat as positional (existing behavior)
- [x] `--` before subcommand boundary: all subsequent tokens are positional for root, no subcommand dispatch
- [x] Handle `app help <sub>` as equivalent to `app <sub> --help` via auto-registered `help` subcommand (strategy B); `_is_help_subcommand` flag; `.disable_help_subcommand()` opt-out API

#### Step 3 — Global (persistent) flags

- [x] Add `.persistent()` builder method on `Argument` (sets `is_persistent: Bool`)
- [x] Before child parse, inject copies of parent's persistent args into the child's arg list (or make child parser aware of them)
- [x] Root-level persistent flag values are parsed before dispatch and merged into child result
- [x] Conflict policy: reject duplicate long/short names between parent persistent args and child local args at registration time (`add_subcommand` raises)
- [x] Bidirectional sync: bubble-up (flag after subcommand → root result) + push-down (flag before subcommand → child result)

#### Step 4 — Help & UX

- [x] Root `_generate_help()` appends a "Commands:" section listing subcommand names + descriptions (aligned like options)
- [x] `app <sub> --help` delegates to `sub._generate_help()` directly
- [x] `app help <sub>` routing via auto-registered real subcommand: `add_subcommand()` auto-inserts a `help` Command with `_is_help_subcommand = True`; dispatch path detects the flag and routes to sibling help
- [x] `.disable_help_subcommand()` opt-out API on `Command`
- [x] Child help includes inherited persistent flags under a "Global Options:" heading
- [x] Usage line shows full command path: `app search [OPTIONS] PATTERN`

#### Step 5 — Error handling

- [x] Unknown subcommand: `"Unknown command '<name>'. Available commands: search, init"`
- [x] Errors inside child parse: prefix with command path for clarity (e.g. `"app search: Option '--foo' requires a value"`)
- [x] Exit codes consistent with current behavior (exit 2 for parse errors)
- [x] `allow_positional_with_subcommands()` — guard preventing accidental mixing of positional args and subcommands on the same Command (following cobra/clap convention); requires explicit opt-in

#### Step 6 — Tests

- [x] Create `tests/test_subcommands.mojo` (Step 0 + Step 1)
- [x] Step 1: `Command.subcommands` empty initially
- [x] Step 1: `add_subcommand()` populates list and preserves child args
- [x] Step 1: Multiple subcommands ordered correctly
- [x] Step 1: `ParseResult.subcommand` defaults to `""`
- [x] Step 1: `has_subcommand_result()` / `get_subcommand_result()` lifecycle
- [x] Step 1: `ParseResult.__copyinit__` preserves subcommand data
- [x] Step 1: `parse_args()` unchanged when no subcommands registered
- [x] Step 2: Basic dispatch: `app search pattern` → subcommand="search", positionals=["pattern"]
- [x] Step 2: Root flag: `app --verbose search pattern` → root flag verbose=true, child positional
- [x] Step 2: Child flag: `app search --max-depth 3 pattern` → child value max-depth=3
- [x] Step 2: `--` stops subcommand dispatch: `app -- search` → positional "search" on root
- [x] Step 2: Unknown token with subcommands registered → positional on root
- [x] Step 2: Child validation errors propagate
- [x] Step 2: Root still validates own required args after dispatch
- [x] Step 2b: `help` subcommand auto-added on first `add_subcommand()` call
- [x] Step 2b: Only added once even with multiple `add_subcommand()` calls
- [x] Step 2b: `help` appears after user subcommands in the list
- [x] Step 2b: `_is_help_subcommand` flag set on auto-entry, not on user subs
- [x] Step 2b: `disable_help_subcommand()` before `add_subcommand()` prevents insertion
- [x] Step 2b: `disable_help_subcommand()` after `add_subcommand()` removes it
- [x] Step 2b: Normal dispatch unaffected by the presence of auto-added help sub
- [x] Step 2b: With help disabled, token `"help"` becomes a root positional
- [x] Step 3: Persistent flag on root works without subcommand
- [x] Step 3: Persistent flag before subcommand → in root result; pushed down to child result
- [x] Step 3: Persistent flag after subcommand → in child result; bubbled up to root result
- [x] Step 3: Short-form persistent flag works in both positions
- [x] Step 3: Persistent value-taking option (not just flag) syncs both ways
- [x] Step 3: Absent persistent flag defaults to False in both root and child
- [x] Step 3: Non-persistent root flag after subcommand causes unknown-option error
- [x] Step 3: Conflict detection — long_name clash raises at `add_subcommand()` time
- [x] Step 3: Conflict detection — short_name clash raises at `add_subcommand()` time
- [x] Step 3: No conflict raised for non-persistent args with the same name
- [x] Step 5: Adding positional after subcommand without opt-in raises error
- [x] Step 5: Adding subcommand after positional without opt-in raises error
- [x] Step 5: `allow_positional_with_subcommands()` opt-in enables both directions
- [x] Step 5: Non-positional args (flags/options) unaffected by guard

#### Step 7 — Documentation & examples

- [x] Add `examples/grep.mojo` — grep-like CLI demonstrating all single-command features
- [x] Add `examples/git.mojo` — git-like CLI demonstrating subcommands, nested subcommands, persistent flags, and all group constraints
- [x] Update user manual with subcommand usage patterns
- [x] Document persistent flag behavior and conflict rules

### Phase 5: Polish (nice-to-have features, may not be implemented soon)

#### Pre-requisite refactor

Before adding Phase 5 features, further decompose `parse_args()` for readability and maintainability:

- [x] Extract `_parse_long_option()` — long option parsing (`--key`, `--key=value`, `--no-X` negation, prefix matching, count/flag/nargs/value)
- [x] Extract `_parse_short_single()` — single-character short option parsing (`-k`, `-k value`)
- [x] Extract `_parse_short_merged()` — merged short flags and attached values (`-abc`, `-ofile.txt`)
- [x] Extract `_dispatch_subcommand()` — subcommand matching, child argv construction, persistent arg injection, bidirectional sync
- [x] Verify all 241 tests still pass after this refactor
- [x] Extract `_help_usage_line()` — description + usage line with positionals / COMMAND / OPTIONS
- [x] Extract `_help_positionals_section()` — "Arguments:" section with dynamic padding
- [x] Extract `_help_options_section()` — "Options:" and "Global Options:" sections (local + persistent, built-in --help/--version)
- [x] Extract `_help_commands_section()` — "Commands:" section listing subcommands
- [x] Extract `_help_tips_section()` — "Tips:" section with `--` hint and user-defined tips
- [x] Verify all 241 tests still pass after help refactor
- [x] Extract `utils.mojo` — move ANSI colour constants (`_RESET`, `_BOLD_UL`, `_RED`…`_ORANGE`, default colour aliases) and utility functions (`_looks_like_number`, `_is_ascii_digit`, `_resolve_color`) into a dedicated internal module; `command.mojo` imports them
- [x] Verify all tests still pass after utils extraction

#### Features

- [x] **Typo suggestions** — "Unknown option '--vrb', did you mean '--verbose'?" (Levenshtein distance; cobra, argparse 3.14)
- [ ] **Flag counter with ceiling** — `.count().max(3)` caps `-vvvvv` at 3 (no major library has this)
- [x] **Colored error output** — ANSI styled error messages (help output already colored)
- [ ] **Argument groups in help** — group related options under headings (argparse add_argument_group)
- [ ] **Usage line customisation** — two approaches: (1) manual override via `.usage("...")` for git-style hand-written usage strings (e.g. `[-v | --version] [-h | --help] [-C <path>] ...`); (2) auto-expanded mode that enumerates every flag inline like argparse (good for small CLIs, noisy for large ones). Current default `[OPTIONS]` / `<COMMAND>` is the cobra/clap/click convention and is the right default.
- [ ] **Partial parsing** — parse known args only, return unknown args as-is (argparse `parse_known_args`)
- [ ] **Require equals syntax** — force `--key=value`, disallow `--key value` (clap `require_equals`)
- [ ] **Default-if-present (const)** — `--opt` (no value) → use const; `--opt val` → use val; absent → use default (argparse `const`)
- [ ] **Response file** — `mytool @args.txt` expands file contents as arguments (argparse `fromfile_prefix_chars`, javac, MSBuild)
- [ ] **Argument parents** — share a common set of Argument definitions across multiple Commands (argparse `parents`)
- [ ] **Interactive prompting** — prompt user for missing required args instead of erroring (Click `prompt=True`)
- [ ] **Password / masked input** — hide typed characters for sensitive values (Click `hide_input=True`)
- [ ] **Confirmation option** — built-in `--yes` / `-y` to skip confirmation prompts (Click `confirmation_option`)
- [ ] **Pre/Post run hooks** — callbacks before/after main logic (cobra `PreRun`/`PostRun`)
- [ ] **REMAINDER nargs** — capture all remaining args including `-` prefixed ones (argparse `nargs=REMAINDER`)
- [ ] **Regex validation** — `.pattern(r"^\d{4}-\d{2}-\d{2}$")` validates value format (no major library has this)
- [ ] **Mutual implication** — `command.implies("debug", "verbose")` — after parsing, if the trigger flag is set, automatically set the implied flag; support chained implication (`debug → verbose → log`); detect circular cycles at registration time (no major library has this built-in)
- [ ] **Stdin value** — `.stdin_value()` on `Argument` — when parsed value is `"-"`, read from stdin; Unix convention (`cat file.txt | mytool --input -`) (cobra supports; depends on Mojo stdin API)
- [ ] **Subcommand aliases** — `sub.alias("co")` registers a shorthand name; typo suggestions search aliases too (cobra `Command.Aliases`, clap `Command::alias`)
- [ ] **Hidden subcommands** — `sub.hidden()` — exclude from the "Commands:" section in help, still dispatchable by exact name (clap `Command::hide`, cobra `Hidden`)
- [ ] **`NO_COLOR` env variable** — honour the [no-color.org](https://no-color.org/) standard: if env `NO_COLOR` is set, suppress all ANSI colour output; lower priority than explicit `.color(False)` API call

### Explicitly Out of Scope

These will **NOT** be implemented (but who knows :D maybe in the future if there's demand):

- Derive/decorator-based API (no macros in Mojo)
- Shell completion script generation
- Usage-string-driven parsing (docopt style)
- Config file parsing (users can pre-process argv)
- Environment variable fallback
- Template-based help formatting

### Phase 6: CJK Features

ArgMojo's differentiating features — no other CLI library addresses CJK-specific pain points.

這部分主要是為了讓 ArgMojo 在 CJK 環境下的使用體驗更好，解決一些常見的問題，比如幫助信息對齊、全角字符自動轉半角、CJK 標點檢測等。畢竟我總是忘了切換輸入法，打出中文的全角標點，然後被 CLI 報錯。

#### 6.1 CJK-aware help formatting

**Problem:** All Western CLI libraries (argparse, cobra, clap) assume 1 char = 1 column. CJK characters occupy 2 terminal columns (full-width), causing misaligned `--help` output when descriptions mix CJK and ASCII:

```bash
  --format <FMT>   Output format              ← aligned
  --ling           使用宇浩靈明編碼           ← CJK chars each take 2 columns, misaligned
```

**Implementation:**

- [ ] Implement `_display_width(s: String) -> Int` in `utils.mojo`, traversing each code point:
  - CJK Unified Ideographs (`U+4E00`–`U+9FFF`), CJK Ext-A/B/C/D/E/F/G/H/I/J, fullwidth forms (`U+FF01`–`U+FF60`) → width 2
  - Other visible characters → width 1
  - Zero-width joiners, combining marks → width 0
- [ ] Replace `len()` with `_display_width()` in all help formatting padding calculations (`_help_positionals_section`, `_help_options_section`, `_help_commands_section`)
- [ ] Add tests with mixed CJK/ASCII help text verifying column alignment

**References:** POSIX `wcwidth(3)`, Python `unicodedata.east_asian_width()`, Rust `unicode-width` crate.

#### 6.2 Full-width → half-width auto-correction

**Problem:** CJK users frequently forget to switch input methods, typing full-width ASCII:

- `－－ｖｅｒｂｏｓｅ` instead of `--verbose`
- `＝` instead of `=`

**Implementation:**

- [ ] Implement `_fullwidth_to_halfwidth(token: String) -> String` in `utils.mojo`:
  - Full-width ASCII range: `U+FF01`–`U+FF5E` → subtract `0xFEE0` to get half-width
  - Full-width space `U+3000` → half-width space `U+0020`
- [ ] In `parse_args()`, scan each token before parsing; if full-width characters are detected in option tokens (`--` or `-` prefixed), auto-correct and print a coloured warning:

  ```bash
  warning: detected full-width characters in '－－ｖｅｒｂｏｓｅ', auto-corrected to '--verbose'
  ```

- [ ] Only correct option names (tokens starting with `-`), **not** positional values (user may intentionally input full-width content)
- [ ] Add `.disable_fullwidth_correction()` opt-out API on `Command`
- [ ] Add tests for full-width flag, full-width `=` in `--key＝value`, and opt-out

#### 6.3 CJK punctuation detection

**Problem:** Users accidentally type Chinese punctuation:

- `——verbose` (em-dash `U+2014` × 2) instead of `--verbose`
- `--key：value` (full-width colon `U+FF1A`) instead of `--key=value`

**Implementation:**

- [ ] Integrate with typo suggestion system — when a token fails to match any known option, check for common CJK punctuation patterns before running Levenshtein:
  - `——` (`U+2014 U+2014`) → `--`
  - `：` (`U+FF1A`) → `=` or `:`
  - `，` (`U+FF0C`) → `,` (affects value delimiters)
- [ ] Produce specific error messages:

  ```bash
  error: unknown option '——verbose'. Did you mean '--verbose'? (detected Chinese em-dash ——)
  ```

- [ ] Add tests for each punctuation substitution

### Phase 7: Type-Safe API (aspirational — blocked on Mojo language features)

These features represent the "next generation" of CLI parser design, inspired by Rust clap's derive API. They require Mojo language features that do **not yet exist** (macros, reflection, sum types). Tracked here as aspirational goals.

> **Note on clap's success:** The claim that "clap succeeded because of strong typing" is partially misleading. clap's **builder API** (`matches.get_one::<String>("name")`) is structurally identical to ArgMojo's `result.get_string("name")` — both are runtime-typed string-keyed lookups. clap was the dominant Rust CLI library for years (v1–v3) before the derive macro was stabilised. The derive API's real value is **boilerplate reduction** (one struct definition encodes name, type, help, default), not type safety per se. Python argparse (dynamic `Namespace`), Go cobra (`GetString("name")`), and Click all use the same runtime-lookup pattern and are the most popular parsers in their ecosystems.

| Feature                                                   | What it needs                            | Status                  |
| --------------------------------------------------------- | ---------------------------------------- | ----------------------- |
| `Parseable` trait                                         | Mojo traits + parametric methods         | Can prototype now       |
| `add_arg[Int]("--port")` generic registration             | `Parseable` trait + type-aware storage   | Can prototype now       |
| `@cli struct Args` derive                                 | Mojo macros / decorators                 | Blocked — no macros     |
| `enum Mode { Debug, Release }` → auto choices             | Mojo reflection on enum variants         | Blocked — no reflection |
| `variant Command { Commit(CommitArgs), Push(PushArgs) }`  | Mojo sum types / enum with payloads      | Blocked — no sum types  |
| `file: String` (required) vs `output: String?` (optional) | Derive macro to map struct fields → args | Blocked — no macros     |
| `Path` / `Url` / `Duration` value types                   | Mojo stdlib types                        | Blocked — stdlib gaps   |

#### What ArgMojo already provides (equivalent functionality)

| "Missing" feature            | ArgMojo equivalent                                                                                                                             | How                                             |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| Typed retrieval              | `get_flag()->Bool`, `get_int()->Int`, `get_string()->String`, `get_count()->Int`, `get_list()->List[String]`, `get_map()->Dict[String,String]` | Already typed at retrieval                      |
| Enum validation              | `.choices(["debug", "release"])`                                                                                                               | String-level enum; help shows `{debug,release}` |
| Required / optional          | `.required()` / `.default("...")`                                                                                                              | Parse-time enforcement with coloured errors     |
| Flag counter (not just bool) | `.count()` + `get_count()`                                                                                                                     | `-vvv → 3`; `.count().max(N)` planned           |
| Subcommand dispatch          | `result.subcommand == "search"` + `get_subcommand_result()`                                                                                    | Same pattern as Go cobra                        |

## 6. Parsing Algorithm

```txt
Input: ["demo", "yuhao", "./src", "--ling", "-i", "--max-depth", "3"]

1. Initialize ParseResult and register positional names
2. If `help_on_no_args` is enabled and only argv[0] exists:
    print help and exit
3. Loop from argv[1] with cursor i:
    ├─ If args[i] == "--":
    │     Enter positional-only mode
    ├─ If positional-only mode is on:
    │     Append token to positional list
    ├─ If args[i] == "--help" or "-h" or "-?":
    │     Print help and exit
    ├─ If args[i] == "--version" or "-V":
    │     Print version and exit
    ├─ If args[i].startswith("--"):
    │     → _parse_long_option(raw_args, i, result) → new i
    │       (--key=value, --no-key negation, prefix match, count/flag/nargs/value)
    ├─ If args[i].startswith("-") and len > 1:
    │     ├─ IF _looks_like_number(token) AND (allow_negative_numbers OR no digit short opts):
    │     │     Treat as positional argument (negative number passthrough)
    │     └─ ELSE:
    │           ├─ Single char → _parse_short_single(key, raw_args, i, result) → new i
    │           └─ Multi char  → _parse_short_merged(key, raw_args, i, result) → new i
    ├─ If subcommands registered:
    │     → _dispatch_subcommand(arg, raw_args, i, result) → new i or -1
    │       (match → build child argv, inject persistent, recurse, sync; no match → -1)
    └─ Otherwise:
            Treat as positional argument
4. Apply defaults for missing arguments (named + positional slots)
5. Validate:
    ├─ Required arguments
    ├─ Positional count (too many positionals)
    ├─ Mutually exclusive groups
    ├─ Required-together groups
    ├─ One-required groups
    └─ Conditional requirements
6. Return ParseResult
```

### 6.1 Subcommand parsing flow

```txt
Input: ["app", "--verbose", "search", "pattern", "--max-depth", "3"]

1. Root parse_args() begins normal cursor walk from argv[1]
2. "--verbose" → starts with "--" → parsed as root-level long option (flag)
3. "search" → no "-" prefix → check registered subcommands:
    ├─ match found → record subcommand = "search"
    ├─ no match + subcommands registered → error (or treat as positional)
    └─ no subcommands registered → treat as positional (existing behavior)
4. Build child argv: ["app search", "pattern", "--max-depth", "3"]
   (argv[0] = command path for child help/error messages)
5. Inject persistent args from root into child's arg list
6. Call child.parse_args(child_argv) → child runs its own full parse loop
   (same code path: long/short/merged/positional/defaults/validation)
7. Store child ParseResult in root result:
    ├─ result.subcommand = "search"
    └─ result.subcommand_result = child_result
8. Root runs _apply_defaults() and _validate() for root-level args only
   (child already validated itself in step 6)
9. Return root ParseResult to application code
```

## 8. Notes on Mojo versions

Here are some important Mojo-specific patterns used throughout this project. Mojo is rapidly evolving, so these may need to be updated in the future.

These are all worthy being checked in [Mojo Miji](https://mojo-lang.com/miji) too.

| Pattern                | What & Why                                          |
| ---------------------- | --------------------------------------------------- |
| `"""Tests..."""`       | Docstring convention                                |
| `@fieldwise_init`      | Replaces `@value`                                   |
| `var self`             | Used for builder methods instead of `owned self`    |
| `String()`             | Explicit conversion; `str()` is not available       |
| `[a, b, c]` for `List` | List literal syntax instead of variadic constructor |
| `.copy()`              | Explicit copy for non-ImplicitlyCopyable types      |
| `Movable` conformance  | Required for structs stored in containers           |
