# Parsing Algorithm

This document describes how `Command.parse_arguments` and
`Command.parse_known_arguments` turn a raw `argv` token list into a
`ParseResult`. It complements the source code in
[src/argmojo/command.mojo](../src/argmojo/command.mojo) and is intended to
help contributors reason about correctness, identify edge cases, and add
tests with confidence.

The two public entry points share the same lexing/dispatch loop
(`_run_parse_loop`); they differ only in (a) which post-parse phases they
run and (b) how they treat unrecognised options.

---

## 1. High-level outline

```text
parse_arguments(raw_tokens)
└── 1. Initialise ParseResult; copy raw_tokens.
    2. (Optional) Expand response files (currently disabled — see comment).
    3. PARSING PHASE → _run_parse_loop(tokens, result, collect_unknown=False)
       ├── CJK auto-correction (fullwidth → ASCII).
       ├── Register positional argument names in declaration order.
       ├── help_on_no_arguments fast-path: print help and exit if argv has only
       │   the program name.
       ├── Cache the index of the remainder positional slot (if any).
       └── Iterate from argv[1]:
           ├── "--" stop marker enters positional-only mode.
           ├── --help / -h / -? prints help and exits.
           ├── --version / -V prints version and exits.
           ├── Built-in --<completions_name> <shell> (long form).
           ├── allow_hyphen_values fast-path.
           ├── Long option (--key, --key=value, --no-key) → _parse_long_option.
           │   (Note: `--no-<flag>` negation is only recognised without `=`;
           │    `--no-flag=value` is treated as a regular long option named
           │    `no-flag` and will raise / be collected as unknown unless
           │    such an option is actually registered.)
           ├── Short option (-k, -k value, -abc, -ofile) → _parse_short_*.
           ├── Built-in <completions_name> <shell> (subcommand form).
           ├── Subcommand dispatch.
           └── Otherwise: bare positional argument.
    4. POST-PARSE PHASE
       ├── _apply_defaults
       ├── _apply_implications
       ├── _prompt_missing_arguments
       ├── _apply_implications  (re-applied; prompts may have triggered new ones)
       ├── _confirm
       └── _validate
    5. Return ParseResult.

parse_known_arguments(raw_tokens)
└── Same as above except:
    • _run_parse_loop(..., collect_unknown=True)
    • POST-PARSE PHASE: _apply_defaults → _apply_implications → _validate
      (no prompt, no confirm; callers typically forward unknowns to a
      downstream tool and should not be interrupted by interactive prompts).
```

---

## 2. Granular outline of `_run_parse_loop`

Every iteration classifies the current token by the *first* rule below
that matches; the rule then either updates the cursor `i` and
`continue`s, or falls through to the next rule. Errors listed under each
branch are raised either directly inside the loop or by the helpers it
calls. Downstream validation (`_validate`) raises additional errors
during the post-parse phase — see Section 3.

```text
_run_parse_loop(tokens, result, collect_unknown)
├── 0. Pre-loop setup
│   ├── _preprocess_cjk_arguments(tokens)             # fullwidth → ASCII
│   ├── Register positional names                     # → result._positional_names
│   ├── if help_on_no_arguments and len(tokens) <= 1:
│   │   └── print _generate_help() → exit(0)
│   └── remainder_pos_idx ← _find_remainder_slot()    # -1 if none
│
└── while i < len(tokens):                            # rules tested top-down; first match wins
    │
    ├── 2.1.1  token == "--"
    │   └── stop_parsing_options = True; i += 1
    │
    ├── 2.1.2  stop_parsing_options is True
    │   └── result._positionals.append(token); i += 1
    │
    ├── 2.1.3  remainder mode (next positional slot ≥ remainder_pos_idx)
    │   └── result._positionals.append(token); i += 1     # leading '-' preserved
    │
    ├── 2.1.4  token in {"--help", "-h", "-?"}
    │   └── print _generate_help() → exit(0)
    │
    ├── 2.1.5  token in {"--version", "-V"}
    │   └── print "<name> <version>" → exit(0)
    │
    ├── 2.1.6  completions long-form  (token == "--" + _completions_name)
    │   ├── if next token exists:
    │   │   └── print generate_completion(shell) → exit(0)
    │   └── else:
    │       └── _error("--<name> requires a shell name: bash, zsh, or fish") → exit(2)
    │
    ├── 2.1.7  allow_hyphen_values fast-path
    │   │     condition: token startswith "-", len > 1,
    │   │                next positional slot has .allow_hyphen_values(),
    │   │                and not _is_known_option(token)
    │   └── result._positionals.append(token); i += 1
    │
    ├── 2.1.8  token startswith "--"  (long option)
    │   │   note: `--no-<flag>` is recognised as the negation form only
    │   │         when there is no `=` in the token; `--no-flag=value`
    │   │         is parsed as a regular long option named `no-flag`
    │   │         (and will raise / be collected as unknown if no such
    │   │         option is registered).
    │   ├── if collect_unknown and not _is_known_option(token):
    │   │   └── result._unknown_arguments.append(token); i += 1
    │   └── else:
    │       └── i = _parse_long_option(tokens, i, result)
    │           ├── raises:
    │           │   ├── Unknown option '<name>'                                 [parse_arguments only]
    │           │   ├── Ambiguous option '<prefix>' could match: '<a>', '<b>', ...
    │           │   ├── Option '<name>' requires a value
    │           │   ├── Option '<name>' requires N values
    │           │   ├── Option '<name>' takes N values; '=' syntax is not supported
    │           │   ├── Option '<name>' requires '=' syntax (use --opt=VALUE)
    │           │   ├── Invalid value '<v>' for argument '<name>' (choose from ...)
    │           │   ├── Value <n> for '<name>' is out of range [a, b]
    │           │   └── Invalid key=value format '<v>' for '<name>'
    │           └── warns to stderr:
    │               ├── '<name>' is deprecated
    │               └── '<name>' count <n> exceeds maximum <m>, capped to <m>
    │
    ├── 2.1.9  token startswith "-" and len > 1  (short option)
    │   ├── if _looks_like_number(token) and (allow_negative_numbers or no digit-short):
    │   │   └── result._positionals.append(token); i += 1               # negative number
    │   ├── elif allow_negative_expressions and not _is_known_option(token):
    │   │   └── result._positionals.append(token); i += 1               # negative expression
    │   ├── elif collect_unknown and not _is_known_option(token):
    │   │   └── result._unknown_arguments.append(token); i += 1
    │   └── else:
    │       ├── if len(token[1:]) == 1:
    │       │   └── i = _parse_short_single(tokens, i, result)
    │       └── else:
    │           └── i = _parse_short_merged(tokens, i, result)          # -abc / -ofile.txt
    │           ↳ raises / warns: same family as 2.1.8, plus
    │             ├── Unknown option '-<c>'
    │             └── Option '-<c>' requires a value
    │
    ├── 2.1.10  completions subcommand-form  (token == _completions_name)
    │   └── same as 2.1.6 but with "<name>" instead of "--<name>"
    │
    ├── 2.1.11  len(self.subcommands) > 0
    │   ├── new_i = _dispatch_subcommand(token, tokens, i, result)
    │   │   ↳ may raise:
    │   │     ├── No matching subcommand for '<path>'
    │   │     └── any error raised by the child command's parse_arguments
    │   ├── if new_i >= 0:
    │   │   └── i = new_i; continue                     # child consumed remainder
    │   └── else:
    │       └── fall through to 2.1.12
    │
    └── 2.1.12  fallthrough  (bare positional)
        └── result._positionals.append(token); i += 1
```

`parse_known_arguments` differs from `parse_arguments` only by setting
`collect_unknown = True`. The `_is_known_option(token)` pre-check in
2.1.8 / 2.1.9 ensures that:

- *Unknown* options are silently routed to `result._unknown_arguments`.
- *Known* but malformed options (missing required value, invalid choice,
  ambiguous prefix, ...) still raise and propagate to the caller.

---

## 3. Post-parse phases

```text
post_parse(result)
├── _apply_defaults(result)                  # both entry points
├── _apply_implications(result)              # both entry points
├── _prompt_missing_arguments(result)        # parse_arguments only
│   └── may raise on I/O errors
├── _apply_implications(result)              # parse_arguments only (re-run)
├── _confirm(result)                         # parse_arguments only
│   └── may raise on user denial / I/O
└── _validate(result)                        # both entry points
    └── raises:
        ├── Required argument '<name>' was not provided
        ├── Too many positional arguments: expected N, got M
        ├── Arguments are mutually exclusive: '<a>', '<b>'
        ├── Arguments required together: '<a>', '<b>'
        ├── At least one of the following arguments is required: '<a>', '<b>', ...
        ├── Argument '<x>' is required when '<y>' is provided
        └── Value <n> for '<name>' is out of range [a, b]
```

`parse_known_arguments` skips prompts and confirmation because callers
that forward unknown options to a downstream tool should not be
interrupted by interactive UI.

---

## 4. Invariants and design notes

1. **`self` is read-only during parsing.** The `Command` is not
   mutated; all per-invocation state lives in the `ParseResult`. This
   makes repeated parses (tests, REPLs, completion) safe.
2. **`_is_known_option` must mirror `_parse_long_option`'s resolution
   rules.** This includes `--no-<flag>` exact and prefix matches against
   *negatable* long names, but **only when the token has no `=`** —
   `--no-flag=value` is not negation and must be classified the same
   way `_parse_long_option` would (i.e. as the long option `no-flag`).
   Whenever the long-option resolver gains a new way to recognise a
   token, `_is_known_option` needs the corresponding update or the
   `allow_hyphen_values` fast-path (2.1.7) and the
   `parse_known_arguments` unknown-collection logic (2.1.8 / 2.1.9)
   will silently misclassify tokens.
3. **`collect_unknown` only diverts unrecognised options.** Real parse
   errors on *known* options always propagate — the
   `parse_known_arguments` docstring promises exactly this and it is
   enforced by the `_is_known_option` pre-check rather than by
   exception swallowing.
4. **Rule order in the cursor loop is significant.** `--` must be
   recognised before option parsing, the remainder fast-path must
   precede option parsing, and `allow_hyphen_values` must precede the
   short/long branches. Re-ordering rules without care can change
   user-visible behaviour.
5. **Negative numbers vs digit short options.** A registered short
   option whose name is a digit (e.g. `-1`) suppresses the
   negative-number fast-path unless `allow_negative_numbers()` is
   explicitly set.
6. **Subcommand recursion.** When a subcommand is dispatched, the child
   parses the remainder of the argv with its own `parse_arguments`;
   the parent loop then exits via the `>= 0` return from
   `_dispatch_subcommand`.

---

## 5. Where to look in the code

| Concern                             | Location                                                       |
| ----------------------------------- | -------------------------------------------------------------- |
| `parse_arguments` entry point       | [src/argmojo/command.mojo](../src/argmojo/command.mojo)        |
|                                     | — search for `def parse_arguments`                             |
| `parse_known_arguments` entry point | same file — search for `def parse_known_arguments`             |
| Shared dispatch loop                | same file — `_run_parse_loop`                                  |
| Long option parser                  | same file — `_parse_long_option`                               |
| Short option parsers                | same file — `_parse_short_single`, `_parse_short_merged`       |
| `--no-<flag>` recognition for       | same file — `_is_known_option`                                 |
| known-option detection              |                                                                |
| Storage helpers                     | same file — `_store_scalar_value`, `_increment_count`,         |
|                                     | `_consume_nargs`, `_find_remainder_slot`                       |
| Validation helpers                  | same file — `_apply_defaults`, `_apply_implications`,          |
|                                     | `_validate`, `_prompt_missing_arguments`, `_confirm`           |
| Test coverage                       | [tests/test_parse.mojo](../tests/test_parse.mojo),             |
|                                     | [tests/test_options.mojo](../tests/test_options.mojo),         |
|                                     | [tests/test_groups.mojo](../tests/test_groups.mojo),           |
|                                     | [tests/test_subcommands.mojo](../tests/test_subcommands.mojo), |
|                                     | [tests/test_help.mojo](../tests/test_help.mojo)                |
