"""Tests for argmojo — password / masked input feature.

Since hiding terminal input requires an interactive terminal, these
tests focus on:
1. Builder method correctness (`.password()`)
2. Field propagation through copy/move
3. Validation guards (password on flag/count rejected)
4. Integration with prompting, choices, defaults, parents, subcommands
5. Non-interactive stdin graceful fallback (the test runner redirects
   stdin from `/dev/null`, so prompting stops without blocking)
"""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Builder method tests ─────────────────────────────────────────────────────


def test_password_builder_basic() raises:
    """Tests that .password() sets _hide_input and implies _prompt."""
    var arg = Argument("token", help="API token").long["token"]().password()
    assert_true(arg._hide_input, msg=".password() should set _hide_input")
    assert_true(arg._prompt, msg=".password() should imply .prompt()")


def test_password_builder_with_explicit_prompt() raises:
    """Tests that .password() works alongside .prompt["text"]()."""
    var arg = (
        Argument("pass", help="Password")
        .long["pass"]()
        .prompt["Enter password"]()
        .password()
    )
    assert_true(arg._hide_input, msg="_hide_input should be True")
    assert_true(arg._prompt, msg="prompt should be True")
    assert_equal(
        arg._prompt_text,
        "Enter password",
        msg="custom prompt text should be preserved",
    )


def test_password_before_prompt() raises:
    """Tests that .password() before .prompt["text"]() works."""
    var arg = (
        Argument("secret", help="Secret key")
        .long["secret"]()
        .password()
        .prompt["Enter your secret key"]()
    )
    assert_true(arg._hide_input, msg="_hide_input should be True")
    assert_true(arg._prompt, msg="prompt should be True")
    assert_equal(
        arg._prompt_text,
        "Enter your secret key",
        msg="prompt text should be set",
    )


def test_password_default_fields() raises:
    """Tests that _hide_input is False by default."""
    var arg = Argument("name", help="Name").long["name"]()
    assert_false(arg._hide_input, msg="_hide_input should be False by default")


# ── Copy and move propagation ────────────────────────────────────────────────


def test_password_copy_preserves_field() raises:
    """Tests that __copyinit__ preserves _hide_input."""
    var original = Argument("pass", help="Password").long["pass"]().password()
    var copy = original.copy()
    assert_true(copy._hide_input, msg="copy should preserve _hide_input")
    assert_true(copy._prompt, msg="copy should preserve _prompt")


# ── Validation guards ────────────────────────────────────────────────────────


def test_password_rejected_on_flag() raises:
    """Tests that .password() on a flag raises at add_argument time."""
    var cmd = Command("test", "Test app")
    var caught = False
    try:
        cmd.add_argument(
            Argument("debug", help="Debug mode")
            .long["debug"]()
            .flag()
            .password()
        )
    except e:
        caught = True
        assert_true(
            "cannot be used on a flag" in String(e),
            msg="error should mention flag restriction: " + String(e),
        )
    assert_true(caught, msg="add_argument should reject .password() on flag")


def test_password_rejected_on_count() raises:
    """Tests that .password() on a count arg raises at add_argument time."""
    var cmd = Command("test", "Test app")
    var caught = False
    try:
        cmd.add_argument(
            Argument("verbose", help="Verbosity")
            .long["verbose"]()
            .count()
            .password()
        )
    except e:
        caught = True
        assert_true(
            "cannot be used on" in String(e),
            msg="error should mention restriction: " + String(e),
        )
    assert_true(caught, msg="add_argument should reject .password() on count")


# ── Prompting skipped when value provided on command line ─────────────────────


def test_password_skipped_when_value_provided() raises:
    """Tests that password prompt is skipped when value is on command line."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("token", help="API token").long["token"]().password()
    )

    var args: List[String] = ["test", "--token", "abc123"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("token"),
        "abc123",
        msg="provided value should be used",
    )


def test_password_with_default() raises:
    """Tests password arg with a default value."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("key", help="API key")
        .long["key"]()
        .default["default-key"]()
        .password()
    )

    # No value on command line + stdin is /dev/null → prompting stops,
    # default is applied.
    var args: List[String] = ["test"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("key"),
        "default-key",
        msg="default should be used when stdin is not interactive",
    )


def test_password_with_choices() raises:
    """Tests password arg with choices (unusual but valid)."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("level", help="Access level")
        .long["level"]()
        .choice["admin"]()
        .choice["user"]()
        .password()
    )

    var args: List[String] = ["test", "--level", "admin"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("level"),
        "admin",
        msg="choice value should be accepted",
    )


# ── Integration with other features ──────────────────────────────────────────


def test_password_with_required() raises:
    """Tests that required + password arg errors on missing value.

    When stdin is /dev/null, prompting stops → the required arg is
    missing → validation error.
    """
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("secret", help="Secret").long["secret"]().required().password()
    )

    var args: List[String] = ["test"]
    var caught = False
    try:
        var result = cmd.parse_arguments(args)
    except e:
        caught = True
        assert_true(
            "required" in String(e).lower(),
            msg="error should mention required: " + String(e),
        )
    assert_true(caught, msg="missing required password arg should error")


def test_password_arg_with_parent() raises:
    """Tests that password fields are inherited via add_parent."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("token", help="API token").long["token"]().password()
    )

    var child = Command("deploy", "Deploy the app")
    child.add_parent(parent)

    # Check the inherited arg has _hide_input and _prompt set.
    var found = False
    for i in range(len(child.args)):
        if child.args[i].name == "token":
            assert_true(
                child.args[i]._hide_input,
                msg="inherited arg should have _hide_input",
            )
            assert_true(
                child.args[i]._prompt,
                msg="inherited arg should have _prompt",
            )
            found = True
            break
    assert_true(found, msg="token should be inherited from parent")


def test_password_with_subcommand() raises:
    """Tests password arg on a subcommand."""
    var app = Command("app", "My app")
    var login = Command("login", "Login to service")
    login.add_argument(
        Argument("password", help="Your password")
        .long["password"]()
        .short["p"]()
        .password()
    )
    app.add_subcommand(login^)

    var args: List[String] = ["app", "login", "--password", "s3cret"]
    var result = app.parse_arguments(args)
    assert_equal(result.subcommand, "login")
    var sub = result.get_subcommand_result()
    assert_equal(
        sub.get_string("password"),
        "s3cret",
        msg="password value should be parsed",
    )


def test_password_not_set_on_normal_prompt() raises:
    """Tests that a normal .prompt() arg does NOT have _hide_input."""
    var arg = Argument("name", help="Name").long["name"]().prompt()
    assert_false(
        arg._hide_input,
        msg="normal prompt should not have _hide_input",
    )


def test_password_positional() raises:
    """Tests password on a positional argument."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("secret", help="Secret value").positional().password()
    )

    var args: List[String] = ["test", "my-secret"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("secret"),
        "my-secret",
        msg="positional password value should be parsed",
    )


def test_password_graceful_on_non_interactive_stdin() raises:
    """Tests that password prompting stops gracefully on non-interactive stdin.

    When the test runs with stdin redirected from /dev/null, input()
    raises on EOF.  ArgMojo catches this and stops prompting.  If the
    arg has a default, the default is used; otherwise validation runs
    normally.
    """
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("token", help="Token")
        .long["token"]()
        .default["fallback"]()
        .password()
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("token"),
        "fallback",
        msg="default should be used when stdin is non-interactive",
    )


# ── Test runner ──────────────────────────────────────────────────────────────


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
