"""Tests for negative number passthrough in argmojo.

Covers:
  - Auto-detect: numeric-looking tokens bypass option parsing when no digit
    short option is registered.
  - Explicit opt-in: allow_negative_numbers() forces bypass unconditionally.
  - Digit short option conflict: auto-detect is suppressed; the token is
    consumed as the registered short flag/value.
  - Explicit opt-in overrides the digit-short conflict.
  - '--' separator still works regardless of these settings.
  - Non-numeric '-x' tokens still raise "Unknown option" as expected.
"""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Arg, Command, ParseResult


# ── Auto-detect tests (no digit short options registered) ───────────────────


fn test_negative_integer_auto_detect() raises:
    """A negative integer token is treated as a positional when no digit
    short option is registered (auto-detect mode)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="A number").positional().required())

    var args: List[String] = ["test", "-9876543"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-9876543")
    print("  ✓ test_negative_integer_auto_detect")


fn test_negative_float_auto_detect() raises:
    """A negative float token (-3.14) is treated as a positional."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="A float").positional().required())

    var args: List[String] = ["test", "-3.14"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-3.14")
    print("  ✓ test_negative_float_auto_detect")


fn test_negative_leading_dot_auto_detect() raises:
    """A negative leading-dot float (-.5) is treated as a positional."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="A float").positional().required())

    var args: List[String] = ["test", "-.5"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-.5")
    print("  ✓ test_negative_leading_dot_auto_detect")


fn test_negative_scientific_auto_detect() raises:
    """A negative scientific notation token (-1.5e10) is treated as a positional.
    """
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="A number").positional().required())

    var args: List[String] = ["test", "-1.5e10"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-1.5e10")
    print("  ✓ test_negative_scientific_auto_detect")


fn test_negative_scientific_negative_exp_auto_detect() raises:
    """A token with negative exponent (-2.0e-3) is treated as a positional."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="A number").positional().required())

    var args: List[String] = ["test", "-2.0e-3"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-2.0e-3")
    print("  ✓ test_negative_scientific_negative_exp_auto_detect")


fn test_multiple_negative_positionals() raises:
    """Two negative number tokens are both collected as positionals."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("a", help="First number").positional().required())
    cmd.add_arg(Arg("b", help="Second number").positional().required())

    var args: List[String] = ["test", "-1", "-2.5"]
    var result = cmd.parse_args(args)
    assert_equal(len(result.positionals), 2)
    assert_equal(result.positionals[0], "-1")
    assert_equal(result.positionals[1], "-2.5")
    print("  ✓ test_multiple_negative_positionals")


fn test_mixed_negative_and_options() raises:
    """Negative positionals coexist with normal named options."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    cmd.add_arg(Arg("value", help="A number").positional().required())

    var args: List[String] = ["test", "--verbose", "-9.5"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.positionals[0], "-9.5")
    print("  ✓ test_mixed_negative_and_options")


# ── Explicit allow_negative_numbers() tests ─────────────────────────────────


fn test_explicit_allow_negative_numbers() raises:
    """The allow_negative_numbers() method forces negative-number tokens to positional
    even when a digit short option is registered."""
    var cmd = Command("test", "Test app")
    cmd.allow_negative_numbers()
    # Register a digit short option — without allow_negative_numbers() this
    # would suppress auto-detect.
    cmd.add_arg(
        Arg("triple", help="Triple mode").long("triple").short("3").flag()
    )
    cmd.add_arg(Arg("value", help="A number").positional().required())

    # "-3.14" should still pass through as a positional.
    var args: List[String] = ["test", "-3.14"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-3.14")
    print("  ✓ test_explicit_allow_negative_numbers")


fn test_explicit_allow_keeps_digit_short_option() raises:
    """With allow_negative_numbers(), an exact digit flag (-3 with no
    fractional part) that has a registered short option is still ambiguous —
    here we verify the exact integer form goes through as a positional too,
    not silently consumed as the flag, because the override is unconditional."""
    var cmd = Command("test", "Test app")
    cmd.allow_negative_numbers()
    cmd.add_arg(
        Arg("triple", help="Triple mode").long("triple").short("3").flag()
    )
    cmd.add_arg(Arg("value", help="A number").positional().required())

    # With allow_negative_numbers set, even bare "-3" becomes a positional.
    var args: List[String] = ["test", "-3"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-3")
    print("  ✓ test_explicit_allow_keeps_digit_short_option")


# ── Digit short option blocks auto-detect ───────────────────────────────────


fn test_digit_short_suppresses_auto_detect() raises:
    """When a digit short option is registered and allow_negative_numbers()
    has NOT been called, the auto-detect is suppressed and the '-3' token
    is consumed as the flag."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("triple", help="Triple mode").long("triple").short("3").flag()
    )

    var args: List[String] = ["test", "-3"]
    var result = cmd.parse_args(args)
    # The flag should be set; no positionals.
    assert_true(result.get_flag("triple"))
    assert_equal(len(result.positionals), 0)
    print("  ✓ test_digit_short_suppresses_auto_detect")


# ── '--' separator ───────────────────────────────────────────────────────────


fn test_double_dash_passes_negative_number() raises:
    """'-- -9.5' always passes -9.5 as a positional (pre-existing behaviour)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="A number").positional().required())

    var args: List[String] = ["test", "--", "-9.5"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "-9.5")
    print("  ✓ test_double_dash_passes_negative_number")


fn test_double_dash_passes_option_like_string() raises:
    """'-- --foo' passes '--foo' as a positional via the '--' separator."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("value", help="Value").positional().required())

    var args: List[String] = ["test", "--", "--foo"]
    var result = cmd.parse_args(args)
    assert_equal(result.positionals[0], "--foo")
    print("  ✓ test_double_dash_passes_option_like_string")


# ── Non-numeric dash tokens still error ─────────────────────────────────────


fn test_unknown_short_option_still_errors() raises:
    """A non-numeric short option that is not registered still raises an error.
    """
    var cmd = Command("test", "Test app")
    # No '-x' registered.

    var args: List[String] = ["test", "-x"]
    var raised = False
    try:
        _ = cmd.parse_args(args)
    except:
        raised = True
    assert_true(raised, msg="'-x' should raise Unknown option error")
    print("  ✓ test_unknown_short_option_still_errors")


fn test_invalid_numeric_form_still_errors() raises:
    """Tokens like '-1-2' or '-1abc' are NOT valid numbers, so they are
    still treated as short-option strings and raise an error."""
    var cmd = Command("test", "Test app")

    var args: List[String] = ["test", "-1abc"]
    var raised = False
    try:
        _ = cmd.parse_args(args)
    except:
        raised = True
    assert_true(raised, msg="'-1abc' is not a number and should raise an error")
    print("  ✓ test_invalid_numeric_form_still_errors")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
