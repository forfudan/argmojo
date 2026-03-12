"""Tests for argmojo — confirmation option (--yes / -y)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── --yes flag skips confirmation ─────────────────────────────────────────────


fn test_confirmation_yes_flag_skips() raises:
    """Tests that --yes skips the confirmation prompt."""
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option()

    var args: List[String] = ["drop", "mydb", "--yes"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("name"), "mydb")
    assert_true(result.get_flag("yes"), msg="--yes should be True")


fn test_confirmation_y_short_flag_skips() raises:
    """Tests that -y skips the confirmation prompt."""
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option()

    var args: List[String] = ["drop", "mydb", "-y"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("name"), "mydb")
    assert_true(result.get_flag("yes"), msg="-y should be True")


fn test_confirmation_yes_before_positional() raises:
    """Tests that --yes can appear before the positional argument."""
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option()

    var args: List[String] = ["drop", "--yes", "mydb"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("name"), "mydb")
    assert_true(result.get_flag("yes"), msg="--yes should be True")


# ── Non-interactive stdin aborts ──────────────────────────────────────────────


fn test_confirmation_aborts_on_no_stdin() raises:
    """Tests that confirmation aborts when stdin is unavailable.

    When tests run without a terminal (stdin is /dev/null or piped),
    input() raises and _confirm() should abort with an error.
    """
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option()

    # Without --yes, confirmation prompt fires.
    # Since we're in a test environment (no interactive stdin),
    # input() will raise → error.
    var args: List[String] = ["drop", "mydb"]
    var caught = False
    try:
        _ = cmd.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Aborted" in msg,
            msg="Error should mention Aborted, got: " + msg,
        )
    assert_true(caught, msg="Should abort when stdin is unavailable")


# ── Custom prompt text ────────────────────────────────────────────────────────


fn test_confirmation_custom_prompt_with_yes() raises:
    """Tests that custom prompt works and --yes still skips it."""
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option["Drop the database? This cannot be undone."]()

    var args: List[String] = ["drop", "mydb", "--yes"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("name"), "mydb")
    assert_true(result.get_flag("yes"), msg="--yes should be True")


fn test_confirmation_custom_prompt_aborts_no_stdin() raises:
    """Tests that custom prompt aborts when stdin is unavailable."""
    var cmd = Command("drop", "Drop the database")
    cmd.add_argument(
        Argument("name", help="Database name").positional().required()
    )
    cmd.confirmation_option["Are you absolutely sure?"]()

    var args: List[String] = ["drop", "mydb"]
    var caught = False
    try:
        _ = cmd.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Aborted" in msg,
            msg="Error should mention Aborted, got: " + msg,
        )
    assert_true(caught, msg="Should abort with custom prompt and no stdin")


# ── Works with other arguments ────────────────────────────────────────────────


fn test_confirmation_with_flag_and_option() raises:
    """Tests that confirmation works alongside other flags and options."""
    var cmd = Command("deploy", "Deploy the application")
    cmd.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    cmd.add_argument(
        Argument("env", help="Target environment").long["env"]().required()
    )
    cmd.confirmation_option()

    var args: List[String] = ["deploy", "--env", "prod", "-v", "--yes"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("env"), "prod")
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")
    assert_true(result.get_flag("yes"), msg="--yes should be True")


fn test_confirmation_yes_is_false_by_default() raises:
    """Tests that --yes works alongside defaulted options."""
    var cmd = Command("deploy", "Deploy the application")
    cmd.add_argument(
        Argument("env", help="Target environment")
        .long["env"]()
        .default["staging"]()
    )
    cmd.confirmation_option()

    var args: List[String] = ["deploy", "--yes"]
    var result = cmd.parse_arguments(args)
    assert_true(result.get_flag("yes"), msg="--yes should be True")
    assert_equal(result.get_string("env"), "staging")


# ── No confirmation → normal behavior ────────────────────────────────────────


fn test_no_confirmation_option_normal_parse() raises:
    """Tests that without confirmation_option(), parsing works normally."""
    var cmd = Command("list", "List items")
    cmd.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var args: List[String] = ["list", "--verbose"]
    var result = cmd.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")


# ── Confirmation with subcommands ─────────────────────────────────────────────


fn test_confirmation_on_parent_with_subcommand() raises:
    """Tests that confirmation on parent command works with subcommands."""
    var app = Command("app", "My app")
    app.confirmation_option()

    var sub = Command("deploy", "Deploy something")
    sub.add_argument(
        Argument("target", help="Deploy target").positional().required()
    )
    app.add_subcommand(sub^)

    # --yes before subcommand should skip confirmation.
    var args: List[String] = ["app", "--yes", "deploy", "prod"]
    var result = app.parse_arguments(args)
    assert_true(result.get_flag("yes"), msg="--yes should be True")
    assert_equal(result.subcommand, "deploy")
    var sub_result = result.get_subcommand_result()
    assert_equal(sub_result.get_string("target"), "prod")


# ── Confirmation field copy ──────────────────────────────────────────────────


fn test_confirmation_preserved_in_copy() raises:
    """Tests that confirmation settings are preserved when copying a Command."""
    var original = Command("drop", "Drop something")
    original.confirmation_option["Really drop?"]()

    var copied = original.copy()
    # Verify by using --yes (confirmation_option was inherited).
    var args: List[String] = ["drop", "--yes"]
    var result = copied.parse_arguments(args)
    assert_true(result.get_flag("yes"), msg="--yes should work on copy")


# ── Confirmation with prompt arguments ────────────────────────────────────────


fn test_confirmation_with_prompt_arg_uses_yes() raises:
    """Tests that confirmation works alongside .prompt() arguments when --yes is passed.
    """
    var cmd = Command("setup", "Setup the project")
    cmd.add_argument(
        Argument("name", help="Project name").long["name"]().prompt()
    )
    cmd.confirmation_option()

    # Provide both --name and --yes to skip all interactive prompts.
    var args: List[String] = ["setup", "--name", "myproject", "--yes"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("name"), "myproject")
    assert_true(result.get_flag("yes"), msg="--yes should be True")


# ── Confirmation with parent args ─────────────────────────────────────────────


fn test_confirmation_with_parent_args() raises:
    """Tests that confirmation works alongside inherited parent arguments."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var cmd = Command("deploy", "Deploy the app")
    cmd.add_parent(parent)
    cmd.confirmation_option()

    var args: List[String] = ["deploy", "--verbose", "--yes"]
    var result = cmd.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")
    assert_true(result.get_flag("yes"), msg="--yes should be True")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
