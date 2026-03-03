# ArgMojo changelog

This document tracks all notable changes to ArgMojo, including new features, API changes, bug fixes, and documentation updates.

<!-->
Do not add unreleased changes here. This file will be edited just before each release to reflect the final changelog for that version.
<-->

## 20260228 (v0.2.0)

ArgMojo v0.2.0 is a major release that transforms the library from a single-command parser into a full **subcommand-capable CLI framework**. It introduces hierarchical subcommands with automatic dispatch, persistent (global) flags with bidirectional sync, negative number passthrough, colored error messages, custom tips, and significant help/UX improvements. The public API is also refined: `Arg` → `Argument`, `Result` → `ParseResult` (old names kept as aliases). Two complete example CLIs (`mgrep` and `mgit`) replace the previous demo.

ArgMojo v0.2.0 is compatible with Mojo v0.26.1.

### ⭐️ New in v0.2.0

**Subcommands:**

1. Implement full subcommand support with `add_subcommand()` API, hierarchical dispatch, and nested subcommands (e.g., `git remote add`).
1. Auto-register a `help` subcommand so that `app help <command>` works out of the box; opt out with `disable_help_subcommand()`.
1. Add `allow_positional_with_subcommands()` guard — prevents accidental mixing of positional args and subcommands on the same `Command`, following the cobra/clap convention. Requires explicit opt-in.
1. Add `subcommand` and `subcommand_result` fields on `ParseResult` with `has_subcommand_result()` / `get_subcommand_result()` accessors.
1. Add `command_aliases()` builder method for subcommand short names (e.g., `clone` → `cl`). Aliases dispatch to the canonical subcommand, appear in help output, shell completions, and typo suggestions.

**Persistent flags:**

1. Add `.persistent()` builder method on `Argument` to mark a flag as global.
1. Persistent args are automatically injected into child commands and support bidirectional sync: flags set before the subcommand push down to the child, and flags set after the subcommand bubble up to the root.
1. Detect conflicting long/short names between parent persistent args and child local args at registration time (`add_subcommand()` raises an error).

**Negative number passthrough:**

1. Recognize negative numeric tokens like `-3.14` or `-42` as positional values instead of unknown short options.
1. Add `allow_negative_numbers()` opt-in on `Command` for explicit control.

**Custom tips:**

1. Add `add_tip()` API on `Command` to attach user-defined tips that render as a dedicated section at the bottom of help output.

**Error handling:**

1. Colored error and warning messages — ANSI-styled stderr output for all parse errors.
1. Unknown subcommand error now lists all available commands.
1. Errors inside child parse are prefixed with the full command path (e.g., `git remote add: ...`).

### 🦋 Changed in v0.2.0

**API rename:**

1. Rename `Arg` struct to `Argument` and `Result` struct to `ParseResult`. The old names are kept as aliases for backward compatibility.
1. Rename source files: `arg.mojo` → `argument.mojo`, `result.mojo` → `parse_result.mojo`.

**Help & UX improvements:**

1. Add a "Commands" section to help output listing available subcommands with aligned descriptions.
1. Show `<COMMAND>` placeholder in the usage line for commands that have subcommands.
1. Display persistent flags under a "Global Options" heading in child help.
1. Show the full command path in child help and error messages (e.g., `Usage: git remote add [OPTIONS] NAME URL`).

**Internal refactoring:**

1. Extract `_apply_defaults()` and `_validate()` into private helper methods on `Command`, enabling clean reuse for both root and child parsing.

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

**Core parsing:**

1. Long options (`--verbose`, `--output file.txt`, `--output=file.txt`) and short options (`-v`, `-o file.txt`).
1. Boolean flags that take no value.
1. Positional arguments matched by position, with optional default values.
1. Required argument validation.
1. `--` stop marker — everything after `--` is treated as positional.
1. Short flag merging — `-abc` expands to `-a -b -c`.
1. Attached short values — `-ofile.txt` means `-o file.txt`.
1. Count flags — `-vvv` → `get_count("verbose") == 3`.
1. Positional argument count validation — reject extra positional args.

**Choices & validation:**

1. Choices validation — restrict values to a set (e.g., `json`, `csv`, `table`).
1. Negatable flags — `--color` / `--no-color` paired flags with `.negatable()`.
1. Long option prefix matching — `--verb` auto-resolves to `--verbose` when unambiguous.
1. Conditional requirements — `--output` required only when `--save` is present.
1. Numeric range validation — `.range(1, 65535)` validates value is within bounds.

**Groups:**

1. Mutually exclusive groups — prevent conflicting flags (e.g., `--json` vs `--yaml`).
1. Required-together groups — enforce that related flags are provided together (e.g., `--username` + `--password`).
1. One-required groups — require at least one argument from a group.

**Collection:**

1. Append / collect action — `--tag x --tag y` collects repeated options into a list with `.append()`.
1. Value delimiter — `--env dev,staging,prod` splits by delimiter into a list with `.delimiter(",")`.
1. Multi-value options (nargs) — `--point 10 20` consumes N consecutive values with `.number_of_values(N)`.
1. Key-value map option — `--define key=value` builds a `Dict` with `.key_value()`.

**Help & display:**

1. Auto-generated help with `--help` / `-h` / `-?`, dynamic column alignment, pixi-style ANSI colours, and customisable header/arg colours.
1. Help on no args — optionally show help when invoked with no arguments.
1. Version display with `--version` / `-V`.
1. Metavar — custom display name for values in help text.
1. Hidden arguments — exclude internal args from help output.

**Other:**

1. Aliases for long names — `.aliases(["color"])` for `--colour` / `--color`.
1. Deprecated arguments — `.deprecated("Use --format instead")` prints warning to stderr.
