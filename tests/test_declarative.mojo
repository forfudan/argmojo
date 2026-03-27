"""End-to-end test for the declarative Parsable API (Phase 1).

Tests _reflect_and_register / _from_result via the public
to_command / parse_args / from_result functions.
"""
from std.testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import (
    Command,
    Parsable,
    Option,
    Flag,
    Positional,
    Count,
    to_command,
    parse_args,
    from_result,
)


# =======================================================================
# Test struct
# =======================================================================


struct Grep(Parsable):
    var output: Option[String, long="output", short="o", help="Output file"]
    var verbose: Flag[short="v", help="Verbose mode"]
    var pattern: Positional[String, help="Search pattern", required=True]
    var debug_level: Count[long="debug", short="d", help="Debug level", max=3]

    def __init__(out self):
        self.output = Option[
            String, long="output", short="o", help="Output file"
        ]()
        self.verbose = Flag[short="v", help="Verbose mode"]()
        self.pattern = Positional[
            String, help="Search pattern", required=True
        ]()
        self.debug_level = Count[
            long="debug", short="d", help="Debug level", max=3
        ]()

    fn __init__(out self, *, deinit take: Self):
        self.output = take.output^
        self.verbose = take.verbose^
        self.pattern = take.pattern^
        self.debug_level = take.debug_level^

    @staticmethod
    def description() -> String:
        return String("Search for patterns in files.")

    @staticmethod
    def name() -> String:
        return String("grep")


# =======================================================================
# Tests
# =======================================================================


def test_to_command() raises:
    """Test that to_command registers all arguments correctly."""
    var cmd = to_command[Grep]()

    # Should have 4 arguments.
    assert_true(
        len(cmd.args) == 4, "expected 4 args, got " + String(len(cmd.args))
    )

    assert_true(cmd.args[0].name == "output", "arg0 name")
    assert_true(cmd.args[0]._long_name == "output", "arg0 long")
    assert_true(cmd.args[0]._short_name == "o", "arg0 short")

    # Check verbose flag.
    assert_true(cmd.args[1]._is_flag, "arg1 flag")
    assert_true(cmd.args[1]._short_name == "v", "arg1 short")

    # Check pattern positional.
    assert_true(cmd.args[2]._is_positional, "arg2 positional")
    assert_true(cmd.args[2]._is_required, "arg2 required")

    # Check debug count.
    assert_true(cmd.args[3]._is_count, "arg3 count")
    assert_true(cmd.args[3]._short_name == "d", "arg3 short")


def test_parse_args() raises:
    """Test full parse + write-back flow."""

    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("result.txt"))
    args.append(String("-v"))
    args.append(String("-ddd"))
    args.append(String("hello.*world"))

    var grep = parse_args[Grep](args)

    assert_true(grep.output.value == "result.txt", "output value")
    assert_true(grep.verbose.value, "verbose value")
    assert_true(grep.pattern.value == "hello.*world", "pattern value")
    assert_true(grep.debug_level.value == 3, "debug_level value")


def test_from_result() raises:
    """Test from_result writes back from an existing ParseResult."""

    var cmd = to_command[Grep]()
    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("out.txt"))
    args.append(String("pattern_str"))

    var result = cmd.parse_arguments(args)
    var grep = from_result[Grep](result)

    assert_true(grep.output.value == "out.txt", "output")
    assert_true(not grep.verbose.value, "verbose should be false")
    assert_true(grep.pattern.value == "pattern_str", "pattern")


struct AutoNameArgs(Parsable):
    var no_color: Flag[help="Disable color"]
    var max_depth: Option[Int, help="Max depth"]

    def __init__(out self):
        self.no_color = Flag[help="Disable color"]()
        self.max_depth = Option[Int, help="Max depth"]()

    fn __init__(out self, *, deinit take: Self):
        self.no_color = take.no_color^
        self.max_depth = take.max_depth^

    @staticmethod
    def description() -> String:
        return String("Auto-naming test.")


def test_auto_naming() raises:
    """Test that underscore field names auto-convert to hyphen long names."""

    var cmd = to_command[AutoNameArgs]()

    assert_true(cmd.args[0]._long_name == "no-color", "no_color -> no-color")
    assert_true(cmd.args[1]._long_name == "max-depth", "max_depth -> max-depth")


def test_trait_methods() raises:
    """Test calling parse/to_command/from_result as trait static methods on the struct.
    """

    # Grep.to_command() — trait method
    var cmd = Grep.to_command()
    assert_true(len(cmd.args) == 4, "trait to_command arg count")

    # Grep.parse_args() — trait method
    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("trait.txt"))
    args.append(String("-v"))
    args.append(String("pattern"))

    var grep = Grep.parse_args(args)
    assert_true(grep.output.value == "trait.txt", "trait parse_args output")
    assert_true(grep.verbose.value, "trait parse_args verbose")
    assert_true(grep.pattern.value == "pattern", "trait parse_args pattern")

    # Grep.from_result() — trait method
    var cmd2 = Grep.to_command()
    var args2 = List[String]()
    args2.append(String("grep"))
    args2.append(String("query"))
    var result = cmd2.parse_arguments(args2)
    var grep2 = Grep.from_result(result)
    assert_true(grep2.pattern.value == "query", "trait from_result pattern")


def test_split_return() raises:
    """Test the split-return pattern: both typed struct AND raw ParseResult."""

    var cmd = to_command[Grep]()
    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("split.txt"))
    args.append(String("-v"))
    args.append(String("-dd"))
    args.append(String("split_pattern"))

    # Parse into a raw ParseResult.
    var result = cmd.parse_arguments(args)

    # Typed write-back (same as what parse_split returns as element 0).
    var grep = from_result[Grep](result)

    # Verify typed access.
    assert_true(grep.output.value == "split.txt", "split typed output")
    assert_true(grep.verbose.value, "split typed verbose")
    assert_true(grep.pattern.value == "split_pattern", "split typed pattern")
    assert_true(grep.debug_level.value == 2, "split typed debug_level")

    # Verify raw ParseResult access (same as what parse_split returns as element 1).
    assert_true(result.get_string("output") == "split.txt", "split raw output")
    assert_true(result.get_flag("verbose"), "split raw verbose")
    assert_true(
        result.get_string("pattern") == "split_pattern", "split raw pattern"
    )
    assert_true(result.get_count("debug_level") == 2, "split raw debug_level")


# =======================================================================
# Main
# =======================================================================


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
