"""Tests for argmojo — interactive features.

Covers three areas:
1. Interactive prompting (.prompt(), .prompt["text"]())
2. Password / masked input (.password())
3. Confirmation option (--yes / -y)

Since these features read from stdin, tests focus on builder method
correctness, field propagation, validation guards, and verifying that
prompting is skipped when values are provided on the command line.
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Prompt tests ─────────────────────────────────────────────────────────────

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


# ── Password tests ───────────────────────────────────────────────────────────

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
    """Tests that Argument.copy() preserves _hide_input and _prompt."""
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


# ── password[asterisk] builder tests ─────────────────────────────────────────


def test_password_asterisk_true_sets_fields() raises:
    """Tests that .password[True]() sets both _hide_input and _show_asterisk."""
    var arg = Argument("pin", help="PIN").long["pin"]().password[True]()
    assert_true(arg._hide_input, msg="_hide_input should be True")
    assert_true(arg._show_asterisk, msg="_show_asterisk should be True")
    assert_true(arg._prompt, msg="_prompt should be implied")


def test_password_asterisk_false_sets_fields() raises:
    """Tests that .password[False]() sets _hide_input but not _show_asterisk."""
    var arg = Argument("pass", help="Password").long["pass"]().password[False]()
    assert_true(arg._hide_input, msg="_hide_input should be True")
    assert_false(arg._show_asterisk, msg="_show_asterisk should be False")
    assert_true(arg._prompt, msg="_prompt should be implied")


def test_password_plain_resets_asterisk() raises:
    """Tests that .password() after .password[True]() resets _show_asterisk.

    The last builder call should win — .password() means fully hidden.
    """
    var arg = (
        Argument("pass", help="Password")
        .long["pass"]()
        .password[True]()
        .password()
    )
    assert_true(arg._hide_input, msg="_hide_input should be True")
    assert_false(
        arg._show_asterisk,
        msg="_show_asterisk should be reset by .password()",
    )


def test_password_asterisk_copy_preserves() raises:
    """Tests that copy preserves _show_asterisk."""
    var original = Argument("pin", help="PIN").long["pin"]().password[True]()
    var copy = original.copy()
    assert_true(copy._show_asterisk, msg="copy should preserve _show_asterisk")
    assert_true(copy._hide_input, msg="copy should preserve _hide_input")


def test_password_asterisk_default_is_false() raises:
    """Tests that _show_asterisk is False by default."""
    var arg = Argument("name", help="Name").long["name"]()
    assert_false(
        arg._show_asterisk, msg="_show_asterisk should be False by default"
    )


def test_password_asterisk_skipped_when_value_provided() raises:
    """Tests that asterisk password prompt is skipped when value is on CLI."""
    var cmd = Command("test", "Test app")
    cmd.add_argument(Argument("pin", help="PIN").long["pin"]().password[True]())

    var args: List[String] = ["test", "--pin", "1234"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("pin"),
        "1234",
        msg="provided value should be used",
    )


def test_password_asterisk_with_default() raises:
    """Tests asterisk password arg with a default.

    When stdin is /dev/null, prompting stops and default is applied.
    """
    var cmd = Command("test", "Test app")
    cmd.add_argument(
        Argument("pin", help="PIN")
        .long["pin"]()
        .default["0000"]()
        .password[True]()
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_arguments(args)
    assert_equal(
        result.get_string("pin"),
        "0000",
        msg="default should be used when stdin is not interactive",
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


# ── Confirmation tests ───────────────────────────────────────────────────────

# ── --yes flag skips confirmation ─────────────────────────────────────────────


def test_confirmation_yes_flag_skips() raises:
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


def test_confirmation_y_short_flag_skips() raises:
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


def test_confirmation_yes_before_positional() raises:
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


def test_confirmation_aborts_on_no_stdin() raises:
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


def test_confirmation_custom_prompt_with_yes() raises:
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


def test_confirmation_custom_prompt_aborts_no_stdin() raises:
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


def test_confirmation_with_flag_and_option() raises:
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


def test_confirmation_yes_is_false_by_default() raises:
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


def test_no_confirmation_option_normal_parse() raises:
    """Tests that without confirmation_option(), parsing works normally."""
    var cmd = Command("list", "List items")
    cmd.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var args: List[String] = ["list", "--verbose"]
    var result = cmd.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")


# ── Confirmation with subcommands ─────────────────────────────────────────────


def test_confirmation_on_parent_with_subcommand() raises:
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


def test_confirmation_preserved_in_copy() raises:
    """Tests that confirmation settings are preserved when copying a Command."""
    var original = Command("drop", "Drop something")
    original.confirmation_option["Really drop?"]()

    var copied = original.copy()
    # Verify by using --yes (confirmation_option was inherited).
    var args: List[String] = ["drop", "--yes"]
    var result = copied.parse_arguments(args)
    assert_true(result.get_flag("yes"), msg="--yes should work on copy")


# ── Confirmation with prompt arguments ────────────────────────────────────────


def test_confirmation_with_prompt_arg_uses_yes() raises:
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


def test_confirmation_with_parent_args() raises:
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


# ── Test runner ──────────────────────────────────────────────────────────────


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
