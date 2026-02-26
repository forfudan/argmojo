"""Tests for persistent (global) flag inheritance in argmojo.

Covers:
  - Persistent flag works normally on the root command (no subcommands).
  - Persistent flag placed BEFORE the subcommand token:
      * root result has the value.
      * child result also gets the value (push-down sync).
  - Persistent flag placed AFTER the subcommand token:
      * child result has the value.
      * root result also gets the value (bubble-up sync).
  - Short-name persistent flags work in both positions.
  - Persistent value-taking options (not just flags) also work.
  - Non-persistent root flags are NOT injected into child parsers.
  - Conflict detection: add_subcommand() raises when a persistent arg on the
    parent shares a long_name or short_name with a local arg on the child.
  - No conflict is raised for non-persistent args with the same name.
  - Absent persistent flag defaults to False / raises as usual.
"""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult


# ── Persistent flag on root without any subcommand ─────────────────────────


fn test_persistent_flag_on_root_no_subcommand() raises:
    """A persistent flag still works as a plain root flag when no subcommand
    is involved."""
    var command = Command("app", "")
    command.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var r = command.parse_args(["app", "--verbose"])
    assert_true(r.get_flag("verbose"), msg="root verbose should be True")
    print("  ✓ test_persistent_flag_on_root_no_subcommand")


fn test_persistent_flag_absent_on_root() raises:
    """Absent persistent flag defaults to False on root."""
    var command = Command("app", "")
    command.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var r = command.parse_args(["app"])
    assert_false(r.get_flag("verbose"), msg="absent verbose should be False")
    print("  ✓ test_persistent_flag_absent_on_root")


# ── Persistent flag BEFORE the subcommand token ────────────────────────────


fn test_persistent_flag_before_subcommand_in_root_result() raises:
    """Persistent flag placed before the subcommand token is stored in the root
    result."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "--verbose", "search", "pattern"])
    assert_true(r.get_flag("verbose"), msg="root verbose should be True")
    assert_equal(r.subcommand, "search")
    print("  ✓ test_persistent_flag_before_subcommand_in_root_result")


fn test_persistent_flag_before_subcommand_pushed_to_child() raises:
    """Persistent flag placed before the subcommand token is pushed down into
    the child result so sub_result.get_flag() also works."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "--verbose", "search", "pattern"])
    var sub = r.get_subcommand_result()
    assert_true(
        sub.get_flag("verbose"),
        msg="child result should also have verbose=True via push-down",
    )
    print("  ✓ test_persistent_flag_before_subcommand_pushed_to_child")


# ── Persistent flag AFTER the subcommand token ─────────────────────────────


fn test_persistent_flag_after_subcommand_in_child_result() raises:
    """Persistent flag placed after the subcommand token is parsed by the child
    (injected) and stored in the child result."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "search", "--verbose", "pattern"])
    var sub = r.get_subcommand_result()
    assert_true(
        sub.get_flag("verbose"), msg="child result should have verbose=True"
    )
    print("  ✓ test_persistent_flag_after_subcommand_in_child_result")


fn test_persistent_flag_after_subcommand_bubbles_to_root() raises:
    """Persistent flag placed after the subcommand token is also bubbled up to
    the root result so root_result.get_flag() always works."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "search", "--verbose", "pattern"])
    assert_true(
        r.get_flag("verbose"),
        msg="root result should have verbose=True via bubble-up",
    )
    print("  ✓ test_persistent_flag_after_subcommand_bubbles_to_root")


fn test_persistent_short_flag_after_subcommand() raises:
    """The short form of a persistent flag also bubbles up from after-subcommand
    position."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "search", "-v", "pattern"])
    assert_true(
        r.get_flag("verbose"), msg="root verbose via short form should be True"
    )
    assert_true(
        r.get_subcommand_result().get_flag("verbose"),
        msg="child verbose via short form should be True",
    )
    print("  ✓ test_persistent_short_flag_after_subcommand")


# ── Persistent value-taking option ─────────────────────────────────────────


fn test_persistent_value_option_after_subcommand() raises:
    """A persistent value-taking option placed after the subcommand token is
    injected into the child, parsed, and synced both ways."""
    var app = Command("app", "")
    app.add_argument(
        Argument("output", help="").long("output").short("o").persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "search", "--output", "json", "pattern"])
    assert_equal(r.get_string("output"), "json")
    assert_equal(r.get_subcommand_result().get_string("output"), "json")
    print("  ✓ test_persistent_value_option_after_subcommand")


fn test_persistent_flag_absent_defaults_false_in_both() raises:
    """When a persistent flag is not provided at all, both root and child
    results return False."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var r = app.parse_args(["app", "search", "pattern"])
    assert_false(
        r.get_flag("verbose"), msg="root verbose should default to False"
    )
    assert_false(
        r.get_subcommand_result().get_flag("verbose"),
        msg="child verbose should default to False",
    )
    print("  ✓ test_persistent_flag_absent_defaults_false_in_both")


# ── Non-persistent flag isolation ──────────────────────────────────────────


fn test_non_persistent_root_flag_not_injected_into_child() raises:
    """A non-persistent root flag placed after the subcommand token is NOT
    recognised by the child and causes an unknown-option error."""
    var app = Command("app", "")
    app.add_argument(
        Argument("root-only", help="").long("root-only").flag()
    )  # NOT persistent
    var search = Command("search", "")
    search.add_argument(Argument("pattern", help="").positional().required())
    app.add_subcommand(search^)

    var raised = False
    try:
        _ = app.parse_args(["app", "search", "--root-only", "pattern"])
    except:
        raised = True
    assert_true(
        raised,
        msg="Non-persistent flag after subcommand should cause an error",
    )
    print("  ✓ test_non_persistent_root_flag_not_injected_into_child")


# ── Conflict detection ──────────────────────────────────────────────────────


fn test_persistent_conflict_long_name_raises() raises:
    """add_subcommand() raises when a persistent parent long_name conflicts
    with a child long_name."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="").long("verbose").flag().persistent()
    )
    var search = Command("search", "")
    search.add_argument(
        Argument("verbose", help="").long("verbose").flag()
    )  # same long name!

    var raised = False
    try:
        app.add_subcommand(search^)
    except:
        raised = True
    assert_true(
        raised,
        msg="Persistent long_name conflict should raise at add_subcommand time",
    )
    print("  ✓ test_persistent_conflict_long_name_raises")


fn test_persistent_conflict_short_name_raises() raises:
    """add_subcommand() raises when a persistent parent short_name conflicts
    with a child short_name."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "")
    search.add_argument(
        Argument("version", help="").long("ver").short("v").flag()
    )  # same short -v!

    var raised = False
    try:
        app.add_subcommand(search^)
    except:
        raised = True
    assert_true(
        raised,
        msg=(
            "Persistent short_name conflict should raise at add_subcommand time"
        ),
    )
    print("  ✓ test_persistent_conflict_short_name_raises")


fn test_no_conflict_for_non_persistent_same_name() raises:
    """No conflict is raised when a non-persistent root arg shares a name with
    a child arg (only persistent args are checked)."""
    var app = Command("app", "")
    app.add_argument(
        Argument("verbose", help="").long("verbose").short("v").flag()
    )  # NOT persistent
    var search = Command("search", "")
    search.add_argument(
        Argument("verbose", help="").long("verbose").flag()
    )  # same name, OK

    app.add_subcommand(search^)  # must not raise
    assert_true(
        True, msg="No conflict should be detected for non-persistent args"
    )
    print("  ✓ test_no_conflict_for_non_persistent_same_name")


# ── Main ───────────────────────────────────────────────────────────────────


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
