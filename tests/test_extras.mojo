"""Tests for argmojo — range validation, key-value map, aliases, deprecated arguments."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Arg, Command, ParseResult

# ── Numeric range validation ─────────────────────────────────────────────────


fn test_range_valid_value() raises:
    """Tests that a value within range is accepted."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 65535))

    var args: List[String] = ["test", "--port", "8080"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("port"), "8080")
    print("  ✓ test_range_valid_value")


fn test_range_boundary_min() raises:
    """Tests that the exact minimum boundary value is accepted."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 65535))

    var args: List[String] = ["test", "--port", "1"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("port"), "1")
    print("  ✓ test_range_boundary_min")


fn test_range_boundary_max() raises:
    """Tests that the exact maximum boundary value is accepted."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 65535))

    var args: List[String] = ["test", "--port", "65535"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("port"), "65535")
    print("  ✓ test_range_boundary_max")


fn test_range_below_min() raises:
    """Tests that a value below the minimum is rejected."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 65535))

    var args: List[String] = ["test", "--port", "0"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "out of range" in msg, msg="error should mention 'out of range'"
        )
        assert_true("[1, 65535]" in msg, msg="error should show range bounds")
    assert_true(caught, msg="Should have raised for value below min")
    print("  ✓ test_range_below_min")


fn test_range_above_max() raises:
    """Tests that a value above the maximum is rejected."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 65535))

    var args: List[String] = ["test", "--port", "70000"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "out of range" in msg, msg="error should mention 'out of range'"
        )
    assert_true(caught, msg="Should have raised for value above max")
    print("  ✓ test_range_above_max")


fn test_range_not_provided_ok() raises:
    """Tests that an optional range arg is fine when not provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 65535))

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_false(result.has("port"), msg="port should not be set")
    print("  ✓ test_range_not_provided_ok")


fn test_range_with_append() raises:
    """Tests range validation on appended values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Ports").long("port").append().range(1, 100))

    var args: List[String] = ["test", "--port", "50", "--port", "101"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "out of range" in msg, msg="error should mention 'out of range'"
        )
        assert_true("101" in msg, msg="error should mention the bad value")
    assert_true(caught, msg="Should have raised for one value out of range")
    print("  ✓ test_range_with_append")


fn test_range_with_short_option() raises:
    """Tests range validation with a short option."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("level", help="Level").long("level").short("l").range(0, 5))

    var args: List[String] = ["test", "-l", "3"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("level"), "3")
    print("  ✓ test_range_with_short_option")


# ── Key-value map option ─────────────────────────────────────────────────────


fn test_map_single_pair() raises:
    """Tests parsing a single key=value map entry."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("define", help="Define vars").long("define").short("D").map_option()
    )

    var args: List[String] = ["test", "--define", "CC=gcc"]
    var result = cmd.parse_args(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")
    print("  ✓ test_map_single_pair")


fn test_map_multiple_pairs() raises:
    """Tests parsing multiple key=value pairs via repeated option."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("define", help="Define vars").long("define").short("D").map_option()
    )

    var args: List[String] = ["test", "--define", "CC=gcc", "-D", "CXX=g++"]
    var result = cmd.parse_args(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")
    assert_equal(m["CXX"], "g++")
    print("  ✓ test_map_multiple_pairs")


fn test_map_equals_syntax() raises:
    """Tests parsing key=value with --define=key=value syntax."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("define", help="Define vars").long("define").map_option())

    var args: List[String] = ["test", "--define=CC=gcc"]
    var result = cmd.parse_args(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")
    print("  ✓ test_map_equals_syntax")


fn test_map_with_delimiter() raises:
    """Tests parsing multiple key=value pairs from one value using a delimiter.
    """
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("define", help="Define vars")
        .long("define")
        .map_option()
        .delimiter(",")
    )

    var args: List[String] = ["test", "--define", "CC=gcc,CXX=g++"]
    var result = cmd.parse_args(args)
    var m = result.get_map("define")
    assert_equal(m["CC"], "gcc")
    assert_equal(m["CXX"], "g++")
    print("  ✓ test_map_with_delimiter")


fn test_map_invalid_no_equals() raises:
    """Tests that a map value without '=' is rejected."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("define", help="Define vars").long("define").map_option())

    var args: List[String] = ["test", "--define", "NOEQUALS"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("key=value" in msg, msg="error should mention format")
    assert_true(caught, msg="Should have raised for missing '='")
    print("  ✓ test_map_invalid_no_equals")


fn test_map_has_check() raises:
    """Tests that has() returns True for a map arg after providing it."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("define", help="Define vars").long("define").map_option())

    var args: List[String] = ["test", "--define", "A=1"]
    var result = cmd.parse_args(args)
    assert_true(result.has("define"), msg="has() should be True for map arg")
    print("  ✓ test_map_has_check")


fn test_map_empty_value() raises:
    """Tests that key= (empty value) is accepted."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("define", help="Define vars").long("define").map_option())

    var args: List[String] = ["test", "--define", "KEY="]
    var result = cmd.parse_args(args)
    var m = result.get_map("define")
    assert_equal(m["KEY"], "")
    print("  ✓ test_map_empty_value")


fn test_map_value_with_equals() raises:
    """Tests that key=val=ue keeps everything after first '=' as the value."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("env", help="Env vars").long("env").map_option())

    var args: List[String] = ["test", "--env", "PATH=/usr/bin:/bin"]
    var result = cmd.parse_args(args)
    var m = result.get_map("env")
    assert_equal(m["PATH"], "/usr/bin:/bin")
    print("  ✓ test_map_value_with_equals")


# ── Aliases ──────────────────────────────────────────────────────────────────


fn test_alias_basic() raises:
    """Tests that an alias resolves to the primary argument."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["color"]
    cmd.add_arg(
        Arg("colour", help="Colour mode").long("colour").aliases(alias_list^)
    )

    var args: List[String] = ["test", "--color", "red"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("colour"), "red")
    print("  ✓ test_alias_basic")


fn test_alias_primary_still_works() raises:
    """Tests that using the primary long name still works alongside aliases."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["color"]
    cmd.add_arg(
        Arg("colour", help="Colour mode").long("colour").aliases(alias_list^)
    )

    var args: List[String] = ["test", "--colour", "blue"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("colour"), "blue")
    print("  ✓ test_alias_primary_still_works")


fn test_alias_multiple() raises:
    """Tests that multiple aliases all resolve correctly."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["out", "fmt"]
    cmd.add_arg(
        Arg("output", help="Output format").long("output").aliases(alias_list^)
    )

    var args: List[String] = ["test", "--fmt", "json"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "json")

    var args2: List[String] = ["test", "--out", "yaml"]
    var result2 = cmd.parse_args(args2)
    assert_equal(result2.get_string("output"), "yaml")
    print("  ✓ test_alias_multiple")


fn test_alias_prefix_match() raises:
    """Tests that prefix matching works with aliases."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["color"]
    cmd.add_arg(
        Arg("colour", help="Colour mode").long("colour").aliases(alias_list^)
    )

    var args: List[String] = ["test", "--colo", "green"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("colour"), "green")
    print("  ✓ test_alias_prefix_match")


fn test_alias_with_flag() raises:
    """Tests that aliases work with flags."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["debug"]
    cmd.add_arg(
        Arg("verbose", help="Verbose output")
        .long("verbose")
        .flag()
        .aliases(alias_list^)
    )

    var args: List[String] = ["test", "--debug"]
    var result = cmd.parse_args(args)
    assert_true(
        result.get_flag("verbose"), msg="--debug alias should set verbose flag"
    )
    print("  ✓ test_alias_with_flag")


# ── Deprecated arguments ─────────────────────────────────────────────────────


fn test_deprecated_still_parses() raises:
    """Tests that a deprecated argument is still parsed successfully."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("format_old", help="Old format")
        .long("format-old")
        .deprecated("Use --format instead")
    )

    var args: List[String] = ["test", "--format-old", "csv"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("format_old"), "csv")
    print("  ✓ test_deprecated_still_parses")


fn test_deprecated_short_option() raises:
    """Tests that a deprecated short option still parses."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("compat", help="Compat mode")
        .long("compat")
        .short("C")
        .flag()
        .deprecated("Will be removed in 2.0")
    )

    var args: List[String] = ["test", "-C"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("compat"), msg="-C should still set the flag")
    print("  ✓ test_deprecated_short_option")


fn test_deprecated_not_provided_ok() raises:
    """Tests that not providing a deprecated arg produces no errors."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("old", help="Old option")
        .long("old")
        .deprecated("Use --new instead")
    )
    cmd.add_arg(Arg("new", help="New option").long("new"))

    var args: List[String] = ["test", "--new", "val"]
    var result = cmd.parse_args(args)
    assert_false(result.has("old"), msg="old should not be present")
    assert_equal(result.get_string("new"), "val")
    print("  ✓ test_deprecated_not_provided_ok")


fn test_deprecated_with_alias() raises:
    """Tests that deprecation works when accessed via an alias."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["out"]
    cmd.add_arg(
        Arg("output", help="Output format")
        .long("output")
        .aliases(alias_list^)
        .deprecated("Use --format instead")
    )

    var args: List[String] = ["test", "--out", "json"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "json")
    print("  ✓ test_deprecated_with_alias")


# ── Help display: deprecated tag and map placeholder ─────────────────────────


fn test_help_deprecated_tag() raises:
    """Tests that deprecated arguments show [deprecated] in help text."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("old", help="Old option")
        .long("old")
        .deprecated("Use --new instead")
    )
    cmd.add_arg(Arg("new", help="New option").long("new"))

    var help = cmd._generate_help(color=False)
    assert_true(
        "[deprecated: Use --new instead]" in help,
        msg="help should contain deprecated tag",
    )
    print("  ✓ test_help_deprecated_tag")


fn test_help_map_placeholder() raises:
    """Tests that map options show <key=value> placeholder in help."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("define", help="Define vars").long("define").short("D").map_option()
    )

    var help = cmd._generate_help(color=False)
    assert_true(
        "<key=value>" in help,
        msg="help should show <key=value> placeholder for map options",
    )
    print("  ✓ test_help_map_placeholder")


fn test_help_alias_shown() raises:
    """Tests that aliases are shown alongside the primary name in help."""
    var cmd = Command("test", "Test app")
    var alias_list: List[String] = ["color"]
    cmd.add_arg(
        Arg("colour", help="Enable colour output")
        .long("colour")
        .flag()
        .aliases(alias_list^)
    )

    var help = cmd._generate_help(color=False)
    assert_true(
        "--colour, --color" in help,
        msg="help should show '--colour, --color' for aliased option",
    )
    print("  ✓ test_help_alias_shown")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
