"""Tests for argmojo — collection features (append, delimiter, nargs)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Arg, Command, ParseResult

# ── Phase 3: Append / collect action ─────────────────────────────────────────


fn test_append_single() raises:
    """Tests that a single --tag x produces a list with one element."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = ["test", "--tag", "alpha"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 1)
    assert_equal(tags[0], "alpha")
    assert_true(result.has("tag"), msg="tag should be present")
    print("  ✓ test_append_single")


fn test_append_multiple() raises:
    """Tests that --tag x --tag y --tag z collects all values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = [
        "test",
        "--tag",
        "alpha",
        "--tag",
        "beta",
        "--tag",
        "gamma",
    ]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")
    assert_equal(tags[2], "gamma")
    print("  ✓ test_append_multiple")


fn test_append_short_option() raises:
    """Tests that -t x -t y collects values via short option."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = ["test", "-t", "alpha", "-t", "beta"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")
    print("  ✓ test_append_short_option")


fn test_append_equals_syntax() raises:
    """Tests that --tag=x --tag=y collects values with equals syntax."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = ["test", "--tag=alpha", "--tag=beta"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")
    print("  ✓ test_append_equals_syntax")


fn test_append_attached_short() raises:
    """Tests that -talpha -tbeta collects values with attached short syntax."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = ["test", "-talpha", "-tbeta"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "alpha")
    assert_equal(tags[1], "beta")
    print("  ✓ test_append_attached_short")


fn test_append_mixed_syntax() raises:
    """Tests mixing long, short, equals, and attached syntax for append."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = ["test", "--tag", "a", "-t", "b", "--tag=c", "-td"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 4)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")
    assert_equal(tags[3], "d")
    print("  ✓ test_append_mixed_syntax")


fn test_append_empty() raises:
    """Tests that get_list returns empty list when option never provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Add a tag").long("tag").short("t").append())

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 0)
    assert_false(result.has("tag"), msg="tag should not be present")
    print("  ✓ test_append_empty")


fn test_append_with_choices() raises:
    """Tests that append respects choices validation."""
    var cmd = Command("test", "Test app")
    var envs: List[String] = ["dev", "staging", "prod"]
    cmd.add_arg(
        Arg("env", help="Target env").long("env").choices(envs^).append()
    )

    # Valid choices
    var args: List[String] = ["test", "--env", "dev", "--env", "prod"]
    var result = cmd.parse_args(args)
    var envlist = result.get_list("env")
    assert_equal(len(envlist), 2)
    assert_equal(envlist[0], "dev")
    assert_equal(envlist[1], "prod")

    # Invalid choice
    var cmd2 = Command("test", "Test app")
    var envs2: List[String] = ["dev", "staging", "prod"]
    cmd2.add_arg(
        Arg("env", help="Target env").long("env").choices(envs2^).append()
    )
    var args2: List[String] = ["test", "--env", "local"]
    var caught = False
    try:
        _ = cmd2.parse_args(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Invalid value" in msg,
            msg="Error should mention invalid value",
        )
    assert_true(caught, msg="Should have raised error for invalid choice")
    print("  ✓ test_append_with_choices")


fn test_append_with_other_args() raises:
    """Tests that append args work alongside regular flags and values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("verbose").long("verbose").short("v").flag())
    cmd.add_arg(Arg("output").long("output").short("o"))
    cmd.add_arg(
        Arg("include", help="Include path").long("include").short("I").append()
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
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    assert_equal(result.get_string("output"), "out.txt")
    var includes = result.get_list("include")
    assert_equal(len(includes), 2)
    assert_equal(includes[0], "/usr/lib")
    assert_equal(includes[1], "/opt/lib")
    print("  ✓ test_append_with_other_args")


# ===------------------------------------------------------------------=== #
# Value delimiter tests
# ===------------------------------------------------------------------=== #


fn test_delimiter_comma() raises:
    """Tests basic comma delimiter splitting."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").short("t").delimiter(","))

    var args: List[String] = ["test", "--tag", "a,b,c"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")
    print("  ✓ test_delimiter_comma")


fn test_delimiter_equals_syntax() raises:
    """Tests delimiter with --key=value syntax."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").delimiter(","))

    var args: List[String] = ["test", "--tag=x,y,z"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 3)
    assert_equal(tags[0], "x")
    assert_equal(tags[1], "y")
    assert_equal(tags[2], "z")
    print("  ✓ test_delimiter_equals_syntax")


fn test_delimiter_short_option() raises:
    """Tests delimiter with short option."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").short("t").delimiter(","))

    var args: List[String] = ["test", "-t", "foo,bar"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "foo")
    assert_equal(tags[1], "bar")
    print("  ✓ test_delimiter_short_option")


fn test_delimiter_attached_short() raises:
    """Tests delimiter with attached short value (-tfoo,bar)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    cmd.add_arg(Arg("tag", help="Tags").long("tag").short("t").delimiter(","))

    # -vta,b means -v -t a,b (v is flag, t takes value)
    var args: List[String] = ["test", "-vta,b"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    print("  ✓ test_delimiter_attached_short")


fn test_delimiter_repeated() raises:
    """Tests delimiter with multiple uses — values accumulate."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").short("t").delimiter(","))

    var args: List[String] = ["test", "--tag", "a,b", "--tag", "c,d"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 4)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    assert_equal(tags[2], "c")
    assert_equal(tags[3], "d")
    print("  ✓ test_delimiter_repeated")


fn test_delimiter_single_value() raises:
    """Tests delimiter with a single value (no delimiter present)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").delimiter(","))

    var args: List[String] = ["test", "--tag", "single"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 1)
    assert_equal(tags[0], "single")
    print("  ✓ test_delimiter_single_value")


fn test_delimiter_with_choices() raises:
    """Tests that choices are validated per-piece after splitting."""
    var cmd = Command("test", "Test app")
    var envs: List[String] = ["dev", "staging", "prod"]
    cmd.add_arg(
        Arg("env", help="Environments")
        .long("env")
        .choices(envs^)
        .delimiter(",")
    )

    # Valid — all pieces are in choices.
    var args1: List[String] = ["test", "--env", "dev,prod"]
    var result = cmd.parse_args(args1)
    var envlist = result.get_list("env")
    assert_equal(len(envlist), 2)
    assert_equal(envlist[0], "dev")
    assert_equal(envlist[1], "prod")

    # Invalid — "local" is not in choices.
    var caught = False
    var args2: List[String] = ["test", "--env", "dev,local"]
    try:
        _ = cmd.parse_args(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true("Invalid value" in msg, msg="Should mention invalid value")
        assert_true("local" in msg, msg="Should mention 'local'")
    assert_true(
        caught, msg="Should raise error for invalid choice in delimited value"
    )
    print("  ✓ test_delimiter_with_choices")


fn test_delimiter_semicolon() raises:
    """Tests using a non-comma delimiter (semicolon)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("path", help="Search paths").long("path").delimiter(";"))

    var args: List[String] = ["test", "--path", "/usr/lib;/opt/lib;/home/lib"]
    var result = cmd.parse_args(args)
    var paths = result.get_list("path")
    assert_equal(len(paths), 3)
    assert_equal(paths[0], "/usr/lib")
    assert_equal(paths[1], "/opt/lib")
    assert_equal(paths[2], "/home/lib")
    print("  ✓ test_delimiter_semicolon")


fn test_delimiter_implies_append() raises:
    """Tests that .delimiter() implies .append() — get_list works."""
    var cmd = Command("test", "Test app")
    # Note: no explicit .append() call — delimiter() implies it.
    cmd.add_arg(Arg("tag", help="Tags").long("tag").delimiter(","))

    var args: List[String] = ["test", "--tag", "x,y"]
    var result = cmd.parse_args(args)
    assert_true(result.has("tag"), msg="tag should be present")
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "x")
    assert_equal(tags[1], "y")
    print("  ✓ test_delimiter_implies_append")


fn test_delimiter_empty_not_provided() raises:
    """Tests delimiter arg not provided returns empty list."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").delimiter(","))

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 0)
    print("  ✓ test_delimiter_empty_not_provided")


fn test_delimiter_trailing_comma() raises:
    """Tests that trailing delimiter does not create empty entry."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("tag", help="Tags").long("tag").delimiter(","))

    var args: List[String] = ["test", "--tag", "a,b,"]
    var result = cmd.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")
    print("  ✓ test_delimiter_trailing_comma")


# ===------------------------------------------------------------------=== #
# Help system improvements
# ===------------------------------------------------------------------=== #


# ===------------------------------------------------------------------=== #
# Nargs (multi-value per option) tests
# ===------------------------------------------------------------------=== #


fn test_nargs_basic() raises:
    """Tests that nargs(2) consumes exactly 2 values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("point", help="X Y coordinates").long("point").nargs(2))

    var args: List[String] = ["test", "--point", "10", "20"]
    var result = cmd.parse_args(args)
    var lst = result.get_list("point")
    assert_equal(len(lst), 2, msg="nargs(2) should produce 2 values")
    assert_equal(lst[0], "10", msg="First value should be '10'")
    assert_equal(lst[1], "20", msg="Second value should be '20'")
    print("  ✓ test_nargs_basic")


fn test_nargs_three() raises:
    """Tests that nargs(3) consumes exactly 3 values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("rgb", help="RGB colour").long("rgb").nargs(3))

    var args: List[String] = ["test", "--rgb", "255", "128", "0"]
    var result = cmd.parse_args(args)
    var lst = result.get_list("rgb")
    assert_equal(len(lst), 3, msg="nargs(3) should produce 3 values")
    assert_equal(lst[0], "255", msg="First = 255")
    assert_equal(lst[1], "128", msg="Second = 128")
    assert_equal(lst[2], "0", msg="Third = 0")
    print("  ✓ test_nargs_three")


fn test_nargs_short_option() raises:
    """Tests nargs with a short option (-p 1 2)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("point", help="X Y").long("point").short("p").nargs(2))

    var args: List[String] = ["test", "-p", "3", "4"]
    var result = cmd.parse_args(args)
    var lst = result.get_list("point")
    assert_equal(len(lst), 2, msg="Short nargs(2) should produce 2 values")
    assert_equal(lst[0], "3", msg="First = 3")
    assert_equal(lst[1], "4", msg="Second = 4")
    print("  ✓ test_nargs_short_option")


fn test_nargs_repeated() raises:
    """Tests that nargs collects across repeated occurrences."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("point", help="X Y").long("point").nargs(2))

    var args: List[String] = [
        "test",
        "--point",
        "1",
        "2",
        "--point",
        "3",
        "4",
    ]
    var result = cmd.parse_args(args)
    var lst = result.get_list("point")
    assert_equal(len(lst), 4, msg="Two nargs(2) calls should produce 4 values")
    assert_equal(lst[0], "1", msg="1st = 1")
    assert_equal(lst[1], "2", msg="2nd = 2")
    assert_equal(lst[2], "3", msg="3rd = 3")
    assert_equal(lst[3], "4", msg="4th = 4")
    print("  ✓ test_nargs_repeated")


fn test_nargs_too_few_values() raises:
    """Tests that nargs raises when not enough values are available."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("point", help="X Y").long("point").nargs(2))

    var args: List[String] = ["test", "--point", "10"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "requires 2 values" in msg,
            msg="Error should mention 'requires 2 values'",
        )
    assert_true(caught, msg="Should raise when not enough values for nargs")
    print("  ✓ test_nargs_too_few_values")


fn test_nargs_too_few_short() raises:
    """Tests that nargs raises with short option when not enough values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("point", help="X Y").short("p").nargs(2))

    var args: List[String] = ["test", "-p", "10"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "requires 2 values" in msg,
            msg="Error should mention 'requires 2 values'",
        )
    assert_true(caught, msg="Should raise when not enough values for nargs")
    print("  ✓ test_nargs_too_few_short")


fn test_nargs_with_choices() raises:
    """Tests that choices validation applies to each nargs value."""
    var cmd = Command("test", "Test app")
    var dirs: List[String] = ["north", "south", "east", "west"]
    cmd.add_arg(
        Arg("dir", help="Two directions").long("dir").nargs(2).choices(dirs^)
    )

    # Valid.
    var args: List[String] = ["test", "--dir", "north", "east"]
    var result = cmd.parse_args(args)
    var lst = result.get_list("dir")
    assert_equal(lst[0], "north", msg="First direction")
    assert_equal(lst[1], "east", msg="Second direction")

    # Invalid: second value not in choices.
    var bad_args: List[String] = ["test", "--dir", "north", "up"]
    var caught = False
    try:
        _ = cmd.parse_args(bad_args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("Invalid value" in msg, msg="Should mention invalid value")
    assert_true(caught, msg="Bad choice in nargs should raise")
    print("  ✓ test_nargs_with_choices")


fn test_nargs_with_other_args() raises:
    """Tests nargs coexisting with flags and regular value args."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    cmd.add_arg(Arg("point", help="X Y").long("point").nargs(2))
    cmd.add_arg(Arg("output", help="File").long("output").short("o"))

    var args: List[String] = [
        "test",
        "--verbose",
        "--point",
        "5",
        "6",
        "-o",
        "out.txt",
    ]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    var lst = result.get_list("point")
    assert_equal(len(lst), 2, msg="point should have 2 values")
    assert_equal(lst[0], "5", msg="point[0] = 5")
    assert_equal(lst[1], "6", msg="point[1] = 6")
    assert_equal(
        result.get_string("output"), "out.txt", msg="output should be out.txt"
    )
    print("  ✓ test_nargs_with_other_args")


fn test_nargs_equals_syntax_rejected() raises:
    """Tests that = syntax is rejected for nargs options."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("point", help="X Y").long("point").nargs(2))

    var args: List[String] = ["test", "--point=10", "20"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'=' syntax is not supported" in msg,
            msg="Error should mention = syntax not supported",
        )
    assert_true(caught, msg="nargs with = should raise")
    print("  ✓ test_nargs_equals_syntax_rejected")


fn test_nargs_prefix_match() raises:
    """Tests that prefix matching works with nargs options."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("position", help="X Y").long("position").nargs(2))

    var args: List[String] = ["test", "--pos", "7", "8"]
    var result = cmd.parse_args(args)
    var lst = result.get_list("position")
    assert_equal(len(lst), 2, msg="prefix --pos should resolve to --position")
    assert_equal(lst[0], "7", msg="First = 7")
    assert_equal(lst[1], "8", msg="Second = 8")
    print("  ✓ test_nargs_prefix_match")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
