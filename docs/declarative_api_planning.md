# ArgMojo Declarative API — Design & Implementation Plan

> **Status**: Planning  
> **Target**: argmojo v0.5.0  
> **Mojo Version**: 0.26.2+  
> **Date**: 2026-03-24

## 1. Design Goals

1. **Optional** — Users who prefer the builder API are completely unaffected. The declarative module is a separate import (`from argmojo.declarative import ...`). Zero change to existing code.

2. **Hybrid** — Builder and declarative can coexist in a single program. A user can define a struct for 80% of arguments, then use builder methods for the remaining 20% (groups, implications, advanced constraints).

3. **Layered** — The declarative layer is a *consumer* of the builder layer. Internally it constructs `Command` + `Argument` objects and calls `Command.parse()`. No new parsing engine.

4. **Type-safe** — Parsed results are returned as the user's own struct with typed fields, not `ParseResult.get_string("name")`.

5. **Two innovations** - I think that there might be two possible features beyond what Swift Argument Parser offers (see [this section](#6-innovations)).

## 2. Mojo Reflection Capabilities (v0.26.2)

Available compile-time reflection primitives:

| API                                 | Purpose                                  |
| ----------------------------------- | ---------------------------------------- |
| `struct_field_count[T]()`           | Number of fields in struct T             |
| `struct_field_names[T]()`           | Indexable list of field name strings     |
| `struct_field_types[T]()`           | Indexable list of field types            |
| `get_type_name[T]()`                | String name of type T                    |
| `__struct_field_ref(idx, instance)` | Reference to field by compile-time index |
| `conforms_to(type, Trait)`          | Compile-time trait conformance check     |
| `trait_downcast[Trait](value)`      | Cast value to trait-conforming type      |
| `@fieldwise_init`                   | Auto-generate constructor from fields    |
| `comptime for idx in range(N)`      | Compile-time loop                        |
| `comptime if condition`             | Compile-time conditional                 |

**Key limitation**: No proc macros, no custom decorators, no `#[derive(...)]`. All declarative behavior must be implemented via parametric functions that reflect over user-defined structs.

**Primary inspiration — Swift Argument Parser**: Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser) is the most relevant prior art because Swift and Mojo share key language characteristics — static typing, struct-oriented design, and protocol/trait conformance. Swift uses **property wrappers** (`@Argument`, `@Option`, `@Flag`) as metadata carriers on struct fields. ArgMojo adopts the same vocabulary directly as **parametric wrapper types** (`Argument[T, ...]`, `Option[T, ...]`, `Flag[...]`), which carry CLI metadata as compile-time keyword parameters. Example:

```swift
struct Greet: ParsableCommand {
    @Argument(help: "The person's name.")
    var name: String

    @Option(name: .shortAndLong, help: "Repeat count.")
    var count: Int = 1

    @Flag(inversion: .prefixedNo, help: "Include greeting.")
    var includeGreeting = true

    mutating func run() throws {
        for _ in 0..<count { print("Hello, \(name)!") }
    }
}
Greet.main()
```

Direct mapping to argmojo declarative API:

| Swift Mechanism                  | ArgMojo Equivalent                          |
| -------------------------------- | ------------------------------------------- |
| `@Argument(help: "...")`         | `Argument[T, help="..."]`                   |
| `@Option(name: .shortAndLong)`   | `Option[T, long="...", short="..."]`        |
| `@Flag(inversion: .prefixedNo)`  | `Flag[negatable=True]`                      |
| (no Swift equivalent)            | `Count[short="v", max=3]`                   |
| `ParsableCommand` protocol       | `ArgStruct` trait                           |
| `@OptionGroup`                   | Argument parents via `Command.add_parent()` |
| `ExpressibleByArgument` protocol | Planned `Parseable` trait                   |
| `CommandGroup`                   | `SubApp[...]`                               |
| `mutating func run()`            | Separate: `App[T].parse()` returns T        |
| `mutating func validate()`       | `fn validate(self) raises` on `ArgStruct`   |

**What argmojo adds beyond Swift**: (1) `to_command()` exposes the underlying `Command` for builder-level customisation — Swift's `ParsableCommand` is a sealed box with no escape hatch to builder-level features like mutually exclusive groups, implications, or custom help formatting. (2) `parse_split()` returns both typed struct + `ParseResult` — Swift requires all fields to live in the struct. (3) Declarative is optional — Swift has no builder alternative; you must use the struct-based approach.

**Lesson — `validate()`**: An optional `fn validate(self) raises` method on `ArgStruct` (mirroring Swift's `validate()`) could complement `to_command()` for post-parse cross-field validation without requiring the builder API.

## 3. Architecture

```txt
┌──────────────────────────────────────────────────────────────────┐
│  User Code                                                       │
│                                                                  │
│  @fieldwise_init                                                 │
│  struct MyArgs(ArgStruct):                                       │
│      var name: Argument[String, help="Name", required=True]      │
│      var verbose: Flag[short="v", help="Verbose"]                │
│      var output: Option[String, long="output", short="o"]        │
│      fn __init__(out self): self = arg_defaults[Self]()          │
│                                                                  │
│  var app = App[MyArgs]()                                         │
│  var cmd = app.to_command()                                      │
│  cmd.mutually_exclusive([...])                                   │
│  var args = app.parse()  →  MyArgs (typed struct)                │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  declarative.mojo  (NEW — ~400-600 lines)                        │
│                                                                  │
│  App[T].to_command()    → Command    (reflect T → builder calls) │
│  App[T].parse()         → T          (parse + write-back)        │
│  App[T].from_result()   → T          (ParseResult → struct)      │
│  arg_defaults[T]()      → T          (default-initialized)       │
│                                                                          │
│  Wrapper types: Option[T, ...], Flag[...], Argument[T, ...], Count[...]  │
│  Trait: ArgStruct                                                        │
│                                                                          │
├──────────────────────────────────────────────────────────────────┤
│  argument.mojo + command.mojo + parse_result.mojo  (UNCHANGED)   │
│                                                                  │
│  Argument(...).long["x"]().short["y"]().flag()                   │
│  Command("app").add_argument(...).parse() → ParseResult          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Files Changed

| File                           | Change                                           |
| ------------------------------ | ------------------------------------------------ |
| `src/argmojo/declarative.mojo` | **New file** — all declarative types and logic   |
| `src/argmojo/__init__.mojo`    | Add `from .declarative import ...` (conditional) |
| Everything else                | **Zero changes**                                 |

## 4. Detailed API Design

### 4.1 Wrapper Types

These are lightweight parametric structs that carry CLI metadata as compile-time parameters while wrapping an inner value at runtime.

```mojo
struct Option[
    T: Defaultable & Movable,
    *,
    long: StringLiteral = "",       # --option name (empty = auto from field name)
    short: StringLiteral = "",      # -o single char
    help: StringLiteral = "",       # help text
    default: StringLiteral = "",    # default value as string
    required: Bool = False,         # must be provided
    choices: StringLiteral = "",    # comma-separated allowed values: "json,yaml,csv"
    value_name: StringLiteral = "", # display name in help
    hidden: Bool = False,           # hidden from help
    deprecated: StringLiteral = "", # deprecation message
    append: Bool = False,           # collect into list (T should be List[String])
    delimiter: StringLiteral = "",  # split by delimiter
    nargs: Int = 0,                 # number of values (0 = single)
    range_min: Int = 0,             # numeric range min
    range_max: Int = 0,             # numeric range max
    has_range: Bool = False,        # enable range validation
    clamp: Bool = False,            # clamp instead of error
    map_option: Bool = False,       # key=value map mode
    persistent: Bool = False,       # inherited by subcommands
    prompt: Bool = False,           # interactive prompt if missing
    prompt_text: StringLiteral = "",# custom prompt message
    password: Bool = False,         # masked input
    require_equals: Bool = False,   # require --key=value syntax
    alias: StringLiteral = "",      # comma-separated alias long names
    negatable: Bool = False,        # --x / --no-x (only if T is Bool)
    allow_hyphen: Bool = False,     # allow hyphen-prefixed values
    group: StringLiteral = "",      # help group name
](Copyable, Movable, Defaultable):
    var value: T

    fn __init__(out self):
        self.value = T()

    fn __init__(out self, val: T):
        self.value = val
```

```mojo
# Convenience aliases for common patterns

alias Flag = Option[Bool, ...]     # Can't do this directly in Mojo yet.
                                # Instead, Flag is a separate struct:

struct Flag[
    *,
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    negatable: Bool = False,
    persistent: Bool = False,
    hidden: Bool = False,
    deprecated: StringLiteral = "",
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    var value: Bool

    fn __init__(out self):
        self.value = False

    fn __init__(out self, val: Bool):
        self.value = val

    # Implicit conversion to Bool for convenience
    fn __bool__(self) -> Bool:
        return self.value
```

```mojo
struct Argument[
    T: Defaultable & Movable,
    *,
    help: StringLiteral = "",
    default: StringLiteral = "",
    required: Bool = False,
    choices: StringLiteral = "",
    value_name: StringLiteral = "",
    remainder: Bool = False,       # consume all remaining tokens
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    var value: T

    fn __init__(out self):
        self.value = T()

    fn __init__(out self, val: T):
        self.value = val
```

```mojo
struct Count[
    *,
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    max: Int = 0,                  # 0 = no ceiling
    persistent: Bool = False,
    hidden: Bool = False,
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    var value: Int

    fn __init__(out self):
        self.value = 0

    fn __init__(out self, val: Int):
        self.value = val
```

**Design choice**: Four wrapper types (`Option`, `Flag`, `Argument`, `Count`) instead of one overloaded `Option` with `is_arg=True` / `is_flag=True`. This is intentional:

- Explicit intent: `Flag[...]` is obviously a flag, `Argument[...]` is obviously positional
- Fewer confusing parameter combinations (e.g., `Argument` doesn't have `long`/`short`)
- Better compile-time validation (can't accidentally make a positional with `long`)

Users can also use **bare types** (like `String`, `Int`, `Bool`) for fields without metadata — they become options named after the field, following Swift's convention for fields without property wrappers.

**Naming note — `Argument` builder vs declarative**: The builder API already has an `Argument` struct (in `argument.mojo`) for defining individual arguments. The declarative module introduces `Argument[T, ...]` (in `declarative.mojo`) as the positional argument wrapper, matching Swift's `@Argument`. They live in separate modules:
- `from argmojo import Argument` — builder struct, constructed at runtime: `Argument("name", help="...")`
- `from argmojo.declarative import Argument` — parametric wrapper, used as a field type: `var name: Argument[String, help="..."]`

In **pure declarative** mode, no conflict. In **hybrid** mode where both are needed, use aliased imports:
```mojo
from argmojo import Command, Argument as BuilderArgument
from argmojo.declarative import App, Option, Flag, Argument, ArgStruct
```

### 4.2 The `ArgStruct` Trait

```mojo
trait ArgStruct(Defaultable, Movable):
    """Marker trait for structs that can be parsed from CLI arguments."""

    @staticmethod
    fn description() -> String:
        """Return the command description for --help."""
        ...

    @staticmethod
    fn version() -> String:
        """Return the version string for --version. Default "0.1.0"."""
        ...

    @staticmethod
    fn name() -> String:
        """Return the command name. Default: lowercased struct name."""
        ...
```

Minimal implementation by users:

```mojo
@fieldwise_init
struct MyArgs(ArgStruct):
    var input: Argument[String, help="Input file", required=True]

    fn __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    fn description() -> String:
        return "My awesome tool"
```

`version()` and `name()` have default implementations in the trait, so they're optional.

### 4.3 The `App[T]` Orchestrator

```mojo
struct App[T: ArgStruct]:
    """Orchestrates struct-to-command conversion, parsing, and write-back."""

    var _command: Command
    var _built: Bool

    fn __init__(out self):
        self._command = Command(T.name(), T.description(), version=T.version())
        self._built = False

    # ── Core methods ──

    fn to_command(mut self) raises -> ref Command:
        """Build and return the underlying Command.
        Users can modify it with builder methods before parsing."""
        if not self._built:
            self._build()
            self._built = True
        return self._command

    fn parse(mut self) raises -> T:
        """Parse sys.argv() and return a populated T instance."""
        if not self._built:
            self._build()
            self._built = True
        var result = self._command.parse()
        return self._from_result(result)

    fn parse_args(mut self, raw_args: List[String]) raises -> T:
        """Parse explicit arg list and return a populated T instance."""
        if not self._built:
            self._build()
            self._built = True
        var result = self._command.parse_arguments(raw_args)
        return self._from_result(result)

    # ── Innovation #1: to_command() — expose Command for builder tweaks (see §6.1) ──

    # to_command() is already defined above in "Core methods".
    # It returns a mutable reference to the underlying Command,
    # allowing arbitrary builder modifications before parsing.
    # No closure required — works in Mojo 0.26.2.

    # ── configure() with non-capturing callback ──
    # Works in Mojo 0.26.2 as long as the callback does NOT capture external state.
    # This is fine for configure() because all operations target the `mut Command` parameter.
    # NOTE: Capturing closures (unified {mut x}) cannot be passed as fn() arguments
    #       due to type mismatch (nonescaping closure ≠ bare fn). Non-capturing is sufficient here.

    fn configure(mut self, callback: fn(mut Command) raises -> None) raises -> ref Self:
        """Apply builder-level customizations via callback."""
        if not self._built:
            self._build()
            self._built = True
        callback(self._command)
        return self

    # ── Innovation #2: parse_split (see §6.2) ──

    fn parse_split(mut self) raises -> (T, ParseResult):
        """Parse and return BOTH a typed struct AND the raw ParseResult.
        The struct contains declarative-registered fields.
        The ParseResult contains everything (including builder-added fields)."""
        if not self._built:
            self._build()
            self._built = True
        var result = self._command.parse()
        var typed = self._from_result(result)
        return (typed, result)

    # ── Internal ──

    fn _build(mut self) raises:
        """Reflect over T's fields and register Arguments."""
        comptime field_count = struct_field_count[T]()
        comptime field_names = struct_field_names[T]()
        comptime field_types = struct_field_types[T]()

        comptime for idx in range(field_count):
            comptime fname = field_names[idx]
            comptime ftype = field_types[idx]

            # Dispatch based on wrapper type
            comptime if _is_option_type(ftype):
                self._register_option(fname, ftype)
            elif _is_flag_type(ftype):
                self._register_flag(fname, ftype)
            elif _is_argument_type(ftype):
                self._register_argument(fname, ftype)
            elif _is_count_type(ftype):
                self._register_count(fname, ftype)
            else:
                # Bare type: treat as named option with field name as long name
                self._register_bare(fname, ftype)

    fn _from_result(self, result: ParseResult) raises -> T:
        """Write ParseResult values back into a T instance."""
        var out = T()
        comptime field_count = struct_field_count[T]()
        comptime field_names = struct_field_names[T]()
        comptime field_types = struct_field_types[T]()

        comptime for idx in range(field_count):
            comptime fname = field_names[idx]
            comptime ftype = field_types[idx]

            comptime if _is_flag_type(ftype):
                ref field = __struct_field_ref(idx, out)
                field.value = result.get_flag(String(fname))
            elif _is_count_type(ftype):
                ref field = __struct_field_ref(idx, out)
                field.value = result.get_count(String(fname))
            elif _is_argument_type(ftype):
                ref field = __struct_field_ref(idx, out)
                # Write positional value:
                #   If T is List[String] → get_list
                #   If T is String → get_string
                #   If T is Int → get_int
                _write_argument_value(field, fname, result)
            elif _is_option_type(ftype):
                ref field = __struct_field_ref(idx, out)
                _write_option_value(field, fname, result)
            else:
                # Bare type
                ref field = __struct_field_ref(idx, out)
                _write_bare_value(field, fname, result)

        return out
```

### 4.4 The `arg_defaults[T]()` Helper

Initialises all wrapper fields to their defaults (inspired by Swift's default property initialization):

```mojo
fn arg_defaults[T: ArgStruct]() -> T:
    """Create a default-initialized instance of T.
    Wrapper types (Option, Flag, Argument, Count) are initialized to their defaults.
    Bare types use their Defaultable implementation."""
    return T()  # Works because T: Defaultable, and all wrappers are Defaultable
```

### 4.5 Auto-Naming Convention

When `long` is not explicitly provided, the field name is used with underscores converted to hyphens:

| Field name    | Auto-generated long | Short  |
| ------------- | ------------------- | ------ |
| `max_count`   | `--max-count`       | (none) |
| `verbose`     | `--verbose`         | (none) |
| `output_file` | `--output-file`     | (none) |

This matches the Swift and clap convention. Fields wrapped in `Argument[...]` do not get auto-generated long names.

### 4.6 Choice Parsing from StringLiteral

Since Mojo parameters must be compile-time constants and we can't pass `List[StringLiteral]`, choices are encoded as a comma-separated string:

```mojo
var format: Option[String, choices="json,yaml,csv", default="json"]
```

Internally, `_register_option()` splits by `,` and calls `.choice["json"]().choice["yaml"]().choice["csv"]()` etc.

Similarly, `alias` is comma-separated:

```mojo
var output: Option[String, long="output", alias="out,dest"]
```

This generates `.alias_name["out"]().alias_name["dest"]()`.

## 5. Usage Examples

### 5.1 Pure Declarative (Simple Tool)

```mojo
from argmojo.declarative import App, Option, Flag, Argument, Count, ArgStruct, arg_defaults

@fieldwise_init
struct Grep(ArgStruct):
    """Search for patterns in files."""

    var pattern: Argument[String, help="Search pattern", required=True]
    var path: Argument[String, help="File or directory", default="."]
    var ignore_case: Flag[short="i", help="Case-insensitive search"]
    var count_only: Flag[short="c", long="count", help="Only print match count"]
    var max_count: Option[Int, short="m", long="max-count", help="Stop after N matches", default="0"]
    var verbose: Count[short="v", help="Increase verbosity", max=3]
    var ext: Option[List[String], short="e", long="ext", help="File extensions", append=True]

    fn __init__(out self):
        self = arg_defaults[Self]()

    @staticmethod
    fn description() -> String:
        return "Search for patterns in files."

    @staticmethod
    fn version() -> String:
        return "1.0.0"

def main() raises:
    var args = App[Grep]().parse()

    print("Pattern:", args.pattern.value)
    print("Path:", args.path.value)
    if args.ignore_case:           # Flag.__bool__() works
        print("Case insensitive mode")
    if args.verbose.value > 0:
        print("Verbosity level:", args.verbose.value)
    for e in args.ext.value:
        print("Extension:", e[])
```

### 5.2 Declarative + Builder Hybrid (Complex Tool)

```mojo
from argmojo import Command, Argument as BuilderArgument
from argmojo.declarative import App, Option, Flag, Argument, ArgStruct, arg_defaults

@fieldwise_init
struct Deploy(ArgStruct):
    var target: Argument[String, help="Deploy target", required=True, choices="staging,prod"]
    var force: Flag[short="f", help="Force deploy without checks"]
    var dry_run: Flag[long="dry-run", help="Simulate without changes"]
    var tag: Option[String, long="tag", short="t", help="Release tag"]
    var replicas: Option[Int, long="replicas", short="r", help="Number of replicas",
                      default="3", has_range=True, range_min=1, range_max=100]

    fn __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    fn description() -> String:
        return "Deploy application to target environment."

def main() raises:
    var app = App[Deploy]()

    # Bridge to builder: add constraints that declarative can't express
    var cmd = app.to_command()
    cmd.mutually_exclusive(["force", "dry-run"])
    cmd.implies("force", "tag")       # force requires a tag
    cmd.confirmation_option["Deploy to production?"]()
    cmd.header_color["CYAN"]()
    cmd.add_tip("Use --dry-run to preview changes first")

    # app.parse() returns typed T; cmd.parse() would return untyped ParseResult.
    # Always prefer app.parse() or app.parse_split() in hybrid mode.
    var args = app.parse()
    print("Deploying to:", args.target.value)
    print("Tag:", args.tag.value)
```

### 5.3 Split Parse (Declarative + Extra Builder Fields)

```mojo
from argmojo import Command, Argument as BuilderArgument
from argmojo.declarative import App, Argument, Option, Flag, ArgStruct, arg_defaults

@fieldwise_init
struct Convert(ArgStruct):
    var input: Argument[String, help="Input file", required=True]
    var output: Option[String, long="output", short="o", help="Output file"]

    fn __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    fn description() -> String:
        return "File format converter."

def main() raises:
    var app = App[Convert]()

    # Add extra builder-only arguments via to_command()
    var cmd = app.to_command()
    cmd.add_argument(
        BuilderArgument("format", help="Output format")
        .long["format"]().short["f"]()
        .choice["json"]().choice["yaml"]().choice["toml"]()
        .default["json"]()
    )
    cmd.add_argument(
        BuilderArgument("indent", help="Indent level")
        .long["indent"]()
        .range[0, 8]().default["2"]()
    )

    # parse_split returns BOTH the typed struct AND the raw ParseResult
    args, result = app.parse_split()

    # Declarative fields: typed access
    print("Input:", args.input.value)
    print("Output:", args.output.value)

    # Builder fields: ParseResult access
    var format = result.get_string("format")
    var indent = result.get_int("indent")
```

### 5.4 Subcommands with Declarative

```mojo
from argmojo.declarative import App, SubApp, Option, Flag, Argument, ArgStruct, arg_defaults

@fieldwise_init
struct Clone(ArgStruct):
    var url: Argument[String, help="Repository URL", required=True]
    var depth: Option[Int, long="depth", help="Clone depth", default="0"]
    var branch: Option[String, short="b", long="branch", help="Branch to clone"]

    fn __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    fn description() -> String:
        return "Clone a repository."

    @staticmethod
    fn name() -> String:
        return "clone"

@fieldwise_init
struct Push(ArgStruct):
    var remote: Argument[String, help="Remote name", default="origin"]
    var force: Flag[short="f", help="Force push"]
    var tags: Flag[long="tags", help="Push all tags"]

    fn __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    fn description() -> String:
        return "Push commits to remote."

    @staticmethod
    fn name() -> String:
        return "push"

def main() raises:
    # SubApp registers multiple ArgStruct types as subcommands
    var result = SubApp["mgit", "A mini git tool", Clone, Push]().parse()

    if result.subcommand == "clone":
        var args = result.get[Clone]()
        print("Cloning:", args.url.value)
    elif result.subcommand == "push":
        var args = result.get[Push]()
        print("Pushing to:", args.remote.value)
```

## 6. Innovations

### 6.1 Innovation #1: `to_command()` — First-Class Declarative-Builder Bridge

**What Swift Argument Parser lacks**: Swift's `ParsableCommand` is a sealed protocol — there is no escape hatch to add builder-level configuration (mutually exclusive groups, implications, colored help, tips, completions). Users who need advanced constraints must implement `validate()` and custom help formatting manually, with no access to a builder API.

**What argmojo adds**: `to_command()` returns a mutable reference to the underlying `Command` object, allowing arbitrary builder modifications before parsing:

```mojo
var app = App[MyArgs]()
var cmd = app.to_command()
cmd.mutually_exclusive(["json", "yaml"])
cmd.required_together(["username", "password"])
cmd.implies("debug", "verbose")
cmd.confirmation_option()
cmd.header_color["CYAN"]()
cmd.add_tip("See docs at https://example.com")
cmd.completions_as_subcommand()
var args = app.parse()
```

This creates a **smooth gradient** between simplicity and power:

```
Pure declarative     Declarative + to_command()    Pure builder
(3 lines)            (10 lines)                    (30 lines)
Simple tools    →    Medium complexity tools   →    Maximum control
```

No other Mojo CLI library offers this continuum. You never have to completely rewrite from one style to another when requirements grow.

**Type safety note**: Using `to_command()` to add **constraints** (groups, implications, colours) preserves full type safety — `parse()` still returns `T`. Using it to add **new arguments** (`add_argument(...)`) introduces partially untyped access — those fields are only available via `ParseResult` from `parse_split()`. This is an intentional trade-off:

```txt
to_command() + constraints only     →  parse()        →  T (fully typed ✅)
to_command() + new arguments        →  parse_split()  →  (T, ParseResult) (partially typed ⚠️)
```

**`configure()` with non-capturing callbacks**: Verified in Mojo 0.26.2 — `configure()` works with non-capturing callbacks (nested functions that don't capture external state). Since `configure()` callbacks only operate on the `mut Command` parameter, capturing is unnecessary:

```mojo
var args = App[MyArgs]()
    .configure(fn(mut cmd) raises: cmd.mutually_exclusive([...]))
    .configure(fn(mut cmd) raises: cmd.implies("a", "b"))
    .parse()
```

**Limitation**: Mojo's capturing closures (`unified {mut x}`) produce a `nonescaping closure` type that cannot be passed as a bare `fn()` argument. This doesn't affect `configure()` since its callbacks don't need captures — the `mut Command` parameter provides all necessary state.

`to_command()` remains the primary bridge for multi-step customization; `configure()` is syntactic sugar for one-liner tweaks.

### 6.2 Innovation #2: `parse_split()` — Dual-Return Parsing

**Problem**: When mixing declarative and builder fields, how do you get typed access to declarative fields AND untyped access to builder-added fields?

**Swift's approach**: Not possible. All fields must be declared in the struct. There is no mechanism for dynamically added options.

**Naive approach**: Return only `ParseResult`, losing the typed struct benefit.

**ArgMojo's approach**: `parse_split()` returns a **tuple of both**:

```mojo
fn parse_split(mut self) raises -> (T, ParseResult):
```

- The first element is the user's struct `T` with all declarative-registered fields populated & typed.
- The second element is the full `ParseResult` containing everything (declarative fields + builder-added fields).

This means:

```mojo
var (args, result) = app.parse_split()

# Declarative fields: compile-time typed access, no string keys
args.verbose          # Bool
args.output.value     # String
args.count.value      # Int

# Builder-added fields: runtime string-keyed access
result.get_string("extra-option")
result.get_int("threads")
result.get_list("tags")
```

This is a **new pattern** not seen in any CLI library in any language. Even Rust's clap cannot do this — once you use its derive macro, all fields must be in the struct. There's no mechanism for "some fields are struct, some are ParseResult."

The dual-return enables a practical workflow:

1. Start with pure declarative
2. Need one advanced option? Add it via `to_command()` + `parse_split()`
3. No need to convert the struct field (or add a new nested type)

## 7. Internal Implementation Details

### 7.1 Reflect-to-Builder Translation Table

Each wrapper type maps to specific `Argument` builder calls:

| Wrapper param                               | Builder call generated                           |
| ------------------------------------------- | ------------------------------------------------ |
| `long="output"`                             | `.long["output"]()`                              |
| `short="o"`                                 | `.short["o"]()`                                  |
| `help="..."`                                | `Argument("name", help="...")`                   |
| `default="val"`                             | `.default["val"]()`                              |
| `required=True`                             | `.required()`                                    |
| `choices="a,b,c"`                           | `.choice["a"]().choice["b"]().choice["c"]()`     |
| `value_name="FILE"`                         | `.value_name["FILE"]()`                          |
| `hidden=True`                               | `.hidden()`                                      |
| `deprecated="msg"`                          | `.deprecated["msg"]()`                           |
| `append=True`                               | `.append()`                                      |
| `delimiter=","`                             | `.delimiter[","]()`                              |
| `nargs=3`                                   | `.number_of_values[3]()`                         |
| `has_range=True, range_min=1, range_max=10` | `.range[1, 10]()`                                |
| `clamp=True`                                | `.clamp()`                                       |
| `map_option=True`                           | `.map_option()`                                  |
| `persistent=True`                           | `.persistent()`                                  |
| `prompt=True`                               | `.prompt()`                                      |
| `prompt_text="msg"`                         | `.prompt["msg"]()`                               |
| `password=True`                             | `.password()`                                    |
| `require_equals=True`                       | `.require_equals()`                              |
| `alias="out,dest"`                          | `.alias_name["out"]().alias_name["dest"]()`      |
| `negatable=True`                            | `.negatable()`                                   |
| `allow_hyphen=True`                         | `.allow_hyphen_values()`                         |
| `group="Advanced"`                          | `.group["Advanced"]()`                           |
| **Flag[...]**                               | `.flag()`                                        |
| **Argument[...]**                           | `.positional()`                                  |
| **Argument[..., remainder=True]**           | `.remainder()`                                   |
| **Count[..., max=5]**                       | `.count().max[5]()`                              |
| **bare String/Int/Bool**                    | auto-detected: Bool→`.flag()`, else named option |

### 7.2 Write-Back Type Dispatch

When populating the user's struct from `ParseResult`, the type determines which accessor to call:

| Field type                                    | ParseResult accessor | Write-back                   |
| --------------------------------------------- | -------------------- | ---------------------------- |
| `Flag[...]`                                   | `get_flag(name)`     | `field.value = Bool`         |
| `Count[...]`                                  | `get_count(name)`    | `field.value = Int`          |
| `Option[String, ...]`                         | `get_string(name)`   | `field.value = String`       |
| `Option[Int, ...]`                            | `get_int(name)`      | `field.value = Int`          |
| `Option[List[String], ..., append=True]`      | `get_list(name)`     | `field.value = List[String]` |
| `Option[Dict[...], ..., map_option=True]`     | `get_map(name)`      | `field.value = Dict`         |
| `Argument[String, ...]`                       | `get_string(name)`   | `field.value = String`       |
| `Argument[Int, ...]`                          | `get_int(name)`      | `field.value = Int`          |
| `Argument[List[String], ..., remainder=True]` | `get_list(name)`     | `field.value = List[String]` |
| bare `String`                                 | `get_string(name)`   | `field = String`             |
| bare `Int`                                    | `get_int(name)`      | `field = Int`                |
| bare `Bool`                                   | `get_flag(name)`     | `field = Bool`               |

Missing/optional values: If `result.has(name)` returns `False` and the field is not required, the default value remains.

### 7.3 SubApp Design

`SubApp` is parameterized on variadic types:

```mojo
struct SubApp[
    app_name: StringLiteral,
    app_description: StringLiteral,
    *Ts: ArgStruct,
]:
    var _command: Command

    fn __init__(out self):
        self._command = Command(String(app_name), String(app_description))

    fn parse(mut self) raises -> SubResult[*Ts]:
        # For each type in Ts, build a sub-Command and register via add_subcommand
        @parameter
        for i in range(len(Ts)):
            var sub_cmd = App[Ts[i]]().to_command()
            self._command.add_subcommand(sub_cmd)
        return SubResult[*Ts](self._command.parse())
```

`SubResult` provides a `get[T]()` method that does the write-back for the matched subcommand.

**Note**: Variadic type parameters are evolving in Mojo. If `*Ts` is not yet stable, a fallback approach uses explicit overloads for 1-8 subcommand types (like `SubApp2[T1, T2]`, `SubApp3[T1, T2, T3]`, etc.).

## 8. What Stays in Builder-Only Territory

Some features are inherently imperative and don't map well to struct declarations. These remain builder-only (accessible via `to_command()`):

| Feature                    | Reason                                 |
| -------------------------- | -------------------------------------- |
| `mutually_exclusive()`     | Cross-field constraint on N args       |
| `required_together()`      | Cross-field constraint on N args       |
| `one_required()`           | Cross-field constraint on N args       |
| `required_if()`            | Cross-field conditional                |
| `implies()`                | Cross-field chain with cycle detection |
| `confirmation_option()`    | Adds a synthetic `--yes` arg           |
| `help_on_no_arguments()`   | Command-level behavior                 |
| `add_tip()`                | Help formatting                        |
| Color config               | Command-level presentation             |
| Completions config         | Command-level behavior                 |
| Response file config       | Command-level behavior                 |
| `allow_negative_numbers()` | Parser behavior flag                   |
| `add_parent()`             | Cross-command inheritance              |

This is the right approach — these features describe *relationships between* arguments or *command-level* behavior, not individual argument metadata. Forcing them into struct field attributes would create a confusing, non-composable API.

## 9. Comparison with Swift Argument Parser

| Aspect                          | Swift Argument Parser           | ArgMojo Declarative                         |
| ------------------------------- | ------------------------------- | ------------------------------------------- |
| Language mechanism              | Property wrappers (`@Option`)   | Parametric wrapper types (`Option[T]`)      |
| Wrapper vocabulary              | `@Argument`, `@Option`, `@Flag` | `Argument[T]`, `Option[T]`, `Flag`, `Count` |
| Protocol / trait                | `ParsableCommand`               | `ArgStruct`                                 |
| Type-safe value access          | Direct field access             | `args.field.value`                          |
| Flag as Bool                    | Direct Bool                     | `Flag.__bool__()` implicit conversion       |
| Count flag                      | ❌ not built-in                  | ✅ `Count[short="v", max=3]`                 |
| Builder fallback                | ❌ no builder API                | ✅ full builder API as alternative           |
| Declarative ↔ builder bridge    | ❌ no escape hatch               | ✅ `to_command()` exposes `Command`          |
| Dual-return parse               | ❌ struct-only return            | ✅ `parse_split()` → (T, ParseResult)        |
| Post-parse validation           | `mutating func validate()`      | `fn validate(self) raises` (planned)        |
| Mutually exclusive groups       | ❌ not in struct schema          | ✅ via `to_command()`                        |
| Interactive prompt              | ❌ not supported                 | ✅ `prompt=True` in wrapper                  |
| Password / masked input         | ❌ not supported                 | ✅ `password=True` in wrapper                |
| Shell completions               | ✅ built-in                      | ✅ inherited from builder                    |
| Subcommands                     | ✅ nested `ParsableCommand`      | ✅ `SubApp[...]` variadic types              |
| CJK-aware help                  | ❌ not supported                 | ✅ inherited from builder                    |
| Auto-naming (underscore→hyphen) | ✅ camelCase→kebab-case          | ✅ snake_case→kebab-case                     |

## 10. Implementation Roadmap

### Phase 1: Core Wrapper Types + App

- [ ] Implement `Option`, `Flag`, `Argument`, `Count` wrapper structs
- [ ] Implement `ArgStruct` trait
- [ ] Implement `arg_defaults[T]()` 
- [ ] Implement `App[T]._build()` — reflection to Command builder calls
- [ ] Implement `App[T]._from_result()` — ParseResult to struct write-back
- [ ] Implement `App[T].parse()` — end-to-end
- [ ] Auto-naming convention (underscore → hyphen)

### Phase 2: Hybrid Features

- [ ] Implement `App[T].to_command()` escape hatch
- [ ] Implement `App[T].parse_split()` dual return
- [ ] Test: declarative + `mutually_exclusive()` via to_command()
- [ ] Test: declarative + extra builder args via parse_split
- [ ] Implement `App[T].configure()` callback (non-capturing, works in 0.26.2)

### Phase 3: Subcommands

- [ ] Implement `SubApp[..., *Ts]` or `SubApp2/3/...` overloads
- [ ] Implement `SubResult.get[T]()` typed subcommand access
- [ ] Test: nested subcommands with declarative

### Phase 4: Polish

- [ ] Comprehensive test suite (parallel to existing builder tests)
- [ ] Examples: simple, hybrid, subcommands
- [ ] User manual additions
- [ ] README update with declarative examples

## 11. Open Questions & Risks

1. **Mojo `@parameter for` over struct fields stability** — This API is marked as "newly introduced and currently incomplete." If reflection primitives change, the declarative module needs updating. Mitigation: keep all reflection code in one file, well-isolated.

2. **Variadic type parameters** — `*Ts: ArgStruct` may not be stable in 0.26.2. Fallback: explicit `SubApp2[T1, T2]`, `SubApp3[T1, T2, T3]` up to a reasonable limit.

3. **Compile-time StringLiteral splitting** — Splitting `choices="a,b,c"` into individual choices at compile time requires careful implementation. May need `@parameter for` over characters or a compile-time string split utility.

4. **`__struct_field_ref` stability** — This is a compiler internal. If Mojo changes the API, write-back logic breaks. Mitigation: encapsulate all uses in helper functions.

5. **Error messages** — When declarative-generated constraints fail, error messages should reference the user's field name, not internal Argument names. May need to customize error formatting.

## 12. Summary

The declarative API adds a **struct-based shorthand** on top of argmojo's existing builder engine, modelled after Swift Argument Parser's `@Argument`/`@Option`/`@Flag` property wrapper pattern.

- **Same vocabulary as Swift**: `Argument`, `Option`, `Flag` — plus `Count` for repeat-counting flags
- **No existing code changes** — builder users are completely unaffected
- **Two innovations** beyond what Swift (or any other CLI library) offers:
  - `to_command()`: first-class declarative↔builder bridge — Swift's `ParsableCommand` has no escape hatch
  - `parse_split()`: dual typed-struct + ParseResult return — Swift requires all fields in the struct
- **Smooth gradient**: pure declarative → declarative + to_command() → declarative + parse_split → pure builder
- The right architecture: **engine first, syntax sugar second** — validated by both Rust's clap and Swift's argument-parser
