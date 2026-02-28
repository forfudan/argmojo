"""Tests for argmojo — typo suggestions (Levenshtein distance)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Long option typo suggestions ─────────────────────────────────────────────


fn test_typo_long_option_suggests() raises:
    """Tests that a typo like --verbos suggests --verbose."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(
        Argument("version", help="Show version").long("version").flag()
    )

    var args: List[String] = ["test", "--verbos"]
    # --verbos is a prefix match for --verbose, so it should resolve.
    # Use a more distant typo to test suggestion path.
    var args2: List[String] = ["test", "--vrebose"]
    var caught = False
    try:
        _ = command.parse_args(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Did you mean" in msg,
            msg="Error should suggest a correction",
        )
        assert_true(
            "verbose" in msg,
            msg="Error should suggest --verbose",
        )
    assert_true(caught, msg="Should have raised error for --vrebose")
    print("  ✓ test_typo_long_option_suggests")


fn test_typo_long_option_no_suggestion() raises:
    """Tests that a completely unrelated option doesn't produce a suggestion."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )

    var args: List[String] = ["test", "--zzzzzzz"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_false(
            "Did you mean" in msg,
            msg="Error should not suggest anything for unrelated option",
        )
    assert_true(caught, msg="Should have raised error for --zzzzzzz")
    print("  ✓ test_typo_long_option_no_suggestion")


fn test_typo_long_option_single_char_diff() raises:
    """Tests that a single character difference triggers a suggestion."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "--outptu", "file.txt"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Did you mean" in msg,
            msg="Error should suggest a correction for --outptu",
        )
        assert_true(
            "output" in msg,
            msg="Error should suggest --output",
        )
    assert_true(caught, msg="Should have raised error for --outptu")
    print("  ✓ test_typo_long_option_single_char_diff")


# ── Subcommand typo suggestions ──────────────────────────────────────────────


fn test_typo_subcommand_suggests() raises:
    """Tests that a typo subcommand like 'serach' suggests 'search'."""
    var root = Command("app", "Test app")
    var search = Command("search", "Search items")
    var list_cmd = Command("list", "List items")
    root.add_subcommand(search^)
    root.add_subcommand(list_cmd^)

    var args: List[String] = ["app", "serach"]
    var caught = False
    try:
        _ = root.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Did you mean" in msg,
            msg="Error should suggest a correction for 'serach'",
        )
        assert_true(
            "search" in msg,
            msg="Error should suggest 'search'",
        )
    assert_true(caught, msg="Should have raised error for 'serach'")
    print("  ✓ test_typo_subcommand_suggests")


fn test_typo_subcommand_no_suggestion() raises:
    """Tests that a completely unrelated subcommand doesn't produce a suggestion.
    """
    var root = Command("app", "Test app")
    var search = Command("search", "Search items")
    root.add_subcommand(search^)

    var args: List[String] = ["app", "xxxxxxx"]
    var caught = False
    try:
        _ = root.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_false(
            "Did you mean" in msg,
            msg="Error should not suggest anything for unrelated command",
        )
    assert_true(caught, msg="Should have raised error for 'xxxxxxx'")
    print("  ✓ test_typo_subcommand_no_suggestion")


# ── Alias typo suggestions ──────────────────────────────────────────────────


fn test_typo_alias_suggests() raises:
    """Tests that a typo close to an alias triggers a suggestion."""
    var command = Command("test", "Test app")
    var alias_list: List[String] = ["color"]
    command.add_argument(
        Argument("colour", help="Enable colour output")
        .long("colour")
        .flag()
        .aliases(alias_list^)
    )

    var args: List[String] = ["test", "--colro"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Did you mean" in msg,
            msg="Error should suggest a correction for --colro",
        )
    assert_true(caught, msg="Should have raised error for --colro")
    print("  ✓ test_typo_alias_suggests")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
