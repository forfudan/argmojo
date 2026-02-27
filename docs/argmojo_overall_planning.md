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
| Suggest on typo (Levenshtein)      | ✓ (3.14) | —     | ✓     | ✓    |                        | Phase 5       |
| CJK-aware help formatting          | —        | —     | —     | —    | ArgMojo unique feature | Phase 6       |
| CJK full-to-half-width correction  | —        | —     | —     | —    | ArgMojo unique feature | Phase 6       |
| CJK punctuation detection          | —        | —     | —     | —    | ArgMojo unique feature | Phase 6       |

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
├── demo.mojo                   # Demo CLI tool, compilable to binary
├── demo_subcommands.mojo       # Subcommand routing demo (dispatch + help sub)
├── demo_persistent.mojo        # Persistent flag demo (injection + sync)
└── demo_negative.mojo          # Negative number passthrough demo
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

- **No file split.** Everything stays in `command.mojo`. Mojo has no partial structs, so splitting would force free functions + parameter threading for little gain at ~1500 lines.
- **No tokenizer.** The single-pass cursor walk (`startswith` checks) is sufficient. Token types are trivially identified inline.
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

- [x] Add `examples/demo_subcommands.mojo` demonstrating Step 2 + Step 2b routing (search / init / build + help subcommand inspection)
- [x] Add `examples/demo_negative.mojo` demonstrating all three negative-number passthrough approaches (auto-detect, `--`, `allow_negative_numbers()`)
- [x] Add `examples/demo_persistent.mojo` demonstrating before/after persistent flags, bidirectional sync, conflict detection
- [x] Update `examples/demo.mojo` with full 2-3 subcommand CLI (after Step 2–5)
- [x] Update user manual with subcommand usage patterns
- [x] Document persistent flag behavior and conflict rules

### Phase 5: Polish (nice-to-have features, may not be implemented soon)

- [ ] **Typo suggestions** — "Unknown option '--vrb', did you mean '--verbose'?" (Levenshtein distance; cobra, argparse 3.14)
- [x] **Colored error output** — ANSI styled error messages (help output already colored)
- [ ] **Argument groups in help** — group related options under headings (argparse add_argument_group)
- [ ] **Usage line customisation** — override the auto-generated usage string
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
- [ ] **Flag counter with ceiling** — `.count().max(3)` caps `-vvvvv` at 3 (no major library has this)

### Explicitly Out of Scope

These will **NOT** be implemented (but who knows :D maybe in the future if there's demand):

- Derive/decorator-based API (no macros in Mojo)
- Shell completion script generation
- Usage-string-driven parsing (docopt style)
- Config file parsing (users can pre-process argv)
- Environment variable fallback
- Template-based help formatting

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
    │     Parse long option
    │     ├─ Support `--key=value`
    │     ├─ Support `--no-key` (negatable flags, with prefix match)
    │     ├─ Resolve by exact long name or unambiguous prefix
    │     ├─ Handle count / flag / nargs / value-taking options
    │     └─ For append args, split by delimiter if configured
    ├─ If args[i].startswith("-") and len > 1:
    │     ├─ IF _looks_like_number(token) AND (allow_negative_numbers OR no digit short opts):
    │     │     Treat as positional argument (negative number passthrough)
    │     └─ ELSE: Parse short option(s)
    │           ├─ Single short: count / flag / nargs / value
    │           └─ Multi-short: merged flags and attached value (`-ofile.txt`)
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

### 6.1 Subcommand parsing flow (planned)

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
