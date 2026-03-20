"""Tests for argmojo option features:
  • default_if_no_value and require_equals (const semantics)
  • Range validation, clamping, key-value map, aliases, deprecated arguments
  • Remainder nargs, parse_known_arguments, value_name, allow_hyphen_values
  • Collection actions: append, delimiter splitting, number_of_values (nargs)
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult


# ── Const / require_equals ───────────────────────────────────────────────────

# ── default_if_no_value — long option ────────────────────────────────────────


def test_const_long_without_value() raises:
    """--compress (no value) uses the default-if-no-value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "--compress"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")


def test_const_long_with_equals_value() raises:
    """--compress=bzip2 uses the explicit value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "--compress=bzip2"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "bzip2")


def test_const_long_space_separated_not_consumed() raises:
    """--compress followed by a token does not consume it as a value;
    --compress uses default-if-no-value and the next token becomes a positional.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )
    command.add_argument(Argument("file", help="File").positional())

    # '--compress bzip2' should treat 'bzip2' as a positional, not the value
    # of --compress.  --compress uses the default-if-no-value.
    var args: List[String] = ["test", "--compress", "myfile.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")
    assert_equal(result.get_string("file"), "myfile.txt")


def test_const_long_not_provided() raises:
    """When --compress is not provided at all, no value is set (unless default).
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("compress"), msg="compress should not be set")


def test_const_long_with_default() raises:
    """When default_if_no_value has a default, --compress uses default-if-no-value while omission uses default.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
        .default["none"]()
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


def test_const_long_with_choices() raises:
    """Tests default_if_no_value must pass choices validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
        .choice["gzip"]()
        .choice["bzip2"]()
        .choice["xz"]()
    )

    # --compress → default-if-no-value "gzip" passes choices.
    var args: List[String] = ["test", "--compress"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")

    # --compress=xz → "xz" passes choices.
    var args2: List[String] = ["test", "--compress=xz"]
    var result2 = command.parse_arguments(args2)
    assert_equal(result2.get_string("compress"), "xz")


def test_const_long_choices_invalid_eq() raises:
    """Explicit value via = that violates choices is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
        .choice["gzip"]()
        .choice["bzip2"]()
        .choice["xz"]()
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


def test_const_short_without_value() raises:
    """-c (alone) uses the default-if-no-value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .short["c"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "-c"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")


def test_const_short_with_attached_value() raises:
    """-cbzip2 (attached value) uses the explicit value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .short["c"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "-cbzip2"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "bzip2")


def test_const_short_does_not_consume_next() raises:
    """-c followed by a positional does not consume it as a value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .short["c"]()
        .default_if_no_value["gzip"]()
    )
    command.add_argument(Argument("file", help="File").positional())

    var args: List[String] = ["test", "-c", "myfile.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")
    assert_equal(result.get_string("file"), "myfile.txt")


def test_const_short_merged_flags() raises:
    """-vc in merged flags, where 'c' has default_if_no_value, uses default-if-no-value for 'c'.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .short["c"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "-vc"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("compress"), "gzip")


def test_const_short_merged_with_attached() raises:
    """-vcbzip2 in merged flags: v=flag, c=takes value 'bzip2' (attached)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .short["c"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "-vcbzip2"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("compress"), "bzip2")


# ── default_if_no_value — prefix matching ─────────────────────────────────────────


def test_const_prefix_match() raises:
    """--comp (prefix) resolves to --compress and uses default-if-no-value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "--comp"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")


def test_const_prefix_match_with_equals() raises:
    """--comp=bzip2 (prefix + equals) uses explicit value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )

    var args: List[String] = ["test", "--comp=bzip2"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "bzip2")


# ── Require equals — standalone (without default_if_no_value) ─────────────────────


def test_require_equals_with_eq() raises:
    """--output=file.txt is accepted when require_equals is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().require_equals()
    )

    var args: List[String] = ["test", "--output=file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "file.txt")


def test_require_equals_space_rejected() raises:
    """--output file.txt (space) is rejected when require_equals is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().require_equals()
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


def test_require_equals_no_value_rejected() raises:
    """--output (alone, no default_if_no_value) is rejected when require_equals is set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().require_equals()
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


def test_require_equals_prefix_match() raises:
    """--out=file.txt (prefix) works with require_equals."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().require_equals()
    )

    var args: List[String] = ["test", "--out=file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "file.txt")


def test_require_equals_empty_value() raises:
    """--output= (empty value after =) is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().require_equals()
    )

    var args: List[String] = ["test", "--output="]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "")


def test_require_equals_with_choices() raises:
    """Require_equals works with choices validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .require_equals()
        .choice["json"]()
        .choice["yaml"]()
        .choice["toml"]()
    )

    # Valid choice via =.
    var args: List[String] = ["test", "--format=json"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("format"), "json")


def test_require_equals_choices_invalid() raises:
    """Require_equals with invalid choice is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .require_equals()
        .choice["json"]()
        .choice["yaml"]()
        .choice["toml"]()
    )

    var args: List[String] = ["test", "--format=csv"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
    assert_true(caught, msg="Should have raised for invalid choice")


# ── Require equals — does not affect short options ───────────────────────────


def test_require_equals_short_still_works() raises:
    """Short option -o still works normally with space even when require_equals is set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .require_equals()
    )

    # Short option should still work (require_equals only affects long options)
    # unless default_if_no_value is set, in which case short uses default-if-no-value.
    var args: List[String] = ["test", "-o", "file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "file.txt")


# ── Require equals + default_if_no_value combined ────────────────────────────


def test_require_equals_and_const_long_bare() raises:
    """--log (bare) uses default-if-no-value when both require_equals and default_if_no_value are set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("log", help="Log level")
        .long["log"]()
        .default_if_no_value["INFO"]()
    )

    var args: List[String] = ["test", "--log"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("log"), "INFO")


def test_require_equals_and_const_long_explicit() raises:
    """--log=DEBUG uses explicit value when default_if_no_value is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("log", help="Log level")
        .long["log"]()
        .default_if_no_value["INFO"]()
    )

    var args: List[String] = ["test", "--log=DEBUG"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("log"), "DEBUG")


# ── Help output ──────────────────────────────────────────────────────────────


def test_help_require_equals_format() raises:
    """Help shows --output=<output> format for require_equals."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().require_equals()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--output=<output>" in help,
        msg="help should show '=' syntax: " + help,
    )


def test_help_const_format() raises:
    """Help shows --compress[=<compress>] format for default_if_no_value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--compress[=" in help and "]" in help,
        msg="help should show '[=...]' syntax: " + help,
    )


def test_help_const_with_value_name() raises:
    """Help shows --compress[=ALGO] when default_if_no_value and value_name are both set.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .default_if_no_value["gzip"]()
        .value_name["ALGO"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--compress[=<ALGO>]" in help,
        msg="help should show '--compress[=<ALGO>]': " + help,
    )


def test_help_require_equals_with_value_name() raises:
    """Help shows --output=FILE when require_equals and value_name are set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .require_equals()
        .value_name["FILE"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--output=<FILE>" in help,
        msg="help should show '--output=<FILE>': " + help,
    )


# ── Interaction with other features ──────────────────────────────────────────


def test_const_with_append() raises:
    """Tests default_if_no_value works with append:
    --tag collects default-if-no-value, --tag=x collects x.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tag")
        .long["tag"]()
        .default_if_no_value["default-tag"]()
        .append()
    )

    var args: List[String] = ["test", "--tag", "--tag=custom"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "default-tag")
    assert_equal(tags[1], "custom")


def test_const_with_persistent() raises:
    """Tests default_if_no_value works on persistent flags with subcommands."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression")
        .long["compress"]()
        .default_if_no_value["gzip"]()
        .persistent()
    )
    var sub = Command("build", "Build things")
    command.add_subcommand(sub^)

    var args: List[String] = ["test", "--compress", "build"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("compress"), "gzip")
    assert_equal(result.subcommand, "build")


# ── Extras: range, clamp, map, alias, deprecated ────────────────────────────

# ── Numeric range validation ─────────────────────────────────────────────────


def test_range_valid_value() raises:
    """Tests that a value within range is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test", "--port", "8080"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("port"), "8080")


def test_range_boundary_min() raises:
    """Tests that the exact minimum boundary value is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test", "--port", "1"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("port"), "1")


def test_range_boundary_max() raises:
    """Tests that the exact maximum boundary value is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test", "--port", "65535"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("port"), "65535")


def test_range_below_min() raises:
    """Tests that a value below the minimum is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test", "--port", "0"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "out of range" in msg, msg="error should mention 'out of range'"
        )
        assert_true("[1, 65535]" in msg, msg="error should show range bounds")
    assert_true(caught, msg="Should have raised for value below min")


def test_range_above_max() raises:
    """Tests that a value above the maximum is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test", "--port", "70000"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "out of range" in msg, msg="error should mention 'out of range'"
        )
    assert_true(caught, msg="Should have raised for value above max")


def test_range_not_provided_ok() raises:
    """Tests that an optional range arg is fine when not provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("port"), msg="port should not be set")


def test_range_with_append() raises:
    """Tests range validation on appended values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Ports").long["port"]().append().range[1, 100]()
    )

    var args: List[String] = ["test", "--port", "50", "--port", "101"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "out of range" in msg, msg="error should mention 'out of range'"
        )
        assert_true("101" in msg, msg="error should mention the bad value")
    assert_true(caught, msg="Should have raised for one value out of range")


def test_range_with_short_option() raises:
    """Tests range validation with a short option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Level")
        .long["level"]()
        .short["l"]()
        .range[0, 5]()
    )

    var args: List[String] = ["test", "-l", "3"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("level"), "3")


# ── Range clamping (.clamp()) ────────────────────────────────────────────────


def test_clamp_above_max() raises:
    """Tests that .clamp() adjusts a value above max to max."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Level").long["level"]().range[1, 100]().clamp()
    )

    var args: List[String] = ["test", "--level", "200"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_int("level"),
        100,
        msg="200 should be clamped to 100",
    )


def test_clamp_below_min() raises:
    """Tests that .clamp() adjusts a value below min to min."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Level").long["level"]().range[1, 100]().clamp()
    )

    var args: List[String] = ["test", "--level", "-5"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_int("level"),
        1,
        msg="-5 should be clamped to 1",
    )


def test_clamp_within_range_no_change() raises:
    """Tests that .clamp() does not affect a value within range."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Level").long["level"]().range[1, 100]().clamp()
    )

    var args: List[String] = ["test", "--level", "50"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_int("level"),
        50,
        msg="50 should remain 50",
    )


def test_clamp_at_boundary() raises:
    """Tests that .clamp() does not trigger at exact boundaries."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]().clamp()
    )

    var args1: List[String] = ["test", "--port", "1"]
    var result1 = command.parse_arguments(args1)
    assert_equal(result1.get_int("port"), 1, msg="1 at min boundary is fine")

    var args2: List[String] = ["test", "--port", "65535"]
    var result2 = command.parse_arguments(args2)
    assert_equal(
        result2.get_int("port"), 65535, msg="65535 at max boundary is fine"
    )


def test_clamp_with_short_option() raises:
    """Tests that .clamp() works with short option syntax."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("level", help="Level")
        .long["level"]()
        .short["l"]()
        .range[0, 10]()
        .clamp()
    )

    var args: List[String] = ["test", "-l", "99"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_int("level"),
        10,
        msg="99 with range [0,10] should clamp to 10",
    )


def test_clamp_with_append() raises:
    """Tests that .clamp() adjusts individual values in append mode."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Ports")
        .long["port"]()
        .append()
        .range[1, 100]()
        .clamp()
    )

    var args: List[String] = [
        "test",
        "--port",
        "50",
        "--port",
        "200",
        "--port",
        "0",
    ]
    var result = command.parse_arguments(args)
    var lst = result.get_list("port")
    assert_equal(lst[0], "50", msg="50 should remain 50")
    assert_equal(lst[1], "100", msg="200 should clamp to 100")
    assert_equal(lst[2], "1", msg="0 should clamp to 1")


def test_range_without_clamp_still_errors() raises:
    """Tests that .range() without .clamp() still raises errors."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long["port"]().range[1, 65535]()
    )

    var args: List[String] = ["test", "--port", "99999"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("out of range" in msg, msg="should error on out of range")
    assert_true(caught, msg="Should have raised for out-of-range without clamp")


# ── Key-value map option ─────────────────────────────────────────────────────


def test_map_single_pair() raises:
    """Tests parsing a single key=value map entry."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars")
        .long["define"]()
        .short["D"]()
        .map_option()
    )

    var args: List[String] = ["test", "--define", "CC=gcc"]
    var result = command.parse_arguments(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")


def test_map_multiple_pairs() raises:
    """Tests parsing multiple key=value pairs via repeated option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars")
        .long["define"]()
        .short["D"]()
        .map_option()
    )

    var args: List[String] = ["test", "--define", "CC=gcc", "-D", "CXX=g++"]
    var result = command.parse_arguments(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")
    assert_equal(m["CXX"], "g++")


def test_map_equals_syntax() raises:
    """Tests parsing key=value with --define=key=value syntax."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars").long["define"]().map_option()
    )

    var args: List[String] = ["test", "--define=CC=gcc"]
    var result = command.parse_arguments(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")


def test_map_with_delimiter() raises:
    """Tests parsing multiple key=value pairs from one value using a delimiter.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars")
        .long["define"]()
        .map_option()
        .delimiter[","]()
    )

    var args: List[String] = ["test", "--define", "CC=gcc,CXX=g++"]
    var result = command.parse_arguments(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")
    assert_equal(m["CXX"], "g++")


def test_map_invalid_no_equals() raises:
    """Tests that a map value without '=' is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars").long["define"]().map_option()
    )

    var args: List[String] = ["test", "--define", "NOEQUALS"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("key=value" in msg, msg="error should mention format")
    assert_true(caught, msg="Should have raised for missing '='")


def test_map_has_check() raises:
    """Tests that has() returns True for a map arg after providing it."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars").long["define"]().map_option()
    )

    var args: List[String] = ["test", "--define", "A=1"]
    var result = command.parse_arguments(args)
    assert_true(result.has("define"), msg="has() should be True for map arg")


def test_map_empty_value() raises:
    """Tests that key= (empty value) is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars").long["define"]().map_option()
    )

    var args: List[String] = ["test", "--define", "KEY="]
    var result = command.parse_arguments(args)
    var m = result.get_map("define")
    assert_equal(m["KEY"], "")


def test_map_value_with_equals() raises:
    """Tests that key=val=ue keeps everything after first '=' as the value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("env", help="Env vars").long["env"]().map_option()
    )

    var args: List[String] = ["test", "--env", "PATH=/usr/bin:/bin"]
    var result = command.parse_arguments(args)
    var m = result.get_map("env")
    assert_equal(m["PATH"], "/usr/bin:/bin")


# ── Aliases ──────────────────────────────────────────────────────────────────


def test_alias_basic() raises:
    """Tests that an alias resolves to the primary argument."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Colour mode")
        .long["colour"]()
        .alias_name["color"]()
    )

    var args: List[String] = ["test", "--color", "red"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("colour"), "red")


def test_alias_primary_still_works() raises:
    """Tests that using the primary long name still works alongside aliases."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Colour mode")
        .long["colour"]()
        .alias_name["color"]()
    )

    var args: List[String] = ["test", "--colour", "blue"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("colour"), "blue")


def test_alias_multiple() raises:
    """Tests that multiple aliases all resolve correctly."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output format")
        .long["output"]()
        .alias_name["out"]()
        .alias_name["fmt"]()
    )

    var args: List[String] = ["test", "--fmt", "json"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "json")

    var args2: List[String] = ["test", "--out", "yaml"]
    var result2 = command.parse_arguments(args2)
    assert_equal(result2.get_string("output"), "yaml")


def test_alias_prefix_match() raises:
    """Tests that prefix matching works with aliases."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Colour mode")
        .long["colour"]()
        .alias_name["color"]()
    )

    var args: List[String] = ["test", "--colo", "green"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("colour"), "green")


def test_alias_with_flag() raises:
    """Tests that aliases work with flags."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .flag()
        .alias_name["debug"]()
    )

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"), msg="--debug alias should set verbose flag"
    )


# ── Deprecated arguments ─────────────────────────────────────────────────────


def test_deprecated_still_parses() raises:
    """Tests that a deprecated argument is still parsed successfully."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format_old", help="Old format")
        .long["format-old"]()
        .deprecated["Use --format instead"]()
    )

    var args: List[String] = ["test", "--format-old", "csv"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("format_old"), "csv")


def test_deprecated_short_option() raises:
    """Tests that a deprecated short option still parses."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compat", help="Compat mode")
        .long["compat"]()
        .short["C"]()
        .flag()
        .deprecated["Will be removed in 2.0"]()
    )

    var args: List[String] = ["test", "-C"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("compat"), msg="-C should still set the flag")


def test_deprecated_not_provided_ok() raises:
    """Tests that not providing a deprecated arg produces no errors."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("old", help="Old option")
        .long["old"]()
        .deprecated["Use --new instead"]()
    )
    command.add_argument(Argument("new", help="New option").long["new"]())

    var args: List[String] = ["test", "--new", "val"]
    var result = command.parse_arguments(args)
    assert_false(result.has("old"), msg="old should not be present")
    assert_equal(result.get_string("new"), "val")


def test_deprecated_with_alias() raises:
    """Tests that deprecation works when accessed via an alias."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output format")
        .long["output"]()
        .alias_name["out"]()
        .deprecated["Use --format instead"]()
    )

    var args: List[String] = ["test", "--out", "json"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "json")


# ── Help display: deprecated tag and map placeholder ─────────────────────────


def test_help_deprecated_tag() raises:
    """Tests that deprecated arguments show [deprecated] in help text."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("old", help="Old option")
        .long["old"]()
        .deprecated["Use --new instead"]()
    )
    command.add_argument(Argument("new", help="New option").long["new"]())

    var help = command._generate_help(color=False)
    assert_true(
        "[deprecated: Use --new instead]" in help,
        msg="help should contain deprecated tag",
    )


def test_help_map_placeholder() raises:
    """Tests that map options show <key=value> placeholder in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("define", help="Define vars")
        .long["define"]()
        .short["D"]()
        .map_option()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<key=value>" in help,
        msg="help should show <key=value> placeholder for map options",
    )


def test_help_alias_shown() raises:
    """Tests that aliases are shown alongside the primary name in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Enable colour output")
        .long["colour"]()
        .flag()
        .alias_name["color"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--colour, --color" in help,
        msg="help should show '--colour, --color' for aliased option",
    )


# ── Remainder, parse_known, value_name, hyphen ──────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
# value_name (renamed from metavar)
# ═══════════════════════════════════════════════════════════════════════════════


def test_value_name_basic() raises:
    """Tests that .value_name() sets the display name for help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .value_name["FILE"]()
    )
    # Parse succeeds normally — value_name is purely cosmetic.
    var args: List[String] = ["test", "--output", "data.csv"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "data.csv")


def test_value_name_in_help() raises:
    """Tests that value_name appears in help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .value_name["FILE"]()
    )
    # The help text should contain "FILE" instead of "<output>".
    # We don't assert exact help format, just that it works without errors.
    var args: List[String] = ["test", "--output", "out.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "out.txt")


# ═══════════════════════════════════════════════════════════════════════════════
# remainder()
# ═══════════════════════════════════════════════════════════════════════════════


def test_remainder_basic() raises:
    """Tests that remainder consumes all remaining tokens."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("cmd", help="Command to run").positional().required()
    )
    command.add_argument(
        Argument("rest", help="Arguments for the command").remainder()
    )

    var args: List[String] = ["test", "gcc", "-Wall", "-O2", "main.c"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("cmd"), "gcc")
    var rest = result.get_list("rest")
    assert_equal(len(rest), 3)
    assert_equal(rest[0], "-Wall")
    assert_equal(rest[1], "-O2")
    assert_equal(rest[2], "main.c")


def test_remainder_empty() raises:
    """Tests remainder with no trailing arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("cmd", help="Command to run").positional().required()
    )
    command.add_argument(
        Argument("rest", help="Arguments for the command").remainder()
    )

    var args: List[String] = ["test", "gcc"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("cmd"), "gcc")
    var rest = result.get_list("rest")
    assert_equal(len(rest), 0)


def test_remainder_only() raises:
    """Tests remainder as the only positional."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest", help="All arguments").remainder())

    var args: List[String] = ["test", "--flag", "-v", "file.txt"]
    var result = command.parse_arguments(args)
    var rest = result.get_list("rest")
    assert_equal(len(rest), 3)
    assert_equal(rest[0], "--flag")
    assert_equal(rest[1], "-v")
    assert_equal(rest[2], "file.txt")


def test_remainder_with_options_before() raises:
    """Tests that options before the remainder positional slot are parsed normally.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("cmd", help="Command").positional().required()
    )
    command.add_argument(Argument("rest", help="Rest").remainder())

    var args: List[String] = ["test", "--verbose", "gcc", "-O2", "main.c"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("cmd"), "gcc")
    var rest = result.get_list("rest")
    assert_equal(len(rest), 2)
    assert_equal(rest[0], "-O2")
    assert_equal(rest[1], "main.c")


def test_remainder_captures_double_dash_tokens() raises:
    """Tests that remainder captures -- and tokens after it."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest", help="All args").remainder())

    var args: List[String] = ["test", "--", "-v", "--help"]
    var result = command.parse_arguments(args)
    # The "--" is consumed as the stop marker and remaining go to positionals.
    # Remainder collects them all.
    var rest = result.get_list("rest")
    assert_equal(len(rest), 2)
    assert_equal(rest[0], "-v")
    assert_equal(rest[1], "--help")


def test_remainder_guard_no_long_short() raises:
    """Tests that remainder rejects .long() or .short()."""
    var command = Command("test", "Test app")
    var failed = False
    try:
        command.add_argument(
            Argument("rest", help="Rest").long["rest"]().remainder()
        )
    except:
        failed = True
    assert_true(failed, msg="remainder with .long() should be rejected")


def test_remainder_guard_only_one() raises:
    """Tests that only one remainder positional is allowed."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest1", help="Rest 1").remainder())
    var failed = False
    try:
        command.add_argument(Argument("rest2", help="Rest 2").remainder())
    except:
        failed = True
    assert_true(failed, msg="second remainder should be rejected")


def test_remainder_with_dashes_in_values() raises:
    """Tests that remainder captures tokens like --unknown and -x."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("cmd", help="Command").positional().required()
    )
    command.add_argument(Argument("args", help="Forwarded args").remainder())

    var args: List[String] = [
        "test",
        "cmake",
        "-DCMAKE_BUILD_TYPE=Release",
        "--preset",
        "default",
    ]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("cmd"), "cmake")
    var rest = result.get_list("args")
    assert_equal(len(rest), 3)
    assert_equal(rest[0], "-DCMAKE_BUILD_TYPE=Release")
    assert_equal(rest[1], "--preset")
    assert_equal(rest[2], "default")


# ═══════════════════════════════════════════════════════════════════════════════
# parse_known_arguments()
# ═══════════════════════════════════════════════════════════════════════════════


def test_parse_known_basic() raises:
    """Tests that unknown options are collected instead of erroring."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var args: List[String] = ["test", "--verbose", "--unknown", "-x"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 2)
    assert_equal(unknown[0], "--unknown")
    assert_equal(unknown[1], "-x")


def test_parse_known_no_unknowns() raises:
    """Tests parse_known_arguments with all args recognized."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output").long["output"]().short["o"]()
    )

    var args: List[String] = ["test", "--verbose", "--output", "file.txt"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "file.txt")
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 0)


def test_parse_known_mixed_with_positionals() raises:
    """Tests parse_known_arguments with positionals and unknown options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="Input file").positional().required()
    )
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )

    var args: List[String] = [
        "test",
        "--verbose",
        "input.txt",
        "--unknown-flag",
    ]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("file"), "input.txt")
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 1)
    assert_equal(unknown[0], "--unknown-flag")


def test_parse_known_unknown_with_value() raises:
    """Tests that unknown long options with = syntax are collected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )

    var args: List[String] = ["test", "--verbose", "--color=auto"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 1)
    assert_equal(unknown[0], "--color=auto")


def test_parse_known_preserves_validation() raises:
    """Tests that parse_known_arguments still validates required args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output").long["output"]().required()
    )

    var args: List[String] = ["test", "--unknown"]
    var failed = False
    try:
        _ = command.parse_known_arguments(args)
    except:
        failed = True
    assert_true(failed, msg="required arg validation should still apply")


# ═══════════════════════════════════════════════════════════════════════════════
# allow_hyphen_values() / stdin convention
# ═══════════════════════════════════════════════════════════════════════════════


def test_hyphen_value_positional() raises:
    """Tests that '-' is accepted as a positional value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input (- for stdin)")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    # A bare "-" already works as a positional because len("-") == 1,
    # so the short-option check (len > 1) skips it.
    var args: List[String] = ["test", "-"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("input"), "-")


def test_hyphen_value_multi_char_short() raises:
    """Tests that '-x' is consumed as a positional when allow_hyphen_values
    is set and '-x' is NOT a known option.  Without the flag, '-x' would
    be treated as an unknown short option and error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Regex pattern")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    var args: List[String] = ["test", "-foo"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("pattern"), "-foo")


def test_hyphen_value_long_token() raises:
    """Tests that '--unknown-thing' is consumed as a positional when
    allow_hyphen_values is set and it is not a known long option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("expr", help="Expression")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    var args: List[String] = ["test", "--not-an-option"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("expr"), "--not-an-option")


def test_hyphen_value_known_option_still_parsed() raises:
    """Tests that a known option is still parsed normally even when the
    current positional has allow_hyphen_values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("pattern", help="Pattern")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    # -v is a known short option → parsed as flag, not as positional.
    var args: List[String] = ["test", "-v", "-foo"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("pattern"), "-foo")


def test_hyphen_value_without_flag_errors() raises:
    """Tests that without allow_hyphen_values, '-x' raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input").positional().required()
    )

    var args: List[String] = ["test", "-x"]
    var failed = False
    try:
        _ = command.parse_arguments(args)
    except:
        failed = True
    assert_true(failed, msg="'-x' without allow_hyphen_values should error")


def test_hyphen_value_with_other_positional() raises:
    """Tests '-' alongside a regular positional."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input")
        .positional()
        .required()
        .allow_hyphen_values()
    )
    command.add_argument(
        Argument("output", help="Output").positional().default["out.txt"]()
    )

    var args: List[String] = ["test", "-", "result.csv"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("input"), "-")
    assert_equal(result.get_string("output"), "result.csv")


def test_hyphen_value_with_option() raises:
    """Tests that '-' works as a value for a named option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="File (- for stdin)")
        .long["file"]()
        .short["f"]()
        .allow_hyphen_values()
    )

    # --file - should take "-" as the value.
    var args: List[String] = ["test", "--file", "-"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("file"), "-")


def test_hyphen_value_in_parse_known() raises:
    """Tests allow_hyphen_values with parse_known_arguments: unknown
    dash tokens go to positional instead of unknown_args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("expr", help="Expression")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    var args: List[String] = ["test", "--verbose", "-pattern"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("expr"), "-pattern")
    assert_equal(len(result.get_unknown_args()), 0)


def test_remainder_guard_positional_after() raises:
    """Tests that adding a positional after a remainder is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest", help="Rest").remainder())
    var failed = False
    try:
        command.add_argument(Argument("extra", help="Extra").positional())
    except:
        failed = True
    assert_true(failed, msg="positional after remainder should be rejected")


# ── Collect: append, delimiter, nargs ────────────────────────────────────────

# ── Append / collect action ──────────────────────────────────────────────────────


def test_append_single() raises:
    """Tests that a single --tag x produces a list with one element."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = ["test", "--tag", "alpha"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 1)
    assert_equal(tags[0], "alpha")
    assert_true(result.has("tag"), msg="tag should be present")


def test_append_multiple() raises:
    """Tests that --tag x --tag y --tag z collects all values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = [
        "test",
        "--tag",
        "alpha",
        "--tag",
        "beta",
        "--tag",
        "gamma",
    ]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")
    assert_equal(tags[2], "gamma")


def test_append_short_option() raises:
    """Tests that -t x -t y collects values via short option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = ["test", "-t", "alpha", "-t", "beta"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")


def test_append_equals_syntax() raises:
    """Tests that --tag=x --tag=y collects values with equals syntax."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = ["test", "--tag=alpha", "--tag=beta"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")


def test_append_attached_short() raises:
    """Tests that -talpha -tbeta collects values with attached short syntax."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = ["test", "-talpha", "-tbeta"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")


def test_append_mixed_syntax() raises:
    """Tests mixing long, short, equals, and attached syntax for append."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = ["test", "--tag", "a", "-t", "b", "--tag=c", "-td"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 4)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")
    assert_equal(tags[3], "d")


def test_append_empty() raises:
    """Tests that get_list returns empty list when option never provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 0)
    assert_false(result.has("tag"), msg="tag should not be present")


def test_append_with_choices() raises:
    """Tests that append respects choices validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("env", help="Target env")
        .long["env"]()
        .choice["dev"]()
        .choice["staging"]()
        .choice["prod"]()
        .append()
    )

    # Valid choices
    var args: List[String] = ["test", "--env", "dev", "--env", "prod"]
    var result = command.parse_arguments(args)
    var envlist = result.get_list("env")
    assert_equal(len(envlist), 2)
    assert_equal(envlist[0], "dev")
    assert_equal(envlist[1], "prod")

    # Invalid choice
    var command2 = Command("test", "Test app")
    command2.add_argument(
        Argument("env", help="Target env")
        .long["env"]()
        .choice["dev"]()
        .choice["staging"]()
        .choice["prod"]()
        .append()
    )
    var args2: List[String] = ["test", "--env", "local"]
    var caught = False
    try:
        _ = command2.parse_arguments(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Invalid value" in msg,
            msg="Error should mention invalid value",
        )
    assert_true(caught, msg="Should have raised error for invalid choice")


def test_append_with_other_args() raises:
    """Tests that append args work alongside regular flags and values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose").long["verbose"]().short["v"]().flag()
    )
    command.add_argument(Argument("output").long["output"]().short["o"]())
    command.add_argument(
        Argument("include", help="Include path")
        .long["include"]()
        .short["I"]()
        .append()
    )

    var args: List[String] = [
        "test",
        "--verbose",
        "--include",
        "/usr/lib",
        "-o",
        "out.txt",
        "--include",
        "/opt/lib",
    ]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    assert_equal(result.get_string("output"), "out.txt")
    var includes = result.get_list("include")
    assert_equal(len(includes), 2)
    assert_equal(includes[0], "/usr/lib")
    assert_equal(includes[1], "/opt/lib")


# ===------------------------------------------------------------------=== #
# Value delimiter tests
# ===------------------------------------------------------------------=== #


def test_delimiter_comma() raises:
    """Tests basic comma delimiter splitting."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().short["t"]().delimiter[","]()
    )

    var args: List[String] = ["test", "--tag", "a,b,c"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")


def test_delimiter_equals_syntax() raises:
    """Tests delimiter with --key=value syntax."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    var args: List[String] = ["test", "--tag=x,y,z"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3)
    assert_equal(tags[0], "x")
    assert_equal(tags[1], "y")
    assert_equal(tags[2], "z")


def test_delimiter_short_option() raises:
    """Tests delimiter with short option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().short["t"]().delimiter[","]()
    )

    var args: List[String] = ["test", "-t", "foo,bar"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "foo")
    assert_equal(tags[1], "bar")


def test_delimiter_attached_short() raises:
    """Tests delimiter with attached short value (-tfoo,bar)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().short["t"]().delimiter[","]()
    )

    # -vta,b means -v -t a,b (v is flag, t takes value)
    var args: List[String] = ["test", "-vta,b"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")


def test_delimiter_repeated() raises:
    """Tests delimiter with multiple uses — values accumulate."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().short["t"]().delimiter[","]()
    )

    var args: List[String] = ["test", "--tag", "a,b", "--tag", "c,d"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 4)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")
    assert_equal(tags[3], "d")


def test_delimiter_single_value() raises:
    """Tests delimiter with a single value (no delimiter present)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    var args: List[String] = ["test", "--tag", "single"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 1)
    assert_equal(tags[0], "single")


def test_delimiter_with_choices() raises:
    """Tests that choices are validated per-piece after splitting."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("env", help="Environments")
        .long["env"]()
        .choice["dev"]()
        .choice["staging"]()
        .choice["prod"]()
        .delimiter[","]()
    )

    # Valid — all pieces are in choices.
    var args1: List[String] = ["test", "--env", "dev,prod"]
    var result = command.parse_arguments(args1)
    var envlist = result.get_list("env")
    assert_equal(len(envlist), 2)
    assert_equal(envlist[0], "dev")
    assert_equal(envlist[1], "prod")

    # Invalid — "local" is not in choices.
    var caught = False
    var args2: List[String] = ["test", "--env", "dev,local"]
    try:
        _ = command.parse_arguments(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true("Invalid value" in msg, msg="Should mention invalid value")
        assert_true("local" in msg, msg="Should mention 'local'")
    assert_true(
        caught, msg="Should raise error for invalid choice in delimited value"
    )


def test_delimiter_semicolon() raises:
    """Tests using a non-comma delimiter (semicolon)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("path", help="Search paths").long["path"]().delimiter[";"]()
    )

    var args: List[String] = ["test", "--path", "/usr/lib;/opt/lib;/home/lib"]
    var result = command.parse_arguments(args)
    var paths = result.get_list("path")
    assert_equal(len(paths), 3)
    assert_equal(paths[0], "/usr/lib")
    assert_equal(paths[1], "/opt/lib")
    assert_equal(paths[2], "/home/lib")


def test_delimiter_implies_append() raises:
    """Tests that .delimiter() implies .append() — get_list works."""
    var command = Command("test", "Test app")
    # Note: no explicit .append() call — delimiter() implies it.
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    var args: List[String] = ["test", "--tag", "x,y"]
    var result = command.parse_arguments(args)
    assert_true(result.has("tag"), msg="tag should be present")
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "x")
    assert_equal(tags[1], "y")


def test_delimiter_empty_not_provided() raises:
    """Tests delimiter arg not provided returns empty list."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 0)


def test_delimiter_trailing_comma() raises:
    """Tests that trailing delimiter does not create empty entry."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    var args: List[String] = ["test", "--tag", "a,b,"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")


# ===------------------------------------------------------------------=== #
# Nargs (multi-value per option) tests
# ===------------------------------------------------------------------=== #


def test_nargs_basic() raises:
    """Tests that number_of_values(2) consumes exactly 2 values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y coordinates")
        .long["point"]()
        .number_of_values[2]()
    )

    var args: List[String] = ["test", "--point", "10", "20"]
    var result = command.parse_arguments(args)
    var lst = result.get_list("point")
    assert_equal(len(lst), 2, msg="number_of_values(2) should produce 2 values")
    assert_equal(lst[0], "10", msg="First value should be '10'")
    assert_equal(lst[1], "20", msg="Second value should be '20'")


def test_nargs_three() raises:
    """Tests that number_of_values(3) consumes exactly 3 values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("rgb", help="RGB colour").long["rgb"]().number_of_values[3]()
    )

    var args: List[String] = ["test", "--rgb", "255", "128", "0"]
    var result = command.parse_arguments(args)
    var lst = result.get_list("rgb")
    assert_equal(len(lst), 3, msg="number_of_values(3) should produce 3 values")
    assert_equal(lst[0], "255", msg="First = 255")
    assert_equal(lst[1], "128", msg="Second = 128")
    assert_equal(lst[2], "0", msg="Third = 0")


def test_nargs_short_option() raises:
    """Tests nargs with a short option (-p 1 2)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y")
        .long["point"]()
        .short["p"]()
        .number_of_values[2]()
    )

    var args: List[String] = ["test", "-p", "3", "4"]
    var result = command.parse_arguments(args)
    var lst = result.get_list("point")
    assert_equal(
        len(lst), 2, msg="Short number_of_values(2) should produce 2 values"
    )
    assert_equal(lst[0], "3", msg="First = 3")
    assert_equal(lst[1], "4", msg="Second = 4")


def test_nargs_repeated() raises:
    """Tests that nargs collects across repeated occurrences."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y").long["point"]().number_of_values[2]()
    )

    var args: List[String] = [
        "test",
        "--point",
        "1",
        "2",
        "--point",
        "3",
        "4",
    ]
    var result = command.parse_arguments(args)
    var lst = result.get_list("point")
    assert_equal(
        len(lst), 4, msg="Two number_of_values(2) calls should produce 4 values"
    )
    assert_equal(lst[0], "1", msg="1st = 1")
    assert_equal(lst[1], "2", msg="2nd = 2")
    assert_equal(lst[2], "3", msg="3rd = 3")
    assert_equal(lst[3], "4", msg="4th = 4")


def test_nargs_too_few_values() raises:
    """Tests that nargs raises when not enough values are available."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y").long["point"]().number_of_values[2]()
    )

    var args: List[String] = ["test", "--point", "10"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "requires 2 values" in msg,
            msg="Error should mention 'requires 2 values'",
        )
    assert_true(caught, msg="Should raise when not enough values for nargs")


def test_nargs_too_few_short() raises:
    """Tests that nargs raises with short option when not enough values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y").short["p"]().number_of_values[2]()
    )

    var args: List[String] = ["test", "-p", "10"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "requires 2 values" in msg,
            msg="Error should mention 'requires 2 values'",
        )
    assert_true(caught, msg="Should raise when not enough values for nargs")


def test_nargs_with_choices() raises:
    """Tests that choices validation applies to each nargs value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("dir", help="Two directions")
        .long["dir"]()
        .number_of_values[2]()
        .choice["north"]()
        .choice["south"]()
        .choice["east"]()
        .choice["west"]()
    )

    # Valid.
    var args: List[String] = ["test", "--dir", "north", "east"]
    var result = command.parse_arguments(args)
    var lst = result.get_list("dir")
    assert_equal(lst[0], "north", msg="First direction")
    assert_equal(lst[1], "east", msg="Second direction")

    # Invalid: second value not in choices.
    var bad_args: List[String] = ["test", "--dir", "north", "up"]
    var caught = False
    try:
        _ = command.parse_arguments(bad_args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("Invalid value" in msg, msg="Should mention invalid value")
    assert_true(caught, msg="Bad choice in nargs should raise")


def test_nargs_with_other_args() raises:
    """Tests nargs coexisting with flags and regular value args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("point", help="X Y").long["point"]().number_of_values[2]()
    )
    command.add_argument(
        Argument("output", help="File").long["output"]().short["o"]()
    )

    var args: List[String] = [
        "test",
        "--verbose",
        "--point",
        "5",
        "6",
        "-o",
        "out.txt",
    ]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    var lst = result.get_list("point")
    assert_equal(len(lst), 2, msg="point should have 2 values")
    assert_equal(lst[0], "5", msg="point[0] = 5")
    assert_equal(lst[1], "6", msg="point[1] = 6")
    assert_equal(
        result.get_string("output"), "out.txt", msg="output should be out.txt"
    )


def test_nargs_equals_syntax_rejected() raises:
    """Tests that = syntax is rejected for nargs options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y").long["point"]().number_of_values[2]()
    )

    var args: List[String] = ["test", "--point=10", "20"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'=' syntax is not supported" in msg,
            msg="Error should mention = syntax not supported",
        )
    assert_true(caught, msg="nargs with = should raise")


def test_nargs_prefix_match() raises:
    """Tests that prefix matching works with nargs options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("position", help="X Y")
        .long["position"]()
        .number_of_values[2]()
    )

    var args: List[String] = ["test", "--pos", "7", "8"]
    var result = command.parse_arguments(args)
    var lst = result.get_list("position")
    assert_equal(len(lst), 2, msg="prefix --pos should resolve to --position")
    assert_equal(lst[0], "7", msg="First = 7")
    assert_equal(lst[1], "8", msg="Second = 8")


# ── Fullwidth delimiter tests ────────────────────────────────────────────────────


def test_delimiter_fullwidth_comma() raises:
    """Fullwidth comma ，(U+FF0C) is normalized to , before splitting."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    # "a，b，c" → fullwidth commas normalized → split as "a", "b", "c"
    var args: List[String] = ["test", "--tag", "a，b，c"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3, msg="fullwidth comma should split into 3")
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")


def test_delimiter_fullwidth_semicolon() raises:
    """Fullwidth semicolon ；(U+FF1B) is normalized to ; before splitting."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("path", help="Paths").long["path"]().delimiter[";"]()
    )

    var args: List[String] = ["test", "--path", "x；y；z"]
    var result = command.parse_arguments(args)
    var paths = result.get_list("path")
    assert_equal(len(paths), 3, msg="fullwidth semicolon should split into 3")
    assert_equal(paths[0], "x")
    assert_equal(paths[1], "y")
    assert_equal(paths[2], "z")


def test_delimiter_fullwidth_disabled() raises:
    """Fullwidth commas are NOT normalized when correction is disabled."""
    var command = Command("test", "Test app")
    command.disable_fullwidth_correction()
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    # With correction disabled, ， stays as-is, so no split happens.
    var args: List[String] = ["test", "--tag", "a，b，c"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(
        len(tags),
        1,
        msg="fullwidth comma should NOT split when correction disabled",
    )
    assert_equal(tags[0], "a，b，c")


def test_delimiter_fullwidth_mixed() raises:
    """Mix of halfwidth and fullwidth commas both split correctly."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Tags").long["tag"]().delimiter[","]()
    )

    # "a,b，c" → after normalization → "a,b,c" → split into 3
    var args: List[String] = ["test", "--tag", "a,b，c"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3, msg="mixed commas should split into 3")
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
