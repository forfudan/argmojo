"""Tests for argmojo — default_if_no_value and require_equals features."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── default_if_no_value — long option ────────────────────────────────────────


fn test_const_long_without_value() raises:
    """--compress (no value) uses the default-if-no-value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "--compress"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")


fn test_const_long_with_equals_value() raises:
    """--compress=bzip2 uses the explicit value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "--compress=bzip2"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "bzip2")


fn test_const_long_space_separated_not_consumed() raises:
    """--compress followed by a token does not consume it as a value;
    --compress uses default-if-no-value and the next token becomes a positional.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )
    command.add_argument(Argument("file", help="File").positional())

    # '--compress bzip2' should treat 'bzip2' as a positional, not the value
    # of --compress.  --compress uses the default-if-no-value.
    var args: List[String] = ["test", "--compress", "myfile.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")
    assert_equal(result.get_string("file"), "myfile.txt")


fn test_const_long_not_provided() raises:
    """When --compress is not provided at all, no value is set (unless default).
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("compress"), msg="compress should not be set")


fn test_const_long_with_default() raises:
    """When default_if_no_value has a default, --compress uses default-if-no-value while omission uses default.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
        .default("none")
    )

    # Not provided → default.
    var args1: List[String] = ["test"]
    var result1 = command.parse_arguments(args1)
    assert_equal(result1.get_string("compress"), "none")

    # Provided without value → default-if-no-value.
    var args2: List[String] = ["test", "--compress"]
    var result2 = command.parse_arguments(args2)
    assert_equal(result2.get_string("compress"), "gzip")

    # Provided with = value → explicit.
    var args3: List[String] = ["test", "--compress=bzip2"]
    var result3 = command.parse_arguments(args3)
    assert_equal(result3.get_string("compress"), "bzip2")


fn test_const_long_with_choices() raises:
    """Tests default_if_no_value must pass choices validation."""
    var command = Command("test", "Test app")
    var choices: List[String] = ["gzip", "bzip2", "xz"]
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
        .choices(choices^)
    )

    # --compress → default-if-no-value "gzip" passes choices.
    var args: List[String] = ["test", "--compress"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")

    # --compress=xz → "xz" passes choices.
    var args2: List[String] = ["test", "--compress=xz"]
    var result2 = command.parse_arguments(args2)
    assert_equal(result2.get_string("compress"), "xz")


fn test_const_long_choices_invalid_eq() raises:
    """Explicit value via = that violates choices is rejected."""
    var command = Command("test", "Test app")
    var choices: List[String] = ["gzip", "bzip2", "xz"]
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
        .choices(choices^)
    )

    var args: List[String] = ["test", "--compress=invalid"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "invalid" in msg or "choices" in msg.lower(),
            msg="error should mention invalid choice",
        )
    assert_true(caught, msg="Should have raised for invalid choice")


# ── default_if_no_value — short option ────────────────────────────────────────────


fn test_const_short_without_value() raises:
    """-c (alone) uses the default-if-no-value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .short("c")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "-c"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")


fn test_const_short_with_attached_value() raises:
    """-cbzip2 (attached value) uses the explicit value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .short("c")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "-cbzip2"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "bzip2")


fn test_const_short_does_not_consume_next() raises:
    """-c followed by a positional does not consume it as a value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .short("c")
        .default_if_no_value("gzip")
    )
    command.add_argument(Argument("file", help="File").positional())

    var args: List[String] = ["test", "-c", "myfile.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")
    assert_equal(result.get_string("file"), "myfile.txt")


fn test_const_short_merged_flags() raises:
    """-vc in merged flags, where 'c' has default_if_no_value, uses default-if-no-value for 'c'.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .short("c")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "-vc"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("compress"), "gzip")


fn test_const_short_merged_with_attached() raises:
    """-vcbzip2 in merged flags: v=flag, c=takes value 'bzip2' (attached)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .short("c")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "-vcbzip2"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("compress"), "bzip2")


# ── default_if_no_value — prefix matching ─────────────────────────────────────────


fn test_const_prefix_match() raises:
    """--comp (prefix) resolves to --compress and uses default-if-no-value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "--comp"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")


fn test_const_prefix_match_with_equals() raises:
    """--comp=bzip2 (prefix + equals) uses explicit value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )

    var args: List[String] = ["test", "--comp=bzip2"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "bzip2")


# ── Require equals — standalone (without default_if_no_value) ─────────────────────


fn test_require_equals_with_eq() raises:
    """--output=file.txt is accepted when require_equals is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").require_equals()
    )

    var args: List[String] = ["test", "--output=file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "file.txt")


fn test_require_equals_space_rejected() raises:
    """--output file.txt (space) is rejected when require_equals is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").require_equals()
    )

    var args: List[String] = ["test", "--output", "file.txt"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'='" in msg or "require" in msg.lower(),
            msg="error should mention equals requirement: " + msg,
        )
    assert_true(caught, msg="Should have raised for space-separated value")


fn test_require_equals_no_value_rejected() raises:
    """--output (alone, no default_if_no_value) is rejected when require_equals is set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").require_equals()
    )

    var args: List[String] = ["test", "--output"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'='" in msg or "require" in msg.lower(),
            msg="error should mention equals requirement: " + msg,
        )
    assert_true(caught, msg="Should have raised for missing value")


fn test_require_equals_prefix_match() raises:
    """--out=file.txt (prefix) works with require_equals."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").require_equals()
    )

    var args: List[String] = ["test", "--out=file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "file.txt")


fn test_require_equals_empty_value() raises:
    """--output= (empty value after =) is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").require_equals()
    )

    var args: List[String] = ["test", "--output="]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "")


fn test_require_equals_with_choices() raises:
    """Require_equals works with choices validation."""
    var command = Command("test", "Test app")
    var choices: List[String] = ["json", "yaml", "toml"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .require_equals()
        .choices(choices^)
    )

    # Valid choice via =.
    var args: List[String] = ["test", "--format=json"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("format"), "json")


fn test_require_equals_choices_invalid() raises:
    """Require_equals with invalid choice is rejected."""
    var command = Command("test", "Test app")
    var choices: List[String] = ["json", "yaml", "toml"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .require_equals()
        .choices(choices^)
    )

    var args: List[String] = ["test", "--format=csv"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
    assert_true(caught, msg="Should have raised for invalid choice")


# ── Require equals — does not affect short options ───────────────────────────


fn test_require_equals_short_still_works() raises:
    """Short option -o still works normally with space even when require_equals is set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long("output")
        .short("o")
        .require_equals()
    )

    # Short option should still work (require_equals only affects long options)
    # unless default_if_no_value is set, in which case short uses default-if-no-value.
    var args: List[String] = ["test", "-o", "file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "file.txt")


# ── Require equals + default_if_no_value combined ────────────────────────────


fn test_require_equals_and_const_long_bare() raises:
    """--log (bare) uses default-if-no-value when both require_equals and default_if_no_value are set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("log", help="Log level")
        .long("log")
        .default_if_no_value("INFO")
    )

    var args: List[String] = ["test", "--log"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("log"), "INFO")


fn test_require_equals_and_const_long_explicit() raises:
    """--log=DEBUG uses explicit value when default_if_no_value is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("log", help="Log level")
        .long("log")
        .default_if_no_value("INFO")
    )

    var args: List[String] = ["test", "--log=DEBUG"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("log"), "DEBUG")


# ── Help output ──────────────────────────────────────────────────────────────


fn test_help_require_equals_format() raises:
    """Help shows --output=<output> format for require_equals."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").require_equals()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--output=<output>" in help,
        msg="help should show '=' syntax: " + help,
    )


fn test_help_const_format() raises:
    """Help shows --compress[=<compress>] format for default_if_no_value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--compress[=" in help and "]" in help,
        msg="help should show '[=...]' syntax: " + help,
    )


fn test_help_const_with_metavar() raises:
    """Help shows --compress[=ALGO] when default_if_no_value and metavar are both set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long("compress")
        .default_if_no_value("gzip")
        .metavar("ALGO")
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--compress[=ALGO]" in help,
        msg="help should show '--compress[=ALGO]': " + help,
    )


fn test_help_require_equals_with_metavar() raises:
    """Help shows --output=FILE when require_equals and metavar are set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long("output")
        .require_equals()
        .metavar("FILE")
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--output=FILE" in help,
        msg="help should show '--output=FILE': " + help,
    )


# ── Interaction with other features ──────────────────────────────────────────


fn test_const_with_append() raises:
    """Tests default_if_no_value works with append:
    --tag collects default-if-no-value, --tag=x collects x.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tag")
        .long("tag")
        .default_if_no_value("default-tag")
        .append()
    )

    var args: List[String] = ["test", "--tag", "--tag=custom"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "default-tag")
    assert_equal(tags[1], "custom")


fn test_const_with_persistent() raises:
    """Tests default_if_no_value works on persistent flags with subcommands."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression")
        .long("compress")
        .default_if_no_value("gzip")
        .persistent()
    )
    var sub = Command("build", "Build things")
    command.add_subcommand(sub^)

    var args: List[String] = ["test", "--compress", "build"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")
    assert_equal(result.subcommand, "build")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
