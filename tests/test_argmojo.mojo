"""Tests for argmojo — command-line argument parser."""

from testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import Arg, Command, ParseResult


fn test_flag_long() raises:
    """Test parsing a long flag (--verbose)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "--verbose"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")
    print("  ✓ test_flag_long")


fn test_flag_short() raises:
    """Test parsing a short flag (-v)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "-v"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    print("  ✓ test_flag_short")


fn test_flag_default_false() raises:
    """Test that an unset flag defaults to False."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_false(result.get_flag("verbose"), msg="unset flag should be False")
    print("  ✓ test_flag_default_false")


fn test_key_value_long_space() raises:
    """Test parsing --key value (space separated)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "--output", "file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_space")


fn test_key_value_long_equals() raises:
    """Test parsing --key=value (equals separated)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "--output=file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_equals")


fn test_key_value_short() raises:
    """Test parsing -o value (short option with value)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "-o", "file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_short")


fn test_positional_args() raises:
    """Test parsing positional arguments."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    var args: List[String] = ["test", "hello", "./src"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
    print("  ✓ test_positional_args")


fn test_positional_with_default() raises:
    """Test that positional arguments use defaults when not provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    var args: List[String] = ["test", "hello"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), ".")
    print("  ✓ test_positional_with_default")


fn test_mixed_args() raises:
    """Test parsing a mix of positional args and options."""
    var cmd = Command("sou", "Search tool")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))
    cmd.add_arg(
        Arg("ling", help="Use Lingming encoding").long("ling").short("l").flag()
    )
    cmd.add_arg(
        Arg("ignore-case", help="Case insensitive")
        .long("ignore-case")
        .short("i")
        .flag()
    )
    cmd.add_arg(
        Arg("max-depth", help="Max directory depth")
        .long("max-depth")
        .short("d")
    )

    var args: List[String] = [
        "sou",
        "zhong",
        "./src",
        "--ling",
        "-i",
        "--max-depth",
        "3",
    ]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "zhong")
    assert_equal(result.get_string("path"), "./src")
    assert_true(result.get_flag("ling"), msg="--ling should be True")
    assert_true(result.get_flag("ignore-case"), msg="-i should be True")
    assert_equal(result.get_string("max-depth"), "3")
    print("  ✓ test_mixed_args")


fn test_double_dash_stop() raises:
    """Test that '--' stops option parsing."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("verbose").long("verbose").short("v").flag())

    var args: List[String] = ["test", "--", "--verbose"]
    var result = cmd.parse_args(args)
    assert_false(
        result.get_flag("verbose"),
        msg="--verbose after -- should not be parsed as flag",
    )
    assert_equal(len(result.positionals), 1)
    assert_equal(result.positionals[0], "--verbose")
    print("  ✓ test_double_dash_stop")


fn test_has() raises:
    """Test the has() method."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("verbose").long("verbose").flag())
    cmd.add_arg(Arg("output").long("output"))

    var args: List[String] = ["test", "--verbose"]
    var result = cmd.parse_args(args)
    assert_true(result.has("verbose"), msg="verbose should exist")
    assert_false(result.has("output"), msg="output should not exist")
    print("  ✓ test_has")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
