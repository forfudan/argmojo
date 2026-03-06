# ArgMojo changelog

This document tracks all notable changes to ArgMojo, including new features, API changes, bug fixes, and documentation updates.

<!--
Comment out unreleased changes here. This file will be edited just before each release to reflect the final changelog for that version.
-->

## Unreleased

### ⭐️ New features

1. Add `.default_if_no_value("value")` builder method for default-if-no-value semantics. When an option has a default-if-no-value, it may appear without an explicit value: `--compress` uses the default-if-no-value, while `--compress=bzip2` uses the explicit value. For long options, `.default_if_no_value()` implies `.require_equals()`. For short options, `-c` uses the default-if-no-value while `-cbzip2` uses the attached value (PR #12).
2. Add `.require_equals()` builder method. When set, long options reject space-separated syntax (`--key value`) and require `--key=value`. Can be used standalone (the value is mandatory via `=`) or combined with `.default_if_no_value()` (the value is optional; omitting it uses default-if-no-value) (PR #12).
3. Help output adapts to the new modifiers: `--key=<value>` for require_equals, `--key[=<value>]` for default_if_no_value (PR #12).
4. ~~Add `response_file_prefix()` builder method on `Command` for response-file support. When enabled, tokens starting with the prefix (default `@`) are expanded by reading the referenced file — each non-empty, non-comment line becomes a separate argument. Supports comments (`#`), escape (`@@literal`), recursive nesting (configurable depth), and custom prefix characters (PR #12).~~ *(Temporarily disabled — triggers a Mojo compiler deadlock under `-D ASSERT=all`. The implementation is preserved as module-level functions and will be re-enabled when the Mojo compiler bug is fixed.)*

### 🔧 Fixes

- Clarify documentation and docstrings: `default_if_no_value` does not "reject" `--key value`; it simply does not consume the next token as a value (PR #12, review feedback).
- Fix cross-library comparison: click is described as "Python CLI framework" instead of incorrectly saying "built on top of argparse" (PR #12, review feedback).
- Reject `.require_equals()` / `.default_if_no_value()` combined with `.number_of_values[N]()` at `add_argument()` time with a clear error (PR #12, review feedback).

### 📚 Documentation and testing

- Add `tests/test_const_require_equals.mojo` with 30 tests covering default_if_no_value, require_equals, and their interactions with choices, append, prefix matching, merged short flags, persistent flags, and help formatting (PR #12).
- Add `tests/test_response_file.mojo` with 17 tests covering basic expansion, comments, whitespace stripping, escape, recursive nesting, depth limit, custom prefix, disabled-by-default, and error handling (PR #12).

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
19. Value delimiter -- `--env dev,staging,prod` splits by delimiter into a list with `.delimiter(",")`.
20. Multi-value options (nargs) -- `--point 10 20` consumes N consecutive values with `.number_of_values[N]()`.
21. Key-value map option -- `--define key=value` builds a `Dict` with `.map_option()`.
22. Auto-generated help with `--help` / `-h` / `-?`, dynamic column alignment, pixi-style ANSI colours, and customisable header/arg colours.
23. Help on no args -- optionally show help when invoked with no arguments.
24. Version display with `--version` / `-V`.
25. Metavar -- custom display name for values in help text.
26. Hidden arguments -- exclude internal args from help output.
27. Aliases for long names -- `.aliases(["color"])` for `--colour` / `--color`.
28. Deprecated arguments -- `.deprecated("Use --format instead")` prints warning to stderr.
