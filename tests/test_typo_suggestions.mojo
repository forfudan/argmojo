"""Tests for argmojo — typo suggestions (Levenshtein distance)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Long option typo suggestions ─────────────────────────────────────────────


fn test_typo_long_option_suggests() raises:
    """Tests that a typo like --verbos suggests --verbose."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("version", help="Show version").long["version"]().flag()
    )

    var _args: List[String] = ["test", "--verbos"]
    # --verbos is a prefix match for --verbose, so it should resolve.
    # Use a more distant typo to test suggestion path.
    var args2: List[String] = ["test", "--vrebose"]
    var caught = False
    try:
        _ = command.parse_arguments(args2)
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


fn test_typo_long_option_no_suggestion() raises:
    """Tests that a completely unrelated option doesn't produce a suggestion."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var args: List[String] = ["test", "--zzzzzzz"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_false(
            "Did you mean" in msg,
            msg="Error should not suggest anything for unrelated option",
        )
    assert_true(caught, msg="Should have raised error for --zzzzzzz")


fn test_typo_long_option_single_char_diff() raises:
    """Tests that a single character difference triggers a suggestion."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var args: List[String] = ["test", "--outptu", "file.txt"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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
        _ = root.parse_arguments(args)
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


fn test_typo_subcommand_no_suggestion() raises:
    """Tests that a completely unrelated subcommand doesn't produce a suggestion.
    """
    var root = Command("app", "Test app")
    var search = Command("search", "Search items")
    root.add_subcommand(search^)

    var args: List[String] = ["app", "xxxxxxx"]
    var caught = False
    try:
        _ = root.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_false(
            "Did you mean" in msg,
            msg="Error should not suggest anything for unrelated command",
        )
    assert_true(caught, msg="Should have raised error for 'xxxxxxx'")


# ── Alias typo suggestions ──────────────────────────────────────────────────


fn test_typo_alias_suggests() raises:
    """Tests that a typo close to an alias triggers a suggestion."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Enable colour output")
        .long["colour"]()
        .flag()
        .alias_name["color"]()
    )

    var args: List[String] = ["test", "--colro"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Did you mean" in msg,
            msg="Error should suggest a correction for --colro",
        )
    assert_true(caught, msg="Should have raised error for --colro")


fn test_typo_subcommand_alias_suggests() raises:
    """Tests that a typo near a subcommand alias triggers a suggestion."""
    var root = Command("app", "Test app")
    var clone = Command("clone", "Clone a repo")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    root.add_subcommand(clone^)

    # "clon" is close to both "clone" and "cl"
    var args: List[String] = ["app", "clon"]
    var caught = False
    try:
        _ = root.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Did you mean" in msg,
            msg="Error should suggest a correction for 'clon'",
        )
        assert_true(
            "clone" in msg,
            msg="Error should suggest 'clone' for 'clon'",
        )
    assert_true(caught, msg="Should have raised error for 'clon'")


fn test_typo_hidden_subcommand_not_suggested() raises:
    """Tests that hidden subcommands are NOT included in typo suggestions."""
    var app = Command("app", "Test app")
    var clone = Command("clone", "Clone a repository")
    app.add_subcommand(clone^)
    var debug = Command("debug", "Internal debug")
    debug.hidden()
    app.add_subcommand(debug^)

    # 'debu' is close to 'debug', but debug is hidden so no suggestion.
    var args: List[String] = ["app", "debu"]
    var caught = False
    var err_msg = String("")
    try:
        _ = app.parse_arguments(args)
    except e:
        caught = True
        err_msg = String(e)
    assert_true(caught, msg="Should have raised error for 'debu'")
    assert_false(
        "debug" in err_msg,
        msg="Hidden sub 'debug' should NOT appear in typo suggestion",
    )
    # But the error should still mention available commands (only clone).
    assert_true(
        "clone" in err_msg,
        msg="Visible sub 'clone' should still be in error message",
    )


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
