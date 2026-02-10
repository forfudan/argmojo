# ArgMojo — User Manual <!-- omit from toc -->

> Comprehensive guide to every feature of the ArgMojo command-line argument parser.

All code examples below assume that you have imported the mojo at the top of your mojo file:

```mojo
from argmojo import Arg, Command
```

## 1. Creating a Command

A **Command** is the top-level object that holds argument definitions and runs the parser.

```mojo
fn main() raises:
    var cmd = Command("myapp", "A short description of the program", version="1.0.0")
    # ... add arguments ...
    var result = cmd.parse()
```

| Parameter     | Type     | Required | Description                                      |
| ------------- | -------- | -------- | ------------------------------------------------ |
| `name`        | `String` | Yes      | Program name, shown in help text and usage line. |
| `description` | `String` | No       | One-line description shown at the top of help.   |
| `version`     | `String` | No       | Version string printed by `--version`.           |

### `parse()` vs `parse_args()`

- **`cmd.parse()`** reads the real command-line via `sys.argv()`.
- **`cmd.parse_args(args)`** accepts a `List[String]` — useful for testing without a real binary.

## 2. Positional Arguments

Positional arguments are matched **by order**, not by name. They do not start with `-` or `--`.

```mojo
cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
cmd.add_arg(Arg("path",    help="Search path").positional().default("."))
```

```bash
myapp "hello" ./src
#       ↑        ↑
#     pattern   path
```

Positional arguments are assigned in the order they are registered with `add_arg()`. If fewer values are provided than defined arguments, the remaining ones use their default values (if any). If more are provided, an error is raised (see [Positional Arg Count Validation](#15-positional-arg-count-validation)).

**Retrieving:**

```mojo
var pattern = result.get_string("pattern")  # "hello"
var path    = result.get_string("path")     # "./src"
```

## 3. Long Options

Long options start with `--` and can receive a value in two ways:

| Syntax        | Example               | Description             |
| ------------- | --------------------- | ----------------------- |
| `--key value` | `--output result.txt` | Space-separated value.  |
| `--key=value` | `--output=result.txt` | Equals-separated value. |

```mojo
cmd.add_arg(Arg("output", help="Output file").long("output"))
```

```bash
myapp --output result.txt
myapp --output=result.txt
```

Both forms produce the same result:

```mojo
result.get_string("output")  # "result.txt"
```

## 4. Short Options

Short options use a **single dash** followed by a **single character**.

```mojo
cmd.add_arg(
    Arg("output", help="Output file").long("output").short("o")
)
```

```bash
myapp -o result.txt          # space-separated
myapp -oresult.txt           # attached value (see §9)
```

A short name is typically defined alongside a long name, but can also be used alone.

## 5. Boolean Flags

A **flag** is a boolean option that takes no value. It is `False` by default and becomes `True` when present.

```mojo
cmd.add_arg(
    Arg("verbose", help="Enable verbose output")
    .long("verbose").short("v").flag()
)
```

```bash
myapp --verbose    # verbose = True
myapp -v           # verbose = True
myapp              # verbose = False (default)
```

**Retrieving:**

```mojo
var verbose = result.get_flag("verbose")  # Bool
```

## 6. Default Values

When an argument is not provided on the command line, its default value (if any) is used.

```mojo
cmd.add_arg(
    Arg("format", help="Output format")
    .long("format").short("f").default("table")
)
cmd.add_arg(
    Arg("path", help="Search path").positional().default(".")
)
```

```bash
myapp "hello"                # format = "table", path = "."
myapp "hello" --format csv   # format = "csv",   path = "."
myapp "hello" ./src          # format = "table", path = "./src"
```

Works for both named options and positional arguments.

## 7. Required Arguments

Mark an argument as **required** to make parsing fail when it is absent.

```mojo
cmd.add_arg(
    Arg("pattern", help="Search pattern").positional().required()
)
```

```bash
myapp "hello"   # OK
myapp           # Error: Required argument 'pattern' was not provided
```

Typically used for positional arguments. Named options can also be marked required.

## 8. Short Flag Merging

When multiple short options are **boolean flags**, they can be combined into a single `-` token.

```mojo
cmd.add_arg(Arg("all",       help="Show all").long("all").short("a").flag())
cmd.add_arg(Arg("brief",     help="Brief mode").long("brief").short("b").flag())
cmd.add_arg(Arg("colorize",  help="Colorize").long("colorize").short("c").flag())
```

```bash
myapp -abc
# Expands to: -a -b -c
# all = True, brief = True, colorize = True
```

**Mixing flags with a value-taking option:** The last character in a merged group can take a value (the rest of the token or the next argument):

```mojo
cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))
```

```bash
myapp -abofile.txt
# Expands to: -a -b -o file.txt
# all = True, brief = True, output = "file.txt"
```

## 9. Attached Short Values

A short option that takes a value can have its value **attached directly** — no space needed.

```mojo
cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))
```

```bash
myapp -ofile.txt          # output = "file.txt"
myapp -o file.txt         # output = "file.txt"  (same result)
```

This is the same behaviour as GCC's `-O2`, tar's `-xzf archive.tar.gz`, and similar UNIX traditions.

## 10. Choices Validation

Restrict an option's value to a fixed set of allowed strings. If the user provides a value not in the set, parsing fails with a clear error message.

```mojo
var levels: List[String] = ["debug", "info", "warn", "error"]
cmd.add_arg(
    Arg("log-level", help="Log level")
    .long("log-level").choices(levels^).default("info")
)
```

```bash
myapp --log-level debug    # OK
myapp --log-level trace    # Error: Invalid value 'trace' for argument 'log-level'
                           #        (choose from 'debug', 'info', 'warn', 'error')
```

**In help text**, choices are shown automatically:

```bash
  --log-level {debug,info,warn,error}  Log level
```

**Combining with short options and attached values:**

```bash
myapp -ldebug              # (if short name is "l") OK
myapp -l trace             # Error, same as above
```

> **Note:** You need to pass the `List[String]` with `^` (ownership transfer) or `.copy()` (a new copy) because `List[String]` is not implicitly copyable.

## 11. Metavar

**Metavar** overrides the placeholder text shown for a value in help output. Without it, the argument's internal name (uppercased) is shown.

```mojo
cmd.add_arg(
    Arg("output", help="Output file path")
    .long("output").short("o").metavar("FILE")
)
cmd.add_arg(
    Arg("max-depth", help="Maximum directory depth")
    .long("max-depth").short("d").metavar("N")
)
```

**Help output (before):**

```bash
  -o, --output <output>       Output file path
  -d, --max-depth <max-depth> Maximum directory depth
```

**Help output (after `.metavar()`):**

```bash
  -o, --output FILE           Output file path
  -d, --max-depth N           Maximum directory depth
```

Metavar is purely cosmetic — it has no effect on parsing.

## 12. Count Flags

A **count** flag increments a counter every time it appears. This is a common pattern for verbosity levels.

```mojo
cmd.add_arg(
    Arg("verbose", help="Increase verbosity (-v, -vv, -vvv)")
    .long("verbose").short("v").count()
)
```

```bash
myapp -v             # verbose = 1
myapp -vv            # verbose = 2
myapp -vvv           # verbose = 3
myapp --verbose      # verbose = 1
myapp -v --verbose   # verbose = 2  (short + long both increment)
myapp                # verbose = 0  (default)
```

**Retrieving:**

```mojo
var level = result.get_count("verbose")  # Int
if level >= 2:
    print("Debug-level output enabled")
```

Count flags are a special kind of boolean flag — calling `.count()` automatically sets `.flag()` as well, so they don't expect a value.

Merged short flags work seamlessly: `-vvv` is three occurrences of `-v`.

## 13. Hidden Arguments

A **hidden** argument is fully functional but excluded from the `--help` output. Useful for internal, deprecated, or debug-only options.

```mojo
cmd.add_arg(
    Arg("debug-index", help="Dump internal search index")
    .long("debug-index").flag().hidden()
)
```

```bash
myapp --debug-index    # Works — flag is set to True
myapp --help           # --debug-index does NOT appear in the help text
```

**Typical use cases:**

- Internal debugging flags that end users shouldn't need.
- Features that are experimental or not yet stable.
- Backward-compatible aliases you don't want to advertise.

## 14. Mutually Exclusive Groups

**Mutually exclusive** means "at most one of these arguments may be provided". If the user supplies two or more arguments from the same group, parsing fails.

This is useful when two options are logically contradictory, such as `--json` vs `--yaml` (you can only pick one output format), or `--color` vs `--no-color`.

### Defining a group

```mojo
cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
cmd.add_arg(Arg("csv",  help="Output as CSV").long("csv").flag())

var group: List[String] = ["json", "yaml", "csv"]
cmd.mutually_exclusive(group^)
```

### Behaviour

```bash
myapp --json           # OK — only one from the group
myapp --yaml           # OK
myapp                  # OK — none from the group is also fine
myapp --json --yaml    # Error: Arguments are mutually exclusive: '--json', '--yaml'
myapp --json --csv     # Error: Arguments are mutually exclusive: '--json', '--csv'
```

### Works with value-taking options too

The group members don't have to be flags — they can be any kind of argument:

```mojo
cmd.add_arg(Arg("input", help="Read from file").long("input"))
cmd.add_arg(Arg("stdin", help="Read from stdin").long("stdin").flag())

var io_group: List[String] = ["input", "stdin"]
cmd.mutually_exclusive(io_group^)
```

```bash
myapp --input data.csv         # OK
myapp --stdin                  # OK
myapp --input data.csv --stdin # Error: mutually exclusive
```

### Multiple groups

You can register more than one exclusive group on the same command:

```mojo
var format_group: List[String] = ["json", "yaml", "csv"]
cmd.mutually_exclusive(format_group^)

var color_group: List[String] = ["color", "no-color"]
cmd.mutually_exclusive(color_group^)
```

Each group is validated independently — using `--json` and `--no-color` together is fine, because they belong to different groups.

### When to use

| Scenario                   | Example                       |
| -------------------------- | ----------------------------- |
| Conflicting output formats | `--json` / `--yaml` / `--csv` |
| Boolean toggle pair        | `--color` / `--no-color`      |
| Exclusive input sources    | `--file <path>` / `--stdin`   |
| Verbose vs quiet           | `--verbose` / `--quiet`       |

> **Note:** Pass the `List[String]` with `^` (ownership transfer).

## 15. Positional Arg Count Validation

ArgMojo ensures that the user does not provide more positional arguments than defined. Extra positional values trigger an error.

```mojo
cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
# Only 1 positional arg is defined.
```

```bash
myapp "hello"                  # OK
myapp "hello" extra1 extra2    # Error: Too many positional arguments: expected 1, got 3
```

With two positional args defined:

```mojo
cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
cmd.add_arg(Arg("path",    help="Search path").positional().default("."))
```

```bash
myapp "hello" ./src            # OK — pattern = "hello", path = "./src"
myapp "hello" ./src /tmp       # Error: Too many positional arguments: expected 2, got 3
```

## 16. The `--` Stop Marker

A bare `--` tells the parser to **stop interpreting options**. Everything after `--` is treated as a positional argument, even if it looks like an option.

```mojo
cmd.add_arg(Arg("ling", help="Use Lingming encoding").long("ling").flag())
cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
```

```bash
myapp -- --ling
# ling = False  (the -- stopped option parsing)
# pattern = "--ling"  (treated as a positional value)
```

This is especially useful for patterns or file paths that look like options:

```bash
myapp --ling -- "-v is not a flag here" ./src
# ling = True  (parsed before --)
# pattern = "-v is not a flag here"
# path = "./src"
```

## 17. Auto-generated Help

Every command automatically supports `--help` (or `-h`). The help text is generated from the registered argument definitions.

```bash
myapp --help
myapp -h
```

**Example output:**

```bash
A CJK-aware text search tool

Usage: myapp <pattern> [path] [OPTIONS]

Arguments:
  pattern    Search pattern
  path       Search path

Options:
  -l, --ling                  Use Lingming IME for encoding
  -i, --ignore-case           Case-insensitive search
  -v, --verbose               Increase verbosity (-v, -vv, -vvv)
  -d, --max-depth N           Maximum directory depth
  -f, --format {json,csv,table}  Output format
      --color                 Force colored output
      --no-color              Disable colored output
  -h, --help                  Show this help message
  -V, --version               Show version
```

**What controls the output:**

| Builder method  | Effect on help                                        |
| --------------- | ----------------------------------------------------- |
| `.help("...")`  | Sets the description text for the option.             |
| `.metavar("X")` | Replaces the default placeholder (e.g., `N`, `FILE`). |
| `.choices()`    | Shows `{a,b,c}` in the placeholder.                   |
| `.hidden()`     | Completely excludes the option from help.             |
| `.required()`   | Positional args show as `<name>` instead of `[name]`. |

After printing help, the program exits cleanly with exit code 0.

## 18. Version Display

Every command automatically supports `--version` (or `-V`).

```bash
myapp --version
myapp -V
```

**Output:**

```bash
myapp 1.0.0
```

The version string is set when creating the Command:

```mojo
var cmd = Command("myapp", "Description", version="1.0.0")
```

After printing the version, the program exits cleanly with exit code 0.

## 19. Reading Parsed Results

After calling `cmd.parse()` or `cmd.parse_args()`, you get a `ParseResult` with these typed accessors:

| Method                      | Returns  | Description                                       |
| --------------------------- | -------- | ------------------------------------------------- |
| `result.get_flag("name")`   | `Bool`   | Returns `True` if the flag was set, else `False`. |
| `result.get_string("name")` | `String` | Returns the string value. Raises if not found.    |
| `result.get_int("name")`    | `Int`    | Parses the value as an integer. Raises on error.  |
| `result.get_count("name")`  | `Int`    | Returns the count (0 if never provided).          |
| `result.has("name")`        | `Bool`   | Returns `True` if the argument was provided.      |

**`get_string()`** works for both named options and positional arguments — positional values are looked up by the name given in `Arg("name", ...)`.

```mojo
var result = cmd.parse()

# Flags
if result.get_flag("verbose"):
    print("Verbose mode on")

# String values
var output = result.get_string("output")

# Integer values
var depth = result.get_int("max-depth")

# Count flags
var verbosity = result.get_count("verbose")

# Check presence
if result.has("output"):
    print("Output was specified:", result.get_string("output"))
```
