# ArgMojo changelog

This document tracks all notable changes to ArgMojo, including new features, API changes, bug fixes, and documentation updates.

## 20260811 (v0.8.0)

ArgMojo v0.8.0 moves to the first stable Mojo release, **v1.0.0**. It also fixes a dozen parser bugs, repairs an FFI signature clash that could break the build of a project using ArgMojo, cuts compile time by about a fifth, and fills several gaps in the declarative API.

ArgMojo v0.8.0 targets Mojo v1.0.0.

### ⭐️ New in v0.8.0

1. Add `ParseResult.was_provided(name)` — True only when the user really supplied the argument, be it on the command line, at a prompt, or through an `implies()` rule. `has(name)` cannot tell you that, because a default is stored in the same place as a parsed value. Group constraints use it internally, and it is often what you want in your own code too:

   ```mojo
   if result.was_provided("format"):
       print("the user asked for " + result.get_string("format"))
   else:
       print("falling back to the default format")
   ```

2. Add `ParseResult.get_float(name)` — reads a value as `Float64`, the way `get_int()` reads it as `Int`.
3. `Option[Float64]` and `Positional[Float64]` now work end to end, defaults included. `has_range` stays integer-only, so combining it with `Float64` is rejected at compile time instead of failing later with a puzzling "expected an integer".
4. `Count` can be unwrapped with `Int()`, as `Flag` can with `Bool()`. Write `Int(args.verbose)` instead of `args.verbose.value`.
5. The four declarative wrappers now take a consistent set of parameters. `alias_name` was on `Option` only and `deprecated` on `Option` and `Flag` only; both are now available wherever they make sense. `Positional` gains `hidden`, `deprecated`, `prompt`, `prompt_text`, `password`, and the range parameters (`has_range`, `range_min`, `range_max`, `clamp`) that `Option` already had. Until now, needing any one of these on a positional meant dropping to the builder API for that one field.

### 🔧 Fixes in v0.8.0

1. Fix an FFI signature clash in `_read_password_asterisk()`. The `read(2)` binding passed its buffer as `Int(ptr)`, which declares `read` as `(Int, Int, Int) -> Int`, while the standard library declares the same symbol as `(Int, Pointer, Int) -> Int`. Any module linking both failed to lower to LLVM IR. The buffer is passed as a real pointer now (PR #59).
2. Group constraints counted a default as user input. `mutually_exclusive()`, `required_together()`, `one_required()` and `required_if()` all asked `has()`, which is True for an argument that merely carries a `.default()` — so `--json` alone could conflict with a `--format` nobody had typed. All four consult `was_provided()` now.
3. A required positional could be satisfied by a *later* positional's default. Filling the later slot pads the positional list up to that index, and the earlier, still-empty slot then looked provided: `src` (required) followed by `dst` (with a default) parsed happily with no arguments at all. A default on the required argument itself still satisfies it, as in clap.
4. `app --=hello` used to set the first positional. The empty name left after splitting on `=` matched `_long_name == ""`, which is true for every positional and every short-only option. It is now reported as `Invalid option '--=hello': missing option name`.
5. An argument carrying both `.prompt()` and `.default()` was never prompted, because defaults were applied first and prompting skips anything that already holds a value. Prompting runs first now, and the default is what an empty answer — or a non-interactive stdin — falls back to, which is what the "(default)" hint always promised.
6. Defaults now reach the accessor that belongs to the argument. Every default used to be written to the string store, so `.flag().default["true"]()` was invisible to `get_flag()`, and `.append().default["x"]()` left `get_list()` empty while `get_string()` returned the value. Defaults go to `_flags`, `_counts`, `_lists`, `_maps` or `_values` according to the kind of the argument.
7. Bad defaults are caught at registration instead of reaching the user. `add_argument()` now raises if a default is not one of the declared `.choice[…]()` values, if a `.flag()` default is not a boolean literal, if a `.count()` default is not an integer, or if a `.map_option()` default is not in `key=value` form; `default_if_no_value` is checked against the choices too. The declarative wrappers already checked the choices at compile time; the builder API checked nothing.
8. An option no longer swallows another option as its value: `--output --verbose` used to store the literal string `"--verbose"`. Only *registered* options and the `--` marker are refused, so `--offset -5` and `--pattern -foo` still work, and `.allow_hyphen_values()` opts out entirely. The guard covers short options and `.number_of_values[N]()` as well.
9. Persistent-argument conflicts were detected in only one registration order. The check lived in `add_subcommand()`, so calling `add_subcommand()` first and `add_argument(... .persistent())` afterwards slipped past it, and the flag then appeared twice in the child's help. `add_argument()` runs the mirror check now, and the injection at dispatch time skips an argument the child already owns.
10. Non-ASCII passwords came back corrupted. `_read_password_asterisk()` rebuilt the typed string byte by byte through `chr()`, which treats each byte as a code point and re-encodes it, so `é` (`C3 A9`) arrived as `Ã©` (`C3 83 C2 A9`) and never matched. The bytes are decoded as UTF-8 in one step now, and the buffer is zeroed before it is freed.
11. An `implies()` rule could fire from a default value — fix 2 again, by another route. The trigger was `has(trigger)`, so a `--mode` that merely defaults to `fast` still set `--parallel`; since an implied argument counts as user input, typing only `--quiet` then reported a conflict with a `--parallel` nobody had asked for. Implications fire on `was_provided(trigger)`.
12. `parse_known_arguments()` applied defaults before implications, the reverse of `parse_arguments()`, so the two entry points could disagree about which arguments counted as supplied. Both run implications first now.

### 🔄 Mojo v1.0.0 migration (PR #59)

- Bump the Mojo dependency from `==1.0.0b2` to `>=1.0.0, <1.1.0` in `pixi.toml`, so ArgMojo builds against any Mojo v1.0.x release.
- Replace the removed `_constrained_field_conforms_to` helper with `comptime assert conforms_to(...)` plus `_field_conforms_to_error`, which is how the standard library now writes reflection-driven trait defaults.
- Drop the `trait_downcast[…]()` calls in `Parsable`. A `comptime if conforms_to(...)` guard (or a `comptime assert`) is now enough for the compiler to resolve trait methods on a reflected field.
- Replace `__struct_field_ref(i, x)` with the public `reflect[Self].field_ref[i](x)`.
- Rename `ImplicitlyDestructible` to `Deinitable`, and drop `Movable` from the `Defaultable & Copyable & Movable` bounds, which the compiler now reports as redundant.
- Rename the move constructor argument from `deinit take:` to `deinit move:` in `Argument`, `Command`, `ParseResult`, and the four argument wrappers.
- Replace `UnsafePointer(to=f).init_pointee_move(v)` with `Pointer(to=f).unsafe_write(v)`.
- Give `Command` and `ParseResult` an explicit, empty `__deinit__()`. Both hold a `List[Self]` field, and deducing `List[Command]: Deinitable` now requires `Command: Deinitable` — exactly what is being deduced. Declaring the destructor breaks the cycle, and the fields are still destroyed automatically.
- Introduce temporary variables where a `String` is rebuilt from a slice of itself (e.g. `key = String(key[byte=:eq])`), because such statements now trip the exclusivity checker.
- Dispatch the declarative wrappers on `reflect[T].name()` compared against the reflected names of the supported types, instead of against string literals. In Mojo v1.0.0, `Int` became an alias of `Scalar[DType.int]` and so reflects as `"SIMD[DType.int, 1]"`; comparing one reflected name with another keeps working across such renames.
- Update `tests/test_wrappers.mojo` to call the move constructor as `(move=a^)`.

### ⚡️ Performance in v0.8.0

- Compiling a program that uses ArgMojo is about 20% faster. Measured cold, with the compiler cache wiped, over the eight examples: 50.2 s down to 39.8 s in total, or 6.08 s down to 4.81 s per example. Nothing about the behaviour changes — help text, the three completion scripts and the error messages are byte-for-byte identical before and after. Four changes get there:
  - `examples/build.sh` builds against the `argmojo.mojoc` it already produces (`-I .`) instead of recompiling `src/argmojo` into all eight binaries (`-I src`). This is the bulk of it: 50.2 s → 42.7 s on its own. Its timing summary now reports hundredths of a second and a total, rather than whole seconds from `date +%s`.
  - Argument lookup returns an index instead of a copy. `_find_by_long()` and `_find_by_short()` deep-copied the whole `Argument` on *each* option token, only to read two or three fields; they are `_find_index_by_long()` / `_find_index_by_short()` now, and callers bind the result with `ref`. The per-loop copies in `_prompt_missing_arguments()`, `_validate()`, `_apply_defaults()` and the three completion generators became `ref` bindings too. This is the largest runtime saving in the release as well: dozens of heap allocations disappear from every parse.
  - Long `+` chains became `String(...)` calls. Building a message as `"a" + x + "b" + y + ...` emits a separate inlined concatenation for every `+`; passing the same pieces to `String(...)` emits one call. 154 sites across `command.mojo`.
  - `_looks_like_number()` and `_levenshtein()` compare bytes rather than one-character strings. `token[byte=j:j+1] >= "0"` writes out a full string comparison per character; a `UInt8` against a byte constant is one instruction. `_looks_like_number()` alone dropped from 17,850 lines of unoptimised IR to 4,431.

  Together the source changes take the unoptimised IR of a one-argument program from 332,047 lines down to 264,929 (−20%).
- Replace the fixed-size `List` scratch buffers with the inline `Array` type, removing four heap allocations from the terminal-handling paths: the 8-byte `ioctl(TIOCGWINSZ)` buffer in `_help_line_width()`, the 96-byte termios buffers in `_disable_echo()` and `_read_password_asterisk()`, and the 1-byte read buffer of the password loop. `_disable_echo()` returns `Optional[Array[UInt32, 24]]` now, instead of signalling failure with an empty list (PR #59).
- Use a stack-allocated `Array[String, 2]` for the argument-name scratch buffer in `required_if()` (PR #59).

### 📖 Documentation in v0.8.0

- `docs/declarative_api_planning.md` gains a "Known Gaps" section: what went wrong in the wrappers, what has been fixed, and why the rest is still open.
- The user manual documents `has()` versus `was_provided()`, which accessor reads back each kind of default, the registration-time rules for default values, how values that look like options are treated, the value types the declarative wrappers accept, and the `Bool()` / `Int()` unwrapping shortcuts.
- `Argument.remainder()` now says what happens when the remainder is the first positional: collection starts at the very first token, so `--help` is swallowed as a remainder value and the command has no help flag. That is what a wrapper command such as `env` wants, but it is worth knowing before you hit it. Declare a positional ahead of the remainder, or call `help_on_no_arguments()`.
- The `_allow_hyphen_values` field docstring claimed it accepts "the literal token `-`". It has always accepted any dash-prefixed token, and it now also switches off the check described in fix 8.

### ⚠️ Known issues in v0.8.0

- `mojo doc` (v1.0.0) does not recognise a struct parameter named `max`: it reports `unknown parameter 'max' in doc string`, then miscounts the index of every parameter declared after it. Two structs that differ only in that name are enough to show it — `max` warns, `maximum` does not — so the bug is in the tool. `Count`'s `max` is therefore described in the struct's prose docstring rather than its `Parameters:` block; renaming it would break every `Count[..., max=N]` already written. See §11 of `docs/declarative_api_planning.md`.
- Response-file expansion (`response_file_prefix()`) is **still disabled**. The Mojo compiler deadlock that blocked it in v0.4.0 also reproduces on Mojo v1.0.0: re-enable the call in `parse_arguments()` and the compilation of `tests/test_parse.mojo` hangs at 0% CPU under `-D ASSERT=all`. Curiously, `tests/test_response_file.mojo` itself *does* compile and pass (17/17) with the call re-enabled, so the trigger depends on the surrounding set of instantiations rather than on the expansion code alone. The implementation is kept as module-level free functions, and `tests/test_response_file.mojo` remains excluded from the `test` and `t` tasks.

## 20260618 (v0.7.0)

ArgMojo v0.7.0 migrates the codebase to Mojo v1.0.0b2 (PR #58).

## 20260510 (v0.6.0)

ArgMojo v0.6.0 introduces auto-dispatch for subcommands, improves parser behavior for mathematical-expression tokens, and migrates the codebase to Mojo v1.0.0b1.

### ⭐️ New in v0.6.0

1. Add `allow_negative_expressions()` on `Command` — treats single-hyphen tokens as positional arguments when they do not conflict with registered short options. Handles mathematical expressions like `-1/3*pi`, `-sin(2)`, and `-e^2`. This is a strict superset of `allow_negative_numbers()`. This is useful for mathematical tools, e.g., [decimo CLI](https://github.com/forfudan/decimo/blob/main/src/cli/main.mojo). (PR #52)
2. Add **auto-dispatch** — `set_run_function(handler)` registers a `def(ParseResult) thin raises -> None` handler on a `Command`; `execute()` parses and auto-dispatches to the matching handler, eliminating manual `if/elif` subcommand chains. `_execute_with_arguments(args)` provides equivalent dispatch for tests with explicit argument lists. Works with nested subcommands, aliases, and persistent flags. (PR #53)

### 🔄 Mojo v1.0.0b1 migration

- Bump Mojo dependency to `==1.0.0b1` in `pixi.toml`. (PR #54)
- Migrate stored function pointers for run handlers to use the `thin` function effect (`def(ParseResult) thin raises -> None`). (PR #54)
- Add explicit `ImplicitlyDestructible` bounds where required (`Defaultable`, `Movable`, `Parsable` generics), because trait hierarchy implications changed. (PR #54)
- Replace deprecated `len(String)` usage with `String.byte_length()`. (PR #54)
- Replace deprecated reflection helpers (`get_type_name[T]()`, `struct_field_*[T]()`) with the unified `reflect[T]()` API. (PR #54)

## 20260404 (v0.5.0)

ArgMojo v0.5.0 introduces the **struct-based declarative API** — define a `Parsable` struct with typed wrapper fields (`Option`, `Flag`, `Positional`, `Count`), call `MyArgs.parse()`, and get typed results. The declarative API coexists with the existing builder API and bridges between them via `to_command()` / `parse_from_command()`. This release also adds asterisk-masked password input and reorganises internal modules.

ArgMojo v0.5.0 targets Mojo v0.26.2.

### ⭐️ New in v0.5.0

1. **Declarative API core** — `Parsable` trait with compile-time reflection over wrapper-typed fields. Conforming structs need only declare fields and provide `description()`; all parsing, Command-building, and write-back methods are provided as trait defaults (PR #34, #35, #37, #40).
2. **Wrapper types** — `Option[T, ...]`, `Flag[...]`, `Positional[T, ...]`, `Count[...]` parametric structs encode CLI metadata as compile-time parameters. Conform to the internal `ArgumentLike` trait with `add_to_command()` / `read_from_result()` hooks (PR #34).
3. **Auto-initialisation** — `Parsable.__init__` uses `mark_initialized` + `comptime for` + `UnsafePointer.init_pointee_move` to default-construct all fields via reflection. Users never need to write `__init__` (PR #37).
4. **Hybrid bridge** — `to_command()` reflects a `Parsable` struct into an owned `Command` for builder-level customisation; `parse_from_command(cmd^)` parses back into a typed struct (PR #35, #40).
5. **Dual-return parsing** — `parse_full()` returns `Tuple[Self, ParseResult]` for workflows that need both typed struct fields and raw `ParseResult` access (e.g. subcommand dispatch). `parse_full_from_command(cmd^)` does the same from a pre-configured Command (PR #40, #42).
6. **Subcommand support** — `subcommands()` hook on `Parsable` returns `List[Command]`; called automatically by `to_command()` for recursive tree assembly. `run(self)` method for leaf command execution. `from_parse_result()` for typed write-back from subcommand results (PR #39, #43).
7. **Asterisk-masked password input** — `.password[True]()` on `Argument` echoes `*` for each keystroke (sudo-rs style), complementing the existing `.password()` which hides input entirely. Uses raw terminal mode with ICANON/ISIG disabled (PR #32).

### 🦋 Changed in v0.5.0

1. Remove `Arg` alias for `Argument` and drop `ArgumentLike` from the public export list. The public API now exports: `Argument`, `Command`, `ParseResult`, `Parsable`, `Option`, `Flag`, `Positional`, `Count` (PR #42).
2. `subcommands()` hook signature changed from `subcommands(mut cmd: Command) raises` to `subcommands() raises -> List[Command]` — returns a list of Commands instead of mutating one (PR #43).
3. Reorganise `Argument` and `Command` source files into clearly grouped internal sections for readability (PR #33).

### 📚 Documentation and testing in v0.5.0

- Add `docs/declarative_api_planning.md` — comprehensive design document for the declarative API (PR #33).
- Add 4 declarative examples: `search.mojo` (pure declarative), `deploy.mojo` (hybrid), `convert.mojo` (full parse + extra builder args), `jomo.mojo` (subcommands with hybrid tree) (PR #41).
- Add 4 test modules: `test_wrappers.mojo` (wrapper defaults, copy/move, `Flag.__bool__`), `test_declarative.mojo` (to_command, parse_args, from_parse_result), `test_hybrid.mojo` (builder customisation, mutually exclusive, implies, configure pattern), `test_subcommands_declarative.mojo` (flat/nested subcommands, run() dispatch, dual return) (PR #38, #39).
- Add `test_interactive.mojo` for interactive prompting edge cases (PR #33).
- Add method matrix table to README, user manual, and planning doc.
- Update README with declarative API Quick Start, examples table, and project structure.
- Update user manual with declarative API usage guide, full-parse section, and API summary.

---

## 20260321 (v0.4.0)

ArgMojo v0.4.0 adds interactive prompting, password input, confirmation, argument parents, custom usage lines, response files, CJK-aware help formatting, and full-width auto-correction. The builder API is fully parameterised with compile-time `StringLiteral` parameters. The codebase is migrated to Mojo v0.26.2 and the test suite consolidated from 20 files into 8 modules.

ArgMojo v0.4.0 targets Mojo v0.26.2.

### ⭐️ New in v0.4.0

1. Add `.default_if_no_value["value"]()` — option appears without a value to use the fallback; with `=value` to override. For long options, implies `.require_equals()` (PR #12).
2. Add `.require_equals()` — long options reject space-separated values and require `--key=value` syntax. Help output adapts: `--key=<value>` for require-equals, `--key[=<value>]` for default-if-no-value (PR #12).
3. Add `response_file_prefix()` on `Command` for `@args.txt` expansion with comments, escaping, and recursive nesting. *(Temporarily disabled due to a Mojo compiler deadlock under `-D ASSERT=all`.)* (PR #12).
4. Add `.remainder()` on `Argument` — consume all remaining tokens (including dash-prefixed) as a single positional, similar to argparse `nargs=REMAINDER` (PR #13).
5. Add `parse_known_arguments()` on `Command` — unrecognised options are collected via `result.get_unknown_args()` instead of raising an error (PR #13).
6. Add `.allow_hyphen_values()` on `Argument` — accept tokens starting with `-` as values without requiring `--` first; covers the stdin `-` convention (PR #13).
7. CJK-aware help alignment using terminal display width; CJK characters treated as 2-column-wide. No API changes — automatic (PR #14).
8. Full-width → half-width auto-correction with a coloured warning when CJK users type fullwidth ASCII (e.g., `－－ｖｅｒｂｏｓｅ` → `--verbose`). Disabled via `disable_fullwidth_correction()` (PR #15).
9. CJK punctuation auto-correction — em-dash `——verbose` corrected to `--verbose`. Disabled via `disable_punctuation_correction()` (PR #16).
10. Add `.group["name"]()` on `Argument` — group arguments under dedicated headings in `--help` output (PR #17).
11. Value-name wrapping control: `.value_name["NAME"]()` renders as `<NAME>` by default; `.value_name["NAME", False]()` renders bare (PR #17).
12. Add runtime `generate_completion("shell")` overload alongside the existing compile-time `generate_completion["shell"]()` (PR #19).
13. Registration-time validation for `mutually_exclusive()`, `required_together()`, `one_required()`, and `required_if()` — catches typos, empty lists, and self-referential rules immediately at `add_argument()` time (PR #22).
14. Add `.prompt()` / `.prompt["text"]()` on `Argument` — interactively prompt for missing values before validation. Shows choices and defaults; handles non-interactive stdin gracefully (PR #23).
15. Add `add_parent(parent)` on `Command` — share argument definitions and group constraints across commands, equivalent to argparse `parents` (PR #25).
16. Add `confirmation_option()` on `Command` — register `--yes`/`-y` and prompt for confirmation after parsing; `--yes` skips the prompt (PR #26).
17. Add `usage(text)` on `Command` — replace the auto-generated usage line with a custom string (PR #27).
18. Add `.password()` on `Argument` — hide typed input via POSIX `tcsetattr(3)` during prompts, equivalent to Click `hide_input=True` (PR #28).

### 🔄 Mojo v0.26.2 migration (PR #29)

- Bump Mojo dependency to `==0.26.2` in `pixi.toml`.
- Migrate stdlib imports to `std.*` namespace (`from sys` → `from std.sys`, etc.).
- Replace `constrained[]` with `comptime assert` and `@parameter if` with `comptime if`.
- Unify `__copyinit__`/`__moveinit__` to new `__init__(out self, *, copy/take: Self)` forms.
- Remove `Stringable` from trait lists (removed from stdlib).
- Add `byte=` keyword to all string slicing operations.
- Replace `fn` with `def` across all 30 files (754 declarations).
- Remove `__str__` methods; consolidate string output into `write_to` (Mojo v0.26.2 convention).

### 🦋 Changed in v0.4.0

1. Rename `.metavar()` to `.value_name()` across the entire API (PR #13).
2. Parameterise `.long[]()` and `.short[]()` as compile-time `StringLiteral` parameters (PR #20).
3. Parameterise `.alias_name[]()`, `.delimiter[]()`, `.default[]()`, `.deprecated[]()`, `.default_if_no_value[]()`, `.group[]()`, `.prompt[]()`, and colour setters (`header_color[]`, `argument_color[]`, `warn_color[]`, `error_color[]`) as compile-time parameters (PR #18, #21).
4. Replace `.choices(list)` with chained `.choice["a"]().choice["b"]()` compile-time parameters (PR #18).
5. Value-name display uses angle brackets by default; `.value_name["FOO", False]()` for bare display (PR #17).
6. Move `print_summary()` from `Command` to `ParseResult` (PR #24).

### 🔧 Fixes in v0.4.0

- Clarify that `default_if_no_value` does not "reject" `--key value` — it simply does not consume the next token (PR #12).
- Fix Click description: "Python CLI framework", not "built on top of argparse" (PR #12).
- Reject `.require_equals()` / `.default_if_no_value()` combined with `.number_of_values[N]()` at `add_argument()` time (PR #12).

### 📚 Documentation and testing in v0.4.0

- Consolidate test suite from 20 files into 8 focused modules (PR #30).
- Add Developer Validation section to user manual with two-layer validation model (compile-time + registration-time) (PR #22).
- Add `pixi run debug` task for `-D ASSERT=all` regression testing (PR #22).

---

## 20260305 (v0.3.0)

ArgMojo v0.3.0 adds shell completion, typo suggestions, mutual implication, hidden subcommands, `NO_COLOR` support, and several builder-method improvements. Internally the code is decomposed into smaller helpers and a new `utils.mojo` module; several API names are refined for consistency. Two breaking changes affect call sites that use `nargs`, `max`, or `range` (now compile-time parameters) and the renamed methods listed below.

ArgMojo v0.3.0 is compatible with Mojo v0.26.1.

### ⭐️ New in v0.3.0

1. Implement shell completion script generation for Bash, Zsh, and Fish, with a built-in `--completions <shell>` flag that emits a ready-to-source script (PR #4).
2. Allow disabling the built-in flag (`disable_default_completions()`), customising the trigger name (`completions_name()`), or exposing completions as a subcommand (`completions_as_subcommand()`) (PR #4).
3. Add Levenshtein-distance based "did you mean ...?" suggestions for misspelled long options and subcommand names (PR #3).
4. Implement `command_aliases()` on `Command` to register alternative names for subcommands. Aliases are shown in help, accepted during dispatch, and included in shell completions and typo suggestions (PR #5).
5. Add `.clamp()` modifier for `.range[min, max]()` -- out-of-range values are adjusted to the nearest boundary with a warning instead of a hard error (PR #6).
6. Move count-ceiling enforcement (`.max[N]()`) and range validation into the `_validate()` phase so all post-parse checks run in a single pass (PR #6).
7. Parameterise `.max[ceiling]()`, `.range[min, max]()`, and `.number_of_values[N]()` as compile-time parameters, enabling build-time validation of invalid values (PR #8).
8. Add `Command.hidden()` builder method. Hidden subcommands are excluded from help output, shell completions, "Available commands" error messages, and typo suggestions, while remaining dispatchable by exact name or alias (PR #9).
9. Honour the `NO_COLOR` environment variable (any value, including empty). When set, all ANSI colour output from help, warning, and error messages is suppressed, following the no-color.org standard (PR #9).
10. Add `Command.implies(trigger, implied)` to automatically set one argument when another is present. Supports chained implications (A -> B -> C) with cycle detection at registration time. Works with flags and count arguments, and integrates with existing constraints (`required_if`, `mutually_exclusive`) (PR #10).

### 🦋 Changed in v0.3.0

1. `parse_args()` renamed to `parse_arguments()` (PR #5).
2. `help_on_no_args()` renamed to `help_on_no_arguments()` (PR #5).
3. `.nargs()` renamed to `.number_of_values()` and `nargs_count` field renamed to `_number_of_values` (PR #5).
4. Several `Argument` and `ParseResult` attributes are now underscore-prefixed (private). Public builder methods are unchanged (PR #7).
5. Decompose `parse_args()` into four sub-methods: `_parse_long_option()`, `_parse_short_single()`, `_parse_short_merged()`, `_dispatch_subcommand()` (PR #2).
6. Decompose `_generate_help()` into five sub-methods: `_help_usage_line()`, `_help_positionals_section()`, `_help_options_section()`, `_help_commands_section()`, `_help_tips_section()` (PR #2).
7. Extract ANSI colour constants and utility functions into a new internal module `utils.mojo` (PR #2).
8. Rename example files to avoid confusion: `git.mojo` -> `mgit.mojo`, `grep.mojo` -> `mgrep.mojo`.
9. Add `examples/demo.mojo` -- a comprehensive showcase of all ArgMojo features in a single CLI (PR #7).

### 📚 Documentation and testing in v0.3.0

- Add `tests/test_typo_suggestions.mojo` covering Levenshtein-based suggestions (PR #3).
- Add `tests/test_completion.mojo` with comprehensive tests for Bash, Zsh, and Fish script generation (PR #4).
- Add `tests/test_implies.mojo` covering basic, chained, and multi-target implications, cycle detection, and constraint integration (PR #10).
- Add builder method compatibility section to the user manual with an ASCII tree, Mermaid diagram, and compatibility table (PR #11).
- Set up GitHub Actions workflow for automatic wiki synchronisation from `docs/user_manual.md`.
- Update user manual to cover all new features.

---

## 20260228 (v0.2.0)

ArgMojo v0.2.0 is a major release that transforms the library from a single-command parser into a full subcommand-capable CLI framework. It introduces hierarchical subcommands with automatic dispatch, persistent (global) flags with bidirectional sync, negative number passthrough, colored error messages, custom tips, and significant help/UX improvements. The public API is also refined: `Arg` -> `Argument`, `Result` -> `ParseResult` (old names kept as aliases). Two complete example CLIs (`mgrep` and `mgit`) replace the previous demo.

ArgMojo v0.2.0 is compatible with Mojo v0.26.1.

### ⭐️ New in v0.2.0

1. Implement full subcommand support with `add_subcommand()` API, hierarchical dispatch, and nested subcommands (e.g., `git remote add`).
2. Auto-register a `help` subcommand so that `app help <command>` works out of the box; opt out with `disable_help_subcommand()`.
3. Add `allow_positional_with_subcommands()` guard -- prevents accidental mixing of positional args and subcommands on the same `Command`, following the cobra/clap convention. Requires explicit opt-in.
4. Add `subcommand` and `subcommand_result` fields on `ParseResult` with `has_subcommand_result()` / `get_subcommand_result()` accessors.
5. Add `command_aliases()` builder method for subcommand short names (e.g., `clone` -> `cl`). Aliases dispatch to the canonical subcommand, appear in help output, shell completions, and typo suggestions.
6. Add `.persistent()` builder method on `Argument` to mark a flag as global.
7. Persistent args are automatically injected into child commands and support bidirectional sync: flags set before the subcommand push down to the child, and flags set after the subcommand bubble up to the root.
8. Detect conflicting long/short names between parent persistent args and child local args at registration time (`add_subcommand()` raises an error).
9. Recognize negative numeric tokens like `-3.14` or `-42` as positional values instead of unknown short options. Add `allow_negative_numbers()` opt-in on `Command` for explicit control.
10. Add `add_tip()` API on `Command` to attach user-defined tips that render as a dedicated section at the bottom of help output.
11. Colored error and warning messages -- ANSI-styled stderr output for all parse errors.
12. Unknown subcommand error now lists all available commands.
13. Errors inside child parse are prefixed with the full command path (e.g., `git remote add: ...`).

### 🦋 Changed in v0.2.0

1. Rename `Arg` struct to `Argument` and `Result` struct to `ParseResult`. The old names are kept as aliases for backward compatibility.
2. Rename source files: `arg.mojo` -> `argument.mojo`, `result.mojo` -> `parse_result.mojo`.
3. Add a "Commands" section to help output listing available subcommands with aligned descriptions.
4. Show `<COMMAND>` placeholder in the usage line for commands that have subcommands.
5. Display persistent flags under a "Global Options" heading in child help.
6. Show the full command path in child help and error messages (e.g., `Usage: git remote add [OPTIONS] NAME URL`).
7. Extract `_apply_defaults()` and `_validate()` into private helper methods on `Command`, enabling clean reuse for both root and child parsing.

### 📚 Documentation and testing in v0.2.0

- Add two complete example CLIs: `examples/mgrep.mojo` (single-command, demonstrating all argument features) and `examples/mgit.mojo` (subcommand-based, with nested subcommands and persistent flags).
- Add `tests/test_subcommands.mojo` covering data model, dispatch, help subcommand, persistent flags, allow-positional guard, and error handling.
- Add `tests/test_negative_numbers.mojo`.
- Add `tests/test_persistent.mojo`.
- Update user manual (`docs/user_manual.md`) to cover all new features.

---

## 20260226 (v0.1.0)

ArgMojo v0.1.0 is the initial release, providing a builder-pattern API for defining and parsing command-line arguments in Mojo. It covers all commonly-used features from `argparse`, `clap`, and `cobra` for single-command CLI applications.

ArgMojo v0.1.0 is compatible with Mojo v0.26.1.

### ⭐️ New in v0.1.0

1. Long options (`--verbose`, `--output file.txt`, `--output=file.txt`) and short options (`-v`, `-o file.txt`).
2. Boolean flags that take no value.
3. Positional arguments matched by position, with optional default values.
4. Required argument validation.
5. `--` stop marker -- everything after `--` is treated as positional.
6. Short flag merging -- `-abc` expands to `-a -b -c`.
7. Attached short values -- `-ofile.txt` means `-o file.txt`.
8. Count flags -- `-vvv` -> `get_count("verbose") == 3`.
9. Positional argument count validation -- reject extra positional args.
10. Choices validation -- restrict values to a set (e.g., `json`, `csv`, `table`).
11. Negatable flags -- `--color` / `--no-color` paired flags with `.negatable()`.
12. Long option prefix matching -- `--verb` auto-resolves to `--verbose` when unambiguous.
13. Conditional requirements -- `--output` required only when `--save` is present.
14. Numeric range validation -- `.range[1, 65535]()` validates value is within bounds.
15. Mutually exclusive groups -- prevent conflicting flags (e.g., `--json` vs `--yaml`).
16. Required-together groups -- enforce that related flags are provided together (e.g., `--username` + `--password`).
17. One-required groups -- require at least one argument from a group.
18. Append / collect action -- `--tag x --tag y` collects repeated options into a list with `.append()`.
19. Value delimiter -- `--env dev,staging,prod` splits by delimiter into a list with `.delimiter[","]()`.
20. Multi-value options (nargs) -- `--point 10 20` consumes N consecutive values with `.number_of_values[N]()`.
21. Key-value map option -- `--define key=value` builds a `Dict` with `.map_option()`.
22. Auto-generated help with `--help` / `-h` / `-?`, dynamic column alignment, pixi-style ANSI colours, and customisable header/arg colours.
23. Help on no args -- optionally show help when invoked with no arguments.
24. Version display with `--version` / `-V`.
25. Metavar -- custom display name for values in help text.
26. Hidden arguments -- exclude internal args from help output.
27. Aliases for long names -- `.alias_name["color"]()` for `--colour` / `--color`.
28. Deprecated arguments -- `.deprecated["Use --format instead"]()` prints warning to stderr.
