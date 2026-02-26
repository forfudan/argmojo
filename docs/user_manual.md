# ArgMojo — User Manual <!-- omit from toc -->

> Comprehensive guide to every feature of the ArgMojo command-line argument parser.

All code examples below assume that you have imported the mojo at the top of your mojo file:

```mojo
from argmojo import Arg, Command
```

- [Getting Started](#getting-started)
  - [Creating a Command](#creating-a-command)
  - [Reading Parsed Results](#reading-parsed-results)
- [Defining Arguments](#defining-arguments)
  - [Positional Arguments](#positional-arguments)
  - [Long Options](#long-options)
  - [Short Options](#short-options)
  - [Boolean Flags](#boolean-flags)
  - [Default Values](#default-values)
  - [Required Arguments](#required-arguments)
  - [Aliases](#aliases)
- [Short Option Details](#short-option-details)
  - [Short Flag Merging](#short-flag-merging)
  - [Attached Short Values](#attached-short-values)
- [Flag Variants](#flag-variants)
  - [Count Flags](#count-flags)
  - [Negatable Flags](#negatable-flags)
- [Collecting Multiple Values](#collecting-multiple-values)
  - [Append / Collect Action](#append--collect-action)
  - [Value Delimiter](#value-delimiter)
  - [Multi-Value Options (nargs)](#multi-value-options-nargs)
  - [Key-Value Map Options](#key-value-map-options)
- [Value Validation](#value-validation)
  - [Choices Validation](#choices-validation)
  - [Positional Arg Count Validation](#positional-arg-count-validation)
  - [Numeric Range Validation](#numeric-range-validation)
- [Group Constraints](#group-constraints)
  - [Mutually Exclusive Groups](#mutually-exclusive-groups)
  - [One-Required Groups](#one-required-groups)
  - [Required-Together Groups](#required-together-groups)
  - [Conditional Requirements](#conditional-requirements)
- [Help \& Display](#help--display)
  - [Metavar](#metavar)
  - [Hidden Arguments](#hidden-arguments)
  - [Deprecated Arguments](#deprecated-arguments)
  - [Auto-generated Help](#auto-generated-help)
  - [Version Display](#version-display)
- [Parsing Behaviour](#parsing-behaviour)
  - [Negative Number Passthrough](#negative-number-passthrough)
  - [Long Option Prefix Matching](#long-option-prefix-matching)
  - [The `--` Stop Marker](#the----stop-marker)

## Getting Started

### Creating a Command

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

---

**`parse()` vs `parse_args()`**

- **`cmd.parse()`** reads the real command-line via `sys.argv()`.
- **`cmd.parse_args(args)`** accepts a `List[String]` — useful for testing without a real binary. Note that `args[0]` is expected to be the program name and will be skipped, so the actual arguments should start from index 1.

### Reading Parsed Results

After calling `cmd.parse()` or `cmd.parse_args()`, you get a `ParseResult` with these typed accessors:

| Method                      | Returns        | Description                                       |
| --------------------------- | -------------- | ------------------------------------------------- |
| `result.get_flag("name")`   | `Bool`         | Returns `True` if the flag was set, else `False`. |
| `result.get_string("name")` | `String`       | Returns the string value. Raises if not found.    |
| `result.get_int("name")`    | `Int`          | Parses the value as an integer. Raises on error.  |
| `result.get_count("name")`  | `Int`          | Returns the count (0 if never provided).          |
| `result.get_list("name")`   | `List[String]` | Returns collected values (empty list if none).    |
| `result.has("name")`        | `Bool`         | Returns `True` if the argument was provided.      |

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

# List (append) values
var tags = result.get_list("tag")  # List[String]

# Check presence
if result.has("output"):
    print("Output was specified:", result.get_string("output"))
```

## Defining Arguments

### Positional Arguments

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

Positional arguments are assigned in the order they are registered with `add_arg()`. If fewer values are provided than defined arguments, the remaining ones use their default values (if any). If more are provided, an error is raised (see [Positional Arg Count Validation](#positional-arg-count-validation)).

**Retrieving:**

```mojo
var pattern = result.get_string("pattern")  # "hello"
var path    = result.get_string("path")     # "./src"
```

### Long Options

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

### Short Options

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

### Boolean Flags

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

### Default Values

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

### Required Arguments

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

### Aliases

Register alternative long names for an argument with `.aliases()`.
Any alias resolves to the same argument during parsing.

```mojo
var alias_list: List[String] = ["color"]
cmd.add_arg(
    Arg("colour", help="Colour theme")
        .long("colour")
        .aliases(alias_list^)
)
```

```bash
myapp --colour red     # OK — colour = "red"
myapp --color  red     # OK — resolved via alias, colour = "red"
```

---

**Prefix matching** applies to aliases as well.  When both the
primary name and an alias share a prefix, `_find_by_long` deduplicates
so the match is never ambiguous within a single argument.

Multiple aliases are supported:

```mojo
var alias_list: List[String] = ["out", "fmt"]
cmd.add_arg(
    Arg("output", help="Output format")
        .long("output")
        .aliases(alias_list^)
)
```

## Short Option Details

### Short Flag Merging

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

### Attached Short Values

A short option that takes a value can have its value **attached directly** — no space needed.

```mojo
cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))
```

```bash
myapp -ofile.txt          # output = "file.txt"
myapp -o file.txt         # output = "file.txt"  (same result)
```

This is the same behaviour as GCC's `-O2`, tar's `-xzf archive.tar.gz`, and similar UNIX traditions.

## Flag Variants

### Count Flags

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

### Negatable Flags

A **negatable** flag automatically creates a `--no-X` counterpart. When the user passes `--X`, the flag is set to `True`; when they pass `--no-X`, it is explicitly set to `False`.

This replaces the manual pattern of defining two separate flags (`--color` and `--no-color`) and a mutually exclusive group.

---

**Defining a negatable flag**

```mojo
cmd.add_arg(
    Arg("color", help="Enable colored output")
    .long("color").flag().negatable()
)
```

---

```bash
myapp --color       # color = True,  has("color") = True
myapp --no-color    # color = False, has("color") = True
myapp               # color = False, has("color") = False  (default)
```

Use `result.has("color")` to distinguish between "user explicitly disabled colour" (`--no-color`) and "user didn't mention colour at all".

---

**Help output**

Negatable flags are displayed as a paired form:

```text
      --color / --no-color    Enable colored output
```

---

**Comparison with manual approach**

**Before (two flags + mutually exclusive):**

```mojo
cmd.add_arg(Arg("color", help="Force colored output").long("color").flag())
cmd.add_arg(Arg("no-color", help="Disable colored output").long("no-color").flag())
var group: List[String] = ["color", "no-color"]
cmd.mutually_exclusive(group^)
```

**After (single negatable flag):**

```mojo
cmd.add_arg(
    Arg("color", help="Enable colored output")
    .long("color").flag().negatable()
)
```

The negatable approach is simpler and uses only one entry in `ParseResult`.

---

| Scenario           | Example                              |
| ------------------ | ------------------------------------ |
| Colour control     | `--color` / `--no-color`             |
| Feature toggle     | `--cache` / `--no-cache`             |
| Header inclusion   | `--headers` / `--no-headers`         |
| Interactive prompt | `--interactive` / `--no-interactive` |

> **Note:** Only flags (`.flag()`) can be made negatable. Calling `.negatable()` on a non-flag argument has no effect on parsing.

## Collecting Multiple Values

### Append / Collect Action

An **append** option collects repeated occurrences into a list. Each time the option appears, its value is added to the list rather than overwriting the previous value.

This is a common pattern for options like `--include`, `--tag`, or `--define` where more than one value is expected.

---

**Defining an append option**

```mojo
cmd.add_arg(
    Arg("tag", help="Add a tag (repeatable)")
    .long("tag").short("t").append()
)
```

---

```bash
myapp --tag alpha --tag beta --tag gamma
# tags = ["alpha", "beta", "gamma"]

myapp -t alpha -t beta
# tags = ["alpha", "beta"]

myapp --tag=alpha --tag=beta
# tags = ["alpha", "beta"]

myapp -talpha -tbeta
# tags = ["alpha", "beta"]

myapp
# tags = []  (empty list, not provided)
```

All value syntaxes (space-separated, equals, attached short) work with append options.

---

**Retrieving**

```mojo
var tags = result.get_list("tag")  # List[String]
for i in range(len(tags)):
    print("tag:", tags[i])
```

`get_list()` returns an empty `List[String]` when the option was never provided.

---

**Help output**

Append options show a `...` suffix to indicate they are repeatable:

```text
  -t, --tag <tag>...            Add a tag (repeatable)
```

If a metavar is set, it replaces the default placeholder:

```mojo
cmd.add_arg(
    Arg("include", help="Include path").long("include").short("I").metavar("DIR").append()
)
```

```text
  -I, --include DIR...          Include path
```

---

**Combining with choices**

Choices validation is applied to each individual value:

```mojo
var envs: List[String] = ["dev", "staging", "prod"]
cmd.add_arg(
    Arg("env", help="Target environment")
    .long("env").choices(envs^).append()
)
```

```bash
myapp --env dev --env prod       # OK
myapp --env dev --env local      # Error: Invalid value 'local' for argument 'env'
```

### Value Delimiter

A **value delimiter** lets users supply multiple values in a single argument token by splitting on a delimiter character. For example, `--env dev,staging,prod` is equivalent to `--env dev --env staging --env prod`.

This is similar to Go cobra's `StringSliceVar` and Rust clap's `value_delimiter`.

---

**Defining a delimiter option**

```mojo
cmd.add_arg(
    Arg("env", help="Target environments")
    .long("env").short("e").delimiter(",")
)
```

Calling `.delimiter(",")` automatically implies `.append()` — you do not need to call both.

---

```bash
myapp --env dev,staging,prod
# envs = ["dev", "staging", "prod"]

myapp --env=dev,staging
# envs = ["dev", "staging"]

myapp -e dev,prod
# envs = ["dev", "prod"]

myapp --env dev,staging --env prod
# envs = ["dev", "staging", "prod"]   (values accumulate across uses)

myapp --env single
# envs = ["single"]                   (no delimiter → one-element list)

myapp
# envs = []                           (not provided → empty list)
```

Trailing delimiters are ignored — `--env a,b,` produces `["a", "b"]`, not `["a", "b", ""]`.

---

**Retrieving**

```mojo
var envs = result.get_list("env")  # List[String]
for i in range(len(envs)):
    print("env:", envs[i])
```

---

**Combining with choices**

Choices are validated per piece after splitting:

```mojo
var envs: List[String] = ["dev", "staging", "prod"]
cmd.add_arg(
    Arg("env", help="Target environments")
    .long("env").choices(envs^).delimiter(",")
)
```

```bash
myapp --env dev,prod       # OK
myapp --env dev,local      # Error: Invalid value 'local' for argument 'env'
```

---

**Custom delimiter**

Any string can be used as the delimiter:

```mojo
cmd.add_arg(
    Arg("path", help="Search paths")
    .long("path").delimiter(";")
)
```

```bash
myapp --path "/usr/lib;/opt/lib;/home/lib"
# paths = ["/usr/lib", "/opt/lib", "/home/lib"]
```

---

**Combining with append**

When a delimiter option is used multiple times, all split values accumulate:

```mojo
cmd.add_arg(
    Arg("tag", help="Tags").long("tag").short("t").append().delimiter(",")
)
```

```bash
myapp --tag a,b --tag c -t d,e
# tags = ["a", "b", "c", "d", "e"]
```

### Multi-Value Options (nargs)

Some options need to consume **multiple consecutive values** per occurrence.
For example, a 2D point needs two values (`--point 10 20`), and an RGB
colour needs three (`--rgb 255 128 0`).

This is similar to Python argparse's `nargs=N` and Rust clap's `num_args`.

---

**Defining a multi-value option**

Use `.nargs(N)` to specify how many values the option consumes:

```mojo
cmd.add_arg(Arg("point", help="X Y coordinates").long("point").nargs(2))
cmd.add_arg(Arg("rgb", help="RGB colour").long("rgb").short("c").nargs(3))
```

`.nargs(N)` automatically implies `.append()` — values are stored in
`ParseResult.lists` and retrieved with `get_list()`.

---

```bash
myapp --point 10 20
# point = ["10", "20"]

myapp --rgb 255 128 0
# rgb = ["255", "128", "0"]
```

---

**Repeated occurrences**

Each occurrence consumes N more values, all accumulating in the same list:

```bash
myapp --point 1 2 --point 3 4
# point = ["1", "2", "3", "4"]
```

---

**Short options**

nargs works with short options too:

```bash
myapp -c 255 128 0
# rgb = ["255", "128", "0"]
```

---

**Retrieving values**

```mojo
var result = cmd.parse()
var coords = result.get_list("point")
# coords[0] = "10", coords[1] = "20"
```

---

**Choices validation**

Choices are validated for **each** value individually:

```mojo
var dirs: List[String] = ["north", "south", "east", "west"]
cmd.add_arg(
    Arg("route", help="Start and end").long("route").nargs(2).choices(dirs^)
)
```

```bash
myapp --route north east    # ✓ both valid
myapp --route north up      # ✗ 'up' is not a valid choice
```

---

**Help output**

nargs options show the placeholder repeated N times:

```
Options:
  --point <point> <point>    X Y coordinates
  --rgb N N N                RGB colour        (with .metavar("N"))
```

Regular append options show `...` to indicate repeatability, while nargs
options show exactly N placeholders — making the expected arity clear.

---

**Limitations**

- **Equals syntax is not supported**: `--point=10 20` will raise an error.
  Use space-separated values: `--point 10 20`.
- **Insufficient values**: if fewer than N values remain on the command
  line, an error is raised with a clear message.

### Key-Value Map Options

`.map_option()` collects `key=value` pairs into a dictionary.
The option is implicitly repeatable (implies `.append()`), and each
value is stored in both a `Dict[String, String]` map and the list.

```mojo
cmd.add_arg(
    Arg("define", help="Define a variable")
        .long("define")
        .short("D")
        .map_option()
)
```

```bash
myapp --define CC=gcc -D CXX=g++
# result.get_map("define") → {"CC": "gcc", "CXX": "g++"}
```

---

**Equals syntax** is supported — `--define=CC=gcc` works.
The first `=` is consumed by argmojo's `--long=value` splitting;
the remaining `CC=gcc` is treated as the raw value and split at the
next `=` to produce key `CC` and value `gcc`.

---

**Value with embedded `=`** — everything after the first `=` in the
raw value is the value part:

```bash
myapp --define PATH=/usr/bin:/bin
# key = "PATH", value = "/usr/bin:/bin"
```

---

**Delimiter** — combine with `.delimiter(",")` to pass multiple
key-value pairs in a single token:

```mojo
cmd.add_arg(
    Arg("define", help="Define vars")
        .long("define")
        .map_option()
        .delimiter(",")
)
```

```bash
myapp --define CC=gcc,CXX=g++
# result.get_map("define") → {"CC": "gcc", "CXX": "g++"}
```

---

**Retrieving values** — use `result.get_map(name)` to get a
`Dict[String, String]` copy of all collected pairs:

```mojo
var m = result.get_map("define")
# Access individual keys:  m["CC"]
```

If the argument was not provided, `get_map()` returns an empty
dictionary just like `get_list()` returns an empty list.

---

**Help placeholder** — map options automatically show
`<key=value>` instead of the default `<name>` placeholder:

```
Options:
  -D, --define <key=value>...    Define a variable
```

## Value Validation

### Choices Validation

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

### Positional Arg Count Validation

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

### Numeric Range Validation

Constrain a numeric argument to an inclusive `[min, max]` range
with `.range(min, max)`.  The validation is applied after parsing,
so the value is still stored as a string; `atol()` is used internally
to convert and compare.

```mojo
cmd.add_arg(
    Arg("port", help="Listening port")
        .long("port")
        .range(1, 65535)
)
```

```bash
myapp --port 8080    # OK
myapp --port 0       # Error: Value 0 for '--port' is out of range [1, 65535]
myapp --port 70000   # Error: Value 70000 for '--port' is out of range [1, 65535]
```

---

**Boundary values** — both min and max are inclusive:

```bash
myapp --port 1       # OK
myapp --port 65535   # OK
```

---

**Append / list values** — when combined with `.append()` or
`.delimiter(",")`, every collected value is validated individually:

```mojo
cmd.add_arg(
    Arg("port", help="Ports").long("port").append().range(1, 100)
)
```

```bash
myapp --port 50 --port 101
# Error: Value 101 for '--port' is out of range [1, 100]
```

## Group Constraints

### Mutually Exclusive Groups

**Mutually exclusive** means "at most one of these arguments may be provided". If the user supplies two or more arguments from the same group, parsing fails.

This is useful when two options are logically contradictory, such as `--json` vs `--yaml` (you can only pick one output format), or `--color` vs `--no-color`.

---

**Defining a group**

```mojo
cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
cmd.add_arg(Arg("csv",  help="Output as CSV").long("csv").flag())

var group: List[String] = ["json", "yaml", "csv"]
cmd.mutually_exclusive(group^)
```

---

```bash
myapp --json           # OK — only one from the group
myapp --yaml           # OK
myapp                  # OK — none from the group is also fine
myapp --json --yaml    # Error: Arguments are mutually exclusive: '--json', '--yaml'
myapp --json --csv     # Error: Arguments are mutually exclusive: '--json', '--csv'
```

---

**Works with value-taking options too**

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

---

**Multiple groups**

You can register more than one exclusive group on the same command:

```mojo
var format_group: List[String] = ["json", "yaml", "csv"]
cmd.mutually_exclusive(format_group^)

var color_group: List[String] = ["color", "no-color"]
cmd.mutually_exclusive(color_group^)
```

Each group is validated independently — using `--json` and `--no-color` together is fine, because they belong to different groups.

---

| Scenario                   | Example                       |
| -------------------------- | ----------------------------- |
| Conflicting output formats | `--json` / `--yaml` / `--csv` |
| Boolean toggle pair        | `--color` / `--no-color`      |
| Exclusive input sources    | `--file <path>` / `--stdin`   |
| Verbose vs quiet           | `--verbose` / `--quiet`       |

> **Note:** Pass the `List[String]` with `^` (ownership transfer).

### One-Required Groups

A **one-required** group declares that at least one argument from the group must be provided. Parsing fails if none are present. This is useful for ensuring the user specifies a mandatory choice — for example, an output format or an input source.

This mirrors Go cobra's `MarkFlagsOneRequired` and Rust clap's `ArgGroup::required`.

---

**Defining a one-required group**

```mojo
cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
var format_group: List[String] = ["json", "yaml"]
cmd.one_required(format_group^)
```

---

```bash
myapp --json               # OK (one provided)
myapp --yaml               # OK (one provided)
myapp                      # Error: At least one of the following arguments is required: '--json', '--yaml'
myapp --json --yaml        # OK (at least one is satisfied — both is fine for one_required alone)
```

Note that `one_required` only checks that **at least one** is present. It does not prevent multiple from being used. To enforce **exactly one**, combine it with `mutually_exclusive`:

---

**Exactly-one pattern (one-required + mutually exclusive)**

```mojo
cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())

var excl: List[String] = ["json", "yaml"]
var req: List[String] = ["json", "yaml"]
cmd.mutually_exclusive(excl^)
cmd.one_required(req^)
```

```bash
myapp --json               # OK
myapp --yaml               # OK
myapp                      # Error: At least one of the following arguments is required: '--json', '--yaml'
myapp --json --yaml        # Error: Arguments are mutually exclusive: '--json', '--yaml'
```

---

**Works with value-taking options**

```mojo
cmd.add_arg(Arg("input", help="Input file").long("input").short("i"))
cmd.add_arg(Arg("stdin", help="Read from stdin").long("stdin").flag())
var source: List[String] = ["input", "stdin"]
cmd.one_required(source^)
```

```bash
myapp --input data.txt     # OK
myapp --stdin              # OK
myapp                      # Error: At least one of the following arguments is required: '--input', '--stdin'
```

---

**Multiple one-required groups**

You can declare multiple groups. Each is validated independently:

```mojo
var format_group: List[String] = ["json", "yaml"]
var source_group: List[String] = ["input", "stdin"]
cmd.one_required(format_group^)
cmd.one_required(source_group^)
```

```bash
myapp --json --input f.txt   # OK (both groups satisfied)
myapp --json                 # Error (source group unsatisfied)
```

---

| Scenario            | Example                             |
| ------------------- | ----------------------------------- |
| Tags / labels       | `--tag release --tag stable`        |
| Include paths       | `-I /usr/lib -I /opt/lib`           |
| Target environments | `--env dev --env staging`           |
| Compiler defines    | `--define DEBUG --define VERSION=2` |

### Required-Together Groups

**Required together** means "if any one of these arguments is provided, all the others must be provided too". If only some are given, parsing fails.

This is useful for sets of arguments that only make sense as a group — for example, authentication credentials (`--username` and `--password`), or network settings (`--host`, `--port`, `--protocol`).

---

**Defining a group**

```mojo
cmd.add_arg(Arg("username", help="Auth username").long("username").short("u"))
cmd.add_arg(Arg("password", help="Auth password").long("password").short("p"))

var group: List[String] = ["username", "password"]
cmd.required_together(group^)
```

---

```bash
myapp --username admin --password secret   # OK — both provided
myapp                                      # OK — neither provided
myapp --username admin                     # Error: Arguments required together:
                                           #        '--password' required when '--username' is provided
myapp --password secret                    # Error: Arguments required together:
                                           #        '--username' required when '--password' is provided
```

---

**Three or more arguments**

Groups can contain any number of arguments:

```mojo
cmd.add_arg(Arg("host",  help="Host").long("host"))
cmd.add_arg(Arg("port",  help="Port").long("port"))
cmd.add_arg(Arg("proto", help="Protocol").long("proto"))

var net_group: List[String] = ["host", "port", "proto"]
cmd.required_together(net_group^)
```

```bash
myapp --host localhost --port 8080 --proto https   # OK
myapp --host localhost                             # Error: '--port', '--proto' required when '--host' is provided
```

---

**Combining with mutually exclusive groups**

Required-together and mutually exclusive can coexist on the same command:

```mojo
# These two must appear together
var auth: List[String] = ["username", "password"]
cmd.required_together(auth^)

# These two cannot appear together
var excl: List[String] = ["json", "yaml"]
cmd.mutually_exclusive(excl^)
```

---

| Scenario            | Example                                 |
| ------------------- | --------------------------------------- |
| Authentication pair | `--username` + `--password`             |
| Network connection  | `--host` + `--port` + `--protocol`      |
| TLS settings        | `--cert` + `--key`                      |
| Database connection | `--db-host` + `--db-user` + `--db-pass` |

> **Note:** Pass the `List[String]` with `^` (ownership transfer).

### Conditional Requirements

Sometimes an argument should only be required when another argument is present. For example, `--output` might only make sense when `--save` is also provided.

---

```mojo
cmd.add_arg(Arg("save", help="Save results").long("save").flag())
cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))
cmd.required_if("output", "save")
```

This means: **if `--save` is provided, then `--output` must also be provided.**

```bash
myapp --save --output out.txt   # OK — both present
myapp --save                    # Error: '--output' is required when '--save' is provided
myapp --output file.txt         # OK — condition not triggered
myapp                           # OK — neither present
```

---

**Multiple conditional rules**

You can declare multiple conditional requirements on the same command:

```mojo
cmd.required_if("output", "save")       # --output required when --save
cmd.required_if("format", "compress")   # --format required when --compress
```

Each rule is checked independently after parsing.

---

**Error messages**

Error messages use `--long` display names when available:

```
Error: Argument '--output' is required when '--save' is provided
```

---

| Scenario                    | Example                               |
| --------------------------- | ------------------------------------- |
| Save to file                | `--output` required when `--save`     |
| Compression settings        | `--format` required when `--compress` |
| Custom export configuration | `--template` required when `--export` |

> **Difference from `required_together()`:** `required_together()` is
> symmetric — if *any* argument from the group appears, *all* must
> appear. `required_if()` is one-directional — only the target is
> required when the condition is present, not vice versa.

## Help & Display

### Metavar

**Metavar** overrides the placeholder text shown for a value in help output. Without it, the argument's internal name is shown in angle brackets (e.g., `<output>`).

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

### Hidden Arguments

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

### Deprecated Arguments

Mark an argument as deprecated with `.deprecated("message")`.
The argument still works normally, but a warning is printed to
**stderr** when the user provides it.

```mojo
cmd.add_arg(
    Arg("format_old", help="Legacy output format")
        .long("format-old")
        .deprecated("Use --format instead")
)
```

```bash
myapp --format-old csv
# stderr: Warning: '--format-old' is deprecated: Use --format instead
# parsing continues: format_old = "csv"
```

---

**Short options** also trigger the warning:

```mojo
cmd.add_arg(
    Arg("compat", help="Compat mode")
        .long("compat").short("C").flag()
        .deprecated("Will be removed in 2.0")
)
```

```bash
myapp -C
# stderr: Warning: '-C' is deprecated: Will be removed in 2.0
```

---

**Help display** — deprecated arguments show the deprecation
message in the help text:

```bash
Options:
  --format-old <format_old>    Legacy output format [deprecated: Use --format instead]
```

### Auto-generated Help

Every command automatically supports `--help` (or `-h` or `-?`). The help text is generated from the registered argument definitions.

```bash
myapp --help
myapp -h
myapp '-?'     # quote needed: ? is a shell glob wildcard
```

**Example output:**

```bash
A CJK-aware text search tool

Usage: myapp <pattern> [path] [OPTIONS]

Arguments:
  pattern    Search pattern
  path       Search path

Options:
  -l, --ling                        Use Lingming IME for encoding
  -i, --ignore-case                 Case-insensitive search
  -v, --verbose                     Increase verbosity (-v, -vv, -vvv)
  -d, --max-depth N                 Maximum directory depth
  -f, --format {json,csv,table}     Output format
      --color / --no-color          Enable colored output
  -?, -h, --help                    Show this help message
  -V, --version                     Show version
```

Help text columns are **dynamically aligned**: the padding between the option
names and the description text adjusts automatically based on the longest
option line, so everything stays neatly aligned regardless of option length.

---

**Coloured Output**

Help output uses **ANSI colour codes** by default to enhance readability.

| Element                 | Default style                        | ANSI code      |
| ----------------------- | ------------------------------------ | -------------- |
| Section headers         | **bold + underline + bright yellow** | `\x1b[1;4;93m` |
| Option / argument names | bright magenta                       | `\x1b[95m`     |
| Deprecation warnings    | **orange** (dark yellow)             | `\x1b[33m`     |
| Parse errors            | **bright red**                       | `\x1b[91m`     |
| Description text        | default terminal colour              | —              |

The `_generate_help()` method accepts an optional `color` parameter:

```mojo
var help_colored = cmd._generate_help()              # color=True (default)
var help_plain   = cmd._generate_help(color=False)   # no ANSI codes
```

---

**Custom Colours**

The **header colour**, **argument-name colour**, **deprecation warning
colour**, and **parse error colour** are all customisable.  Section headers
always keep the **bold + underline** style; only the colour changes.

```mojo
var cmd = Command("myapp", "My app")
cmd.header_color("BLUE")     # section headers in bright blue
cmd.arg_color("GREEN")       # option/argument names in bright green
cmd.warn_color("YELLOW")     # deprecation warnings (default: orange)
cmd.error_color("MAGENTA")   # parse errors (default: red)
```

Available colour names (case-insensitive):

| Name      | ANSI code | Preview            |
| --------- | --------- | ------------------ |
| `RED`     | 91        | bright red         |
| `GREEN`   | 92        | bright green       |
| `YELLOW`  | 93        | bright yellow      |
| `BLUE`    | 94        | bright blue        |
| `MAGENTA` | 95        | bright magenta     |
| `PINK`    | 95        | alias for MAGENTA  |
| `CYAN`    | 96        | bright cyan        |
| `WHITE`   | 97        | bright white       |
| `ORANGE`  | 33        | orange/dark yellow |

An unrecognised colour name raises an `Error` at runtime.

Padding calculation is always based on the **plain-text width** (without
escape codes), so columns remain correctly aligned regardless of whether
colour is enabled.

**What controls the output:**

| Builder method  | Effect on help                                        |
| --------------- | ----------------------------------------------------- |
| `.help("...")`  | Sets the description text for the option.             |
| `.metavar("X")` | Replaces the default placeholder (e.g., `N`, `FILE`). |
| `.choices()`    | Shows `{a,b,c}` in the placeholder.                   |
| `.hidden()`     | Completely excludes the option from help.             |
| `.required()`   | Positional args show as `<name>` instead of `[name]`. |

After printing help, the program exits cleanly with exit code 0.

---

**Show Help When No Arguments Provided**

Use `help_on_no_args()` to automatically display help when the user invokes
the command with no arguments (like `git`, `docker`, or `cargo`):

```mojo
var cmd = Command("myapp", "My application")
cmd.add_arg(Arg("file", help="Input file").long("file").required())
cmd.help_on_no_args()
var result = cmd.parse()
```

```bash
myapp          # prints help and exits
myapp --file x # normal parsing
```

This is particularly useful for commands that require arguments — instead of
showing an obscure "missing required argument" error, the user sees the
full help text.

### Version Display

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

## Parsing Behaviour

### Negative Number Passthrough

By default, tokens starting with `-` are interpreted as options. This creates a problem when you need to pass **negative numbers** (like `-9.5`, `-3.14`, `-1.5e10`) as positional values.

ArgMojo provides three complementary approaches to handle this, inspired by Python's argparse.

---

**Approach 1: Auto-detect (zero configuration)**

When no registered short option uses a **digit character** as its name, ArgMojo automatically recognises numeric-looking tokens and treats them as positional arguments instead of options.

```mojo
var cmd = Command("calc", "Calculator")
cmd.add_arg(Arg("operand", help="A number").positional().required())
```

```bash
calc -9876543        # operand = "-9876543" (auto-detected as a number)
calc -3.14           # operand = "-3.14"
calc -.5             # operand = "-.5"
calc -1.5e10         # operand = "-1.5e10"
calc -2.0e-3         # operand = "-2.0e-3"
```

This works because `-9`, `-3`, etc. do not match any registered short option. The parser sees a numeric pattern and skips the option-dispatch path.

Recognised patterns: `-N`, `-N.N`, `-.N`, `-NeX`, `-N.NeX`, `-Ne+X`, `-Ne-X` (where `N` and `X` are digit sequences).

---

**Approach 2: The `--` separator (always works)**

The `--` stop marker forces everything after it to be treated as positional. This is the most universal approach and works regardless of any configuration.

```bash
calc -- -9.5         # operand = "-9.5"
calc -- -3e4         # operand = "-3e4"
```

See [The `--` Stop Marker](#the----stop-marker) for details. When positional arguments are registered, ArgMojo's help output includes a **Tip** line reminding users about this:

```text
Tip: Use '--' to pass values that start with '-' (e.g., negative numbers):  calc -- -9.5
```

---

**Approach 3: `allow_negative_numbers()` (explicit opt-in)**

If you have a registered short option that uses a digit character (e.g., `-3` for `--triple`), the auto-detect is suppressed to avoid ambiguity. In this case, call `allow_negative_numbers()` to force all numeric-looking tokens to be treated as positionals.

```mojo
var cmd = Command("calc", "Calculator")
cmd.allow_negative_numbers()   # Explicit opt-in
cmd.add_arg(
    Arg("triple", help="Triple mode").long("triple").short("3").flag()
)
cmd.add_arg(Arg("operand", help="A number").positional().required())
```

```bash
calc --triple -3.14   # triple = True, operand = "-3.14"
calc -3               # operand = "-3" (NOT the -3 flag!)
```

> **Warning:** When `allow_negative_numbers()` is active, even a bare `-3` that exactly matches a registered short option will be consumed as a positional number. Use the long form (`--triple`) to set the flag.

---

**When to use which approach**

| Scenario                                                                  | Recommended approach               |
| ------------------------------------------------------------------------- | ---------------------------------- |
| No digit short options registered                                         | Auto-detect (nothing to configure) |
| You have digit short options (`-3`, `-5`, etc.) and need negative numbers | `allow_negative_numbers()`         |
| You need to pass arbitrary dash-prefixed strings (not just numbers)       | `--` separator                     |
| Legacy or defensive: works in all cases                                   | `--` separator                     |

---

**What is NOT a number**

Tokens like `-1abc`, `-e5`, or `-1-2` are not valid numeric patterns. They will still be parsed as short-option strings and may raise "Unknown option" errors if unregistered.

### Long Option Prefix Matching

ArgMojo supports **prefix matching** (also known as *abbreviation*) for long options. If a user types a prefix of a long option name that **unambiguously** matches exactly one registered option, it is automatically resolved.

This mirrors Python argparse's `allow_abbrev` behaviour.

---

```mojo
cmd.add_arg(Arg("verbose", help="Verbose output").long("verbose").short("v").flag())
cmd.add_arg(Arg("output",  help="Output file").long("output").short("o"))
```

```bash
myapp --verb               # resolves to --verbose
myapp --out file.txt       # resolves to --output file.txt
myapp --out=file.txt       # resolves to --output=file.txt
```

---

**Ambiguous prefixes**

If the prefix matches more than one option, an error is raised:

```mojo
cmd.add_arg(Arg("verbose",      help="Verbose").long("verbose").flag())
cmd.add_arg(Arg("version-info", help="Version info").long("version-info").flag())
```

```bash
myapp --ver
# Error: Ambiguous option '--ver' could match: '--verbose', '--version-info'
```

---

**Exact match always wins**

If the user's input is an **exact match** for one option, it is chosen even if it is also a prefix of another option:

```mojo
cmd.add_arg(Arg("color",    help="Color mode").long("color").flag())
cmd.add_arg(Arg("colorize", help="Colorize output").long("colorize").flag())
```

```bash
myapp --color       # exact match → color (not ambiguous with colorize)
myapp --col         # ambiguous → error
```

---

**Works with negatable flags**

Prefix matching also applies to `--no-X` negation:

```bash
myapp --no-col      # resolves to --no-color (if color is the only negatable match)
```

---

This feature is always enabled — no configuration needed. It is most useful for long option names where typing the full name is cumbersome:

```bash
myapp --max 5       # instead of --max-depth 5
myapp --ig          # instead of --ignore-case
```

> **Tip:** Exact long option names are always accepted. Prefix matching is a convenience that does not change the behaviour of exact matches.

### The `--` Stop Marker

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

A common use-case is passing **negative numbers** as positional arguments:

```bash
myapp -- -9.5
# pattern = "-9.5"
```

> **Tip:** ArgMojo's [Auto-detect](#negative-number-passthrough) can handle most negative-number cases without `--`. Use `--` only when auto-detect is insufficient (e.g., a digit short option is registered without `allow_negative_numbers()`).
