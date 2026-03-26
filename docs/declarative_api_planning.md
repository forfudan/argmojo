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

1. **Optional** — If you prefer the builder API, nothing changes for you. The parser module is a separate import (`from argmojo.parser import ...`). Zero change to existing code.

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

| Swift Mechanism                  | ArgMojo Equivalent                          |
| -------------------------------- | ------------------------------------------- |
| `@Argument(help: "...")`         | `Positional[T, help="..."]`                 |
| `@Option(name: .shortAndLong)`   | `Option[T, long="...", short="..."]`        |
| `@Flag(inversion: .prefixedNo)`  | `Flag[negatable=True]`                      |
| (no Swift equivalent)            | `Count[short="v", max=3]`                   |
| (no Swift equivalent)            | `Parser[T]`                                 |
| `ParsableCommand` protocol       | `Parsable` trait                            |
| `@OptionGroup`                   | Argument parents via `Command.add_parent()` |
| `ExpressibleByArgument` protocol | `ExpressibleByArgument` trait               |
| `CommandGroup`                   | `SubParser[...]`                            |
| `mutating func run()`            | Separate: `Parser[T].parse()` returns T     |
| `mutating func validate()`       | `def validate(self) raises` on `Parsable`   |

What I think argmojo can add beyond Swift:

1. `to_command()` exposes the underlying `Command` (as reference) for builder-level customisation — Swift's `ParsableCommand` is a sealed box with no escape hatch to things like mutually exclusive groups, implications, or custom help formatting.
2. `parse_split()` returns both typed struct + `ParseResult` — Swift requires all fields to live in the struct.
3. Declarative is optional — Swift has no builder alternative; you *must* use the struct-based approach.

**`validate()`**: I'm also thinking about an optional `def validate(self) raises` method on `Parsable` (mirroring Swift's `validate()`). It would complement `to_command()` for post-parse cross-field validation without requiring the builder API.

**A note on naming** — I had to pick names for several structs and traits. Some were genuinely hard. The final names inevitably reflect my personal taste, but I tried to be consistent and self-explanatory. Here's what I chose and why:

1. **`Parser`**: The declarative orchestrator — you call `.parse()` on it, much like `Command`. I originally called it `Declaration`, but that was misleading since it wraps and drives a `Command` internally. `Parser` aligns with clap's `#[derive(Parser)]` and clearly communicates its role: it parses CLI arguments from a struct schema. `CLI` was another candidate, but `CLI.to_command()` reads oddly. `Parser[T]` felt right — short, familiar, and it tells you this is the declarative counterpart to `Command`.

2. **`Parsable`**: This is the trait that user structs conform to. It follows Swift's `ParsableCommand` naming and Mojo's `TypeName+able` pattern (`Int`→`Intable`, `String`→`Stringable`, `Parser`→`Parsable`). `Parser[T: Parsable]` reads naturally: "a parser of something parsable." The user struct describes *what* to parse (the schema), and `Parser` knows *how* to parse it. You should always think of the user struct (`Parsable`) and `Parser` as a pair — one cannot exist without the other.

3. **`Positional`**: Swift calls it `@Argument`, but I already have an `Argument` struct in the builder layer that covers *all* argument types. Two different `Argument` types with different meanings would be confusing. `Positional` is unambiguous — it tells you exactly what kind of argument it is.

## 3. Architecture

```txt
┌──────────────────────────────────────────────────────────────────────────┐
│  User Code                                                               │
│                                                                          │
│  @fieldwise_init                                                         │
│  struct MyArgs(Parsable):                                                │
│      var name: Positional[String, help="Name", required=True]            │
│      var verbose: Flag[short="v", help="Verbose"]                        │
│      var output: Option[String, long="output", short="o"]                │
│      def __init__(out self): self = arg_defaults[Self]()                 │
│                                                                          │
│  var decl = Parser[MyArgs]()                                             │
│  var cmd = decl.to_command()                                             │
│  cmd.mutually_exclusive([...])                                           │
│  var args = decl.parse()  →  MyArgs (typed struct)                       │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  parser.mojo  (NEW — ~400-600 lines)                                     │
│                                                                          │
│  Parser[T].to_command() → Command  (reflect T → builder calls)           │
│  Parser[T].parse()      → T        (parse + write-back)                  │
│  Parser[T].from_result()→ T        (ParseResult → struct)                │
│  arg_defaults[T]()      → T          (default-initialized)               │
│                                                                          │
│  Wrapper types: Positional[T, ...], Option[T, ...], Flag[...], Count[...]│
│  Trait: Parsable                                                         │
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

| File                        | Change                                      |
| --------------------------- | ------------------------------------------- |
| `src/argmojo/parser.mojo`   | **New file** — all parser types and logic   |
| `src/argmojo/__init__.mojo` | Add `from .parser import ...` (conditional) |
| Everything else             | **Zero changes**                            |

### Comparison between Builder and Declarative APIs

| Aspect        | Builder API                 | Declarative API                                            |
| ------------- | --------------------------- | ---------------------------------------------------------- |
| Command       | `Command`                   | `Parser[MyArgs: Parsable]` (two layers)                    |
| Argument      | `Argument`                  | `Positional`, `Option`, `Flag`, `Count` (four types)       |
| Add arguments | `command.add_argument(...)` | 4 types of structs within `MyArgs` (compile-time metadata) |
| Parse         | `command.parse()`           | `parser.parse()` (returns typed struct)                    |
| Parse result  | `ParseResult`               | Typed struct `MyArgs` with inner `.value` fields           |
| Transform     | `Parser.to_command()`       | -                                                          |

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
from argmojo.parser import Parser, Option, Flag, Positional, Parsable
```

### 4.2 The `Parsable` Trait

```mojo
trait Parsable(Defaultable, Movable):
    """Marker trait for structs that can be parsed from CLI arguments."""

    @staticmethod
    def description() -> String:
        """Return the command description for --help."""
        ...

    @staticmethod
    def version() -> String:
        """Return the version string for --version. Default "0.1.0"."""
        ...

    @staticmethod
    def name() -> String:
        """Return the command name. Default: lowercased struct name."""
        ...
```

Minimal implementation — you only need to provide `description()`:

```mojo
@fieldwise_init
struct MyArgs(Parsable):
    var input: Positional[String, help="Input file", required=True]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "My awesome tool"
```

`version()` and `name()` have default implementations in the trait, so they're optional.

### 4.3 The `Parser[T]` Orchestrator

```mojo
struct Parser[T: Parsable]:
    """Orchestrates struct-to-command conversion, parsing, and write-back."""

    var _command: Command
    var _built: Bool

    def __init__(out self):
        self._command = Command(T.name(), T.description(), version=T.version())
        self._built = False

    # ── Core methods ──

    def to_command(mut self) raises -> ref [self._command] Command:
        """Build and return the underlying Command.
        Users can modify it with builder methods before parsing."""
        if not self._built:
            self._build()
            self._built = True
        return self._command

    def parse(mut self) raises -> T:
        """Parse sys.argv() and return a populated T instance."""
        if not self._built:
            self._build()
            self._built = True
        var result = self._command.parse()
        return self._from_result(result)

    def parse_args(mut self, raw_args: List[String]) raises -> T:
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
    # NOTE: Capturing closures (unified {mut x}) cannot be passed as def() arguments
    #       due to type mismatch (nonescaping closure ≠ bare def). Non-capturing is sufficient here.

    def configure(mut self, callback: def(mut Command) raises -> None) raises -> ref [self] Self:
        """Apply builder-level customizations via callback."""
        if not self._built:
            self._build()
            self._built = True
        callback(self._command)
        return self

    # ── Innovation #2: parse_split (see §6.2) ──

    def parse_split(mut self) raises -> (T, ParseResult):
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

    def _build(mut self) raises:
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
            elif _is_positional_type(ftype):
                self._register_positional(fname, ftype)
            elif _is_count_type(ftype):
                self._register_count(fname, ftype)
            else:
                # Bare type: treat as named option with field name as long name
                self._register_bare(fname, ftype)

    def _from_result(self, result: ParseResult) raises -> T:
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
                # Write positional value:
                #   If T is List[String] → get_list
                #   If T is String → get_string
                #   If T is Int → get_int
                _write_positional_value(field, fname, result)
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
from argmojo.parser import Parser, Option, Flag, Positional, Count, Parsable, arg_defaults

@fieldwise_init
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
    var args = Parser[Grep]().parse()

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
from argmojo.parser import Parser, Option, Flag, Positional, Parsable, arg_defaults

@fieldwise_init
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
    var decl = Parser[Deploy]()

    # Bridge to builder: add constraints that the parser can't express
    var cmd = decl.to_command()
    cmd.mutually_exclusive(["force", "dry-run"])
    cmd.implies("force", "tag")       # force requires a tag
    cmd.confirmation_option["Deploy to production?"]()
    cmd.header_color["CYAN"]()
    cmd.add_tip("Use --dry-run to preview changes first")

    # decl.parse() returns typed T; cmd.parse() would return untyped ParseResult.
    # Always prefer decl.parse() or decl.parse_split() in hybrid mode.
    var args = decl.parse()
    print("Deploying to:", args.target.value)
    print("Tag:", args.tag.value)
```

### 5.3 Split Parse (Declarative + Extra Builder Fields)

```mojo
from argmojo import Command, Argument
from argmojo.parser import Parser, Positional, Option, Flag, Parsable, arg_defaults

@fieldwise_init
struct Convert(Parsable):
    var input: Positional[String, help="Input file", required=True]
    var output: Option[String, long="output", short="o", help="Output file"]

    def __init__(out self): self = arg_defaults[Self]()

    @staticmethod
    def description() -> String:
        return "File format converter."

def main() raises:
    var decl = Parser[Convert]()

    # Add extra builder-only arguments via to_command()
    var cmd = decl.to_command()
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
    args, result = decl.parse_split()

    # Declarative fields: typed access
    print("Input:", args.input.value)
    print("Output:", args.output.value)

    # Builder fields: ParseResult access
    var format = result.get_string("format")
    var indent = result.get_int("indent")
```

### 5.4 Subcommands with Declarative

```mojo
from argmojo.parser import Parser, SubParser, Option, Flag, Positional, Parsable, arg_defaults

@fieldwise_init
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

@fieldwise_init
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
    # SubParser registers multiple Parsable types as subcommands
    var result = SubParser["mgit", "A mini git tool", Clone, Push]().parse()

    if result.subcommand == "clone":
        var args = result.get[Clone]()
        print("Cloning:", args.url.value)
    elif result.subcommand == "push":
        var args = result.get[Push]()
        print("Pushing to:", args.remote.value)
```

## 6. Innovations

### 6.1 Innovation #1: `to_command()` — First-Class Declarative-Builder Bridge

**What Swift Argument Parser lacks**: Swift's `ParsableCommand` is a sealed protocol — there's no escape hatch to add builder-level configuration. If you need mutually exclusive groups, implications, colored help, tips, or completions, you're on your own with `validate()` and custom help formatting.

**What I'm adding**: `to_command()` returns a mutable reference to the underlying `Command` object, so you can do arbitrary builder modifications before parsing:

```mojo
var decl = Parser[MyArgs]()
var cmd = decl.to_command()
cmd.mutually_exclusive(["json", "yaml"])
cmd.required_together(["username", "password"])
cmd.implies("debug", "verbose")
cmd.confirmation_option()
cmd.header_color["CYAN"]()
cmd.add_tip("See docs at https://example.com")
cmd.completions_as_subcommand()
var args = decl.parse()
```

This creates a **smooth gradient** between simplicity and power:

```txt
Pure declarative     Declarative + to_command()    Pure builder
(3 lines)            (10 lines)                    (30 lines)
Simple tools    →    Medium complexity tools   →    Maximum control
```

I don't know of any other Mojo CLI library that offers this continuum. You never have to completely rewrite from one style to another when requirements grow.

**Type safety note**: If you use `to_command()` to add **constraints** (groups, implications, colours), full type safety is preserved — `parse()` still returns `T`. But if you add **new arguments** (`add_argument(...)`), those fields are only available via `ParseResult` from `parse_split()`. This is an intentional trade-off:

```txt
to_command() + constraints only     →  parse()        →  T (fully typed ✓)
to_command() + new arguments        →  parse_split()  →  (T, ParseResult) (partially typed ⚠️)
```

**`configure()` with non-capturing callbacks**: I've verified in Mojo 0.26.2 that `configure()` works with non-capturing callbacks (nested functions that don't capture external state). Since `configure()` callbacks only operate on the `mut Command` parameter, capturing is unnecessary:

```mojo
var args = Parser[MyArgs]()
    .configure(def(mut cmd) raises: cmd.mutually_exclusive([...]))
    .configure(def(mut cmd) raises: cmd.implies("a", "b"))
    .parse()
```

**Limitation**: Mojo's capturing closures (`unified {mut x}`) produce a `nonescaping closure` type that can't be passed as a bare `def()` argument. This doesn't affect `configure()` since its callbacks don't need captures — the `mut Command` parameter provides all necessary state.

`to_command()` is the primary bridge for multi-step customization; `configure()` is syntactic sugar for one-liner tweaks.

### 6.2 Innovation #2: `parse_split()` — Dual-Return Parsing

**The problem**: When mixing declarative and builder fields, how do I give you typed access to declarative fields AND untyped access to builder-added fields?

**Swift's answer**: You can't. All fields must be declared in the struct.

**Naive approach**: Return only `ParseResult`, losing the typed struct benefit.

**My approach**: `parse_split()` returns a **tuple of both**:

```mojo
def parse_split(mut self) raises -> Tuple[T, ParseResult]:
```

- The first element is your struct `T` with all declarative-registered fields populated & typed.
- The second element is the full `ParseResult` containing everything (declarative fields + builder-added fields).

This means:

```mojo
var (args, result) = decl.parse_split()

# Declarative fields: compile-time typed access, no string keys
args.verbose          # Bool
args.output.value     # String
args.count.value      # Int

# Builder-added fields: runtime string-keyed access
result.get_string("extra-option")
result.get_int("threads")
result.get_list("tags")
```

As far as I know, this is a **new pattern** not seen in any CLI library in any language. Even Rust's clap can't do this — once you use its derive macro, all fields must be in the struct. There's no mechanism for "some fields are struct, some are ParseResult."

The dual-return enables a practical workflow:

1. Start with pure declarative
2. Need one advanced option? Add it via `to_command()` + `parse_split()`
3. No need to convert the struct field (or add a new nested type)

### 6.3 Innovation #3: Compile-Time Schema Validation

**The problem**: In every runtime CLI library, schema errors (duplicate short flags, invalid short flag length, positional-after-optional ordering) only surface when you run the program — or worse, when a user triggers the specific code path.

**What I'm adding**: Since all wrapper metadata lives in compile-time parameters (`StringLiteral`, `Bool`, `Int`), the declarative layer can validate the **entire schema at compile time** using `comptime assert`. Your program won't even compile if the schema is invalid.

Concrete checks in `Parser[T]._build()`:

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

**Why this matters**: Neither Swift Argument Parser, Rust clap, nor mojopt can do this. Swift's property wrappers are validated at runtime. Rust's proc macros catch *some* errors but not all (e.g. duplicate short flags pass the proc macro and fail at runtime). Mojo's parametric type system uniquely enables full schema validation at compile time.

**Zero-cost guarantee**: All checks use `comptime assert` — they're erased from the binary. No performance cost, no code bloat.

### 6.4 Innovation #4: Declarative `depends_on` / `conflicts_with`

**The problem**: Cross-field constraints like "username requires password" or "json conflicts with yaml" currently require the imperative `to_command()` escape hatch:

```mojo
var decl = Parser[MyArgs]()
var cmd = decl.to_command()
cmd.required_together(["username", "password"])
cmd.mutually_exclusive(["json", "yaml"])
var args = decl.parse()
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

**Translation in `_build()`**:

| Declarative parameter        | Builder call generated                                   |
| ---------------------------- | -------------------------------------------------------- |
| `depends_on="password"`      | `cmd.required_if("password", "username")`                |
| `conflicts_with="json,yaml"` | `cmd.mutually_exclusive(["this_field", "json", "yaml"])` |

**Compile-time name validation**: Since `depends_on` and `conflicts_with` are `StringLiteral` parameters, and all field names are known at compile time via `struct_field_names`, I can verify at compile time that every referenced name actually exists in the struct:

```mojo
# In _build(), at comptime:
# depends_on="password" → verify "password" is in struct_field_names[T]()
# If not → comptime assert failure with a clear error message
```

This catches typos like `depends_on="passwrod"` at compile time — something no other CLI library can do.

**Symmetry note**: `depends_on` is symmetric by convention (if A depends on B, B depends on A). A single `depends_on="password"` on `username` generates `required_together(["username", "password"])`. If both sides declare it, deduplication in `_build()` prevents double-registration.

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

**How it works**: During `_build()`, when a field has a non-empty `choices` parameter, the generated completion script automatically includes those values as completions for that argument's value. The builder's `generate_completion["fish"]()` / `generate_completion["zsh"]()` / `generate_completion["bash"]()` already reads `_choice_values` — the declarative layer simply ensures they're populated.

**Compile-time generation**: Since all choices are `StringLiteral` values known at compile time, the entire completion script could be generated as a compile-time constant:

```mojo
# Hypothetical: completion script as a compile-time StringLiteral
alias fish_completion = Parser[MyArgs].completion_script["fish"]()
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

### 7.3 SubParser Design

`SubParser` is parameterized on variadic types:

```mojo
struct SubParser[
    app_name: StringLiteral,
    app_description: StringLiteral,
    *Ts: Parsable,
]:
    var _command: Command

    def __init__(out self):
        self._command = Command(String(app_name), String(app_description))

    def parse(mut self) raises -> SubResult[*Ts]:
        # For each type in Ts, build a sub-Command and register via add_subcommand
        @parameter
        for i in range(len(Ts)):
            var sub_cmd = Parser[Ts[i]]().to_command()
            self._command.add_subcommand(sub_cmd)
        return SubResult[*Ts](self._command.parse())
```

`SubResult` provides a `get[T]()` method that does the write-back for the matched subcommand.

**Note**: Variadic type parameters are still evolving in Mojo. If `*Ts` isn't stable yet, I'll fall back to explicit overloads for 1–8 subcommand types (like `SubParser2[T1, T2]`, `SubParser3[T1, T2, T3]`, etc.).

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
| Declarative ↔ builder bridge    | ✗ no escape hatch               | ✓ `to_command()` exposes `Command`            |
| Dual-return parse               | ✗ struct-only return            | ✓ `parse_split()` → (T, ParseResult)          |
| Post-parse validation           | `mutating func validate()`      | `def validate(self) raises` (planned)         |
| Mutually exclusive groups       | ✗ not in struct schema          | ✓ via `to_command()`                          |
| Interactive prompt              | ✗ not supported                 | ✓ `prompt=True` in wrapper                    |
| Password / masked input         | ✗ not supported                 | ✓ `password=True` in wrapper                  |
| Shell completions               | ✓ built-in                      | ✓ inherited from builder                      |
| Compile-time schema validation  | ✗ validated at runtime          | ✓ `comptime assert` catches errors (§6.3)     |
| Declarative field constraints   | ✗ not in struct schema          | ✓ `depends_on`/`conflicts_with` (§6.4)        |
| Auto-derived completions        | ✗ manual registration           | ✓ from `choices` at compile time (§6.5)       |
| Subcommands                     | ✓ nested `ParsableCommand`      | ✓ `SubParser[...]` variadic types             |
| CJK-aware help                  | ✗ not supported                 | ✓ inherited from builder                      |
| Auto-naming (underscore→hyphen) | ✓ camelCase→kebab-case          | ✓ snake_case→kebab-case                       |

## 10. Implementation Roadmap

### Phase 1: Core Wrapper Types + Parser

- [ ] Implement `Positional`, `Option`, `Flag`, `Count` wrapper structs
- [ ] Implement `Parsable` trait
- [ ] Implement `arg_defaults[T]()`
- [ ] Implement `Parser[T]._build()` — reflection to Command builder calls
- [ ] Implement `Parser[T]._from_result()` — ParseResult to struct write-back
- [ ] Implement `Parser[T].parse()` — end-to-end
- [ ] Auto-naming convention (underscore → hyphen)

### Phase 2: Hybrid Features

- [ ] Implement `Parser[T].to_command()` escape hatch
- [ ] Implement `Parser[T].parse_split()` dual return
- [ ] Test: parser + `mutually_exclusive()` via to_command()
- [ ] Test: parser + extra builder args via parse_split
- [ ] Implement `Parser[T].configure()` callback (non-capturing, works in 0.26.2)

### Phase 3: Subcommands

- [ ] Implement `SubParser[..., *Ts]` or `SubParser2/3/...` overloads
- [ ] Implement `SubResult.get[T]()` typed subcommand access
- [ ] Test: nested subcommands with parser

### Phase 4: Further enhancements

- [ ] Implement `_validate_schema[T]()` compile-time checks (§6.3)
  - [ ] Duplicate short flag detection
  - [ ] Invalid short flag length
  - [ ] Positional ordering enforcement
  - [ ] Type-metadata mismatch detection
  - [ ] Choices vs default consistency
- [ ] Add `depends_on`/`conflicts_with` parameters to `Option` and `Flag` (§6.4)
  - [ ] Compile-time validation of referenced field names
  - [ ] Translation to builder `required_together()`/`mutually_exclusive()` in `_build()`
- [ ] Auto-derive completions from `choices` parameters (§6.5)
  - [ ] Ensure choices flow to `generate_completion` output
  - [ ] Explore compile-time completion script generation

### Phase 5: Polish

- [ ] Comprehensive test suite (parallel to existing builder tests)
- [ ] Examples: simple, hybrid, subcommands
- [ ] User manual additions
- [ ] README update with declarative examples
