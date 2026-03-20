"""Tests for argmojo — interactive prompting feature.

Since interactive prompting reads from stdin, these tests focus on:
1. Builder method correctness (`.prompt()`, `.prompt["custom text"]()`)
2. Prompting is SKIPPED when arguments are provided on the command line
3. Prompt fields are set correctly on Argument instances
4. Choices/defaults appear in the prompt (tested via field inspection)
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Builder method tests ─────────────────────────────────────────────────────


def test_prompt_builder_default() raises:
    """Tests that .prompt() enables prompting."""
    var arg = Argument("name", help="Your name").long["name"]().prompt()
    assert_true(arg._prompt, msg=".prompt() should enable prompting")
    assert_equal(
        arg._prompt_text, "", msg="prompt text should be empty by default"
    )


def test_prompt_builder_with_text() raises:
    """Tests that .prompt["..."]() sets custom text and enables prompting."""
    var arg = (
        Argument("name", help="Your name")
        .long["name"]()
        .prompt["Enter your full name"]()
    )
    assert_true(arg._prompt, msg=".prompt[text] should enable prompting")
    assert_equal(
        arg._prompt_text,
        "Enter your full name",
        msg="prompt text should match",
    )


def test_prompt_with_custom_text_standalone() raises:
    """Tests that .prompt["..."]() works as a standalone builder."""
    var arg = (
        Argument("email", help="Email address")
        .long["email"]()
        .prompt["Please enter your email"]()
    )
    assert_true(arg._prompt, msg="prompt should be enabled")
    assert_equal(
        arg._prompt_text,
        "Please enter your email",
        msg="prompt text should be set",
    )


# ── Prompting skipped when value provided ────────────────────────────────────


def test_prompt_skipped_when_value_provided() raises:
    """Tests that prompting is skipped when the argument is on the command line.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("name", help="Your name").long["name"]().prompt()
    )

    # Value provided on command line — no stdin interaction needed.
    var args: List[String] = ["test", "--name", "Alice"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("name"),
        "Alice",
        msg="provided value should be used",
    )


def test_prompt_skipped_for_flag_provided() raises:
    """Tests that a prompt-enabled flag is skipped when provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .flag()
        .prompt()
    )

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="flag should be True from command line",
    )


def test_prompt_skipped_for_positional_provided() raises:
    """Tests that a prompt-enabled positional is skipped when provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="Input file").positional().prompt()
    )

    var args: List[String] = ["test", "data.txt"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("file"),
        "data.txt",
        msg="positional should be set from command line",
    )


def test_prompt_skipped_when_short_used() raises:
    """Tests that prompting is skipped when the short option is used."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .prompt()
    )

    var args: List[String] = ["test", "-o", "out.txt"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("output"),
        "out.txt",
        msg="short option value should be used",
    )


def test_prompt_skipped_when_equals_used() raises:
    """Tests that prompting is skipped when --key=value syntax is used."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format").long["format"]().prompt()
    )

    var args: List[String] = ["test", "--format=json"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("format"),
        "json",
        msg="equals value should be used",
    )


# ── Prompt with choices and defaults ─────────────────────────────────────────


def test_prompt_with_choices_skipped_when_provided() raises:
    """Tests that a prompt arg with choices works when value is on CLI."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .choice["json"]()
        .choice["csv"]()
        .choice["table"]()
        .prompt()
    )

    var args: List[String] = ["test", "--format", "json"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("format"),
        "json",
        msg="choice value should be accepted",
    )


def test_prompt_with_default_skipped_when_provided() raises:
    """Tests that a prompt arg with default uses CLI value over default."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Log level")
        .long["level"]()
        .default["info"]()
        .prompt()
    )

    var args: List[String] = ["test", "--level", "debug"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("level"),
        "debug",
        msg="CLI value should override default",
    )


def test_prompt_default_applied_when_no_prompt_input() raises:
    """Tests that defaults still apply for prompt args when stdin is not a TTY.

    When stdin is not a TTY (piped/closed), prompting is skipped entirely
    and defaults are applied normally.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Log level")
        .long["level"]()
        .default["info"]()
        .prompt()
    )

    # No --level on CLI → prompting is skipped (stdin is pipe in test
    # runner), _apply_defaults fills in "info".
    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("level"),
        "info",
        msg="default should be applied when prompting is skipped",
    )


# ── Prompt field propagation through copy/move ───────────────────────────────


def test_prompt_field_copy() raises:
    """Tests that prompt fields survive Argument copy."""
    var original = (
        Argument("name", help="Your name").long["name"]().prompt["Enter name"]()
    )
    var copy = original.copy()
    assert_true(copy._prompt, msg="copy should preserve _prompt")
    assert_equal(
        copy._prompt_text,
        "Enter name",
        msg="copy should preserve _prompt_text",
    )


# ── Combined features ───────────────────────────────────────────────────────


def test_prompt_combined_with_required() raises:
    """Tests that prompt works alongside .required() when value is given."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("name", help="Your name").long["name"]().required().prompt()
    )

    var args: List[String] = ["test", "--name", "Bob"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("name"),
        "Bob",
        msg="required+prompt should work when value provided",
    )


def test_prompt_combined_with_group() raises:
    """Tests that prompt works alongside .group[]()."""
    var arg = (
        Argument("user", help="Username")
        .long["user"]()
        .prompt()
        .group["Auth"]()
    )
    assert_true(arg._prompt, msg="prompt should be set")
    assert_equal(arg._group, "Auth", msg="group should be set")


def test_prompt_on_optional_arg_with_default() raises:
    """Tests that prompt works on non-required args (no .required())."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Output color")
        .long["color"]()
        .default["auto"]()
        .prompt()
    )

    # Provide value on CLI — prompt is skipped.
    var args: List[String] = ["test", "--color", "red"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("color"),
        "red",
        msg="optional prompt arg should accept CLI value",
    )


def test_prompt_on_optional_arg_default_applied() raises:
    """Tests that non-required prompt arg falls back to default when
    stdin is not interactive (piped/closed)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Output color")
        .long["color"]()
        .default["auto"]()
        .prompt()
    )

    # No --color on CLI, stdin is pipe → default "auto" used.
    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("color"),
        "auto",
        msg="default should apply for optional prompt arg when not prompted",
    )


def test_multiple_prompt_args_all_provided() raises:
    """Tests that multiple prompt-enabled args work when all provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("name", help="Your name").long["name"]().prompt()
    )
    command.add_argument(
        Argument("email", help="Email").long["email"]().prompt()
    )
    command.add_argument(Argument("age", help="Age").long["age"]().prompt())

    var args: List[String] = [
        "test",
        "--name",
        "Alice",
        "--email",
        "alice@example.com",
        "--age",
        "30",
    ]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("name"), "Alice")
    assert_equal(result.get_string("email"), "alice@example.com")
    assert_equal(result.get_string("age"), "30")


# ── Test runner ──────────────────────────────────────────────────────────────


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
