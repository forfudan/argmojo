"""Tests for compile-time schema validation.

Positive tests: valid schemas that should compile and work.
Negative tests cannot live here (they prevent compilation);
see the shell script tests/check_schema_errors.sh instead.
"""

from std.testing import assert_true, TestSuite

from argmojo import (
    Parsable,
    Option,
    Flag,
    Positional,
    Count,
)


# =======================================================================
# Positive: valid single-char short flags on all wrapper types
# =======================================================================


struct AllShortFlags(Parsable):
    var output: Option[String, long="output", short="o", help="Output"]
    var verbose: Flag[short="v", help="Verbose"]
    var debug: Count[short="d", help="Debug"]
    var pattern: Positional[String, help="Pattern"]

    @staticmethod
    def description() -> String:
        return String("All short flag types.")


def test_valid_short_flags() raises:
    """All single-char short flags compile fine."""
    var command = AllShortFlags.to_command()
    assert_true(len(command.arguments) == 4, "4 args")
    assert_true(command.arguments[0]._short_name == "o", "Option short")
    assert_true(command.arguments[1]._short_name == "v", "Flag short")
    assert_true(command.arguments[2]._short_name == "d", "Count short")


# =======================================================================
# Positive: choices + default consistency
# =======================================================================


struct ChoicesDefaultMatch(Parsable):
    var fmt: Option[
        String,
        long="format",
        short="f",
        choices="json,yaml,csv",
        default="yaml",
    ]

    @staticmethod
    def description() -> String:
        return String("Choices with matching default.")


def test_choices_default_match() raises:
    """Default value matches one of the choices — compiles fine."""
    var args = List[String]()
    args.append(String("command"))
    var result = ChoicesDefaultMatch.parse_arguments(args)
    assert_true(result.fmt.value == "yaml", "default yaml applied")


# =======================================================================
# Positive: range with min == max (edge case)
# =======================================================================


struct RangeEqualMinMax(Parsable):
    var count: Option[
        Int,
        long="count",
        has_range=True,
        range_min=5,
        range_max=5,
    ]

    @staticmethod
    def description() -> String:
        return String("Range min==max edge case.")


def test_range_equal_bounds() raises:
    """Range where range_min == range_max is valid (exactly one allowed value).
    """
    var command = RangeEqualMinMax.to_command()
    assert_true(command.arguments[0]._range_min == 5, "min 5")
    assert_true(command.arguments[0]._range_max == 5, "max 5")


# =======================================================================
# Positive: Positional choices + default
# =======================================================================


struct PositionalChoices(Parsable):
    var action: Positional[
        String, help="Action", choices="start,stop,restart", default="start"
    ]

    @staticmethod
    def description() -> String:
        return String("Positional with choices and default.")


def test_positional_choices_default() raises:
    """Positional with valid choices+default compiles fine."""
    var command = PositionalChoices.to_command()
    assert_true(command.arguments[0]._is_positional, "is positional")
    assert_true(len(command.arguments[0]._choice_values) == 3, "3 choices")
    assert_true(command.arguments[0]._default_value == "start", "default start")


# =======================================================================
# Positive: no short flags at all (no validation triggered)
# =======================================================================


struct NoShortFlags(Parsable):
    var output: Option[String, long="output", help="Output"]
    var verbose: Flag[long="verbose", help="Verbose"]

    @staticmethod
    def description() -> String:
        return String("No short flags.")


def test_no_short_flags() raises:
    """Schema with no short flags compiles without issues."""
    var command = NoShortFlags.to_command()
    assert_true(len(command.arguments) == 2, "2 args")
    assert_true(command.arguments[0]._short_name == "", "no short on output")
    assert_true(command.arguments[1]._short_name == "", "no short on verbose")


# =======================================================================
# Main
# =======================================================================


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
