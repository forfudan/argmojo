"""Tests for argmojo — custom usage line."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Custom usage in help ─────────────────────────────────────────────────────────


def test_custom_usage_in_plain_help() raises:
    """Tests that custom usage appears in plain help output."""
    var cmd = Command("git", "The stupid content tracker")
    cmd.usage("git [-v | --version] [-C <path>] <command> [<args>]")

    var help = cmd._generate_help(color=False)
    assert_true(
        "Usage: git [-v | --version] [-C <path>] <command> [<args>]" in help,
        msg="Custom usage should appear in plain help: " + help,
    )


def test_custom_usage_in_colored_help() raises:
    """Tests that custom usage appears in colored help output."""
    var cmd = Command("git", "The stupid content tracker")
    cmd.usage("git [-v | --version] [-C <path>] <command> [<args>]")

    var help = cmd._generate_help(color=True)
    # The custom text should appear (wrapped in ANSI codes for "Usage:")
    assert_true(
        "git [-v | --version]" in help,
        msg="Custom usage text should appear in colored help: " + help,
    )


def test_custom_usage_replaces_auto_generated() raises:
    """Tests that custom usage replaces the auto-generated positionals."""
    var cmd = Command("myapp", "My app")
    cmd.add_argument(
        Argument("file", help="Input file").positional().required()
    )
    cmd.add_argument(Argument("output", help="Output file").long["output"]())
    cmd.usage("myapp FILE [--output FILE]")

    var help = cmd._generate_help(color=False)
    assert_true(
        "Usage: myapp FILE [--output FILE]" in help,
        msg="Custom usage should replace auto-generated: " + help,
    )
    # The auto-generated "<file> [OPTIONS]" should NOT appear in usage line
    var lines = help.split("\n")
    for i in range(len(lines)):
        if "Usage:" in lines[i]:
            assert_false(
                "<file>" in lines[i],
                msg="Auto-generated positional should not appear in usage line",
            )
            break


# ── Default usage still works ────────────────────────────────────────────────────


def test_default_usage_when_no_custom() raises:
    """Tests that auto-generated usage is used when no custom is set."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("file", help="Input file").positional().required()
    )

    var help = cmd._generate_help(color=False)
    assert_true(
        "Usage: test <file> [OPTIONS]" in help,
        msg="Default usage should show auto-generated format: " + help,
    )


def test_default_usage_with_optional_positional() raises:
    """Tests auto-generated usage for optional positional."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("path", help="Search path").positional().default["."]()
    )

    var help = cmd._generate_help(color=False)
    assert_true(
        "Usage: test [path] [OPTIONS]" in help,
        msg="Optional positional should be in brackets: " + help,
    )


def test_default_usage_with_subcommands() raises:
    """Tests auto-generated usage with subcommands."""
    var app = Command("app", "My app")
    var sub = Command("deploy", "Deploy something")
    app.add_subcommand(sub^)

    var help = app._generate_help(color=False)
    assert_true(
        "Usage: app <COMMAND> [OPTIONS]" in help,
        msg="Subcommand usage should show <COMMAND>: " + help,
    )


# ── Custom usage preserved in copy ───────────────────────────────────────────────


def test_custom_usage_preserved_in_copy() raises:
    """Tests that custom usage is preserved when copying a Command."""
    var original = Command("git", "Git")
    original.usage("git [options] <command> [<args>]")

    var copied = original.copy()
    var help = copied._generate_help(color=False)
    assert_true(
        "Usage: git [options] <command> [<args>]" in help,
        msg="Custom usage should be preserved in copy: " + help,
    )


# ── Custom usage with other features ─────────────────────────────────────────────


def test_custom_usage_with_subcommands() raises:
    """Tests custom usage with subcommands registered."""
    var app = Command("app", "My app")
    app.usage("app [-v] <command>")
    var sub = Command("deploy", "Deploy something")
    app.add_subcommand(sub^)

    var help = app._generate_help(color=False)
    assert_true(
        "Usage: app [-v] <command>" in help,
        msg="Custom usage should override even with subcommands: " + help,
    )
    # Auto-generated <COMMAND> should NOT appear
    assert_false(
        "<COMMAND>" in help,
        msg="Auto-generated <COMMAND> should not appear with custom usage",
    )


def test_custom_usage_description_still_shown() raises:
    """Tests that description is still shown above custom usage."""
    var cmd = Command("myapp", "A great application")
    cmd.usage("myapp [options]")

    var help = cmd._generate_help(color=False)
    assert_true(
        "A great application" in help,
        msg="Description should still appear: " + help,
    )
    assert_true(
        "Usage: myapp [options]" in help,
        msg="Custom usage should appear after description: " + help,
    )


def test_custom_usage_parsing_still_works() raises:
    """Tests that custom usage doesn't affect parsing behavior."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("file", help="Input file").positional().required()
    )
    cmd.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    cmd.usage("test FILE [--verbose]")

    var args: List[String] = ["test", "input.txt", "--verbose"]
    var result = cmd.parse_arguments(args)
    assert_equal(result.get_string("file"), "input.txt")
    assert_true(result.get_flag("verbose"), msg="--verbose should work")


def test_custom_usage_in_plain_usage_hint() raises:
    """Tests that custom usage appears in the plain usage hint (_plain_usage).
    """
    var cmd = Command("git", "The stupid content tracker")
    cmd.usage("git [-v | --version] [-C <path>] <command> [<args>]")

    # _plain_usage is used for error/usage hints; ensure it reflects custom usage.
    var usage = cmd._plain_usage()
    assert_true(
        "git [-v | --version] [-C <path>] <command> [<args>]" in usage,
        msg="Custom usage should appear in plain usage hint: " + usage,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
