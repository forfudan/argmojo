"""End-to-end test for the declarative Parsable API (Phase 1).

Tests to_command / from_parse_result via the Parsable trait
static methods: to_command(), parse_args(), from_parse_result().
"""
from std.testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import (
    Command,
    Parsable,
    Option,
    Flag,
    Positional,
    Count,
)


# =======================================================================
# Test struct
# =======================================================================


struct Grep(Parsable):
    var output: Option[String, long="output", short="o", help="Output file"]
    var verbose: Flag[short="v", help="Verbose mode"]
    var pattern: Positional[String, help="Search pattern", required=True]
    var debug_level: Count[long="debug", short="d", help="Debug level", max=3]

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
    var cmd = Grep.to_command()

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

    var grep = Grep.parse_args(args)

    assert_true(grep.output.value == "result.txt", "output value")
    assert_true(grep.verbose.value, "verbose value")
    assert_true(grep.pattern.value == "hello.*world", "pattern value")
    assert_true(grep.debug_level.value == 3, "debug_level value")


def test_from_result() raises:
    """Test from_parse_result writes back from an existing ParseResult."""

    var cmd = Grep.to_command()
    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("out.txt"))
    args.append(String("pattern_str"))

    var result = cmd.parse_arguments(args)
    var grep = Grep.from_parse_result(result)

    assert_true(grep.output.value == "out.txt", "output")
    assert_true(not grep.verbose.value, "verbose should be false")
    assert_true(grep.pattern.value == "pattern_str", "pattern")


struct AutoNameArgs(Parsable):
    var no_color: Flag[help="Disable color"]
    var max_depth: Option[Int, help="Max depth"]

    @staticmethod
    def description() -> String:
        return String("Auto-naming test.")


def test_auto_naming() raises:
    """Test that underscore field names auto-convert to hyphen long names."""

    var cmd = AutoNameArgs.to_command()

    assert_true(cmd.args[0]._long_name == "no-color", "no_color -> no-color")
    assert_true(cmd.args[1]._long_name == "max-depth", "max_depth -> max-depth")


def test_trait_methods() raises:
    """Test calling parse/to_command/from_parse_result as trait static methods on the struct.
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

    # Grep.from_parse_result() — trait method
    var cmd2 = Grep.to_command()
    var args2 = List[String]()
    args2.append(String("grep"))
    args2.append(String("query"))
    var result = cmd2.parse_arguments(args2)
    var grep2 = Grep.from_parse_result(result)
    assert_true(
        grep2.pattern.value == "query", "trait from_parse_result pattern"
    )


def test_split_return() raises:
    """Test the split-return pattern: both typed struct AND raw ParseResult."""

    var cmd = Grep.to_command()
    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("split.txt"))
    args.append(String("-v"))
    args.append(String("-dd"))
    args.append(String("split_pattern"))

    # Parse into a raw ParseResult.
    var result = cmd.parse_arguments(args)

    # Typed write-back (same as what parse_full returns as element 0).
    var grep = Grep.from_parse_result(result)

    # Verify typed access.
    assert_true(grep.output.value == "split.txt", "split typed output")
    assert_true(grep.verbose.value, "split typed verbose")
    assert_true(grep.pattern.value == "split_pattern", "split typed pattern")
    assert_true(grep.debug_level.value == 2, "split typed debug_level")

    # Verify raw ParseResult access (same as what parse_full returns as element 1).
    assert_true(result.get_string("output") == "split.txt", "split raw output")
    assert_true(result.get_flag("verbose"), "split raw verbose")
    assert_true(
        result.get_string("pattern") == "split_pattern", "split raw pattern"
    )
    assert_true(result.get_count("debug_level") == 2, "split raw debug_level")


# ==============================================================================
# Schema validation: valid schemas compile and work correctly.
#
# Compile-time schema validation is enforced via ``comptime assert`` in each
# wrapper's ``add_to_command()``.  The checks below exercise code paths that
# touch every validated property — if any ``comptime assert`` fires erroneously
# on a valid schema, these tests will fail to compile.
#
# Invalid schemas (e.g. short="abc", default not in choices) cannot be tested
# at runtime because they prevent compilation.  These negative cases are
# verified by tests/check_schema_errors.sh (run automatically via `pixi run test`).
# ==============================================================================


struct ValidChoicesDefault(Parsable):
    """Schema where default is one of the choices — should compile fine."""

    var fmt: Option[
        String,
        long="format",
        short="f",
        choices="json,yaml,csv",
        default="json",
    ]

    @staticmethod
    def description() -> String:
        return String("Valid choices+default test.")


def test_valid_choices_default() raises:
    """Test that a valid choices+default schema compiles and parses."""
    var cmd = ValidChoicesDefault.to_command()
    assert_true(len(cmd.args) == 1, "expected 1 arg")
    assert_true(cmd.args[0]._long_name == "format", "long name")
    assert_true(len(cmd.args[0]._choice_values) == 3, "3 choices")


struct ValidRange(Parsable):
    """Schema with valid range (min <= max) — should compile fine."""

    var port: Option[
        Int,
        long="port",
        short="p",
        has_range=True,
        range_min=1,
        range_max=65535,
    ]

    @staticmethod
    def description() -> String:
        return String("Valid range test.")


def test_valid_range() raises:
    """Test that a valid range schema compiles and parses."""
    var cmd = ValidRange.to_command()
    assert_true(len(cmd.args) == 1, "expected 1 arg")
    assert_true(cmd.args[0]._has_range, "has_range set")
    assert_true(cmd.args[0]._range_min == 1, "range_min")
    assert_true(cmd.args[0]._range_max == 65535, "range_max")


struct ChoicesNoDefault(Parsable):
    """Schema with choices but no default — should compile fine."""

    var level: Option[String, long="level", choices="debug,info,warn,error"]

    @staticmethod
    def description() -> String:
        return String("Choices without default test.")


def test_choices_without_default() raises:
    """Test that choices without default compiles correctly."""
    var cmd = ChoicesNoDefault.to_command()
    assert_true(len(cmd.args[0]._choice_values) == 4, "4 choices")


struct HyphenPos(Parsable):
    """Positional that accepts hyphen-prefixed values."""

    var expr: Positional[
        String, help="Expression", required=True, allow_hyphen=True
    ]

    @staticmethod
    def description() -> String:
        return String("Hyphen-positional test.")


def test_positional_allow_hyphen() raises:
    """Test that Positional allow_hyphen=True sets _allow_hyphen_values."""
    var cmd = HyphenPos.to_command()
    assert_true(
        cmd.args[0]._allow_hyphen_values, "allow_hyphen_values on positional"
    )

    var args_list = List[String]()
    args_list.append(String("hp"))
    args_list.append(String("-1+2*sin(x)"))
    var args = HyphenPos.parse_args(args_list)
    assert_equal(args.expr.value, "-1+2*sin(x)")


# =======================================================================
# Main
# =======================================================================


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
