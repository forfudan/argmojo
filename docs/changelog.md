# ArgMojo changelog

This document tracks all notable changes to ArgMojo, including new features, API changes, bug fixes, and documentation updates.

<!--
Comment out unreleased changes here. This file will be edited just before each release to reflect the final changelog for that version.
-->

## Unreleased (v0.4.0)

### ⭐️ New features in v0.4.0

1. Add `.default_if_no_value["value"]()` builder method for default-if-no-value semantics. When an option has a default-if-no-value, it may appear without an explicit value: `--compress` uses the default-if-no-value, while `--compress=bzip2` uses the explicit value. For long options, `.default_if_no_value()` implies `.require_equals()`. For short options, `-c` uses the default-if-no-value while `-cbzip2` uses the attached value (PR #12).
2. Add `.require_equals()` builder method. When set, long options reject space-separated syntax (`--key value`) and require `--key=value`. Can be used standalone (the value is mandatory via `=`) or combined with `.default_if_no_value()` (the value is optional; omitting it uses default-if-no-value) (PR #12).
3. Help output adapts to the new modifiers: `--key=<value>` for require_equals, `--key[=<value>]` for default_if_no_value (PR #12).
4. ~~Add `response_file_prefix()` builder method on `Command` for response-file support. When enabled, tokens starting with the prefix (default `@`) are expanded by reading the referenced file — each non-empty, non-comment line becomes a separate argument. Supports comments (`#`), escape (`@@literal`), recursive nesting (configurable depth), and custom prefix characters (PR #12).~~ *(Temporarily disabled — triggers a Mojo compiler deadlock under `-D ASSERT=all`. The implementation is preserved as module-level functions and will be re-enabled when the Mojo compiler bug is fixed.)*
5. Add `.remainder()` builder method on `Argument`. A remainder positional consumes **all** remaining tokens (including ones starting with `-`), similar to argparse `nargs=REMAINDER` or clap `trailing_var_arg`. At most one remainder positional is allowed per command and it must be the last positional (PR #13).
6. Add `parse_known_arguments()` method on `Command`. Like `parse_arguments()`, but unrecognised options are collected into the result instead of raising an error. Access them via `result.get_unknown_args()`. Useful for forwarding unknown flags to another program (PR #13).
7. Add `.allow_hyphen_values()` builder method on `Argument`. When set on a positional, values starting with `-` are accepted without requiring `--` (e.g., `-` for stdin). Remainder positionals have this enabled automatically (PR #13).
8. **CJK-aware help alignment.** Help output now computes column padding using terminal display width instead of byte length. CJK ideographs and fullwidth characters are correctly treated as 2-column-wide, so help descriptions stay aligned when option names, positional names, or subcommand names contain Chinese, Japanese, or Korean characters. ANSI escape sequences are skipped during width calculation. No API changes — this is automatic (PR #14).
9. **Full-width → half-width auto-correction.** When CJK users forget to switch input methods and type fullwidth ASCII (e.g., `－－ｖｅｒｂｏｓｅ` instead of `--verbose`, or `＝` instead of `=`), ArgMojo auto-detects and corrects these characters with a coloured warning. Fullwidth spaces (`U+3000`) embedded in a token cause it to be split into multiple arguments. All tokens containing fullwidth ASCII are normalized; only option tokens (starting with `-` after correction) trigger a warning. Disabled via `disable_fullwidth_correction()` (PR #15).
10. **CJK punctuation auto-correction.** Common CJK punctuation outside the fullwidth ASCII range is also corrected — for example, em-dash (`——verbose`) is converted to `--verbose`. This runs as a separate pass after fullwidth correction. Disabled via `disable_punctuation_correction()` (PR #16).
11. **Argument groups in help.** Add `.group["name"]()` builder method on `Argument`. Arguments assigned to the same group are displayed under a dedicated heading in `--help` output, in first-appearance order. Ungrouped arguments remain under the default "Options:" heading. Persistent arguments are collected under "Global Options:" as before (PR #17).
12. **Value-name wrapping control.** Change `.value_name()` to accept compile-time parameters: `.value_name["NAME"]()` or `.value_name["NAME", False]()`. When `wrapped` is `True` (the default), the custom value name is displayed in angle brackets (`<NAME>`) in help output — matching the convention used by clap, cargo, pixi, and git. When `wrapped` is `False`, the value name is displayed bare (`NAME`). The auto-generated default placeholder (`<arg_name>`) is not affected (PR #17).
13. **Registration-time validation for group constraints.** `mutually_exclusive()`, `required_together()`, `one_required()`, and `required_if()` now validate argument names against `self.args` at the moment they are called. An `Error` is raised immediately if any name is unknown, empty lists are rejected, and duplicates are silently deduplicated. `required_if()` additionally rejects self-referential rules (`target == condition`). This catches developer typos on the very first `mojo run`, without waiting for end-user input (PR #22).
14. **Interactive prompting.** Add `.prompt()` and `.prompt["text"]()` builder methods on `Argument`. When an argument marked with `.prompt()` is not provided on the command line, the user is interactively prompted for its value before validation runs. Use `.prompt()` to prompt with the argument's help text, or `.prompt["Custom text"]()` to set a custom message. Works on both required and optional arguments. Prompts show valid choices for `.choice[]()` arguments and show default values in parentheses. For flag arguments, `y`/`n` input is accepted. When stdin is not a terminal (e.g., piped input, CI environments, `/dev/null`), or when `input()` otherwise raises, the exception is caught, prompting stops gracefully, and any values collected so far are preserved (PR #23).
15. **Argument parents.** Add `add_parent(parent)` method on `Command`. Copies all argument definitions and group constraints (mutually exclusive, required together, one-required, conditional requirements, implications) from a parent `Command` into the current command. This lets you share a common set of arguments across multiple commands without repeating them — equivalent to Python argparse's `parents` parameter. The parent is not modified. All registration-time validation guards run on each inherited argument as usual (PR #25).
16. **Confirmation option.** Add `confirmation_option()` and `confirmation_option["prompt"]()` builder methods on `Command`. When enabled, the command automatically registers a `--yes` / `-y` flag and prompts the user for confirmation after parsing (and after interactive prompting, if any). If the user does not confirm (`y`/`yes`), the command aborts with an error. Passing `--yes` or `-y` on the command line skips the prompt entirely. When stdin is not interactive (piped input, `/dev/null`), the command aborts gracefully. This is equivalent to Click's `confirmation_option` decorator (PR #26).
17. **Usage line customisation.** Add `usage(text)` method on `Command`. When set, the given text replaces the auto-generated `Usage: myapp [OPTIONS] ...` line in both `--help` output and error messages. This lets you write git-style usage strings like `git [-v | --version] [-h | --help] [-C <path>] <command> [<args>]`. When not set, the default auto-generated usage line is used.

### 🦋 Changed in v0.4.0

- **Rename `.metavar()` to `.value_name()`** across the entire API and documentation. The internal field is now `_value_name`. This follows clap's naming convention and better describes the purpose. There is no backward-compatible alias — all call sites must use `.value_name()` (PR #13).
- **Value-name display now uses angle brackets by default.** Custom value names set via `.value_name["FOO"]()` are now rendered as `<FOO>` in help output. To preserve the old behaviour (bare `FOO`), use `.value_name["FOO", False]()`. This only affects custom value names — the auto-generated placeholder was already wrapped in `<>` (PR #17).
- **Parameterise `.alias_name[]()` as a compile-time parameter.** Changed from `.aliases(["color"])` (runtime `List[String]`) to `.alias_name["color"]()` (compile-time `StringLiteral`). Alias names are validated at compile time (same rules as `.long[]`). For multiple aliases, chain calls: `.alias_name["out"]().alias_name["fmt"]()` (PR #18).
- **Parameterise `.delimiter[]()` as a compile-time parameter.** Changed from `.delimiter(",")` (runtime `String`) to `.delimiter[","]()` (compile-time `StringLiteral`). Only `,`, `;`, `:`, `|` are accepted; validated at compile time (PR #18).
- **Parameterise `.default[]()` as a compile-time parameter.** Changed from `.default("val")` (runtime `String`) to `.default["val"]()` (compile-time `StringLiteral`). No additional compile-time validation beyond the type change.
- **Parameterise `.deprecated[]()` as a compile-time parameter.** Changed from `.deprecated("msg")` (runtime `String`) to `.deprecated["msg"]()` (compile-time `StringLiteral`). Message must be non-empty (validated at compile time).
- **Parameterise `.default_if_no_value[]()` as a compile-time parameter.** Changed from `.default_if_no_value("val")` (runtime `String`) to `.default_if_no_value["val"]()` (compile-time `StringLiteral`). No additional compile-time validation beyond the type change.
- **Parameterise `.group[]()` as a compile-time parameter.** Changed from `.group("name")` (runtime `String`) to `.group["name"]()` (compile-time `StringLiteral`). Group name must be non-empty (validated at compile time).
- **Replace `.choices()` with chained `.choice[]()`.** Changed from `.choices(list^)` (runtime `List[String]`) to chained `.choice["a"]().choice["b"]()` (compile-time `StringLiteral`). Each choice value must be non-empty (validated at compile time). This uses the same singular-parameter + chaining pattern as `.alias_name[]()`, since Mojo's `StringLiteral` embeds its value in the type and variadic parameters require homogeneous types.

### 🔧 Fixes in v0.4.0

- Clarify documentation and docstrings: `default_if_no_value` does not "reject" `--key value`; it simply does not consume the next token as a value (PR #12, review feedback).
- Fix cross-library comparison: click is described as "Python CLI framework" instead of incorrectly saying "built on top of argparse" (PR #12, review feedback).
- Reject `.require_equals()` / `.default_if_no_value()` combined with `.number_of_values[N]()` at `add_argument()` time with a clear error (PR #12, review feedback).

### 🛡️ Validation improvements in v0.4.0

- **Compile-time `StringLiteral` parameters.** Builder methods that accept fixed, known values (`.long[]`, `.short[]`, `.choice[]`, `.default[]`, `.delimiter[]`, `.deprecated[]`, `.default_if_no_value[]`, `.group[]`, `.alias_name[]`, `.value_name[]`, `header_color[]`, `arg_color[]`, `warn_color[]`, `error_color[]`, `.max[]`, `.range[]`, `.number_of_values[]`, `response_file_max_depth[]`) now use compile-time `StringLiteral` or `Int` parameters. Invalid values are rejected by the compiler before a binary is produced (PR #18, and earlier PRs).
- **Registration-time name validation.** `mutually_exclusive()`, `required_together()`, `one_required()`, and `required_if()` now raise an `Error` immediately if any referenced argument name is not registered. Empty lists are rejected and duplicates are deduplicated. `required_if()` rejects self-referential rules. This matches the existing pattern in `implies()` (PR #22).

### 📚 Documentation and testing in v0.4.0

- Add `tests/test_const_require_equals.mojo` with 30 tests covering default_if_no_value, require_equals, and their interactions with choices, append, prefix matching, merged short flags, persistent flags, and help formatting (PR #12).
- Add `tests/test_response_file.mojo` with 17 tests covering basic expansion, comments, whitespace stripping, escape, recursive nesting, depth limit, custom prefix, disabled-by-default, and error handling (PR #12).
- Add `tests/test_remainder_known.mojo` with 18 tests covering remainder positionals, `parse_known_arguments()`, `allow_hyphen_values()`, and the `value_name` rename (PR #13).
- Add `tests/test_fullwidth.mojo` with 30 tests covering full-width → half-width auto-correction and CJK punctuation correction, including utility functions, fullwidth flags, equals syntax, embedded fullwidth spaces, opt-out, choices validation, merged short flags, subcommand dispatch, parse_known_arguments, and CJK punctuation em-dash correction (PR #15, #16).
- Add `tests/test_groups_help.mojo` with 25 tests covering argument groups in help output and value-name wrapping control, including basic grouping, multiple groups, independent padding, hidden arguments in groups, groups with subcommands, wrapped/unwrapped value names with append/nargs/require_equals/default_if_no_value, and coloured output (PR #17).
- Add 5 tests to `tests/test_groups.mojo` covering registration-time validation: unknown argument detection for `mutually_exclusive`, `required_together`, `one_required`, and `required_if` (both target and condition) (PR #22).
- Add Developer Validation section to user manual documenting the two-layer validation model (compile-time `StringLiteral` + runtime registration-time `raises`) with recommended workflow (PR #22).
- Add `pixi run debug` task that runs all examples under `-D ASSERT=all` with `--help` to exercise registration-time validation in CI (PR #22).
- Add `tests/test_prompt.mojo` with tests covering interactive prompting builder methods, optional/required prompt arguments, prompting skipped when values are provided, choices and defaults integration, field propagation through copy, and combined features (PR #23).
- Add `tests/test_parents.mojo` with 20 tests covering argument parents: basic flag/value/positional/default inheritance, short flags, multiple parents, child-own args coexistence, group constraint inheritance (mutually exclusive, required together, one-required, conditional, implications), parent shared across children, count/append/range argument inheritance, empty parent, parent immutability, and parent with subcommands (PR #25).
- Add `tests/test_confirmation.mojo` with 13 tests covering confirmation option: `--yes`/`-y` flag skips, non-interactive stdin abort, custom prompt text, coexistence with other arguments, no-confirmation normal behavior, subcommand integration, copy preservation, prompt argument integration, and parent argument integration (PR #26).

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
