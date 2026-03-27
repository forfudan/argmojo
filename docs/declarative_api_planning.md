# ArgMojo Declarative API — Design & Implementation Plan

> **Status**: Planning  
> **Target**: argmojo v0.5.0  
> **Mojo Version**: 0.26.2+  
> **Initial Date**: 2026-03-24  
>
> 子曰工欲善其事必先利其器  
> The mechanic, who wishes to do his work well, must first sharpen his tools -- Confucius

## 1. Design Goals

I want the declarative API to satisfy five goals:

1. **Optional** — If you prefer the builder API, nothing changes for you. The declarative types are a separate import (`from argmojo import Parsable, Option, Flag, ...`). Zero change to existing code.

2. **Hybrid** — Builder and declarative can coexist in a single program. You define a struct for 80% of arguments, then reach for builder methods for the remaining 20% (groups, implications, advanced constraints).

3. **Layered** — The declarative layer is a *consumer* of the builder layer. Internally it constructs `Command` + `Argument` objects and calls `Command.parse()`. I'm not building a new parsing engine.

4. **Type-safe** — Parsed results come back as your own struct with typed fields, not `ParseResult.get_string("name")`.

5. **Five innovations** — I think there are five features I can offer beyond what Swift Argument Parser does (see [§6](#6-innovations)).

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

**Key limitation**: No proc macros, no custom decorators, no `#[derive(...)]`. So all declarative behavior has to be implemented via parametric functions that reflect over user-defined structs.

**Primary inspiration — Swift Argument Parser**: My main inspiration is Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser). Swift and Mojo share key language characteristics — static typing, struct-oriented design, and protocol/trait conformance — so it's the most relevant prior art. Swift uses **property wrappers** (`@Argument`, `@Option`, `@Flag`) as metadata carriers on struct fields. I adopted a similar approach using **parametric wrapper types** (`Positional[T, ...]`, `Option[T, ...]`, `Flag[...]`, `Count[...]`), which carry CLI metadata as compile-time keyword parameters. Here's how Swift looks:

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

What the compiler actually sees — Swift **desugars** the `@` property wrappers into hidden parametric structs:

```swift
struct Greet: ParsableCommand {
    // @Argument(help: "The person's name.")
    // var name: String
    //   desugared into:
    var _name: Argument<String> = Argument<String>(help: "The person's name.")
    var name: String {
        get { _name.wrappedValue }
        set { _name.wrappedValue = newValue }
    }

    // @Option(name: .shortAndLong, help: "Repeat count.")
    // var count: Int = 1
    //   desugared into:
    var _count: Option<Int> = Option<Int>(name: .shortAndLong, help: "Repeat count.", wrappedValue: 1)
    var count: Int {
        get { _count.wrappedValue }
        set { _count.wrappedValue = newValue }
    }

    // @Flag(inversion: .prefixedNo, help: "Include greeting.")
    // var includeGreeting = true
    //   desugared into:
    var _includeGreeting: Flag<Bool> = Flag<Bool>(inversion: .prefixedNo, help: "Include greeting.", wrappedValue: true)
    var includeGreeting: Bool {
        get { _includeGreeting.wrappedValue }
        set { _includeGreeting.wrappedValue = newValue }
    }

    mutating func run() throws {
        for _ in 0..<count { print("Hello, \(name)!") }
    }
}
```

So under the hood, Swift is wrapping each field in a parametric metadata-carrying struct (`Argument<String>`, `Option<Int>`, `Flag<Bool>`). The `@` sugar just hides the wrapper and generates a computed property so users write `args.name` instead of `args._name.wrappedValue`.

This is inspiring, great! It can be translated into Mojo with explicit parametric structs — the only cost is the lack of `@` sugar, so users access the inner value via `.value` instead of a compiler-generated computed property.

Direct mapping to argmojo declarative API:

| Swift Mechanism                  | ArgMojo Equivalent                                              |
| -------------------------------- | --------------------------------------------------------------- |
| `@Argument(help: "...")`         | `Positional[T, help="..."]`                                     |
| `@Option(name: .shortAndLong)`   | `Option[T, long="...", short="..."]`                            |
| `@Flag(inversion: .prefixedNo)`  | `Flag[negatable=True]`                                          |
| (no Swift equivalent)            | `Count[short="v", max=3]`                                       |
| `ParsableCommand` protocol       | `Parsable` trait                                                |
| `@OptionGroup`                   | Argument parents via `Command.add_parent()`                     |
| `ExpressibleByArgument` protocol | `ExpressibleByArgument` trait                                   |
| `CommandGroup`                   | `Parsable` at every level + `to_command()` / `add_subcommand()` |
| `Greet.main()`                   | `Greet.parse()` — trait default method                          |
| `mutating func validate()`       | `def validate(self) raises` on `Parsable`                       |

What I think argmojo can add beyond Swift:

1. `to_command()` returns an owned `Command` for builder-level customisation followed by `from_command(cmd^)` — Swift's `ParsableCommand` is a sealed box with no escape hatch to things like mutually exclusive groups, implications, or custom help formatting.
2. `parse_split()` returns both typed struct + `ParseResult` — Swift requires all fields to live in the struct.
3. Declarative is optional — Swift has no builder alternative; you *must* use the struct-based approach.

**`validate()`**: I'm also thinking about an optional `def validate(self) raises` method on `Parsable` (mirroring Swift's `validate()`). It would complement `to_command()` for post-parse cross-field validation without requiring the builder API.

**A note on naming** — I had to pick names for several structs and traits. Some were genuinely hard. The final names inevitably reflect my personal taste, but I tried to be consistent and self-explanatory. Here's what I chose and why:

1. **`Parsable`**: This is the trait that user structs conform to. It follows Swift's `ParsableCommand` naming and Mojo's `TypeName+able` pattern (`Int`→`Intable`, `String`→`Stringable`). `MyArgs.parse()` reads naturally: "my args, parse yourself." The user struct describes *what* to parse (the schema) and carries the *how* via trait default methods. There is no separate orchestrator — the struct is self-contained.

2. **`Positional`**: Swift calls it `@Argument`, but I already have an `Argument` struct in the builder layer that covers *all* argument types. Two different `Argument` types with different meanings would be confusing. `Positional` is unambiguous — it tells you exactly what kind of argument it is.

3. **No `Parser[T]` struct** — In an earlier draft I had a `Parser[T]` orchestrator struct. But I realised this extra wrapper serves no purpose: Mojo 0.26.2 supports `Self` reflection inside trait default methods, so the `Parsable` trait itself can host `parse()`, `to_command()`, `parse_split()`, etc. This eliminates one layer of indirection and produces an API that matches Rust's `MyArgs::parse()` and Swift's `Greet.main()` — the user struct is the parser. This is also directly analogous to Rust clap's `#[derive(Parser)]`, which generates `MyArgs::parse()` on the implementing struct — our `Parsable` trait's default methods achieve the same effect without proc macros. I verified this approach in `temp_test_plan_b_full.mojo` — all 7 patterns (parse, to_command, from_command, parse_split, validate, parse_args, configure callback) compile and run correctly.

## 3. Architecture

```txt
┌──────────────────────────────────────────────────────────────────────────┐
│  User Code                                                               │
│                                                                          │
│  struct MyArgs(Parsable):                                                │
│      var name: Positional[String, help="Name", required=True]            │
│      var verbose: Flag[short="v", help="Verbose"]                        │
│      var output: Option[String, long="output", short="o"]                │
│      def __init__(out self): self = arg_defaults[Self]()                 │
│                                                                          │
│  # Pure declarative (one line):                                          │
│  var args = MyArgs.parse()                                               │
│                                                                          │
│  # Hybrid (to_command → customise → from_command):                       │
│  var cmd = MyArgs.to_command()                                           │
│  cmd.mutually_exclusive([...])                                           │
│  var args = MyArgs.from_command(cmd^)                                    │
│                                                                          │
│  # Dual return:                                                          │
│  var result = MyArgs.parse_split()                                       │
│  print(result[0].name.value)   # typed                                   │
│  print(result[1].get_string("extra"))  # untyped                         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  parsable.mojo  (trait default methods — the core of declarative API)    │
│                                                                          │
│  Parsable.to_command()  → Command   (reflect Self → builder calls)       │
│  Parsable.parse()       → Self      (to_command + parse + write-back)    │
│  Parsable.from_command() → Self     (parse from pre-configured Command)  │
│  Parsable.parse_split() → (Self, ParseResult)  (dual return)             │
│  Parsable.parse_args()  → Self      (parse from explicit arg list)       │
│  Parsable.validate()    → None      (post-parse cross-field validation)  │
│  arg_defaults[T]()      → T        (default-initialized)                 │
│                                                                          │
│  argument_wrappers.mojo — wrapper types:                                 │
│  Positional[T, ...], Option[T, ...], Flag[...], Count[...]               │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  argument.mojo + command.mojo + parse_result.mojo  (UNCHANGED)           │
│                                                                          │
│  Argument(...).long["x"]().short["y"]().flag()                           │
│  Command("app").add_argument(...).parse() → ParseResult                  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Files Changed

| File                                 | Change                                              |
| ------------------------------------ | --------------------------------------------------- |
| `src/argmojo/parsable.mojo`          | **Expanded** — trait default methods + internal fns |
| `src/argmojo/argument_wrappers.mojo` | **Already exists** — wrapper types                  |
| `src/argmojo/__init__.mojo`          | Add `from .parsable import ...` (conditional)       |
| Everything else                      | **Zero changes**                                    |

### Comparison between Builder and Declarative APIs

| Aspect        | Builder API                 | Declarative API                                              |
| ------------- | --------------------------- | ------------------------------------------------------------ |
| Schema        | `Command` + `Argument`      | `Parsable` struct with wrapper-typed fields                  |
| Add arguments | `command.add_argument(...)` | 4 types of structs within `MyArgs` (compile-time metadata)   |
| Parse         | `command.parse()`           | `MyArgs.parse()` (returns typed struct)                      |
| Parse result  | `ParseResult`               | Typed struct `MyArgs` with inner `.value` fields             |
| Hybrid bridge | —                           | `MyArgs.to_command()` → modify → `MyArgs.from_command(cmd^)` |
| Dual return   | —                           | `MyArgs.parse_split()` → `Tuple[MyArgs, ParseResult]`        |

## 4. Detailed API Design

### 4.1 Wrapper Types

These are lightweight parametric structs. They carry CLI metadata as compile-time parameters while wrapping an inner value at runtime. I'll walk through each one.

```mojo
struct Option[
    T: Defaultable & Movable,
    *,
    # ── Naming ──
    long: StringLiteral = "",       # --option name (empty = auto from field name)
    short: StringLiteral = "",      # -o single char
    help: StringLiteral = "",       # help text
    alias_name: StringLiteral = "", # comma-separated alias long names
    # ── Argument type ──
    negatable: Bool = False,        # --x / --no-x (only if T is Bool)
    # ── Value defaults & validation ──
    default: StringLiteral = "",    # default value as string
    required: Bool = False,         # must be provided
    choices: StringLiteral = "",    # comma-separated allowed values: "json,yaml,csv"
    range_min: Int = 0,             # numeric range min
    range_max: Int = 0,             # numeric range max
    has_range: Bool = False,        # enable range validation
    clamp: Bool = False,            # clamp instead of error
    # ── Collection modes ──
    append: Bool = False,           # collect into list (T should be List[String])
    delimiter: StringLiteral = "",  # split by delimiter
    nargs: Int = 0,                 # number of values (0 = single)
    map_option: Bool = False,       # key=value map mode
    # ── Parsing behavior ──
    require_equals: Bool = False,   # require --key=value syntax
    allow_hyphen: Bool = False,     # allow hyphen-prefixed values
    persistent: Bool = False,       # inherited by subcommands
    # ── Display & help ──
    value_name: StringLiteral = "", # display name in help
    hidden: Bool = False,           # hidden from help
    deprecated: StringLiteral = "", # deprecation message
    group: StringLiteral = "",      # help group name
    # ── Interactive prompting ──
    prompt: Bool = False,           # interactive prompt if missing
    prompt_text: StringLiteral = "",# custom prompt message
    password: Bool = False,         # masked input
](Copyable, Movable, Defaultable):
    var value: T

    def __init__(out self):
        self.value = T()

    def __init__(out self, val: T):
        self.value = val
```

```mojo
# Convenience aliases for common patterns

struct Flag[
    *,
    # ── Naming ──
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    # ── Argument type ──
    negatable: Bool = False,
    # ── Parsing behavior ──
    persistent: Bool = False,
    # ── Display & help ──
    hidden: Bool = False,
    deprecated: StringLiteral = "",
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    var value: Bool

    def __init__(out self):
        self.value = False

    def __init__(out self, val: Bool):
        self.value = val

    # Implicit conversion to Bool for convenience
    def __bool__(self) -> Bool:
        return self.value
```

```mojo
struct Positional[
    T: Defaultable & Movable,
    *,
    help: StringLiteral = "",
    # ── Argument type ──
    remainder: Bool = False,       # consume all remaining tokens
    # ── Value defaults & validation ──
    default: StringLiteral = "",
    required: Bool = False,
    choices: StringLiteral = "",
    # ── Display & help ──
    value_name: StringLiteral = "",
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    var value: T

    def __init__(out self):
        self.value = T()

    def __init__(out self, val: T):
        self.value = val
```

```mojo
struct Count[
    *,
    # ── Naming ──
    long: StringLiteral = "",
    short: StringLiteral = "",
    help: StringLiteral = "",
    # ── Argument type ──
    max: Int = 0,                  # 0 = no ceiling
    # ── Parsing behavior ──
    persistent: Bool = False,
    # ── Display & help ──
    hidden: Bool = False,
    group: StringLiteral = "",
](Copyable, Movable, Defaultable):
    var value: Int

    def __init__(out self):
        self.value = 0

    def __init__(out self, val: Int):
        self.value = val
```

I use four distinct wrapper types (`Positional`, `Option`, `Flag`, `Count`) instead of one overloaded struct with `is_arg=True` / `is_flag=True`. Each type maps to exactly one **mental model** of how a CLI argument works:

| Wrapper         | CLI syntax                   | Mental model                                | Example               |
| --------------- | ---------------------------- | ------------------------------------------- | --------------------- |
| `Positional[T]` | Bare value, matched by order | "user types a bare value"                   | `tool input.txt`      |
| `Option[T]`     | `--key value` or `-k value`  | "user types a named key-value pair"         | `tool --output f.txt` |
| `Flag`          | `--switch` (no value)        | "user flips a boolean switch"               | `tool --verbose`      |
| `Count`         | `-vvv` (repeated)            | "user repeats a flag to increase intensity" | `tool -vvv`           |

This is intentional. Here's why I like it:

- **Explicit intent**: `Flag[...]` is obviously a flag, `Positional[...]` is obviously positional — the type name *is* the documentation.
- **Fewer confusing parameter combinations**: `Positional` doesn't have `long`/`short`, `Flag` doesn't have `append`/`delimiter` — impossible states are unrepresentable.
- **Better compile-time validation**: You can't accidentally make a positional with `long`, or a flag with `nargs`.

**Why `Positional` instead of `Argument`?** Swift Argument Parser uses `@Argument` for positional arguments. I deliberately chose `Positional` instead, because my builder API already has an `Argument` struct (in `argument.mojo`) that covers *all* argument types. Two different `Argument` types — one meaning "everything" in the builder layer and another meaning "positional only" in the declarative layer — would be confusing. `Positional` is unambiguous: it tells you exactly what it does.

You can also use **bare types** (like `String`, `Int`, `Bool`) for fields without metadata — they become options named after the field, following Swift's convention for fields without property wrappers.

In **hybrid** mode, imports are clean with no name collisions:

```mojo
from argmojo import Command, Argument
from argmojo import Parsable, Option, Flag, Positional
```

### 4.2 The `Parsable` Trait

The `Parsable` trait is the **heart** of the declarative API. Unlike the old `Parser[T]` design, there is no separate orchestrator struct — the trait's default methods handle everything: building, parsing, validation, and hybrid bridging. This is possible because Mojo 0.26.2 supports `struct_field_count[Self]()` inside trait default `@staticmethod` methods.

```mojo
trait Parsable(Defaultable, Movable):
    """Trait for structs that can be parsed from CLI arguments.
    
    Default methods use compile-time reflection over Self to translate
    wrapper-typed fields to Command/Argument builder calls."""

    @staticmethod
    def description() -> String:
        """Return the command description for --help."""
        ...

    @staticmethod
    def version() -> String:
        """Return the version string for --version. Default "0.1.0"."""
        return String("0.1.0")

    @staticmethod
    def name() -> String:
        """Return the command name. Default: lowercased struct name."""
        return String("")

    # ── Core: one-line parse ──

    @staticmethod
    def parse() raises -> Self:
        """Build, parse sys.argv(), and return a populated Self.
        This is the primary entry point."""
        var cmd = Self.to_command()
        var result = cmd.parse()
        return _from_result[Self](result)

    # ── Hybrid: to_command → customise → from_command ──

    @staticmethod
    def to_command() raises -> Command:
        """Reflect over Self's fields and return a configured Command.
        Users can modify it with builder methods before calling from_command()."""
        var cmd_name = Self.name()
        if not cmd_name:
            cmd_name = String("command")
        var cmd = Command(cmd_name, Self.description(), version=Self.version())
        _reflect_and_register[Self](cmd)
        return cmd^

    @staticmethod
    def from_command(cmd: Command) raises -> Self:
        """Parse from a pre-configured Command (hybrid mode).
        Use after to_command() + builder customisations."""
        var result = cmd.parse()
        return _from_result[Self](result)

    # ── Dual return ──

    @staticmethod
    def parse_split() raises -> Tuple[Self, ParseResult]:
        """Parse and return BOTH a typed struct AND the raw ParseResult.
        The struct covers declarative fields; ParseResult covers everything."""
        var cmd = Self.to_command()
        var result = cmd.parse()
        var typed = _from_result[Self](result)
        return Tuple[Self, ParseResult](typed^, result^)

    @staticmethod
    def from_command_split(owned cmd: Command) raises -> Tuple[Self, ParseResult]:
        """Parse from a pre-configured Command and return BOTH typed Self
        AND raw ParseResult. Essential for subcommand dispatch:
        the typed Self gives root-level flags, ParseResult gives
        subcommand name + fields for from_result() write-back."""
        var result = cmd.parse()
        var typed = _from_result[Self](result)
        return Tuple[Self, ParseResult](typed^, result^)

    # ── Subcommand write-back ──

    @staticmethod
    def from_result(result: ParseResult) raises -> Self:
        """Write-back from an existing ParseResult without re-parsing.
        Used for subcommand dispatch: the parent already parsed,
        this extracts the matched subcommand's fields into Self."""
        return _from_result[Self](result)

    # ── Testing helper ──

    @staticmethod
    def parse_args(args: List[String]) raises -> Self:
        """Parse from an explicit arg list (useful for testing)."""
        var cmd = Self.to_command()
        var result = cmd.parse_arguments(args)
        return _from_result[Self](result)

    # ── Post-parse validation ──

    def validate(self) raises:
        """Cross-field validation. Override to add custom checks.
        Called automatically after parse() if overridden."""
        pass
```

Minimal implementation — you only need to provide `description()`:

```mojo
struct MyArgs(Parsable):
    var input: Positional[String, help="Input file", required=True]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "My awesome tool"
```

Everything else (`parse()`, `to_command()`, `from_command()`, `from_command_split()`, `from_result()`, `parse_split()`, `parse_args()`, `validate()`, `version()`, `name()`) comes from trait defaults.

### 4.3 Internal Free Functions

The trait default methods delegate to module-level free functions for the heavy lifting:

```mojo
def _reflect_and_register[T: Parsable](mut cmd: Command) raises:
    """Reflect over T's fields and register Arguments on cmd."""
    comptime field_count = struct_field_count[T]()
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

    comptime for idx in range(field_count):
        comptime fname = field_names[idx]
        comptime ftype = field_types[idx]

        # Dispatch based on wrapper type
        comptime if _is_option_type(ftype):
            _register_option(cmd, fname, ftype)
        elif _is_flag_type(ftype):
            _register_flag(cmd, fname, ftype)
        elif _is_positional_type(ftype):
            _register_positional(cmd, fname, ftype)
        elif _is_count_type(ftype):
            _register_count(cmd, fname, ftype)
        else:
            # Bare type: treat as named option with field name as long name
            _register_bare(cmd, fname, ftype)

def _from_result[T: Parsable](result: ParseResult) raises -> T:
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
        elif _is_positional_type(ftype):
            ref field = __struct_field_ref(idx, out)
            _write_positional_value(field, fname, result)
        elif _is_option_type(ftype):
            ref field = __struct_field_ref(idx, out)
            _write_option_value(field, fname, result)
        else:
            ref field = __struct_field_ref(idx, out)
            _write_bare_value(field, fname, result)

    return out
```

### 4.4 The `arg_defaults[T]()` Helper

This initialises all wrapper fields to their defaults (inspired by Swift's default property initialization):

```mojo
def arg_defaults[T: Parsable]() -> T:
    """Create a default-initialized instance of T.
    Wrapper types (Positional, Option, Flag, Count) are initialized to their defaults.
    Bare types use their Defaultable implementation."""
    return T()  # Works because T: Defaultable, and all wrappers are Defaultable
```

### 4.5 Auto-Naming Convention

When you don't provide an explicit `long`, I use the field name with underscores converted to hyphens:

| Field name    | Auto-generated long | Short  |
| ------------- | ------------------- | ------ |
| `max_count`   | `--max-count`       | (none) |
| `verbose`     | `--verbose`         | (none) |
| `output_file` | `--output-file`     | (none) |

This matches how Swift and clap do it. Fields wrapped in `Positional[...]` don't get auto-generated long names.

### 4.6 Choice Parsing from StringLiteral

Since Mojo parameters must be compile-time constants and I can't pass `List[StringLiteral]`, choices are encoded as a comma-separated string:

```mojo
var format: Option[String, choices="json,yaml,csv", default="json"]
```

Internally, `_register_option()` splits by `,` and calls `.choice["json"]().choice["yaml"]().choice["csv"]()` etc.

Similarly, `alias_name` is comma-separated:

```mojo
var output: Option[String, long="output", alias_name="out,dest"]
```

This generates `.alias_name["out"]().alias_name["dest"]()`.

## 5. Usage Examples

### 5.1 Pure Declarative (Simple Tool)

```mojo
from argmojo import Parsable, Option, Flag, Positional, Count, arg_defaults

struct Grep(Parsable):
    """Search for patterns in files."""

    var pattern: Positional[String, help="Search pattern", required=True]
    var path: Positional[String, help="File or directory", default="."]
    var ignore_case: Flag[short="i", help="Case-insensitive search"]
    var count_only: Flag[short="c", long="count", help="Only print match count"]
    var max_count: Option[Int, short="m", long="max-count", help="Stop after N matches", default="0"]
    var verbose: Count[short="v", help="Increase verbosity", max=3]
    var ext: Option[List[String], short="e", long="ext", help="File extensions", append=True]

    def __init__(out self):
        self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "Search for patterns in files."

    @staticmethod
    def version() -> String:
        return "1.0.0"

def main() raises:
    var args = Grep.parse()            # One line. No wrapper struct.

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
from argmojo import Command, Argument
from argmojo import Parsable, Option, Flag, Positional, arg_defaults

struct Deploy(Parsable):
    var target: Positional[String, help="Deploy target", required=True, choices="staging,prod"]
    var force: Flag[short="f", help="Force deploy without checks"]
    var dry_run: Flag[long="dry-run", help="Simulate without changes"]
    var tag: Option[String, long="tag", short="t", help="Release tag"]
    var replicas: Option[Int, long="replicas", short="r", help="Number of replicas",
                      default="3", has_range=True, range_min=1, range_max=100]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "Deploy application to target environment."

def main() raises:
    # to_command() returns an owned Command — customise it freely
    var cmd = Deploy.to_command()
    cmd.mutually_exclusive(["force", "dry-run"])
    cmd.implies("force", "tag")       # force requires a tag
    cmd.confirmation_option["Deploy to production?"]()
    cmd.header_color["CYAN"]()
    cmd.add_tip("Use --dry-run to preview changes first")

    # from_command() takes the customised Command and returns typed Deploy
    var args = Deploy.from_command(cmd^)
### 5.3 Split Parse (Declarative + Extra Builder Fields)

```mojo
from argmojo import Command, Argument
from argmojo import Parsable, Positional, Option, arg_defaults

struct Convert(Parsable):
    var input: Positional[String, help="Input file", required=True]
    var output: Option[String, long="output", short="o", help="Output file"]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "File format converter."

def main() raises:
    # to_command() → customise → parse_split()
    var cmd = Convert.to_command()
    cmd.add_argument(
        Argument("format", help="Output format")
        .long["format"]().short["f"]()
        .choice["json"]().choice["yaml"]().choice["toml"]()
        .default["json"]()
    )
    cmd.add_argument(
        Argument("indent", help="Indent level")
        .long["indent"]()
        .range[0, 8]().default["2"]()
    )

    # parse_split returns BOTH the typed struct AND the raw ParseResult
    var result = Convert.parse_split()
    var args = result[0]       # typed Convert
    var raw  = result[1]       # untyped ParseResult

    # Declarative fields: typed access
    print("Input:", args.input.value)
    print("Output:", args.output.value)

    # Builder fields: ParseResult access
    var format = raw.get_string("format")
    var indent = raw.get_int("indent")
```

### 5.4 Subcommands with Declarative

Every level in the command tree is a `Parsable` struct — root, mid-level, and leaf. This mirrors Swift's `ParsableCommand` and Rust clap's `#[derive(Parser)]`.

```mojo
from argmojo import Parsable, Option, Flag, Positional, arg_defaults

# Root command — has its own flags
struct MyGit(Parsable):
    var verbose: Flag[short="v", help="Verbose output", persistent=True]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def name() -> String:
        return "mgit"

    @staticmethod
    def description() -> String:
        return "A mini git tool."

# Leaf subcommands — also Parsable
struct Clone(Parsable):
    var url: Positional[String, help="Repository URL", required=True]
    var depth: Option[Int, long="depth", help="Clone depth", default="0"]
    var branch: Option[String, short="b", long="branch", help="Branch to clone"]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "Clone a repository."

    @staticmethod
    def name() -> String:
        return "clone"

struct Push(Parsable):
    var remote: Positional[String, help="Remote name", default="origin"]
    var force: Flag[short="f", help="Force push"]
    var tags: Flag[long="tags", help="Push all tags"]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "Push commits to remote."

    @staticmethod
    def name() -> String:
        return "push"

def main() raises:
    # Build command tree — every level is Parsable
    var cmd = MyGit.to_command()
    cmd.add_subcommand(Clone.to_command())
    cmd.add_subcommand(Push.to_command())

    # Parse: root flags (typed) + full result (for subcommand dispatch)
    var (git_args, result) = MyGit.from_command_split(cmd^)

    if git_args.verbose:
        print("Verbose mode on")

    # Dispatch subcommands with typed write-back
    if result.subcommand == "clone":
        var args = Clone.from_result(result)
        print("Cloning:", args.url.value)
    elif result.subcommand == "push":
        var args = Push.from_result(result)
        print("Pushing to:", args.remote.value)
```

#### 5.4.1 Nested Subcommands

The same pattern scales to arbitrary depth (e.g. `mgit remote add`):

```mojo
# Mid-level command — Parsable with its own flags
struct Remote(Parsable):
    var timeout: Option[Int, long="timeout", help="Timeout in seconds", default="30"]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def name() -> String:
        return "remote"

    @staticmethod
    def description() -> String:
        return "Manage remotes."

struct AddRemote(Parsable):
    var name_: Positional[String, help="Remote name", required=True]
    var url: Positional[String, help="Remote URL", required=True]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "Add a remote."

    @staticmethod
    def name() -> String:
        return "add"

def main() raises:
    # Build nested tree
    var remote_cmd = Remote.to_command()
    remote_cmd.add_subcommand(AddRemote.to_command())
    remote_cmd.add_subcommand(RemoveRemote.to_command())

    var root = MyGit.to_command()
    root.add_subcommand(Clone.to_command())
    root.add_subcommand(remote_cmd)
    root.header_color["CYAN"]()
    root.add_tip("Run 'mgit help <command>' for details")

    # Parse root
    var (git_args, result) = MyGit.from_command_split(root^)

    if result.subcommand == "remote":
        var remote_args = Remote.from_result(result)
        print("Timeout:", remote_args.timeout.value)
        # Nested dispatch
        if result.sub_result().subcommand == "add":
            var args = AddRemote.from_result(result.sub_result())
            print("Adding remote:", args.name_.value, args.url.value)
```

**Note**: Root-level customization (colors, tips, persistent flags) is natural — `to_command()` gives you the `Command` to modify before parsing. No escape hatch needed.

## 6. Innovations

### 6.1 Innovation #1: `to_command()` + `from_command()` — First-Class Declarative-Builder Bridge

**What Swift Argument Parser lacks**: Swift's `ParsableCommand` is a sealed protocol — there's no escape hatch to add builder-level configuration. If you need mutually exclusive groups, implications, colored help, tips, or completions, you're on your own with `validate()` and custom help formatting.

**What I'm adding**: `to_command()` returns an **owned** `Command` object (not a reference), so you can do arbitrary builder modifications before parsing with `from_command()`:

```mojo
var cmd = MyArgs.to_command()
cmd.mutually_exclusive(["json", "yaml"])
cmd.required_together(["username", "password"])
cmd.implies("debug", "verbose")
cmd.confirmation_option()
cmd.header_color["CYAN"]()
cmd.add_tip("See docs at https://example.com")
cmd.completions_as_subcommand()
var args = MyArgs.from_command(cmd^)
```

This creates a **smooth gradient** between simplicity and power:

```txt
Pure declarative     Declarative + to_command()    Pure builder
(3 lines)            (10 lines)                    (30 lines)
Simple tools    →    Medium complexity tools   →    Maximum control
```

I don't know of any other Mojo CLI library that offers this continuum. You never have to completely rewrite from one style to another when requirements grow.

**Type safety note**: If you use `to_command()` to add **constraints** (groups, implications, colours), full type safety is preserved — `from_command()` still returns `T`. But if you add **new arguments** (`add_argument(...)`), those fields are only available via `ParseResult` from `parse_split()`. This is an intentional trade-off:

```txt
to_command() + constraints only    →  from_command()  →  T (fully typed ✓)
to_command() + new arguments       →  parse_split()   →  Tuple[T, ParseResult] (partially typed ⚠️)
```

**`configure()` as a free function pattern**: I've verified in Mojo 0.26.2 that non-capturing callbacks work. Since there's no `Parser[T]` wrapper to chain on, the configure pattern uses a free function or inline modification:

```mojo
# Option A: just modify the Command directly (preferred)
var cmd = MyArgs.to_command()
cmd.mutually_exclusive([...])
cmd.implies("a", "b")
var args = MyArgs.from_command(cmd^)

# Option B: helper function for reusable configuration
def configure_deploy(mut cmd: Command) raises:
    cmd.mutually_exclusive(["force", "dry-run"])
    cmd.implies("force", "tag")

var cmd = Deploy.to_command()
configure_deploy(cmd)
var args = Deploy.from_command(cmd^)
```

`to_command()` + `from_command()` is the primary bridge for multi-step customization.

### 6.2 Innovation #2: `parse_split()` — Dual-Return Parsing

**The problem**: When mixing declarative and builder fields, how do I give you typed access to declarative fields AND untyped access to builder-added fields?

**Swift's answer**: You can't. All fields must be declared in the struct.

**Naive approach**: Return only `ParseResult`, losing the typed struct benefit.

**My approach**: `parse_split()` returns a **tuple of both**:

```mojo
@staticmethod
def parse_split() raises -> Tuple[Self, ParseResult]:
```

- The first element is your struct `T` with all declarative-registered fields populated & typed.
- The second element is the full `ParseResult` containing everything (declarative fields + builder-added fields).

This means:

```mojo
var result = MyArgs.parse_split()
var args = result[0]       # typed MyArgs
var raw  = result[1]       # untyped ParseResult

# Declarative fields: compile-time typed access, no string keys
args.verbose          # Bool
args.output.value     # String
args.count.value      # Int

# Builder-added fields: runtime string-keyed access
raw.get_string("extra-option")
raw.get_int("threads")
raw.get_list("tags")
```

As far as I know, this is a **new pattern** not seen in any CLI library in any language. Even Rust's clap can't do this — once you use its derive macro, all fields must be in the struct. There's no mechanism for "some fields are struct, some are ParseResult."

The dual-return enables a practical workflow:

1. Start with pure declarative
2. Need one advanced option? Add it via `to_command()` + `parse_split()`
3. No need to convert the struct field (or add a new nested type)

### 6.3 Innovation #3: Compile-Time Schema Validation

**The problem**: In every runtime CLI library, schema errors (duplicate short flags, invalid short flag length, positional-after-optional ordering) only surface when you run the program — or worse, when a user triggers the specific code path.

**What I'm adding**: Since all wrapper metadata lives in compile-time parameters (`StringLiteral`, `Bool`, `Int`), the declarative layer can validate the **entire schema at compile time** using `comptime assert`. Your program won't even compile if the schema is invalid.

Concrete checks in `_reflect_and_register[]`:

```mojo
@parameter
fn _validate_schema[T: Parsable]():
    # 1. Duplicate short flags
    #    Nested comptime loop over all field pairs; extract each wrapper's
    #    `short` parameter and assert no two are equal.

    # 2. Invalid short flag length
    #    comptime assert len(short) == 1 for every field that declares one.

    # 3. Positional ordering
    #    Track a "seen_non_positional" flag. If a Positional appears after
    #    an Option/Flag, assert failure — positionals must come first.

    # 4. Type-metadata mismatch
    #    e.g. `choices` on a Flag has no meaning; `append` on a Positional
    #    without `remainder` is contradictory. comptime assert catches these.

    # 5. choices vs default consistency
    #    If `choices="json,yaml,csv"` and `default="xml"`, the default is
    #    not in the choices set — comptime assert failure.
    ...
```

**Why this matters**: Neither Swift Argument Parser nor Rust clap can do this. Swift's property wrappers are validated at runtime. Rust's proc macros catch *some* errors but not all (e.g. duplicate short flags pass the proc macro and fail at runtime). Mojo's parametric type system uniquely enables full schema validation at compile time.

**Zero-cost guarantee**: All checks use `comptime assert` — they're erased from the binary. No performance cost, no code bloat.

### 6.4 Innovation #4: Declarative `depends_on` / `conflicts_with`

**The problem**: Cross-field constraints like "username requires password" or "json conflicts with yaml" currently require the imperative `to_command()` escape hatch:

```mojo
var cmd = MyArgs.to_command()
cmd.required_together(["username", "password"])
cmd.mutually_exclusive(["json", "yaml"])
var args = MyArgs.from_command(cmd^)
```

This works, but it breaks the "everything in the struct" philosophy and requires string-keyed names (typo-prone).

**What I'm adding**: `depends_on` and `conflicts_with` as StringLiteral parameters on wrapper types:

```mojo
@value
struct MyArgs(Parsable):
    var username: Option[String, long="username", short="u",
                         depends_on="password"]
    var password: Option[String, long="password", short="p",
                         depends_on="username"]
    var json: Flag[long="json", conflicts_with="yaml"]
    var yaml: Flag[long="yaml", conflicts_with="json"]
```

**Translation in `_reflect_and_register()`**:

| Declarative parameter        | Builder call generated                                   |
| ---------------------------- | -------------------------------------------------------- |
| `depends_on="password"`      | `cmd.required_if("password", "username")`                |
| `conflicts_with="json,yaml"` | `cmd.mutually_exclusive(["this_field", "json", "yaml"])` |

**Compile-time name validation**: Since `depends_on` and `conflicts_with` are `StringLiteral` parameters, and all field names are known at compile time via `struct_field_names`, I can verify at compile time that every referenced name actually exists in the struct:

```mojo
# In _reflect_and_register(), at comptime:
# depends_on="password" → verify "password" is in struct_field_names[T]()
# If not → comptime assert failure with a clear error message
```

This catches typos like `depends_on="passwrod"` at compile time — something no other CLI library can do.

**Symmetry note**: `depends_on` is symmetric by convention (if A depends on B, B depends on A). A single `depends_on="password"` on `username` generates `required_together(["username", "password"])`. If both sides declare it, deduplication in `_reflect_and_register()` prevents double-registration.

### 6.5 Innovation #5: Compile-Time Derived Completions from `choices`

**The problem**: Shell completions for argument values usually require explicit registration — you declare choices in one place and completions in another, duplicating information. In the builder API:

```mojo
var arg = Argument("format", help="Output format")
    .choice["json"]()
    .choice["yaml"]()
    .choice["csv"]()
# Choices are registered, but completions only work if generate_completion is called
```

**What I'm adding**: Since `choices` is a compile-time `StringLiteral` parameter, the declarative layer can **automatically derive** shell completions from choices — no explicit completion registration needed:

```mojo
@value
struct MyArgs(Parsable):
    var format: Option[String, long="format", short="f",
                       choices="json,yaml,csv"]
    # ^ completions for --format automatically include "json", "yaml", "csv"
```

**How it works**: During `_reflect_and_register()`, when a field has a non-empty `choices` parameter, the generated completion script automatically includes those values as completions for that argument's value. The builder's `generate_completion["fish"]()` / `generate_completion["zsh"]()` / `generate_completion["bash"]()` already reads `_choice_values` — the declarative layer simply ensures they're populated.

**Compile-time generation**: Since all choices are `StringLiteral` values known at compile time, the entire completion script could be generated as a compile-time constant:

```mojo
# Hypothetical: completion script as a compile-time StringLiteral
alias fish_completion = Parsable.completion_script["fish", MyArgs]()
# This is a StringLiteral — zero runtime cost to produce
```

**Practical value**: For tools with many `choices`-based arguments (e.g. `--format`, `--color`, `--log-level`), this eliminates the boilerplate of manually wiring completions. The struct declaration is the single source of truth for both validation and completions.

## 7. Internal Implementation Details

### 7.1 Reflect-to-Builder Translation Table

Here's how each wrapper parameter maps to builder calls under the hood:

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
| `alias_name="out,dest"`                     | `.alias_name["out"]().alias_name["dest"]()`      |
| `negatable=True`                            | `.negatable()`                                   |
| `allow_hyphen=True`                         | `.allow_hyphen_values()`                         |
| `group="Advanced"`                          | `.group["Advanced"]()`                           |
| **Flag[...]**                               | `.flag()`                                        |
| **Positional[...]**                         | `.positional()`                                  |
| **Positional[..., remainder=True]**         | `.remainder()`                                   |
| **Count[..., max=5]**                       | `.count().max[5]()`                              |
| **bare String/Int/Bool**                    | auto-detected: Bool→`.flag()`, else named option |

### 7.2 Write-Back Type Dispatch

When populating your struct from `ParseResult`, I dispatch based on the field type:

| Field type                                      | ParseResult accessor | Write-back                   |
| ----------------------------------------------- | -------------------- | ---------------------------- |
| `Flag[...]`                                     | `get_flag(name)`     | `field.value = Bool`         |
| `Count[...]`                                    | `get_count(name)`    | `field.value = Int`          |
| `Option[String, ...]`                           | `get_string(name)`   | `field.value = String`       |
| `Option[Int, ...]`                              | `get_int(name)`      | `field.value = Int`          |
| `Option[List[String], ..., append=True]`        | `get_list(name)`     | `field.value = List[String]` |
| `Option[Dict[...], ..., map_option=True]`       | `get_map(name)`      | `field.value = Dict`         |
| `Positional[String, ...]`                       | `get_string(name)`   | `field.value = String`       |
| `Positional[Int, ...]`                          | `get_int(name)`      | `field.value = Int`          |
| `Positional[List[String], ..., remainder=True]` | `get_list(name)`     | `field.value = List[String]` |
| bare `String`                                   | `get_string(name)`   | `field = String`             |
| bare `Int`                                      | `get_int(name)`      | `field = Int`                |
| bare `Bool`                                     | `get_flag(name)`     | `field = Bool`               |

Missing/optional values: if `result.has(name)` returns `False` and the field isn't required, the default value stays.

### 7.3 Subcommand Design — Parsable Everywhere

Instead of a separate compositor type (like an `SubParser[*Ts]` struct), subcommands use the same `Parsable` trait at every level. This mirrors Swift's `ParsableCommand` and Rust clap's `#[derive(Parser)]` — one concept, not two.

**Every level is Parsable**: root commands, mid-level commands, and leaf commands are all `Parsable` structs. Root-level and mid-level flags live naturally as struct fields.

**Subcommand registration uses the builder bridge**: `to_command()` produces a `Command`, and `add_subcommand()` wires the tree together. This reuses the existing builder infrastructure — no new type or wiring mechanism needed.

**Two new methods on `Parsable`** enable subcommand workflows:

```mojo
@staticmethod
def from_command_split(owned cmd: Command) raises -> Tuple[Self, ParseResult]:
    """Parse cmd and return both typed Self (root flags)
    and raw ParseResult (for subcommand dispatch)."""
    var result = cmd.parse()
    var typed = _from_result[Self](result)
    return Tuple[Self, ParseResult](typed^, result^)

@staticmethod
def from_result(result: ParseResult) raises -> Self:
    """Write-back from an existing ParseResult without re-parsing.
    Used for subcommand dispatch: the parent already parsed,
    this extracts the matched subcommand's fields into Self."""
    return _from_result[Self](result)
```

**Typical flow**:

```mojo
# 1. Build the tree
var root = MyGit.to_command()
root.add_subcommand(Clone.to_command())
root.add_subcommand(Push.to_command())

# 2. Parse — root flags are typed, subcommand info is in ParseResult
var (git_args, result) = MyGit.from_command_split(root^)

# 3. Dispatch with typed write-back
if result.subcommand == "clone":
    var args = Clone.from_result(result)
```

**Why not a separate compositor type?**

| Concern                      | Parsable everywhere        | Separate compositor (e.g. `App[*Ts]`)         |
| ---------------------------- | -------------------------- | --------------------------------------------- |
| Root-level flags             | Natural struct fields      | No home — needs builder escape                |
| Nesting (2+ levels)          | Uniform at all depths      | Breaks: compositor ≠ Parsable                 |
| Concept count                | One (`Parsable`)           | Two (`Parsable` + compositor)                 |
| Root customization           | Natural via `to_command()` | Needs `to_command()` bridge on compositor too |
| Compile-time subcommand list | Manual `add_subcommand()`  | Automatic from type params                    |

The compile-time registration guarantee is the one trade-off, but it's outweighed by the uniform model that scales to arbitrary nesting with natural support for mid-level flags and root customization.

## 8. What Stays in Builder-Only Territory

Some features are inherently imperative and don't fit neatly into struct declarations. I'm keeping these builder-only (accessible via `to_command()`):

| Feature                    | Reason                                                             |
| -------------------------- | ------------------------------------------------------------------ |
| `mutually_exclusive()`     | Partially declarative via `conflicts_with` (§6.4); builder for N>2 |
| `required_together()`      | Partially declarative via `depends_on` (§6.4); builder for N>2     |
| `one_required()`           | Cross-field constraint on N args                                   |
| `required_if()`            | Cross-field conditional                                            |
| `implies()`                | Cross-field chain with cycle detection                             |
| `confirmation_option()`    | Adds a synthetic `--yes` arg                                       |
| `help_on_no_arguments()`   | Command-level behavior                                             |
| `add_tip()`                | Help formatting                                                    |
| Color config               | Command-level presentation                                         |
| Completions config         | Command-level behavior                                             |
| Response file config       | Command-level behavior                                             |
| `allow_negative_numbers()` | Parser behavior flag                                               |
| `add_parent()`             | Cross-command inheritance                                          |

I think this is the right call — these features describe *relationships between* arguments or *command-level* behavior, not individual argument metadata. Trying to force them into struct field attributes would create a confusing, non-composable API.

## 9. Comparison with Swift Argument Parser

| Aspect                          | Swift Argument Parser           | ArgMojo Declarative                           |
| ------------------------------- | ------------------------------- | --------------------------------------------- |
| Language mechanism              | Property wrappers (`@Option`)   | Parametric wrapper types (`Option[T]`)        |
| Wrapper vocabulary              | `@Argument`, `@Option`, `@Flag` | `Positional[T]`, `Option[T]`, `Flag`, `Count` |
| Protocol / trait                | `ParsableCommand`               | `Parsable`                                    |
| Type-safe value access          | Direct field access             | `args.field.value`                            |
| Flag as Bool                    | Direct Bool                     | `Flag.__bool__()` implicit conversion         |
| Count flag                      | ✗ not built-in                  | ✓ `Count[short="v", max=3]`                   |
| Builder fallback                | ✗ no builder API                | ✓ full builder API as alternative             |
| Declarative ↔ builder bridge    | ✗ no escape hatch               | ✓ `to_command()` exposes owned `Command`      |
| Dual-return parse               | ✗ struct-only return            | ✓ `parse_split()` → (T, ParseResult)          |
| Post-parse validation           | `mutating func validate()`      | `def validate(self) raises` (planned)         |
| Mutually exclusive groups       | ✗ not in struct schema          | ✓ via `to_command()`                          |
| Interactive prompt              | ✗ not supported                 | ✓ `prompt=True` in wrapper                    |
| Password / masked input         | ✗ not supported                 | ✓ `password=True` in wrapper                  |
| Shell completions               | ✓ built-in                      | ✓ inherited from builder                      |
| Compile-time schema validation  | ✗ validated at runtime          | ✓ `comptime assert` catches errors (§6.3)     |
| Declarative field constraints   | ✗ not in struct schema          | ✓ `depends_on`/`conflicts_with` (§6.4)        |
| Auto-derived completions        | ✗ manual registration           | ✓ from `choices` at compile time (§6.5)       |
| Subcommands                     | ✓ nested `ParsableCommand`      | ✓ `Parsable` at every level + `to_command()`  |
| CJK-aware help                  | ✗ not supported                 | ✓ inherited from builder                      |
| Auto-naming (underscore→hyphen) | ✓ camelCase→kebab-case          | ✓ snake_case→kebab-case                       |

## 10. Implementation Roadmap

### Phase 1: Core Wrapper Types + Trait Default Methods

- [ ] Implement `Positional`, `Option`, `Flag`, `Count` wrapper structs
- [ ] Implement `Parsable` trait with all default methods (`parse`, `to_command`, `from_command`, `parse_split`, `parse_args`, `validate`)
- [ ] Implement `arg_defaults[T]()`
- [ ] Implement `_reflect_and_register[T]()` — reflection to Command builder calls
- [ ] Implement `_from_result[T]()` — ParseResult to struct write-back
- [ ] Auto-naming convention (underscore → hyphen)

### Phase 2: Hybrid Features

- [ ] Test `to_command()` + builder modifications + `from_command()` end-to-end
- [ ] Test `parse_split()` dual return with extra builder args
- [ ] Test: `mutually_exclusive()` via `to_command()`
- [ ] Test: extra builder args via `parse_split()`
- [ ] Document the `configure()` free function pattern for reusable configuration

### Phase 3: Subcommands

- [ ] Implement `from_command_split()` on `Parsable` trait
- [ ] Implement `from_result()` on `Parsable` trait (public write-back)
- [ ] Test: flat subcommands with `to_command()` + `add_subcommand()`
- [ ] Test: nested subcommands (2+ levels) with mid-level flags
- [ ] Test: root-level customization (colors, tips, persistent flags) with subcommands

### Phase 4: Further enhancements

- [ ] Implement `_validate_schema[T]()` compile-time checks (§6.3)
  - [ ] Duplicate short flag detection
  - [ ] Invalid short flag length
  - [ ] Positional ordering enforcement
  - [ ] Type-metadata mismatch detection
  - [ ] Choices vs default consistency
- [ ] Add `depends_on`/`conflicts_with` parameters to `Option` and `Flag` (§6.4)
  - [ ] Compile-time validation of referenced field names
  - [ ] Translation to builder `required_together()`/`mutually_exclusive()` in `_reflect_and_register()`
- [ ] Auto-derive completions from `choices` parameters (§6.5)
  - [ ] Ensure choices flow to `generate_completion` output
  - [ ] Explore compile-time completion script generation

### Phase 5: Polish

- [ ] Comprehensive test suite (parallel to existing builder tests)
- [ ] Examples: simple, hybrid, subcommands
- [ ] User manual additions
- [ ] README update with declarative examples
