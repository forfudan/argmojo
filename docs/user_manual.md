# ArgMojo — User Manual <!-- omit from toc -->

> Comprehensive guide to every feature of the ArgMojo command-line argument parser.

All code examples below assume that you have imported the mojo at the top of your mojo file:

```mojo
from argmojo import Argument, Command
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
- [Builder Method Compatibility](#builder-method-compatibility)
  - [ASCII Tree](#ascii-tree)
  - [Compatibility Table](#compatibility-table)
- [Short Option Details](#short-option-details)
  - [Short Flag Merging](#short-flag-merging)
  - [Attached Short Values](#attached-short-values)
- [Flag Variants](#flag-variants)
  - [Count Flags](#count-flags)
  - [Count Ceiling (`.max[N]()`)](#count-ceiling-maxn)
  - [Negatable Flags](#negatable-flags)
- [Collecting Multiple Values](#collecting-multiple-values)
  - [Append / Collect Action](#append--collect-action)
  - [Value Delimiter](#value-delimiter)
  - [Multi-Value Options (nargs)](#multi-value-options-nargs)
  - [Key-Value Map Options](#key-value-map-options)
- [Value Validation](#value-validation)
  - [Choices Validation](#choices-validation)
  - [Positional Argument Count Validation](#positional-argument-count-validation)
  - [Numeric Range Validation](#numeric-range-validation)
  - [Range Clamping (`.clamp()`)](#range-clamping-clamp)
- [Group Constraints](#group-constraints)
  - [Mutually Exclusive Groups](#mutually-exclusive-groups)
  - [One-Required Groups](#one-required-groups)
  - [Required-Together Groups](#required-together-groups)
  - [Conditional Requirements](#conditional-requirements)
  - [Mutual Implication](#mutual-implication)
- [Subcommands](#subcommands)
  - [Defining Subcommands](#defining-subcommands)
  - [Parsing Subcommand Results](#parsing-subcommand-results)
  - [Persistent (Global) Flags](#persistent-global-flags)
  - [The help Subcommand](#the-help-subcommand)
  - [Subcommand Aliases](#subcommand-aliases)
  - [Unknown Subcommand Error](#unknown-subcommand-error)
  - [Hidden Subcommands](#hidden-subcommands)
  - [Mixing Positional Args with Subcommands](#mixing-positional-args-with-subcommands)
- [Help \& Display](#help--display)
  - [Value Name](#value-name)
  - [Hidden Arguments](#hidden-arguments)
  - [Deprecated Arguments](#deprecated-arguments)
  - [Default-if-no-value](#default-if-no-value)
  - [Require Equals Syntax](#require-equals-syntax)
  - [Argument Groups](#argument-groups)
  - [Auto-generated Help](#auto-generated-help)
  - [Custom Tips](#custom-tips)
  - [Version Display](#version-display)
  - [CJK-Aware Help Alignment](#cjk-aware-help-alignment)
  - [Full-Width → Half-Width Auto-Correction](#full-width--half-width-auto-correction)
- [Parsing Behaviour](#parsing-behaviour)
  - [Negative Number Passthrough](#negative-number-passthrough)
  - [Long Option Prefix Matching](#long-option-prefix-matching)
  - [The `--` Stop Marker](#the----stop-marker)
  - [Remainder Positional (`.remainder()`)](#remainder-positional-remainder)
  - [Allow Hyphen Values (`.allow_hyphen_values()`)](#allow-hyphen-values-allow_hyphen_values)
  - [Partial Parsing (`parse_known_arguments()`)](#partial-parsing-parse_known_arguments)
- [Interactive Prompting](#interactive-prompting)
  - [Setup Example](#setup-example)
  - [Enabling Prompting](#enabling-prompting)
  - [Interactive Session Examples](#interactive-session-examples)
    - [All arguments missing — full prompting](#all-arguments-missing--full-prompting)
    - [Partial arguments — only missing ones are prompted](#partial-arguments--only-missing-ones-are-prompted)
    - [All arguments provided — no prompting at all](#all-arguments-provided--no-prompting-at-all)
    - [Empty input with a default — default value is used](#empty-input-with-a-default--default-value-is-used)
    - [Flag argument — y/n prompt](#flag-argument--yn-prompt)
    - [Argument with choices — choices are shown](#argument-with-choices--choices-are-shown)
  - [Prompt Format](#prompt-format)
  - [Interaction with Other Features](#interaction-with-other-features)
  - [Non-Interactive Use (CI / Piped Input)](#non-interactive-use-ci--piped-input)
- [Argument Parents and Inheritance](#argument-parents-and-inheritance)
  - [Defining Shared Arguments](#defining-shared-arguments)
  - [What Gets Inherited](#what-gets-inherited)
  - [Multiple Parents](#multiple-parents)
  - [Using with Subcommands](#using-with-subcommands)
  - [Notes](#notes)
- [Password / Masked Input](#password--masked-input)
  - [Basic Usage](#basic-usage)
  - [Custom Prompt Text](#custom-prompt-text)
  - [Restrictions](#restrictions)
  - [Non-Interactive Use](#non-interactive-use)
- [Confirmation Option](#confirmation-option)
  - [Basic Usage](#basic-usage-1)
  - [Custom Prompt Text](#custom-prompt-text-1)
  - [Using with Subcommands](#using-with-subcommands-1)
  - [Non-Interactive Use](#non-interactive-use-1)
- [Usage Line Customisation](#usage-line-customisation)
- [Shell Completion](#shell-completion)
  - [Built-in `--completions` Flag](#built-in---completions-flag)
  - [Disabling the Built-in Flag](#disabling-the-built-in-flag)
  - [Customising the Trigger Name](#customising-the-trigger-name)
  - [Using a Subcommand Instead of an Option](#using-a-subcommand-instead-of-an-option)
  - [Generating a Script Programmatically](#generating-a-script-programmatically)
  - [Installing Completions](#installing-completions)
  - [What Gets Completed](#what-gets-completed)
- [Developer Validation](#developer-validation)
  - [Compile-Time Validation](#compile-time-validation)
  - [Runtime Registration Validation](#runtime-registration-validation)
  - [Recommended Workflow](#recommended-workflow)
- [Declarative API (Struct-Based)](#declarative-api-struct-based)
  - [Wrapper Types](#wrapper-types)
  - [The `Parsable` Trait](#the-parsable-trait)
  - [Pure Declarative — One-Line Parse](#pure-declarative--one-line-parse)
  - [Hybrid — Declarative + Builder Customisation](#hybrid--declarative--builder-customisation)
  - [Full Parse — Declarative + Extra Builder Fields](#full-parse--declarative--extra-builder-fields)
  - [Subcommands](#subcommands-1)
  - [Auto-Naming Convention](#auto-naming-convention)
  - [API Summary](#api-summary)
- [Cross-Library Method Name Reference](#cross-library-method-name-reference)
  - [Argument-Level Builder Methods](#argument-level-builder-methods)
  - [Command-Level Constraint Methods](#command-level-constraint-methods)
  - [Notes](#notes-1)
<!-- Response Files (temporarily disabled — Mojo compiler deadlock with -D ASSERT=all)
- [Response Files](#response-files)
  - [Enabling Response Files](#enabling-response-files)
  - [File Format](#file-format)
  - [Escaping the Prefix](#escaping-the-prefix)
  - [Recursive Response Files](#recursive-response-files)
  - [Custom Prefix](#custom-prefix)
-->

## Getting Started

### Creating a Command

A **Command** is the top-level object that holds argument definitions and runs the parser.

```mojo
def main() raises:
    var command = Command("myapp", "A short description of the program", version="1.0.0")
    # ... add arguments ...
    var result = command.parse()
```

| Parameter     | Type     | Required | Description                                      |
| ------------- | -------- | -------- | ------------------------------------------------ |
| `name`        | `String` | Yes      | Program name, shown in help text and usage line. |
| `description` | `String` | No       | One-line description shown at the top of help.   |
| `version`     | `String` | No       | Version string printed by `--version`.           |

---

**`parse()` vs `parse_arguments()`**

- **`command.parse()`** reads the real command-line via `sys.argv()`.
- **`command.parse_arguments(args)`** accepts a `List[String]` — useful for testing without a real binary. Note that `args[0]` is expected to be the program name and will be skipped, so the actual arguments should start from index 1.

### Reading Parsed Results

After calling `command.parse()` or `command.parse_arguments()`, you get a `ParseResult` with these typed accessors:

| Method                      | Returns                | Description                                           |
| --------------------------- | ---------------------- | ----------------------------------------------------- |
| `result.get_flag("name")`   | `Bool`                 | Returns `True` if the flag was set, else `False`.     |
| `result.get_string("name")` | `String`               | Returns the string value. Raises if not found.        |
| `result.get_int("name")`    | `Int`                  | Parses the value as an integer. Raises on error.      |
| `result.get_count("name")`  | `Int`                  | Returns the count (0 if never provided).              |
| `result.get_list("name")`   | `List[String]`         | Returns collected values (empty list if none).        |
| `result.get_map("name")`    | `Dict[String, String]` | Returns key-value pairs (empty dict if none).         |
| `result.has("name")`        | `Bool`                 | Returns `True` if the argument was provided.          |
| `result.print_summary()`    | `None`                 | Prints a human-readable summary of all parsed values. |

**`get_string()`** works for both named options and positional arguments — positional values are looked up by the name given in `Argument("name", ...)`.

```mojo
var result = command.parse()

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
command.add_argument(Argument("pattern", help="Search pattern").positional().required())
command.add_argument(Argument("path",    help="Search path").positional().default["."]())
```

```bash
myapp "hello" ./src
#       ↑        ↑
#     pattern   path
```

Positional arguments are assigned in the order they are registered with `add_argument()`. If fewer values are provided than defined arguments, the remaining ones use their default values (if any). If more are provided, an error is raised (see [Positional Argument Count Validation](#positional-argument-count-validation)).

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
command.add_argument(Argument("output", help="Output file").long["output"]())
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
command.add_argument(
    Argument("output", help="Output file").long["output"]().short["o"]()
)
```

```bash
myapp -o result.txt          # space-separated
myapp -oresult.txt           # attached value (see §9)
```

A short name is typically defined alongside a long name, but can also be used alone.

> **Compile-time validation.** Both `.long["x"]()` and `.short["x"]()` accept
> a `StringLiteral` parameter.  `.short` enforces that the name is exactly one
> character; `.long` enforces that the name is non-empty and does not start
> with `-`.  Invalid names are caught at compile time — the program will not
> compile.

### Boolean Flags

A **flag** is a boolean option that takes no value. It is `False` by default and becomes `True` when present.

```mojo
command.add_argument(
    Argument("verbose", help="Enable verbose output")
    .long["verbose"]().short["v"]().flag()
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
command.add_argument(
    Argument("format", help="Output format")
    .long["format"]().short["f"]().default["table"]()
)
command.add_argument(
    Argument("path", help="Search path").positional().default["."]()
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
command.add_argument(
    Argument("pattern", help="Search pattern").positional().required()
)
```

```bash
myapp "hello"   # OK
myapp           # Error: Required argument 'pattern' was not provided
```

Typically used for positional arguments. Named options can also be marked required.

### Aliases

Register alternative long names for an argument with `.alias_name[]()`. The alias
is validated at compile time (same rules as `.long[]()`: not empty, no `-` prefix,
no `=`).  Chain multiple calls for several aliases.

```mojo
command.add_argument(
    Argument("colour", help="Colour theme")
        .long["colour"]()
        .alias_name["color"]()
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

Multiple aliases are supported by chaining:

```mojo
command.add_argument(
    Argument("output", help="Output format")
        .long["output"]()
        .alias_name["out"]().alias_name["fmt"]()
)
```

## Builder Method Compatibility

The `Argument` builder has 27 chainable methods, and the `Command` struct has additional configuration methods and constraint methods. Not all combinations make sense. The diagrams below show **which methods can be used together** at a glance.

### ASCII Tree

```txt
Argument("name", help="...")
║
╠══ Named option ═══════════════════════════════════════════════════════════════
║   .long["x"]() ─── .short["x"]()             ← pick one or both
║   │
║   ├── [value mode] (default)             ← takes a string value
║   │   ├── .required()
║   │   ├── .default["val"]()
║   │   ├── .choice["a"]().choice["b"]().choice["c"]()
║   │   ├── .range[1, 100]() ─── .clamp()
║   │   ├── .append()
║   │   │   ├── .delimiter[","]()
║   │   │   └── .number_of_values[2]()
║   │   ├── .map_option()
║   │   └── .allow_hyphen_values()               accept -x as a value, not option
║   │
║   ├── .flag()                            ← boolean, no value
║   │   └── .negatable()                     adds --no-X form
║   │
║   └── .count()                           ← counter: -vvv → 3
║       └── .max[3]()                        cap the counter
║
╠══ Positional ═════════════════════════════════════════════════════════════════
║   .positional()                          ← matched by position
║   ├── .required()
║   ├── .default["val"]()
║   ├── .choice["a"]().choice["b"]().choice["c"]()
║   ├── .allow_hyphen_values()               accept -x as a value, not option
║   └── .remainder()                         consume ALL remaining tokens
║       └── (implies .allow_hyphen_values())
║
╠══ Decorators (combine with any path above) ═══════════════════════════════════
║   .value_name["FILE"]()                       display name in help      (value / positional)
║   └── [wrapped=False]                         wrap in <> (default); [False] = bare
║   .group["Network"]()                         section heading in help
║                                               (named options only; ignored for positionals)
║   .hidden()                                   hide from --help          (any)
║   .alias_name["alt"]().alias_name["other"]()  alternative --names       (named only)
║   .deprecated["msg"]()                        deprecation warning       (any)
║   .persistent()                               inherit to subcommands    (named only)
║   .default_if_no_value["val"]()               default-if-no-value       (value only)
║   .require_equals()                           force --key=value syntax  (named value only)
║   .prompt()                                   prompt interactively      (any)
║   .prompt["msg"]()                            custom prompt message     (any; implies .prompt())
║   .password()                                 hide input during prompt  (value / positional only)
║
╠══ Command-level constraints (called on Command, not Argument) ════════════════
║   command.mutually_exclusive(["a","b"])  at most one from the group
║   command.one_required(["a","b"])        at least one from the group
║   command.required_together(["a","b"])   all or none from the group
║   command.required_if("target","cond")   target required when cond is set
║   command.implies("trigger","implied")   auto-set implied when trigger is set
║
╠══ Command-level configuration (called on Command) ════════════════════════════
║   command.help_on_no_arguments()                show help when invoked with no args
║   command.allow_negative_numbers()              negative tokens treated as positionals
║   command.allow_positional_with_subcommands()   allow positionals + subcommands
║   command.add_tip("...")                        custom tip shown in help footer
║   command.command_aliases(["co"])               alternate names for this subcommand
║   command.hidden()                              hide subcommand from help/completions
║   command.disable_help_subcommand()             opt out of auto-added help subcommand
║   ├── Colour customisation
║   │   command.header_color["CYAN"]()            section header colour
║   │   command.arg_color["GREEN"]()              argument name colour
║   │   command.warn_color["YELLOW"]()            deprecation warning colour
║   │   command.error_color["RED"]()              error message colour
║   ├── Shell completion
║   │   command.disable_default_completions()     disable built-in --completions
║   │   command.completions_name("name")          custom trigger name
║   │   command.completions_as_subcommand()       expose as subcommand instead
║   ├── Response files
║   │   command.response_file_prefix("@")         enable @args.txt expansion ⁵
║   │   command.response_file_max_depth[10]()     max recursive nesting depth ⁵
║   ├── CJK / i18n
║   │   command.disable_fullwidth_correction()    disable fullwidth→halfwidth auto-fix
║   │   command.disable_punctuation_correction()  disable CJK punctuation correction
║   ├── Argument inheritance
║   │   command.add_parent(parent)                copy arguments from a parent command
║   ├── Confirmation
║   │   command.confirmation_option()             add --yes/-y confirmation prompt
║   │   command.confirmation_option["text"]()     custom confirmation prompt text
║   └── Usage
║       command.usage("...")                      override the auto-generated usage line
╚═══════════════════════════════════════════════════════════════════════════════
```

> **Reading guide:** Indentation shows "goes after" — e.g. `.clamp()` is
> indented under `.range[min,max]()` because it requires range.  The three main
> paths (value / flag / count) under *Named option* are **mutually
> exclusive** — pick exactly one mode per argument.  Command-level methods
> are called on `Command`, not chained on `Argument`.

### Compatibility Table

The table below shows which builder methods can be used with each argument mode. **✓** = compatible, **—** = not applicable.

| Method                            | Named value | `.flag()` | `.count()` | `.positional()` |
| --------------------------------- | :---------: | :-------: | :--------: | :-------------: |
| `.long["x"]()`                    |      ✓      |     ✓     |     ✓      |        —        |
| `.short["x"]()`                   |      ✓      |     ✓     |     ✓      |        —        |
| `.required()`                     |      ✓      |     ✓     |     ✓      |        ✓        |
| `.default["val"]()`               |      ✓      |     —     |     —      |        ✓        |
| `.choice["a"]().choice["b"]()`    |      ✓      |     —     |     —      |        ✓        |
| `.range[min,max]()`               |      ✓      |     —     |     —      |        —        |
| `.clamp()`                        |     ✓ ¹     |     —     |     —      |        —        |
| `.append()`                       |      ✓      |     —     |     —      |        —        |
| `.delimiter[","]()`               |     ✓ ²     |     —     |     —      |        —        |
| `.number_of_values[N]()`          |     ✓ ²     |     —     |     —      |        —        |
| `.map_option()`                   |      ✓      |     —     |     —      |        —        |
| `.negatable()`                    |      —      |     ✓     |     —      |        —        |
| `.max[N]()`                       |      —      |     —     |     ✓      |        —        |
| `.value_name["FILE"]()` ⁴         |      ✓      |     —     |     —      |        ✓        |
| `.group["name"]()`                |      ✓      |     ✓     |     ✓      |        —        |
| `.hidden()`                       |      ✓      |     ✓     |     ✓      |        ✓        |
| `.alias_name["alt"]()`            |      ✓      |     ✓     |     ✓      |        —        |
| `.deprecated["msg"]()`            |      ✓      |     ✓     |     ✓      |        ✓        |
| `.persistent()`                   |      ✓      |     ✓     |     ✓      |        —        |
| `.default_if_no_value["val"]()`   |      ✓      |     —     |     —      |        —        |
| `.allow_hyphen_values()`          |      ✓      |     —     |     —      |        ✓        |
| `.remainder()`                    |      —      |     —     |     —      |        ✓        |
| `.prompt()`                       |      ✓      |     ✓     |     ✓      |        ✓        |
| `.prompt["msg"]()`                |      ✓      |     ✓     |     ✓      |        ✓        |
| `.password()`                     |      ✓      |     —     |     —      |        ✓        |
| `.require_equals()`               |      ✓      |     —     |     —      |        —        |
| `command.mutually_exclusive()` ³  |      ✓      |     ✓     |     ✓      |        —        |
| `command.one_required()` ³        |      ✓      |     ✓     |     ✓      |        —        |
| `command.required_together()` ³   |      ✓      |     ✓     |     ✓      |        —        |
| `command.required_if()` ³         |      ✓      |     ✓     |     ✓      |        —        |
| `command.implies()` ³             |      ✓      |     ✓     |     ✓      |        —        |
| `command.add_parent()` ³          |      ✓      |     ✓     |     ✓      |        ✓        |
| `command.confirmation_option()` ³ |      —      |     —     |     —      |        —        |
| `command.usage()` ³               |      —      |     —     |     —      |        —        |

> ¹ Requires `.range[min,max]()` first.  ² Implies `.append()` automatically.  ³ Command-level method — called on `Command`, not chained on `Argument`.  ⁴ Accepts compile-time parameter: `.value_name[wrapped: Bool = True]("NAME")` — `True` wraps in `<NAME>`, `False` displays bare `NAME`.  ⁵ Response files temporarily disabled due to Mojo compiler bug.

## Short Option Details

### Short Flag Merging

When multiple short options are **boolean flags**, they can be combined into a single `-` token.

```mojo
command.add_argument(Argument("all",       help="Show all").long["all"]().short["a"]().flag())
command.add_argument(Argument("brief",     help="Brief mode").long["brief"]().short["b"]().flag())
command.add_argument(Argument("colorize",  help="Colorize").long["colorize"]().short["c"]().flag())
```

```bash
myapp -abc
# Expands to: -a -b -c
# all = True, brief = True, colorize = True
```

**Mixing flags with a value-taking option:** The last character in a merged group can take a value (the rest of the token or the next argument):

```mojo
command.add_argument(Argument("output", help="Output file").long["output"]().short["o"]())
```

```bash
myapp -abofile.txt
# Expands to: -a -b -o file.txt
# all = True, brief = True, output = "file.txt"
```

### Attached Short Values

A short option that takes a value can have its value **attached directly** — no space needed.

```mojo
command.add_argument(Argument("output", help="Output file").long["output"]().short["o"]())
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
command.add_argument(
    Argument("verbose", help="Increase verbosity (-v, -vv, -vvv)")
    .long["verbose"]().short["v"]().count()
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

### Count Ceiling (`.max[N]()`)

You can cap a count flag at a maximum value with `.max[n]()`. The ceiling value `n` is a compile-time parameter (must be ≥ 1); invalid values are caught at build time. Any occurrences beyond the ceiling are clamped to the maximum and a warning is printed to stderr informing the user of the adjustment.

```mojo
command.add_argument(
    Argument("verbose", help="Increase verbosity (capped at 3)")
    .long["verbose"]().short["v"]().count().max[3]()
)
```

```bash
myapp -vvv           # verbose = 3
myapp -vvvvv         # verbose = 3  (capped, warning printed)
myapp -vvvvvvvvvv    # verbose = 3  (capped, warning printed)
myapp -vv            # verbose = 2  (below ceiling, not affected)
```

The warning looks like:

```bash
warning: '--verbose' count 5 exceeds maximum 3, capped to 3
```

This is useful when verbosity levels above a certain threshold have no additional effect, or to prevent accidental over-counting. From users' perspective, they get a clear warning rather than a hard error, which is friendlier than using the count option without a ceiling and silently ignoring extra occurrences.

### Negatable Flags

A **negatable** flag automatically creates a `--no-X` counterpart. When the user passes `--X`, the flag is set to `True`; when they pass `--no-X`, it is explicitly set to `False`.

This replaces the manual pattern of defining two separate flags (`--color` and `--no-color`) and a mutually exclusive group.

---

**Defining a negatable flag**

```mojo
command.add_argument(
    Argument("color", help="Enable colored output")
    .long["color"]().flag().negatable()
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
command.add_argument(Argument("color", help="Force colored output").long["color"]().flag())
command.add_argument(Argument("no-color", help="Disable colored output").long["no-color"]().flag())
var group: List[String] = ["color", "no-color"]
command.mutually_exclusive(group^)
```

**After (single negatable flag):**

```mojo
command.add_argument(
    Argument("color", help="Enable colored output")
    .long["color"]().flag().negatable()
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
command.add_argument(
    Argument("tag", help="Add a tag (repeatable)")
    .long["tag"]().short["t"]().append()
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

If a value name is set, it replaces the default placeholder:

```mojo
command.add_argument(
    Argument("include", help="Include path").long["include"]().short["I"]().value_name["DIR"]().append()
)
```

```text
  -I, --include DIR...          Include path
```

---

**Combining with choices**

Choices validation is applied to each individual value:

```mojo
command.add_argument(
    Argument("env", help="Target environment")
    .long["env"]().choice["dev"]().choice["staging"]().choice["prod"]().append()
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
command.add_argument(
    Argument("env", help="Target environments")
    .long["env"]().short["e"]().delimiter[","]()
)
```

Calling `.delimiter[","]()` automatically implies `.append()` — you do not need to call both.

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
command.add_argument(
    Argument("env", help="Target environments")
    .long["env"]().choice["dev"]().choice["staging"]().choice["prod"]().delimiter[","]()
)
```

```bash
myapp --env dev,prod       # OK
myapp --env dev,local      # Error: Invalid value 'local' for argument 'env'
```

---

**Other delimiters**

The allowed delimiters are `,` `;` `:` `|`. When fullwidth correction is enabled (the default), fullwidth equivalents in user input (e.g. `，` `；` `：` `｜`) are auto-corrected before splitting:

```mojo
command.add_argument(
    Argument("path", help="Search paths")
    .long["path"]().delimiter[";"]()
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
command.add_argument(
    Argument("tag", help="Tags").long["tag"]().short["t"]().append().delimiter[","]()
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

Use `.number_of_values[N]()` to specify how many values the option consumes:

```mojo
command.add_argument(Argument("point", help="X Y coordinates").long["point"]().number_of_values[2]())
command.add_argument(Argument("rgb", help="RGB colour").long["rgb"]().short["c"]().number_of_values[3]())
```

`.number_of_values[N]()` automatically implies `.append()` — values are
retrieved with `get_list()`.

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
var result = command.parse()
var coords = result.get_list("point")
# coords[0] = "10", coords[1] = "20"
```

---

**Choices validation**

Choices are validated for **each** value individually:

```mojo
command.add_argument(
    Argument("route", help="Start and end").long["route"]().number_of_values[2]()
    .choice["north"]().choice["south"]().choice["east"]().choice["west"]()
)
```

```bash
myapp --route north east    # ✓ both valid
myapp --route north up      # ✗ 'up' is not a valid choice
```

---

**Help output**

nargs options show the placeholder repeated N times:

```txt
Options:
  --point <point> <point>    X Y coordinates
  --rgb N N N                RGB colour        (with .value_name["N"]())
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
command.add_argument(
    Argument("define", help="Define a variable")
        .long["define"]()
        .short["D"]()
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

**Delimiter** — combine with `.delimiter[","]()` to pass multiple
key-value pairs in a single token:

```mojo
command.add_argument(
    Argument("define", help="Define vars")
        .long["define"]()
        .map_option()
        .delimiter[","]()
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
command.add_argument(
    Argument("log-level", help="Log level")
    .long["log-level"]().choice["debug"]().choice["info"]().choice["warn"]().choice["error"]().default["info"]()
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

### Positional Argument Count Validation

ArgMojo ensures that the user does not provide more positional arguments than defined. Extra positional values trigger an error.

```mojo
command.add_argument(Argument("pattern", help="Search pattern").positional().required())
# Only 1 positional arg is defined.
```

```bash
myapp "hello"                  # OK
myapp "hello" extra1 extra2    # Error: Too many positional arguments: expected 1, got 3
```

With two positional args defined:

```mojo
command.add_argument(Argument("pattern", help="Search pattern").positional().required())
command.add_argument(Argument("path",    help="Search path").positional().default["."]())
```

```bash
myapp "hello" ./src            # OK — pattern = "hello", path = "./src"
myapp "hello" ./src /tmp       # Error: Too many positional arguments: expected 2, got 3
```

### Numeric Range Validation

Constrain a numeric argument to an inclusive `[min, max]` range
with `.range[min, max]()`.  The validation is applied after parsing,
so the value is still stored as a string; `atol()` is used internally
to convert and compare.

```mojo
command.add_argument(
    Argument("port", help="Listening port")
        .long["port"]()
        .range[1, 65535]()
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
`.delimiter[","]()`, every collected value is validated individually:

```mojo
command.add_argument(
    Argument("port", help="Ports").long["port"]().append().range[1, 100]()
)
```

```bash
myapp --port 50 --port 101
# Error: Value 101 for '--port' is out of range [1, 100]
```

### Range Clamping (`.clamp()`)

By default, an out-of-range value causes a hard error. If you prefer a gentler approach, chain `.clamp()` after `.range[min, max]()` to **adjust** the value to the nearest boundary and print a warning instead of failing.

```mojo
command.add_argument(
    Argument("level", help="Compression level (0–9)")
        .long["level"]()
        .range[0, 9]()
        .clamp()
)
```

```bash
myapp --level 5      # OK — level = 5
myapp --level 20     # Warning, level = 9  (clamped to max)
myapp --level -3     # Warning, level = 0  (clamped to min)
```

The warning looks like:

```bash
warning: '--level' value 20 is out of range [0, 9], clamped to 9
```

---

**With append mode** — each collected value is clamped individually:

```mojo
command.add_argument(
    Argument("port", help="Ports").long["port"]().append().range[1, 100]().clamp()
)
```

```bash
myapp --port 50 --port 200 --port 0
# warning: '--port' value 200 is out of range [1, 100], clamped to 100
# warning: '--port' value 0 is out of range [1, 100], clamped to 1
# Result: ports = [50, 100, 1]
```

---

**Without `.clamp()`** — the existing behaviour is unchanged; an out-of-range value raises an error:

```bash
myapp --port 200
# Error: Value 200 for '--port' is out of range [1, 100]
```

## Group Constraints

### Mutually Exclusive Groups

**Mutually exclusive** means "at most one of these arguments may be provided". If the user supplies two or more arguments from the same group, parsing fails.

This is useful when two options are logically contradictory, such as `--json` vs `--yaml` (you can only pick one output format), or `--color` vs `--no-color`.

---

**Defining a group**

```mojo
command.add_argument(Argument("json", help="Output as JSON").long["json"]().flag())
command.add_argument(Argument("yaml", help="Output as YAML").long["yaml"]().flag())
command.add_argument(Argument("csv",  help="Output as CSV").long["csv"]().flag())

var group: List[String] = ["json", "yaml", "csv"]
command.mutually_exclusive(group^)
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
command.add_argument(Argument("input", help="Read from file").long["input"]())
command.add_argument(Argument("stdin", help="Read from stdin").long["stdin"]().flag())

var io_group: List[String] = ["input", "stdin"]
command.mutually_exclusive(io_group^)
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
command.mutually_exclusive(format_group^)

var color_group: List[String] = ["color", "no-color"]
command.mutually_exclusive(color_group^)
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
command.add_argument(Argument("json", help="Output as JSON").long["json"]().flag())
command.add_argument(Argument("yaml", help="Output as YAML").long["yaml"]().flag())
var format_group: List[String] = ["json", "yaml"]
command.one_required(format_group^)
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
command.add_argument(Argument("json", help="Output as JSON").long["json"]().flag())
command.add_argument(Argument("yaml", help="Output as YAML").long["yaml"]().flag())

var excl: List[String] = ["json", "yaml"]
var req: List[String] = ["json", "yaml"]
command.mutually_exclusive(excl^)
command.one_required(req^)
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
command.add_argument(Argument("input", help="Input file").long["input"]().short["i"]())
command.add_argument(Argument("stdin", help="Read from stdin").long["stdin"]().flag())
command.one_required(["input", "stdin"])
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
command.one_required(["json", "yaml"])
command.one_required(["input", "stdin"])
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
command.add_argument(Argument("username", help="Auth username").long["username"]().short["u"]())
command.add_argument(Argument("password", help="Auth password").long["password"]().short["p"]())

var group: List[String] = ["username", "password"]
command.required_together(group^)
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
command.add_argument(Argument("host",  help="Host").long["host"]())
command.add_argument(Argument("port",  help="Port").long["port"]())
command.add_argument(Argument("proto", help="Protocol").long["proto"]())

var net_group: List[String] = ["host", "port", "proto"]
command.required_together(net_group^)
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
command.required_together(auth^)

# These two cannot appear together
var excl: List[String] = ["json", "yaml"]
command.mutually_exclusive(excl^)
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
command.add_argument(Argument("save", help="Save results").long["save"]().flag())
command.add_argument(Argument("output", help="Output file").long["output"]().short["o"]())
command.required_if("output", "save")
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
command.required_if("output", "save")       # --output required when --save
command.required_if("format", "compress")   # --format required when --compress
```

Each rule is checked independently after parsing.

---

**Error messages**

Error messages use `--long` display names when available:

```bash
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

### Mutual Implication

Use `implies()` to declare that setting one argument automatically sets another. This is useful when one mode logically entails another — for example, debug mode should always enable verbose output.

---

```mojo
command.add_argument(Argument("debug", help="Debug mode").long["debug"]().flag())
command.add_argument(Argument("verbose", help="Verbose output").long["verbose"]().short["v"]().flag())
command.implies("debug", "verbose")
```

This means: **if `--debug` is provided, `--verbose` is automatically set too.**

```bash
myapp --debug          # OK — --verbose is auto-set
myapp --debug -v       # OK — --verbose already set, no conflict
myapp --verbose        # OK — --debug is NOT set (one-directional)
myapp                  # OK — neither set
```

---

**Chained implications**

Implications can be chained. If A implies B and B implies C, then setting A will also set C:

```mojo
command.implies("debug", "verbose")
command.implies("verbose", "log")
# --debug → --verbose → --log (all three are set)
```

---

**Multiple implications from one trigger**

A single argument can imply multiple targets:

```mojo
command.implies("debug", "verbose")
command.implies("debug", "log")
# --debug sets both --verbose and --log
```

---

**Works with count arguments**

When the implied argument is a count (`.count()`), it is set to 1 if not already present. Explicit counts are preserved:

```mojo
command.add_argument(Argument("verbose", help="Verbosity").long["verbose"]().short["v"]().count())
command.implies("debug", "verbose")
# --debug        → verbose count = 1
# --debug -vvv   → verbose count = 3 (explicit value kept)
```

---

**Cycle detection**

Circular implications are detected at registration time and raise an error:

```mojo
command.implies("a", "b")
command.implies("b", "a")   # Error: cycle detected
```

This also catches indirect cycles (A → B → C → A).

---

**Integration with other constraints**

Implications are applied *after* defaults and *before* validation, so implied arguments participate in all subsequent constraint checks:

```mojo
command.implies("debug", "verbose")
command.required_if("output", "verbose")
# --debug implies --verbose, which triggers the conditional requirement for --output
```

```mojo
command.implies("debug", "verbose")
var excl: List[String] = ["verbose", "quiet"]
command.mutually_exclusive(excl^)
# --debug --quiet fails: --debug implies --verbose, which conflicts with --quiet
```

---

| Scenario                  | Example                                                        |
| ------------------------- | -------------------------------------------------------------- |
| Debug enables verbose     | `implies("debug", "verbose")`                                  |
| Verbose enables logging   | `implies("verbose", "log")`                                    |
| Strict enables all checks | `implies("strict", "lint")` + `implies("strict", "typecheck")` |

> **Difference from `required_if()`:** `required_if()` *requires* the
> user to provide the target argument — parsing fails if they don't.
> `implies()` *automatically sets* the target — no user action needed.

## Subcommands

Subcommands (`app <subcommand> [args]`) let you group related functionality under a single binary — similar to `git commit`, `docker run`, or `cargo build`. In ArgMojo, a subcommand is simply another `Command` instance registered on the parent.

### Defining Subcommands

Register subcommands with `add_subcommand()`. Each subcommand has its own set of arguments, help text, and validation rules.

```mojo
var app = Command("app", "My CLI tool", version="1.0.0")
app.add_argument(Argument("verbose", help="Verbose output").long["verbose"]().short["v"]().flag())

var search = Command("search", "Search for patterns")
search.add_argument(Argument("pattern", help="Search pattern").positional().required())
search.add_argument(Argument("max-depth", help="Max depth").long["max-depth"]().short["d"]().value_name["N"]())

var init = Command("init", "Initialise a new project")
init.add_argument(Argument("name", help="Project name").positional().required())

app.add_subcommand(search^)
app.add_subcommand(init^)

var result = app.parse()
```

```bash
app search "fn main" --max-depth 3
app init my-project
```

---

**Root-level flags before the subcommand token** are parsed as part of the root command:

```bash
app --verbose search "fn main"
# verbose = True (root flag), subcommand = "search"
```

---

**Help output** — when subcommands are registered, the root help automatically includes a **Commands** section and the usage line shows `<COMMAND>`:

```text
My CLI tool

Usage: app <COMMAND> [OPTIONS]

Options:
  -v, --verbose    Verbose output
  -h, --help       Show this help message
  -V, --version    Show version

Commands:
  search    Search for patterns
  init      Initialise a new project
```

---

**Child help** shows the full command path in the usage line:

```bash
app search --help
```

```text
Search for patterns

Usage: app search <pattern> [OPTIONS]

Arguments:
  pattern    Search pattern

Options:
  -d, --max-depth N    Max depth
  -h, --help           Show this help message
  -V, --version        Show version
```

---

**The `--` stop marker** prevents subcommand dispatch. After `--`, all tokens become positional arguments for the root command:

```bash
app -- search
# "search" is a root positional, NOT a subcommand dispatch
```

### Parsing Subcommand Results

After parsing, check `result.subcommand` to see which subcommand was selected, and use `result.get_subcommand_result()` to access the child's parsed values.

```mojo
var result = app.parse()

if result.subcommand == "search":
    var sub = result.get_subcommand_result()
    var pattern = sub.get_string("pattern")
    var depth = sub.get_int("max-depth") if sub.has("max-depth") else 10
    print("Searching for:", pattern)

elif result.subcommand == "init":
    var sub = result.get_subcommand_result()
    var name = sub.get_string("name")
    print("Initialising project:", name)
```

| Method / Field                   | Returns       | Description                                  |
| -------------------------------- | ------------- | -------------------------------------------- |
| `result.subcommand`              | `String`      | Name of selected subcommand (empty if none). |
| `result.has_subcommand_result()` | `Bool`        | `True` if a subcommand was dispatched.       |
| `result.get_subcommand_result()` | `ParseResult` | The child command's parsed result.           |

All standard `ParseResult` methods (`get_flag()`, `get_string()`, `get_int()`, `get_list()`, `get_map()`, `get_count()`, `has()`) work on the subcommand result.

### Persistent (Global) Flags

A **persistent** flag is declared on the parent command but is automatically available in every subcommand. The user can place it either **before** or **after** the subcommand token — both work identically.

This is inspired by Go cobra's `PersistentFlags()` and is useful for cross-cutting concerns like verbosity, output format, or colour control.

---

**Defining persistent flags**

```mojo
var app = Command("app", "My app")

# These are available everywhere
app.add_argument(
    Argument("verbose", help="Verbose output")
    .long["verbose"]().short["v"]().flag().persistent()
)
app.add_argument(
    Argument("output", help="Output format")
    .long["output"]().short["o"]()
    .choice["json"]().choice["text"]().choice["yaml"]()
    .default["text"]()
    .persistent()
)

var search = Command("search", "Search for patterns")
search.add_argument(Argument("pattern", help="Pattern").positional().required())
app.add_subcommand(search^)
```

---

**Both positions work**

```bash
app --verbose search "fn main"     # flag BEFORE subcommand
app search --verbose "fn main"     # flag AFTER subcommand  (same result)
app -v search -o json "fn main"    # short forms work too
```

---

**Bidirectional sync** — persistent flag values are synchronised between root and child results, regardless of where the user places them:

```mojo
var result = app.parse()
var sub = result.get_subcommand_result()

# Both see the same value, no matter where the flag was placed
print(result.get_flag("verbose"))   # True
print(sub.get_flag("verbose"))      # True
```

---

**Help output** — persistent flags appear under a separate **Global Options** heading in both root and child help:

```text
# Root help (app --help)
Options:
  -h, --help       Show this help message
  -V, --version    Show version

Global Options:
  -v, --verbose               Verbose output
  -o, --output {json,text,yaml}    Output format

# Child help (app search --help)
Options:
  -h, --help    Show this help message
  -V, --version Show version

Global Options:
  -v, --verbose               Verbose output
  -o, --output {json,text,yaml}    Output format
```

---

**Conflict detection** — if a persistent flag on the parent has the same long or short name as a local flag on a child, `add_subcommand()` raises an error at registration time:

```mojo
var app = Command("app", "My app")
app.add_argument(Argument("verbose", help="Verbose").long["verbose"]().short["v"]().flag().persistent())

var sub = Command("sub", "A child")
sub.add_argument(Argument("verbose", help="Also verbose").long["verbose"]().flag())  # conflict!

app.add_subcommand(sub^)  # raises: Persistent flag '--verbose' on 'app'
                           #         conflicts with '--verbose' on subcommand 'sub'
```

Non-persistent root flags with the same name as child flags do **not** conflict — they are independent and scoped to their own command.

---

**All argument types** can be made persistent — flags, count flags, value options, choices, etc.:

```mojo
app.add_argument(
    Argument("log-level", help="Log level")
    .long["log-level"]().choice["debug"]().choice["info"]().choice["warn"]().choice["error"]()
    .default["info"]().persistent()
)
```

### The help Subcommand

When you call `add_subcommand()` for the first time, ArgMojo automatically registers a `help` subcommand. This mirrors the behaviour of `git help`, `cargo help`, and `kubectl help`.

```bash
app help search    # equivalent to: app search --help
app help init      # equivalent to: app init --help
app help           # shows root help (same as: app --help)
```

The auto-registered `help` subcommand is excluded from the **Commands** section in help output to avoid clutter.

---

**Disabling the help subcommand**

If you don't want the auto-registered `help` subcommand (e.g., you want to use `help` as a real subcommand name), call `disable_help_subcommand()`:

```mojo
app.disable_help_subcommand()
```

This can be called before or after `add_subcommand()`. If called after, the auto-added `help` entry is removed.

### Subcommand Aliases

You can register short aliases for subcommands with `command_aliases()`. When the user types an alias, ArgMojo dispatches to the canonical subcommand and stores the **canonical name** (not the alias) in `result.subcommand`.

```mojo
var clone = Command("clone", "Clone a repository")
var aliases: List[String] = ["cl"]
clone.command_aliases(aliases^)
app.add_subcommand(clone^)
```

```bash
app cl https://example.com/repo.git   # dispatches to "clone"
app clone https://example.com/repo.git # still works
```

```mojo
var result = app.parse()
print(result.subcommand)  # always "clone", even if user typed "cl"
```

Aliases appear in help output alongside the primary name:

```
Commands:
  clone, cl    Clone a repository
  commit, ci   Record changes to the repository
```

Aliases are also included in shell-completion scripts and typo suggestions.

### Unknown Subcommand Error

When the root command has subcommands registered **and `allow_positional_with_subcommands()` has not been called**, an unrecognised token triggers an error listing available commands:

```bash
app foobar
# error: app: Unknown command 'foobar'. Available commands: search, init
```

The error message excludes the auto-registered `help` subcommand and hidden subcommands from the list.

If the command has opted in via `allow_positional_with_subcommands()`, unknown tokens are treated as positionals rather than triggering this error.

### Hidden Subcommands

A **hidden** subcommand is fully functional but excluded from user-facing surfaces:

- `--help` output (the `Commands:` section and usage line)
- Shell completion scripts (bash, zsh, fish)
- "Available commands" error messages
- Typo suggestions

The subcommand remains dispatchable by its exact name or alias. This is useful for internal, experimental, or deprecated commands.

```mojo
var app = Command("myapp", "My application")

var debug = Command("debug", "Internal diagnostics")
debug.hidden()                          # mark as hidden
app.add_subcommand(debug^)

var search = Command("search", "Search for items")
app.add_subcommand(search^)

# 'debug' won't appear in --help or completions, but:
#   myapp debug ...   still works
```

Hidden subcommand aliases also remain functional:

```mojo
var debug = Command("debug", "Internal diagnostics")
debug.hidden()
var aliases: List[String] = ["dbg"]
debug.command_aliases(aliases^)
app.add_subcommand(debug^)
# myapp dbg   still dispatches to debug
```

### Mixing Positional Args with Subcommands

By default, ArgMojo **prevents** mixing positional arguments and subcommands on the same command. This follows the convention of major CLI frameworks (cobra, clap, Click) — mixing the two creates ambiguity about whether an unknown token is a misspelt subcommand or a positional value.

```mojo
var app = Command("app", "My app")
app.add_subcommand(Command("search", "Search"))
app.add_argument(Argument("query", help="Query").positional())  # raises!
```

The same guard triggers if you add a subcommand to a command that already has positional arguments:

```mojo
var app = Command("app", "My app")
app.add_argument(Argument("file", help="File").positional())
app.add_subcommand(Command("init", "Init"))  # raises!
```

If you genuinely need both (e.g., `--` stopping dispatch so the subcommand name becomes a positional), call `allow_positional_with_subcommands()` before adding either:

```mojo
var app = Command("app", "My app")
app.allow_positional_with_subcommands()
app.add_subcommand(Command("search", "Search"))
app.add_argument(Argument("fallback", help="Fallback").positional())

# "foo" doesn't match any subcommand → treated as positional
var args: List[String] = ["app", "foo"]
var result = app.parse_arguments(args)
print(result.get_string("fallback"))  # "foo"
```

Please seriously **think twice** before doing this — it's usually better to design your CLI with a clear separation between subcommands and positionals. Allowing both on the same command can lead to confusing user experiences and error messages.

---

**Error path prefix** — errors inside child parsing include the full command path for clarity:

```bash
app search --unknown-flag
# error: app search: Unknown option '--unknown-flag'
```

This makes it immediately clear which subcommand triggered the error, especially in deeply nested command trees.

## Help & Display

### Value Name

**Value name** overrides the placeholder text shown for a value in help output. Without it, the argument's internal name is shown in angle brackets (e.g., `<output>`).

By default, custom value names are also wrapped in angle brackets, matching the convention used by clap, cargo, pixi, and git. To display a bare value name without brackets, pass `wrapped=False` as a compile-time parameter.

> Libraries with similar support: **argparse** (`metavar`), **clap** (`value_name`), **cobra** (`metavar`), **Click** (`metavar`).

```mojo
command.add_argument(
    Argument("output", help="Output file path")
    .long["output"]().short["o"]().value_name["FILE"]()
)
command.add_argument(
    Argument("max-depth", help="Maximum directory depth")
    .long["max-depth"]().short["d"]().value_name["N"]()
)
```

**Help output (before):**

```bash
  -o, --output <output>       Output file path
  -d, --max-depth <max-depth> Maximum directory depth
```

**Help output (after `.value_name()` — wrapped by default):**

```bash
  -o, --output <FILE>         Output file path
  -d, --max-depth <N>         Maximum directory depth
```

**Unwrapped value name** — pass `False` to suppress the angle brackets:

```mojo
command.add_argument(
    Argument("point", help="A 3D coordinate")
    .long["point"]().number_of_values[3]().value_name["COORD", False]()
)
```

```bash
      --point COORD COORD COORD    A 3D coordinate
```

Value name is purely cosmetic — it has no effect on parsing.

### Hidden Arguments

A **hidden** argument is fully functional but excluded from the `--help` output. Useful for internal, deprecated, or debug-only options.

```mojo
command.add_argument(
    Argument("debug-index", help="Dump internal search index")
    .long["debug-index"]().flag().hidden()
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

Mark an argument as deprecated with `.deprecated["message"]()`.
The argument still works normally, but a warning is printed to
**stderr** when the user provides it.

```mojo
command.add_argument(
    Argument("format_old", help="Legacy output format")
        .long["format-old"]()
        .deprecated["Use --format instead"]()
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
command.add_argument(
    Argument("compat", help="Compat mode")
        .long["compat"]().short["C"]().flag()
        .deprecated["Will be removed in 2.0"]()
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

### Default-if-no-value

Use `.default_if_no_value["value"]()` to make an option's value **optional**. When the option is present without an explicit value, the default-if-no-value is used. When an explicit value is provided (via `=` for long options, or attached for short options), that value is used instead.

`.default_if_no_value()` automatically implies `.require_equals()` for long options in the sense that `=` is required to attach an *explicit* value. A bare `--key` is still accepted and uses the default-if-no-value; `--key value` (space-separated) does *not* treat `value` as the argument to `--key` but leaves it to be parsed as a positional argument or another option. To supply an explicit value to the option itself, the user must write `--key=value`.

```mojo
command.add_argument(
    Argument("compress", help="Compression algorithm")
    .long["compress"]()
    .short["c"]()
    .default_if_no_value["gzip"]()
)
```

**Behaviour:**

| Syntax             | Value                                              |
| ------------------ | -------------------------------------------------- |
| *(omitted)*        | not set (or default, if `.default()` is also used) |
| `--compress`       | `"gzip"` (default-if-no-value)                     |
| `--compress=bzip2` | `"bzip2"` (explicit)                               |
| `-c`               | `"gzip"` (default-if-no-value)                     |
| `-cbzip2`          | `"bzip2"` (attached)                               |

**Combined with `.default()`:**

```mojo
command.add_argument(
    Argument("compress", help="Compression algorithm")
    .long["compress"]()
    .default_if_no_value["gzip"]()
    .default["none"]()
)
# Not provided  → "none"  (default)
# --compress    → "gzip"  (default-if-no-value)
# --compress=xz → "xz"    (explicit)
```

**Help display** — the optional value is shown in brackets:

```bash
Options:
      --compress[=<compress>]    Compression algorithm
```

With `.value_name["ALGO"]()`:

```bash
Options:
      --compress[=ALGO]          Compression algorithm
```

### Require Equals Syntax

Use `.require_equals()` to force `--key=value` syntax. Space-separated `--key value` is rejected, which avoids ambiguity when values might start with `-`.

```mojo
command.add_argument(
    Argument("output", help="Output file")
    .long["output"]()
    .short["o"]()
    .require_equals()
)
```

**Behaviour:**

| Syntax              | Result                                           |
| ------------------- | ------------------------------------------------ |
| `--output=file.txt` | `"file.txt"` (OK)                                |
| `--output file.txt` | error                                            |
| `--output`          | error                                            |
| `-o file.txt`       | `"file.txt"` (OK — short options are unaffected) |

**Help display** — the `=` is shown in the help:

```bash
Options:
  -o, --output=<output>    Output file
```

**Combined with `.default_if_no_value()`** — see [Default-if-no-value](#default-if-no-value) above. When both are set, `--key` uses the default-if-no-value while `--key=val` uses the explicit value.

### Argument Groups

By default, all options appear under a single "Options:" heading in `--help`. Use `.group["name"]()` to organise related arguments under their own section heading.

```mojo
command.add_argument(
    Argument("host", help="Server hostname")
    .long["host"]().value_name["ADDR"]().group["Network"]()
)
command.add_argument(
    Argument("port", help="Server port")
    .long["port"]().short["P"]().group["Network"]()
)
command.add_argument(
    Argument("output", help="Output file path")
    .long["output"]().short["o"]().value_name["FILE"]().group["Output"]()
)
command.add_argument(
    Argument("verbose", help="Increase verbosity")
    .long["verbose"]().short["v"]().count()
)
```

**Help output:**

```bash
Options:
  -v, --verbose              Increase verbosity
  -h, --help                 Show this help message

Network:
      --host <ADDR>    Server hostname
  -P, --port <port>    Server port

Output:
  -o, --output <FILE>    Output file path
```

**Key behaviours:**

- **Ungrouped arguments** remain under "Options:".
- **Group headings** appear in first-appearance order after "Options:".
- **Persistent arguments** are collected under "Global Options:" regardless of their group.
- **Hidden arguments** are excluded from all sections.
- **Column padding** is computed independently per section, so each group aligns neatly.
- Groups are purely cosmetic — they do not affect parsing or validation.

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

Help text columns are **dynamically aligned**: the padding between the option names and the description text adjusts automatically based on the longest option line, so everything stays neatly aligned regardless of option length.

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
var help_colored = command._generate_help()              # color=True (default)
var help_plain   = command._generate_help(color=False)   # no ANSI codes
```

---

**Custom Colours**

The **header colour**, **argument-name colour**, **deprecation warning colour**, and **parse error colour** are all customisable.  Section headers always keep the **bold + underline** style; only the colour changes.

```mojo
var command = Command("myapp", "My app")
command.header_color["BLUE"]()     # section headers in bright blue
command.arg_color["GREEN"]()       # option/argument names in bright green
command.warn_color["YELLOW"]()     # deprecation warnings (default: orange)
command.error_color["MAGENTA"]()   # parse errors (default: red)
```

Available colour names (uppercase only):

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

An unrecognised colour name is caught at **compile time** — the program will not compile if you pass an invalid name. Note that the colour name is a `StringLiteral` parameter and must be provided as a compile-time string literal (bracket-parameter form); dynamic runtime selection of colours is not supported by this API.

Padding calculation is always based on the **plain-text width** (without escape codes), so columns remain correctly aligned regardless of whether colour is enabled.

**What controls the output:**

| Builder method       | Effect on help                                        |
| -------------------- | ----------------------------------------------------- |
| `.help("...")`       | Sets the description text for the option.             |
| `.value_name["X"]()` | Replaces the default placeholder (e.g., `N`, `FILE`). |
| `.choice[]()`        | Shows `{a,b,c}` in the placeholder.                   |
| `.hidden()`          | Completely excludes the option from help.             |
| `.required()`        | Positional args show as `<name>` instead of `[name]`. |

After printing help, the program exits cleanly with exit code 0.

---

**`NO_COLOR` Environment Variable**

ArgMojo respects the [`NO_COLOR`](https://no-color.org/) convention. When the `NO_COLOR` environment variable is **set** (any value, including an empty string), all ANSI colour codes are suppressed in:

- Help output (`_generate_help()`)
- Warning messages (`_warn()`)
- Error messages (`_error()` and `_error_with_usage()`)

```bash
NO_COLOR=1 myapp --help    # plain-text help, no colours
NO_COLOR= myapp --help     # also suppressed (empty string counts as "set")
myapp --help               # coloured output (NO_COLOR is unset)
```

This takes priority over the `color=True` default but does **not** override an explicit `_generate_help(color=False)` call (which already produces plain output regardless).

---

**Show Help When No Arguments Provided**

Use `help_on_no_arguments()` to automatically display help when the user invokes the command with no arguments (like `git`, `docker`, or `cargo`):

```mojo
var command = Command("myapp", "My application")
command.add_argument(Argument("file", help="Input file").long["file"]().required())
command.help_on_no_arguments()
var result = command.parse()
```

```bash
myapp          # prints help and exits
myapp --file x # normal parsing
```

This is particularly useful for commands that require arguments — instead of showing an obscure "missing required argument" error, the user sees the full help text.

### Custom Tips

Add custom **tip lines** to the bottom of your help output with `add_tip()`. This is useful for documenting common patterns, gotchas, or examples.

```mojo
var command = Command("calc", "A calculator")
command.add_argument(Argument("expr", help="Expression").positional().required())
command.add_tip("Expressions starting with `-` are accepted.")
command.add_tip("Use quotes if you use spaces in expressions.")
```

```text
A calculator

Usage: calc <expr> [OPTIONS]

Arguments:
  expr    Expression

Options:
  -h, --help       Show this help message
  -V, --version    Show version

Tip: Use '--' to pass values starting with '-' as positionals:  calc -- -10.18
Tip: Expressions starting with `-` are accepted.
Tip: Use quotes if you use spaces in expressions.
```

---

**Smart default tip** — when positional arguments are defined, ArgMojo automatically adds a built-in tip explaining the `--` separator. The example in this default tip adapts based on whether negative numbers are auto-detected: if they are, it uses `-my-value`; otherwise, it uses `-10.18`.

User-defined tips appear **below** the built-in tip.

---

Multiple tips can be added; each is displayed on its own line prefixed with `Tip:`.

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
var command = Command("myapp", "Description", version="1.0.0")
```

After printing the version, the program exits cleanly with exit code 0.

### CJK-Aware Help Alignment

ArgMojo automatically handles CJK (Chinese, Japanese, Korean) characters in help output. CJK ideographs and fullwidth characters occupy **two terminal columns** instead of one, so naïve byte- or codepoint-based padding would cause misaligned help columns.

ArgMojo's help formatter uses **display width** (East Asian Width) to compute padding, so help descriptions stay aligned even when option names, positional names, subcommand names, or help text contain CJK characters.

See the [Unicode East Asian Width specification](https://www.unicode.org/reports/tr11/) for details on CJK character ranges and properties.

**Example — mixed ASCII and CJK options:**

```mojo
var command = Command("工具", "一個命令行工具")
command.add_argument(
    Argument("output", help="Output path").long["output"]().short["o"]()
)
command.add_argument(
    Argument("編碼", help="設定編碼").long["編碼"]()
)
```

```txt
Options:
  -o, --output <output>    Output path
      --編碼 <編碼>        設定編碼
```

**Example — CJK subcommands:**

```mojo
var app = Command("工具", "一個命令行工具")
var init_cmd = Command("初始化", "建立新項目")
app.add_subcommand(init_cmd^)
var build_cmd = Command("構建", "編譯項目")
app.add_subcommand(build_cmd^)
```

```txt
Commands:
  初始化    建立新項目
  構建      編譯項目
```

No configuration is needed — CJK-aware alignment is always active.

### Full-Width → Half-Width Auto-Correction

CJK users frequently forget to switch input methods, accidentally typing **fullwidth ASCII** characters instead of their normal halfwidth equivalents:

- `－－ｖｅｒｂｏｓｅ` instead of `--verbose`
- `＝` instead of `=`
- `－ｖ` instead of `-v`

ArgMojo automatically detects and corrects these characters **before parsing**, printing a coloured warning to stderr:

```bash
warning: detected full-width characters in '－－ｖｅｒｂｏｓｅ', auto-corrected to '--verbose'
```

**What gets corrected:**

- Fullwidth ASCII characters (`U+FF01`–`U+FF5E`) are converted to their halfwidth equivalents (`U+0021`–`U+007E`) by subtracting `0xFEE0`.
- Fullwidth spaces (`U+3000`) are converted to regular spaces (`U+0020`). When a single token contains embedded fullwidth spaces (e.g., `--name\u3000yuhao\u3000--verbose` as one argv token), it is split into multiple arguments.
- All tokens containing fullwidth ASCII are normalized (converted to halfwidth). Only tokens that start with `-` after correction are treated as options and trigger a warning. Positional values are also converted but no warning is emitted.

**Example — fullwidth flag:**

```mojo
var app = Command("myapp", "My CLI")
app.add_argument(Argument("verbose", help="Verbose").long["verbose"]().short["v"]().flag())
var result = app.parse_arguments(["myapp", "－－ｖｅｒｂｏｓｅ"])
# result.get_flag("verbose") == True
# stderr: warning: detected full-width characters in '－－ｖｅｒｂｏｓｅ', auto-corrected to '--verbose'
```

**Example — fullwidth equals syntax:**

```mojo
var app = Command("myapp", "My CLI")
app.add_argument(Argument("output", help="Output").long["output"]().takes_value())
var result = app.parse_arguments(["myapp", "－－ｏｕｔｐｕｔ＝ｆｉｌｅ．ｔｘｔ"])
# result.get_string("output") == "file.txt"
```

**Disabling auto-correction:**

Call `disable_fullwidth_correction()` if you prefer strict parsing:

```mojo
var app = Command("myapp", "My CLI")
app.disable_fullwidth_correction()
# Now: fullwidth characters are NOT corrected
```

**Whitespace handling:**

By default, only fullwidth space (`U+3000`) triggers token splitting. Other Unicode whitespace characters (for example, EM SPACE `U+2003`) are treated as regular characters and do **not** cause tokens to be split.

This feature is enabled by default and works with both `parse_arguments()` and `parse_known_arguments()`.

## Parsing Behaviour

### Negative Number Passthrough

By default, tokens starting with `-` are interpreted as options. This creates a problem when you need to pass **negative numbers** (like `-10.18`, `-3.14`, `-1.5e10`) as positional values.

ArgMojo provides three complementary approaches to handle this, inspired by Python's argparse.

---

**Approach 1: Auto-detect (zero configuration)**

When no registered short option uses a **digit character** as its name, ArgMojo automatically recognises numeric-looking tokens and treats them as positional arguments instead of options.

```mojo
var command = Command("calc", "Calculator")
command.add_argument(Argument("operand", help="A number").positional().required())
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
calc -- -10.18         # operand = "-10.18"
calc -- -3e4         # operand = "-3e4"
```

See [The `--` Stop Marker](#the----stop-marker) for details. When positional arguments are registered, ArgMojo's help output includes a **Tip** line reminding users about this:

```text
Tip: Use '--' to pass values that start with '-' (e.g., negative numbers):  calc -- -10.18
```

---

**Approach 3: `allow_negative_numbers()` (explicit opt-in)**

If you have a registered short option that uses a digit character (e.g., `-3` for `--triple`), the auto-detect is suppressed to avoid ambiguity. In this case, call `allow_negative_numbers()` to force all numeric-looking tokens to be treated as positionals.

```mojo
var command = Command("calc", "Calculator")
command.allow_negative_numbers()   # Explicit opt-in
command.add_argument(
    Argument("triple", help="Triple mode").long["triple"]().short["3"]().flag()
)
command.add_argument(Argument("operand", help="A number").positional().required())
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
command.add_argument(Argument("verbose", help="Verbose output").long["verbose"]().short["v"]().flag())
command.add_argument(Argument("output",  help="Output file").long["output"]().short["o"]())
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
command.add_argument(Argument("verbose",      help="Verbose").long["verbose"]().flag())
command.add_argument(Argument("version-info", help="Version info").long["version-info"]().flag())
```

```bash
myapp --ver
# Error: Ambiguous option '--ver' could match: '--verbose', '--version-info'
```

---

**Exact match always wins**

If the user's input is an **exact match** for one option, it is chosen even if it is also a prefix of another option:

```mojo
command.add_argument(Argument("color",    help="Color mode").long["color"]().flag())
command.add_argument(Argument("colorize", help="Colorize output").long["colorize"]().flag())
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
command.add_argument(Argument("ling", help="Use Lingming encoding").long["ling"]().flag())
command.add_argument(Argument("pattern", help="Search pattern").positional().required())
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
myapp -- -10.18
# pattern = "-10.18"
```

> **Tip:** ArgMojo's [Auto-detect](#negative-number-passthrough) can handle most negative-number cases without `--`. Use `--` only when auto-detect is insufficient (e.g., a digit short option is registered without `allow_negative_numbers()`).

### Remainder Positional (`.remainder()`)

A **remainder** positional consumes **all** remaining command-line tokens once it starts matching, including tokens that look like options (e.g., `--foo`, `-x`, `--some-flag`). This is useful for wrapper CLIs that forward arguments to another program.

> Libraries with similar support: **argparse** (`nargs=argparse.REMAINDER`), **clap** (`trailing_var_arg`), **cobra** (`TraverseChildren` + `ArbitraryArgs`).

```mojo
var command = Command("runner", "Run a program with arguments")
command.add_argument(
    Argument("program", help="Program to run").positional().required()
)
command.add_argument(
    Argument("args", help="Arguments to pass through").remainder()
)
```

```bash
runner myapp --verbose -x --output=foo.txt
# program = "myapp"
# args    = ["--verbose", "-x", "--output=foo.txt"]
```

The remainder positional automatically implies `.positional()` and `.append()`. In help output, it is displayed as `args...` (with trailing ellipsis).

**Rules:**

- `.remainder()` must not have `.long()` or `.short()` — it is positional-only.
- At most **one** remainder positional is allowed per command.
- The remainder positional must be the **last** positional argument.
- When no trailing tokens are present, the remainder list is empty (not an error).

### Allow Hyphen Values (`.allow_hyphen_values()`)

By default, tokens starting with `-` are interpreted as options. The `.allow_hyphen_values()` builder method tells the parser that a specific positional argument may accept tokens starting with `-` as regular values without requiring `--` beforehand. This covers both the bare `-` (Unix stdin/stdout convention) and any other dash-prefixed literal.

A common use case is accepting `-` as a conventional shorthand for **stdin/stdout**:

```mojo
var command = Command("cat", "Concatenate files")
command.add_argument(
    Argument("file", help="Input file (use - for stdin)")
    .positional()
    .required()
    .allow_hyphen_values()
)
```

```bash
cat -        # file = "-"  (stdin convention)
cat input.txt  # file = "input.txt"
```

> **Note:** `.remainder()` automatically enables `.allow_hyphen_values()` — no need to set it separately on remainder positionals.

### Partial Parsing (`parse_known_arguments()`)

`parse_known_arguments()` works like `parse_arguments()` but **does not raise an error** for unrecognised options. Instead, unknown tokens are collected and can be retrieved from the result.

> Libraries with similar support: **argparse** (`parse_known_args()`), **clap** (not built-in; use `allow_external_subcommands`), **cobra** (`FParseErrWhitelist`).

```mojo
var command = Command("wrapper", "Wrapper that forwards unknown flags")
command.add_argument(
    Argument("verbose", help="Verbose output").long["verbose"]().flag()
)
command.add_argument(
    Argument("file", help="Input file").positional().required()
)

var args: List[String] = ["wrapper", "input.txt", "--verbose", "--color", "-x"]
var result = command.parse_known_arguments(args)

# Known arguments are accessed normally:
var verbose = result.get_flag("verbose")
var file = result.get_string("file")

# Unknown arguments are collected separately:
var unknown = result.get_unknown_args()
# e.g., ["--color", "-x", "--threads=4"]
```

```bash
wrapper input.txt --verbose --color -x --threads=4
# verbose = True
# file    = "input.txt"
# unknown = ["--color", "-x", "--threads=4"]
```

All other validation (required arguments, choices, range) still applies. Only the "Unknown option" error is suppressed.

> **Note:** Unknown options using `=` syntax (e.g., `--color=auto`) are captured as a single token. For space-separated syntax (`--color auto`), only `--color` is recorded as unknown; `auto` flows to positional arguments because the parser cannot tell whether the unknown option takes a value. Use `=` syntax when forwarding unknown options reliably.

<!-- Response Files section temporarily disabled — Mojo compiler deadlock with -D ASSERT=all.
     The implementation is preserved as module-level functions and will be re-enabled
     when the Mojo compiler bug is fixed.
     
## Response Files

A **response file** (also called an **args file**) lets users store arguments in a text file and reference it on the command line with a prefix character (default `@`). This is useful when the argument list is very long or when the same set of arguments is reused frequently.

> Libraries with similar support: **argparse** (`fromfile_prefix_chars`), **javac** (`@argfile`), **MSBuild** (`@file`), **gcc** (`@file`).

### Enabling Response Files

Call `response_file_prefix()` on your command to enable the feature:

```mojo
var command = Command("mytool", "My CLI tool")
command.response_file_prefix()  # default '@'
```

Now `mytool @args.txt` reads arguments from `args.txt`, with each line becoming a separate argument.

### File Format

Each non-empty line in the response file becomes one argument. Lines starting with `#` are comments and are ignored. Leading and trailing whitespace per line is stripped.

```text
# args.txt — common flags for the build
--verbose
--output=build/release
--jobs=4

# source files
src/main.mojo
src/utils.mojo
```

```bash
mytool @args.txt
# equivalent to: mytool --verbose --output=build/release --jobs=4 src/main.mojo src/utils.mojo
```

Response file arguments can be mixed freely with direct CLI arguments:

```bash
mytool --debug @args.txt --extra-flag
```

### Escaping the Prefix

To pass a literal token that starts with `@` (e.g., an email address), double the prefix:

```bash
mytool @@user@example.com
# parsed as: @user@example.com
```

The same escape works inside response files:

```text
# users.txt
@@admin
@@guest
```

### Recursive Response Files

Response files may reference other response files:

```text
# base-args.txt
--verbose

# build-args.txt
@base-args.txt
--output=build/release
```

```bash
mytool @build-args.txt
# expands to: mytool --verbose --output=build/release
```

Recursion depth is limited to 10 by default. Adjust with `response_file_max_depth[depth]()`:

```mojo
command.response_file_max_depth[5]()
```

A self-referencing or circular response file triggers an error once the depth limit is reached.

### Custom Prefix

Use a different prefix character if `@` conflicts with your argument values:

```mojo
command.response_file_prefix("+")
# Now: mytool +args.txt
```

end of Response Files section -->

## Interactive Prompting

ArgMojo supports **interactive prompting** for missing arguments. When an argument marked with `.prompt()` is not provided on the command line, the user is asked to enter its value interactively before validation runs.

This is useful for required credentials, configuration wizards, or any scenario where guided input improves the user experience.

### Setup Example

The examples below use this `login` command:

```mojo
from argmojo import Argument, Command

def main() raises:
    var command = Command("login", "Authenticate with the service")
    command.add_argument(
        Argument("user", help="Username")
        .long["user"]()
        .required()
        .prompt()
    )
    command.add_argument(
        Argument("token", help="API token")
        .long["token"]()
        .required()
        .prompt["Enter your API token"]()
    )
    command.add_argument(
        Argument("region", help="Server region")
        .long["region"]()
        .choice["us"]()
        .choice["eu"]()
        .choice["ap"]()
        .default["us"]()
        .prompt()
    )
    var result = command.parse()
```

Three arguments are prompt-enabled:

- `--user` — required, prompt uses the help text `"Username"`.
- `--token` — required, prompt uses custom text `"Enter your API token"`.
- `--region` — optional with choices and a default, prompt shows choices and default.

### Enabling Prompting

Use `.prompt()` on any argument — both required and optional — to enable interactive prompting:

```mojo
# Prompt using the argument's help text (or name as fallback).
Argument("user", help="Username").long["user"]().prompt()

# Prompt with custom text.
Argument("token", help="API token").long["token"]().prompt["Enter your API token"]()
```

`.prompt()` and `.prompt["custom text"]()` are the same builder method. When no text is given, the argument's help text is displayed. When custom text is provided, it overrides the help text in the prompt.

### Interactive Session Examples

#### All arguments missing — full prompting

When none of the prompt-enabled arguments are provided, the user is prompted for each one in order:

```console
$ ./login
Username: alice
Enter your API token: secret-123
Server region [us/eu/ap] (us): eu
```

The parsed result contains `user="alice"`, `token="secret-123"`, `region="eu"`.

#### Partial arguments — only missing ones are prompted

When some arguments are already provided on the command line, only the missing ones trigger a prompt:

```console
$ ./login --user alice
Enter your API token: secret-123
Server region [us/eu/ap] (us): ap
```

`--user` was given on the CLI, so `Username:` is **not** asked.

#### All arguments provided — no prompting at all

```console
./login --user alice --token secret-123 --region eu
```

No prompts appear. The CLI values are used directly.

#### Empty input with a default — default value is used

When the user presses Enter without typing anything and the argument has a `.default[]()`, the default is applied:

```console
$ ./login
Username: alice
Enter your API token: secret-123
Server region [us/eu/ap] (us):
```

The user pressed Enter at `Server region`, so `region` gets the default value `"us"`.

#### Flag argument — y/n prompt

Flag arguments accept `y`/`n`/`yes`/`no` (case-insensitive):

```mojo
Argument("verbose", help="Enable verbose output")
    .long["verbose"]()
    .flag()
    .prompt()
```

```console
$ ./app
Enable verbose output [y/n]: y
```

Answering `y` or `yes` sets the flag to `True`. Answering `n` or `no` sets it to `False`.

#### Argument with choices — choices are shown

When a prompt-enabled argument has `.choice[]()` values, they are displayed in brackets. If a default exists, it is shown in parentheses:

```console
$ ./login --user alice --token secret
Server region [us/eu/ap] (us): eu
```

The user sees the valid options and the default before typing.

### Prompt Format

The prompt message is built automatically from the argument's metadata:

```text
<text> [choice1/choice2/choice3] (default_value): _
```

Where:

- **`<text>`** — custom prompt text if given via `.prompt["..."]()`, otherwise the argument's help text, otherwise the argument name.
- **`[choices]`** — shown only when `.choice[]()` values exist.
- **`(default)`** — shown only when `.default[]()` is set.
- **`[y/n]`** — shown instead of choices for `.flag()` arguments.

Examples of prompt lines:

```console
Username:                           ← help text, no choices, no default
Enter your API token:               ← custom prompt text
Server region [us/eu/ap] (us):      ← help text + choices + default
Enable verbose output [y/n]:        ← flag prompt
```

### Interaction with Other Features

- **`.required()`**: Prompting happens *before* validation. If the user provides a value via the prompt, the required check passes. `.prompt()` does **not** require `.required()` — it works on any argument.
- **`.default[]()`**: If the user presses Enter (empty input), the default is applied by the normal default-filling phase.
- **`.choice[]()`**: Choices are displayed in the prompt. If the user enters an invalid choice, a validation error is raised after prompting.
- **Subcommands**: Each subcommand can have its own prompt-enabled arguments.
- **Persistent flags**: Persistent arguments with `.prompt()` are prompted at the level where they are missing.
- **`help_on_no_arguments()`**: Cannot be combined with `.prompt()` on the same command. When no arguments are given, `help_on_no_arguments()` prints help and exits *before* prompting runs, making prompt-enabled arguments unreachable. ArgMojo raises a registration-time error if you attempt this combination.

### Non-Interactive Use (CI / Piped Input)

When stdin is not a terminal (piped input, CI environments, `< /dev/null`), the `input()` call raises on EOF. ArgMojo catches this gracefully and stops prompting — any values collected so far are preserved, defaults are then applied normally, and validation proceeds as usual.

```console
echo "" | ./login --user alice --token secret
```

Prompts are still printed to stdout, but `input()` reads from the pipe. Once the pipe is exhausted, `input()` raises and prompting stops. `--region` gets its default `"us"`.

To avoid prompting entirely, always provide all arguments on the command line:

```console
./login --user alice --token secret --region eu
```

## Argument Parents and Inheritance

When multiple commands share the same set of arguments (e.g., `--verbose`, `--format`, `--output`), you can define them once in a **parent** command and inherit them via `add_parent()`. This is equivalent to Python argparse's `parents` parameter.

### Defining Shared Arguments

```mojo
from argmojo import Command, Argument

def main() raises:
    # Define shared arguments in a "parent" command.
    # The name is arbitrary — it is never shown to users.
    var shared = Command("_shared")
    shared.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]().short["v"]().flag()
    )
    shared.add_argument(
        Argument("format", help="Output format")
        .long["format"]().short["f"]()
        .choice["json"]().choice["yaml"]().choice["csv"]()
        .default["json"]()
    )

    # Inherit into multiple commands.
    var cmd_a = Command("export", "Export data")
    cmd_a.add_parent(shared)
    cmd_a.add_argument(
        Argument("path", help="Export path").positional().required()
    )

    var cmd_b = Command("report", "Generate report")
    cmd_b.add_parent(shared)
    cmd_b.add_argument(
        Argument("title", help="Report title").long["title"]()
    )
```

Both `export` and `report` now accept `--verbose`, `-v`, `--format`, and `-f` without repeating their definitions.

### What Gets Inherited

`add_parent()` copies:

- **All arguments** — flags, options, positionals, count flags, append, map, etc.
- **Mutually exclusive groups** — `mutually_exclusive()`
- **Required-together groups** — `required_together()`
- **One-required groups** — `one_required()`
- **Conditional requirements** — `required_if()`
- **Implications** — `implies()`

All registration-time validation guards run on each inherited argument, so invalid combinations are caught immediately.

### Multiple Parents

A command can inherit from multiple parents:

```mojo
var io_args = Command("_io")
io_args.add_argument(
    Argument("output", help="Output file").long["output"]().short["o"]()
)

var log_args = Command("_log")
log_args.add_argument(
    Argument("verbose", help="Verbose").long["verbose"]().short["v"]().flag()
)

var cmd = Command("process", "Process data")
cmd.add_parent(io_args)
cmd.add_parent(log_args)
# cmd now has --output, -o, --verbose, -v
```

### Using with Subcommands

Parent arguments can include `.persistent()` flags, which are then inherited by the command and automatically propagated to its subcommands:

```mojo
var global_args = Command("_global")
global_args.add_argument(
    Argument("verbose", help="Verbose")
    .long["verbose"]().short["v"]().flag().persistent()
)

var app = Command("app", "My app")
app.add_parent(global_args)

var sub = Command("run", "Run something")
sub.add_argument(Argument("target", help="Target").positional().required())
app.add_subcommand(sub^)

var result = app.parse()
# app -v run main  →  verbose=True, subcommand="run"
```

### Notes

- The parent `Command` is **not modified** by `add_parent()` — it can be shared safely across multiple children.
- Child arguments added via `add_argument()` coexist with inherited ones.
- If you need different constraints for different children, apply them after `add_parent()` on each child individually.

## Password / Masked Input

For passwords, API tokens, and other sensitive values, you want to **hide the user's typed input** so it doesn't appear on screen. ArgMojo's `.password()` builder method does exactly this — equivalent to Click's `hide_input=True` or Python's `getpass.getpass()`.

> **Naming note:** The method is named `.password()` following HTML's `<input type="password">` convention, where the word "password" universally signals "hide the typed characters". Click uses `hide_input=True` (describing the *behaviour*); ArgMojo uses `.password()` (describing the *use case*) for brevity and instant recognition.

### Basic Usage

```mojo
from argmojo import Command, Argument

def main() raises:
    var command = Command("login", "Authenticate with the server")
    command.add_argument(
        Argument("username", help="Your username").long["username"]().short["u"]().required()
    )
    command.add_argument(
        Argument("password", help="Your password").long["password"]().short["p"]().password()
    )

    var result = command.parse()
    var user = result.get_string("username")
    var pass_ = result.get_string("password")
```

```console
$ ./login --username alice
Your password: <hidden>
```

The `.password()` builder method:

1. **Implies `.prompt()`** — if prompting is not already enabled, `.password()` enables it automatically.
2. **Disables terminal echo** — on POSIX systems (macOS, Linux), terminal echo is suppressed via `tcsetattr(3)` while the user types, then re-enabled afterwards.
3. **Falls back gracefully** — if stdin is not a terminal (piped input, CI, `/dev/null`), echo control silently returns `False` and prompting stops via the normal EOF-handling path. Defaults are applied as usual.

### Custom Prompt Text

Combine `.password()` with `.prompt["text"]()` to customise the prompt message:

```mojo
command.add_argument(
    Argument("token", help="API token")
    .long["token"]()
    .prompt["Enter your API token"]()
    .password()
)
```

```console
Enter your API token: ••••••••
```

The order of `.prompt["text"]()` and `.password()` does not matter — both produce the same result.

### Restrictions

`.password()` can only be used on **value-taking arguments** (named options or positionals). It cannot be combined with:

- **`.flag()`** — flags are boolean and don't read input.
- **`.count()`** — count arguments are incremental and don't read input.

Attempting to register a `.password()` argument on a flag or count raises a registration-time error.

### Non-Interactive Use

When stdin is not a terminal, the echo-control calls return `False` (harmless), and `input()` raises on EOF. ArgMojo catches the exception and stops prompting gracefully — exactly the same behaviour as regular `.prompt()` arguments.

To bypass the prompt entirely, provide the value on the command line:

```console
./login --username alice --password s3cret
```

## Confirmation Option

Some commands are destructive or irreversible — dropping databases, deleting files, deploying to production. The **confirmation option** adds a built-in `--yes` / `-y` flag that lets users skip an interactive confirmation prompt. This is equivalent to Click's `confirmation_option` decorator.

### Basic Usage

```mojo
from argmojo import Command, Argument

def main() raises:
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option()

    var result = cmd.parse()
    # Without --yes: prompts "Are you sure? [y/N]: "
    # With --yes or -y: skips the prompt
    print("Dropping database:", result.get_string("name"))
```

Running without `--yes`:

```sh
$ ./drop mydb
Are you sure? [y/N]: y
Dropping database: mydb
```

Running with `--yes`:

```sh
$ ./drop mydb --yes
Dropping database: mydb
```

### Custom Prompt Text

Use the compile-time parameter overload to set a custom prompt:

```mojo
cmd.confirmation_option["Drop the database? This cannot be undone."]()
```

This changes the prompt to:
  
```sh
Drop the database? This cannot be undone. [y/N]: 
```

### Using with Subcommands

Confirmation works naturally with subcommands. The `--yes` flag is registered on the command that calls `confirmation_option()`:

```mojo
var app = Command("app", "My app")
app.confirmation_option()

var deploy = Command("deploy", "Deploy to production")
deploy.add_argument(Argument("env", help="Environment").positional().required())
app.add_subcommand(deploy^)

var result = app.parse()
# app --yes deploy prod  →  skips confirmation
```

### Non-Interactive Use

When stdin is not available (piped input, CI environments, `/dev/null`), the confirmation prompt cannot be displayed. In this case, the command **aborts with an error** unless `--yes` is passed. This ensures that destructive commands never run silently without explicit opt-in:

```sh
$ echo "" | ./drop mydb
error: drop: Aborted (no interactive input available)

$ ./drop mydb --yes    # works in CI
Dropping database: mydb
```

## Usage Line Customisation

By default, ArgMojo generates usage lines like `Usage: myapp <PATTERN> [OPTIONS]` — showing `[OPTIONS]` for named arguments and listing each positional. This convention (shared by clap, cobra, and Click) works well for most CLIs.

For some programs you may want a hand-written usage string — for example, git's usage line enumerates a few key flags inline rather than collapsing them into `[OPTIONS]`. The `usage()` method on `Command` lets you replace the auto-generated usage line with your own text:

```mojo
from argmojo import Command, Argument

def main() raises:
    var cmd = Command("git", "The stupid content tracker", version="2.45.0")
    cmd.usage("git [-v | --version] [-h | --help] [-C <path>] <command> [<args>]")

    cmd.add_argument(Argument("verbose", help="Verbose output").long["verbose"]().short["v"]().flag())
    cmd.add_argument(Argument("path", help="Run as if started in <path>").short["C"]())

    var result = cmd.parse()
```

The custom string appears as-is after `Usage:` in both `--help` output and error messages:

```sh
$ ./git --help
The stupid content tracker

Usage: git [-v | --version] [-h | --help] [-C <path>] <command> [<args>]

Options:
  -v, --verbose   Verbose output
  -C <path>       Run as if started in <path>
  -h, --help      Print help
  -V, --version   Print version
```

When no custom usage is set, the auto-generated line is used as before — no change in default behaviour.

## Shell Completion

ArgMojo can generate **shell completion scripts** for Bash, Zsh, and Fish. These scripts enable tab-completion for your CLI's options, flags, subcommands, and choice values — with zero runtime overhead.

The generated scripts are **static**: they are produced once from your command tree and sourced by the user's shell. No runtime hook or callback mechanism is needed.

### Built-in `--completions` Flag

Every `Command` automatically responds to `--completions <shell>` — just like `--help` and `--version`. **No extra code is required.**

```mojo
var app = Command("myapp", "My application", version="1.0.0")
app.add_argument(Argument("verbose", help="Verbose output").long["verbose"]().short["v"]().flag())
app.add_argument(Argument("output", help="Output file").long["output"]().short["o"]().value_name["FILE"]())
app.add_argument(Argument("format", help="Output format").long["format"]().choice["json"]().choice["csv"]().choice["table"]())

var sub = Command("serve", "Start a server")
sub.add_argument(Argument("port", help="Port number").long["port"]().short["p"]())
app.add_subcommand(sub^)

# parse() handles --completions automatically — no extra code needed
var result = app.parse()
```

Users run:

```bash
myapp --completions bash   # prints Bash completion script and exits
myapp --completions zsh    # prints Zsh completion script and exits
myapp --completions fish   # prints Fish completion script and exits
```

The `--completions` option is shown in the help output alongside `--help` and `--version`:

```bash
Options:
  --help                  Show this help message and exit
  --version               Show the version and exit
  --completions {bash,zsh,fish}
                          Generate shell completion script
```

### Disabling the Built-in Flag

If you want to use `completions` as a regular argument name — or handle completion triggering entirely on your own — call `disable_default_completions()`:

```mojo
var app = Command("myapp", "My CLI")
app.disable_default_completions()   # --completions is now an unknown option
```

`disable_default_completions()` removes `--completions` from the parse loop, help output, and all generated completion scripts. The `generate_completion()` method remains available for programmatic use.

### Customising the Trigger Name

By default the option is called `--completions`. Use `completions_name()` to rename it:

```mojo
var app = Command("myapp", "My CLI")
app.completions_name("autocomp")    # → --autocomp bash/zsh/fish
```

Help output, parse loop, and generated scripts all reflect the new name.

### Using a Subcommand Instead of an Option

To expose completion generation as a subcommand rather than a `--` option, call `completions_as_subcommand()`:

```mojo
var app = Command("myapp", "My CLI")
app.completions_as_subcommand()     # → myapp completions bash
```

The trigger moves from `Options:` to `Commands:` in help output. This can be combined with `completions_name()`:

```mojo
app.completions_name("comp")
app.completions_as_subcommand()     # → myapp comp bash
```

### Generating a Script Programmatically

You can also call `generate_completion` directly to get a completion script as a `String`:

```mojo
# Compile-time validated (bracket syntax) — invalid shell names fail to compile
var script = app.generate_completion["bash"]()
print(script)
```

A runtime overload is also available for when the shell name comes from user input:

```mojo
# Runtime dispatch (case-insensitive) — raises on unknown shell
var script = app.generate_completion(shell_name)   # "bash", "zsh", or "fish"
```

The runtime overload is **case-insensitive** (`"Bash"`, `"BASH"`, `"bash"` all work). An error is raised for unrecognised shell names.

### Installing Completions

After generating a script, users `source` it or place it in a shell-specific directory.

---

**Bash:**

```bash
# One-shot (current session only)
eval "$(myapp --completions bash)"

# Persistent
myapp --completions bash > ~/.bash_completion.d/myapp
# Then add to ~/.bashrc:  source ~/.bash_completion.d/myapp
```

---

**Zsh:**

```bash
# Place in your fpath (file must be named _myapp)
myapp --completions zsh > ~/.zsh/completions/_myapp

# Make sure ~/.zsh/completions is in fpath (add to ~/.zshrc):
#   fpath=(~/.zsh/completions $fpath)
#   autoload -Uz compinit && compinit
```

---

**Fish:**

```bash
# Fish auto-loads from this directory
myapp --completions fish > ~/.config/fish/completions/myapp.fish
```

### What Gets Completed

The generated scripts cover the full command tree:

| Element                           | Completed?       | Notes                                                                |
| --------------------------------- | ---------------- | -------------------------------------------------------------------- |
| Long options (`--verbose`)        | Yes              | With description text from `help`                                    |
| Short options (`-v`)              | Yes              | Paired with long option when both exist                              |
| Boolean flags                     | Yes              | Marked as no-argument (no file/value completion after the flag)      |
| Count flags (`-vvv`)              | Yes              | Treated like boolean flags (no value expected)                       |
| Choices (`--format json`)         | Yes              | Tab-completes the allowed values (`json`, `csv`, `table`)            |
| Subcommands                       | Yes              | Listed with descriptions; scoped completions for each subcommand     |
| Built-in `--help` / `--version`   | Yes              | Automatically included                                               |
| Built-in `--completions {bash,…}` | Yes              | Automatically included; disable with `disable_default_completions()` |
| Hidden arguments                  | No (intentional) | `.hidden()` arguments are excluded from completion                   |
| Positional arguments              | No (by design)   | Positionals use default shell completion (file paths, etc.)          |
| Persistent (global) flags         | Yes (root level) | Inherited flags appear in the root command's completions             |

> **Note:** Negatable flags (`--color` / `--no-color`) — the `--no-X` form is **not** separately listed in completions. The base `--color` flag is completed; users type `--no-` manually. This matches the behaviour of other CLI frameworks.

## Developer Validation

ArgMojo provides **two layers of validation** to catch developer mistakes as early as possible — before end users ever see them.

### Compile-Time Validation

All `Argument` builder methods that accept fixed, known values use **compile-time parameters** (`StringLiteral`). The Mojo compiler rejects invalid values during `mojo build`, so the binary is never produced:

```mojo
# ✓ Valid — compiles successfully
Argument("verbose", help="Verbose output").long["verbose"]().short["v"]().flag()

# ✗ Compile error — "REED" is not a valid colour name
command.header_color["REED"]()   # caught by comptime assert at compile time
```

Methods validated at compile time include:

| Method                         | What is checked                             |
| ------------------------------ | ------------------------------------------- |
| `.long[name]()`                | Long option name is a `StringLiteral`       |
| `.short[ch]()`                 | Short option character is a `StringLiteral` |
| `.choice[val]()`               | Choice value is a `StringLiteral`           |
| `.default[val]()`              | Default value is a `StringLiteral`          |
| `.value_name[name]()`          | Value placeholder is a `StringLiteral`      |
| `.max[N]()`                    | Count ceiling is a positive `Int`           |
| `.number_of_values[N]()`       | Value count is a positive `Int`             |
| `.range[min, max]()`           | Range bounds are valid `Int` values         |
| `header_color[name]()`         | Colour name is one of the accepted names    |
| `arg_color[name]()`            | Same as above                               |
| `warn_color[name]()`           | Same as above                               |
| `error_color[name]()`          | Same as above                               |
| `response_file_max_depth[N]()` | Depth is a positive `Int`                   |

### Runtime Registration Validation

Some `Command`-level methods accept **argument names as strings** to define group constraints or relationships. Because the set of registered arguments is built dynamically at runtime (via `add_argument()`), these names cannot be validated at compile time.

Instead, ArgMojo validates them **at registration time** — the moment you call the method, not when the end user provides input. If any name does not match a registered argument, an `Error` is raised immediately:

```mojo
var command = Command("myapp", "A sample application")
command.add_argument(Argument("json", help="JSON output").long["json"]().flag())
command.add_argument(Argument("yaml", help="YAML output").long["yaml"]().flag())

# ✓ Valid — both names are registered
command.one_required(["json", "yaml"])

# ✗ Runtime Error — "ymal" is not a registered argument
# Error: one_required(): unknown argument 'ymal'
command.one_required(["json", "ymal"])   # typo caught on first execution
```

This error fires **every time the program starts**, during command construction, regardless of what arguments the end user passes. The developer sees it on their very first `mojo run`.

Methods validated at registration time:

| Method                           | What is checked                                      |
| -------------------------------- | ---------------------------------------------------- |
| `mutually_exclusive(names)`      | All names exist in `self.args`                       |
| `required_together(names)`       | All names exist in `self.args`                       |
| `one_required(names)`            | All names exist in `self.args`                       |
| `required_if(target, condition)` | Both names exist in `self.args`                      |
| `implies(trigger, implied)`      | Both names exist, implied is a flag/count, no cycles |

### Recommended Workflow

To ensure your CLI definition is free of developer errors:

1. **Compile your application** (`mojo build …`) — catches compile-time parameter errors (wrong colour names, invalid builder values, etc.).
2. **Run the executable once** (even without arguments) — catches registration-time errors (typos in argument names passed to group constraints).

Note that a single `mojo run` is enough (it sequentially builds and then executes the binary).

> **ArgMojo contributors:** the repository provides `pixi run debug`, which packages the library and runs every example under `-D ASSERT=all` with `--help`. This exercises both compile-time and registration-time validation in one step. The CI workflow runs `pixi run package`, `pixi run test`, and `pixi run debug`, so pull requests automatically catch both classes of errors.

## Declarative API (Struct-Based)

> **Status**: Available since v0.5.0. The declarative API is **optional** — if you prefer the builder API, nothing changes for you.

ArgMojo provides a struct-based declarative API inspired by Swift's [swift-argument-parser](https://github.com/apple/swift-argument-parser). Instead of building `Command` + `Argument` chains imperatively, you define a struct that conforms to the `Parsable` trait, and ArgMojo uses compile-time reflection to generate the parser automatically.

```mojo
from argmojo import Parsable, Option, Flag, Positional, Count
```

### Wrapper Types

Four wrapper types encode argument metadata as compile-time parameters:

| Wrapper         | CLI syntax                   | Example                                                           |
| --------------- | ---------------------------- | ----------------------------------------------------------------- |
| `Positional[T]` | Bare value, matched by order | `var input: Positional[String, help="Input file", required=True]` |
| `Option[T]`     | `--key value` or `-k value`  | `var output: Option[String, long="output", short="o"]`            |
| `Flag`          | `--switch` (no value)        | `var verbose: Flag[short="v", help="Verbose mode"]`               |
| `Count`         | `-vvv` (repeated)            | `var debug: Count[short="d", help="Debug level", max=3]`          |

Each wrapper accepts the same parameters as the corresponding builder methods (e.g. `choices`, `default`, `append`, `range_min`/`range_max`, `group`, `prompt`, `password`, etc.) as compile-time keyword parameters. See `src/argmojo/argument_wrappers.mojo` for the full parameter list.

### The `Parsable` Trait

A struct conforming to `Parsable` only needs to provide `description()`:

```mojo
struct MyArgs(Parsable):
    var pattern: Positional[String, help="Search pattern", required=True]
    var verbose: Flag[short="v", help="Verbose output"]

    @staticmethod
    def description() -> String:
        return "My awesome tool."
```

No `__init__` is needed — the trait auto-initialises all fields via reflection. Optional overrides:

| Method          | Default      | Purpose                             |
| --------------- | ------------ | ----------------------------------- |
| `description()` | *(required)* | Help text description               |
| `version()`     | `"0.1.0"`    | `--version` string                  |
| `name()`        | `"command"`  | Program name in help                |
| `subcommands()` | no-op        | Register child commands (see below) |
| `run()`         | no-op        | Execute command logic after parsing |

### Pure Declarative — One-Line Parse

For simple tools, one line is all you need:

```mojo
def main() raises:
    var args = Search.parse()      # build + parse sys.argv() + typed result
    print(args.pattern.value)
    print(args.verbose.value)
```

For testing without a real binary, use `parse_args()` with an explicit argument list:

```mojo
var args = Search.parse_args(List[String]("search", "--verbose", "query"))
```

See [`examples/declarative/search.mojo`](../examples/declarative/search.mojo) for a complete example.

### Hybrid — Declarative + Builder Customisation

When you need builder-level features (mutually exclusive groups, implications, colours, tips) on top of a declarative struct, use the `to_command()` → modify → `parse_from_command()` bridge:

```mojo
def main() raises:
    var cmd = Deploy.to_command()               # struct → owned Command
    cmd.mutually_exclusive(["force", "dry_run"])
    cmd.implies("force", "validated")
    cmd.add_tip("Use --dry-run to preview changes first")
    cmd.header_color["CYAN"]()
    var deploy = Deploy.parse_from_command(cmd^)       # Command → typed struct
    print(deploy.target.value)
```

See [`examples/declarative/deploy.mojo`](../examples/declarative/deploy.mojo) for a complete example.

### Full Parse — Declarative + Extra Builder Fields

When some arguments are too complex for the struct, add them via builder methods and retrieve both the typed struct and the raw `ParseResult`:

```mojo
def main() raises:
    var cmd = Convert.to_command()
    cmd.add_argument(
        Argument("format", help="Output format")
        .long["format"]().choice["json"]().choice["yaml"]().default["json"]()
    )
    var (args, raw) = Convert.parse_full_from_command(cmd^)
    print(args.input.value)              # typed — from struct
    print(raw.get_string("format"))      # untyped — from builder
```

See [`examples/declarative/convert.mojo`](../examples/declarative/convert.mojo) for a complete example.

### Subcommands

Every level in the command tree is a `Parsable` struct. Register children via the `subcommands()` hook:

```mojo
struct Clone(Parsable):
    var url: Positional[String, help="Repository URL", required=True]
    var depth: Option[Int, long="depth", help="Clone depth", default="0"]

    @staticmethod
    def description() -> String: return "Clone a repository."
    @staticmethod
    def name() -> String: return "clone"
    def run(self) raises:
        print("Cloning:", self.url.value)

struct MyGit(Parsable):
    var verbose: Flag[short="v", help="Verbose output", persistent=True]

    @staticmethod
    def name() -> String: return "mgit"
    @staticmethod
    def description() -> String: return "A mini git tool."

    @staticmethod
    def subcommands() raises -> List[Command]:
        var subs = List[Command]()
        subs.append(Clone.to_command())
        return subs^

def main() raises:
    var (git_args, result) = MyGit.parse_full()
    if git_args.verbose:
        print("Verbose mode on")
    if result.subcommand == "clone":
        var sub = result.get_subcommand_result()
        Clone.from_parse_result(sub).run()
```

See [`examples/declarative/jomo.mojo`](../examples/declarative/jomo.mojo) for a more complete example that mixes declarative and builder subcommands, including nested subcommands.

### Auto-Naming Convention

When you don't provide an explicit `long` name, the field name is used with underscores converted to hyphens:

| Field name    | Auto-generated `--` name |
| ------------- | ------------------------ |
| `max_count`   | `--max-count`            |
| `verbose`     | `--verbose`              |
| `output_file` | `--output-file`          |

Fields wrapped in `Positional[...]` don't get auto-generated long names.

### API Summary

| Method                            | Returns                 | Purpose                                                      |
| --------------------------------- | ----------------------- | ------------------------------------------------------------ |
| `T.parse()`                       | `T`                     | Build + parse `sys.argv()` + typed result                    |
| `T.parse_args(args)`              | `T`                     | Parse explicit arg list (testing)                            |
| `T.to_command()`                  | `Command`               | Reflect struct → owned `Command` for customisation           |
| `T.parse_from_command(cmd^)`      | `T`                     | Parse a customised `Command` → typed struct                  |
| `T.parse_full()`                  | `Tuple[T, ParseResult]` | Typed struct + raw result from `sys.argv()`                  |
| `T.parse_full_from_command(cmd^)` | `Tuple[T, ParseResult]` | Typed struct + raw result from customised `Command`          |
| `T.from_parse_result(result)`     | `T`                     | Write-back from existing `ParseResult` (subcommand dispatch) |

The four parsing methods follow a 2×2 naming convention:

|                 | `sys.argv()`   | from `Command`                  |
| --------------- | -------------- | ------------------------------- |
| returns `Self`  | `parse()`      | `parse_from_command(cmd^)`      |
| returns `Tuple` | `parse_full()` | `parse_full_from_command(cmd^)` |

- **`full`** means dual return — you get both the typed struct and the raw `ParseResult`.
- **`from_command`** means parsing from a pre-configured `Command` (created via `to_command()` + builder customisation).

## Cross-Library Method Name Reference

The table below maps every ArgMojo builder method / command-level method to its equivalent in four popular CLI libraries. **An empty cell means the name is identical (or near-identical) to ArgMojo's.** A filled cell shows the other library's name or approach. **—** means the library has no built-in equivalent.

> Libraries compared: **argparse** (Python stdlib), **click** (Python CLI framework), **clap** (Rust, derive & builder API), **cobra / pflag** (Go).

### Argument-Level Builder Methods

| ArgMojo method                  | argparse                          | click                                    | clap (Rust)                     | cobra / pflag (Go)             |
| ------------------------------- | --------------------------------- | ---------------------------------------- | ------------------------------- | ------------------------------ |
| `Argument("name", help="…")`    | `add_argument("name", help="…")`  | `@click.option("--name", help="…")`      | `Arg::new("name").help("…")`    | `cmd.Flags().StringP(…)`       |
| `.long["x"]()`                  | prefix `--x` in name string       | prefix `--x` in decorator                | `.long("x")`                    | implicit from flag name        |
| `.short["x"]()`                 | prefix `-x` in name string        | implicit or combined with long           | `.short('x')`                   | `StringP` → second arg         |
| `.flag()`                       | `action="store_true"`             | `is_flag=True`                           | `action(ArgAction::SetTrue)`    | `BoolP` / `BoolVarP`           |
| `.required()`                   | `required=True`                   |                                          | `.required(true)`               | `MarkFlagRequired()` ¹         |
| `.positional()`                 | no prefix (positional by default) | `@click.argument()`                      | `.index(N)` ²                   | `cmd.Args` ³                   |
| `.takes_value()`                | (default for non-flag)            | (default for options)                    | `.action(ArgAction::Set)`       | (default for non-bool)         |
| `.default["val"]()`             | `default="val"`                   |                                          | `.default_value("val")`         | flag definition arg            |
| `.choice["a"]().choice["b"]()`  | `choices=["a","b"]`               | `type=click.Choice(…)`                   | `.value_parser(["a","b"])`      | — ⁴                            |
| `.value_name["FILE"]()`         | `metavar="FILE"`                  | `metavar="FILE"`                         | `.value_name("FILE")`           | —                              |
| `.hidden()`                     | `help=argparse.SUPPRESS`          |                                          | `.hide(true)`                   | `MarkHidden()` ¹               |
| `.count()`                      | `action="count"`                  | `count=True`                             | `.action(ArgAction::Count)`     | `CountP` / `CountVarP`         |
| `.max[N]()`                     | —                                 | —                                        | —                               | —                              |
| `.negatable()`                  | `BooleanOptionalAction`           | `flag_value` / `is_flag` + `secondary` ⁵ | —                               | `--no-x` pattern ⁶             |
| `.append()`                     | `action="append"`                 | `multiple=True`                          | `.action(ArgAction::Append)`    | `StringSliceP`                 |
| `.delimiter[","]()`             | `type` + split                    | —                                        | `.value_delimiter(',')`         | `StringSliceP` (comma default) |
| `.number_of_values[N]()`        | `nargs=N`                         | `nargs=N`                                | `.num_args(N)`                  | —                              |
| `.range[min,max]()`             | `type` + manual check             | `type=IntRange(…)`                       | `.value_parser(RangedI64…)`     | — ⁴                            |
| `.clamp()`                      | —                                 | `clamp=True` (on `IntRange`)             | —                               | —                              |
| `.map_option()`                 | —                                 | —                                        | —                               | —                              |
| `.alias_name["alt"]()`          | — (use multiple names)            | —                                        | `.visible_alias("alt")`         | —                              |
| `.deprecated["msg"]()`          | `deprecated` (3.13+)              | `deprecated=True`                        | `.hide(true)` + manual          | `ShorthandDeprecated()` ¹      |
| `.persistent()`                 | — ⁷                               | —                                        | `.global(true)`                 | `PersistentFlags()`            |
| `.default_if_no_value["val"]()` | `const="val"` + `nargs="?"`       | — ⁸                                      | `.default_missing_value("val")` | `NoOptDefVal` field            |
| `.require_equals()`             | —                                 | —                                        | `.require_equals(true)`         | —                              |
| `.remainder()`                  | `nargs=argparse.REMAINDER`        | —                                        | `.trailing_var_arg(true)` ¹¹    | `TraverseChildren` ¹²          |
| `.allow_hyphen_values()`        | —                                 | —                                        | `.allow_hyphen_values(true)`    | —                              |
| `.prompt()`                     | —                                 | `prompt=True`                            | —                               | —                              |
| `.prompt["msg"]()`              | —                                 | `prompt="msg"`                           | —                               | —                              |
| `.password()`                   | —                                 | `hide_input=True`                        | —                               | —                              |

### Command-Level Constraint Methods

| ArgMojo method              | argparse                         | click                           | clap (Rust)                    | cobra / pflag (Go)              |
| --------------------------- | -------------------------------- | ------------------------------- | ------------------------------ | ------------------------------- |
| `mutually_exclusive(…)`     | `add_mutually_exclusive_group()` | `cls=MutuallyExclusiveOption` ⁹ | `.conflicts_with("x")` per arg | — ⁴                             |
| `one_required(…)`           | group + `required=True`          | —                               | `.group["G"]().required(true)` | — ⁴                             |
| `required_together(…)`      | —                                | —                               | `.requires("x")` per arg       | `MarkFlagsRequiredTogether()` ¹ |
| `required_if(target, cond)` | —                                | —                               | `.required_if_eq("x","v")`     | `MarkFlagRequired…` ¹           |
| `implies(trigger, implied)` | —                                | —                               | `.requires_if("v","x")` ¹⁰     | —                               |
| `parse_known_arguments()`   | `parse_known_args()`             | —                               | — ¹¹                           | `FParseErrWhitelist` ¹²         |
| `response_file_prefix()`    | `fromfile_prefix_chars="@"`      | —                               | —                              | —                               |
| `add_parent(parent)`        | `parents=[parent]`               | —                               | —                              | —                               |
| `confirmation_option()`     | —                                | `confirmation_option`           | —                              | —                               |

### Notes

1. Cobra / pflag uses imperative `cmd.MarkFlag…()` calls on the command, not builder-chaining on the flag definition.
2. clap positional args are defined by `.index(1)`, `.index(2)`, etc., or by omitting `.long()` / `.short()`.
3. Cobra uses `cobra.ExactArgs(n)`, `cobra.MinimumNArgs(n)`, etc. — a completely different approach.
4. No built-in support; typically implemented with custom validation logic.
5. click supports `--flag/--no-flag` via `is_flag=True, flag_value=…` or the `secondary` parameter.
6. Cobra / pflag has no first-class negatable flag; users manually add a `--no-x` flag.
7. argparse has `parents=` for sharing argument definitions, but not inheritable persistent flags in a subcommand tree.
8. click's closest equivalent is `is_eager` combined with a custom callback; there is no direct `const` equivalent for options.
9. click has no built-in `MutuallyExclusiveOption`; it is typically implemented via a custom `cls` or callback.
10. clap's `.requires_if("val", "other_arg")` means "if this arg has value `val`, then `other_arg` is also required", which is a superset of ArgMojo's `implies`.
11. clap uses `.trailing_var_arg(true)` on the command (not the argument) for remainder-like behaviour. For `parse_known_arguments`, clap has no direct equivalent; use `allow_external_subcommands`.
12. Cobra uses `TraverseChildren` for remainder-like behaviour. For partial parsing, Cobra's `FParseErrWhitelist{UnknownFlags: true}` ignores unknown flags.
