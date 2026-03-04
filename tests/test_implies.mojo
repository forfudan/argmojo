"""Tests for argmojo — mutual implication (implies) feature."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Basic implication ─────────────────────────────────────────────────────────


fn test_implies_basic_flag() raises:
    """Tests that --debug implies --verbose (both flags)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(
        result.get_flag("verbose"), msg="verbose should be implied by debug"
    )
    print("  ✓ test_implies_basic_flag")


fn test_implies_no_trigger() raises:
    """Tests that without --debug, --verbose is not auto-set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("debug"), msg="debug should not be set")
    assert_false(result.has("verbose"), msg="verbose should not be set")
    print("  ✓ test_implies_no_trigger")


fn test_implies_both_set_explicitly() raises:
    """Tests that both --debug --verbose works without conflict."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--debug", "--verbose"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    print("  ✓ test_implies_both_set_explicitly")


fn test_implies_unidirectional() raises:
    """Tests that implication is unidirectional: --verbose alone doesn't set --debug.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_arguments(args)
    assert_false(result.has("debug"), msg="debug should not be set")
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    print("  ✓ test_implies_unidirectional")


# ── Chained implication ──────────────────────────────────────────────────────


fn test_implies_chain() raises:
    """Tests chained implication: --debug → --verbose → --log."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(
        Argument("log", help="Enable logging").long("log").flag()
    )
    command.implies("debug", "verbose")
    command.implies("verbose", "log")

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(
        result.get_flag("verbose"), msg="verbose should be implied by debug"
    )
    assert_true(
        result.get_flag("log"), msg="log should be implied by verbose (chain)"
    )
    print("  ✓ test_implies_chain")


fn test_implies_chain_middle() raises:
    """Tests chain from middle: --verbose sets --log but not --debug."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(
        Argument("log", help="Enable logging").long("log").flag()
    )
    command.implies("debug", "verbose")
    command.implies("verbose", "log")

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_arguments(args)
    assert_false(result.has("debug"), msg="debug should NOT be set")
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    assert_true(result.get_flag("log"), msg="log should be implied by verbose")
    print("  ✓ test_implies_chain_middle")


# ── Multiple implications from same trigger ──────────────────────────────────


fn test_implies_multiple_from_same_trigger() raises:
    """Tests that one trigger can imply multiple targets."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(
        Argument("log", help="Enable logging").long("log").flag()
    )
    command.implies("debug", "verbose")
    command.implies("debug", "log")

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(result.get_flag("verbose"), msg="verbose should be implied")
    assert_true(result.get_flag("log"), msg="log should be implied")
    print("  ✓ test_implies_multiple_from_same_trigger")


# ── Count arguments ──────────────────────────────────────────────────────────


fn test_implies_count_argument() raises:
    """Tests that implication works with count-type arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_equal(
        result.get_count("verbose"),
        1,
        msg="verbose count should be 1 (implied)",
    )
    print("  ✓ test_implies_count_argument")


fn test_implies_count_already_set() raises:
    """Tests that explicit count is preserved when trigger is also set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--debug", "-vvv"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_equal(
        result.get_count("verbose"),
        3,
        msg="verbose count should stay at 3 (explicit)",
    )
    print("  ✓ test_implies_count_already_set")


# ── Cycle detection ──────────────────────────────────────────────────────────


fn test_implies_self_cycle() raises:
    """Tests that A implies A is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )

    var caught = False
    try:
        command.implies("debug", "debug")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "cycle" in String.lower(msg),
            msg="error should mention 'cycle'",
        )
    assert_true(caught, msg="self-cycle should raise an error")
    print("  ✓ test_implies_self_cycle")


fn test_implies_direct_cycle() raises:
    """Tests that A→B, B→A cycle is detected at registration."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("a", help="Flag A").long("a").flag())
    command.add_argument(Argument("b", help="Flag B").long("b").flag())
    command.implies("a", "b")

    var caught = False
    try:
        command.implies("b", "a")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "cycle" in String.lower(msg),
            msg="error should mention 'cycle'",
        )
    assert_true(caught, msg="direct cycle should raise an error")
    print("  ✓ test_implies_direct_cycle")


fn test_implies_indirect_cycle() raises:
    """Tests that A→B→C, C→A cycle is detected at registration."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("a", help="Flag A").long("a").flag())
    command.add_argument(Argument("b", help="Flag B").long("b").flag())
    command.add_argument(Argument("c", help="Flag C").long("c").flag())
    command.implies("a", "b")
    command.implies("b", "c")

    var caught = False
    try:
        command.implies("c", "a")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "cycle" in String.lower(msg),
            msg="error should mention 'cycle'",
        )
    assert_true(caught, msg="indirect cycle should raise an error")
    print("  ✓ test_implies_indirect_cycle")


fn test_implies_no_false_cycle() raises:
    """Tests that non-cyclic diamond shape is allowed: A→B, A→C, B→D, C→D."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("a", help="A").long("a").flag())
    command.add_argument(Argument("b", help="B").long("b").flag())
    command.add_argument(Argument("c", help="C").long("c").flag())
    command.add_argument(Argument("d", help="D").long("d").flag())
    command.implies("a", "b")
    command.implies("a", "c")
    command.implies("b", "d")
    command.implies("c", "d")  # Diamond, not a cycle — should succeed

    var args: List[String] = ["test", "--a"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("a"), msg="a should be True")
    assert_true(result.get_flag("b"), msg="b should be implied")
    assert_true(result.get_flag("c"), msg="c should be implied")
    assert_true(result.get_flag("d"), msg="d should be implied")
    print("  ✓ test_implies_no_false_cycle")


# ── Integration with other constraints ───────────────────────────────────────


fn test_implies_with_required_if() raises:
    """Tests implies combined with required_if: debug implies verbose,
    verbose requires output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output path").long("output"))
    command.implies("debug", "verbose")
    command.required_if("output", "verbose")

    # --debug implies --verbose, which triggers required_if for --output.
    # Without --output, this should fail.
    var args: List[String] = ["test", "--debug"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
    assert_true(
        caught,
        msg=(
            "should fail because --output is required when --verbose is present"
        ),
    )
    print("  ✓ test_implies_with_required_if")


fn test_implies_with_required_if_satisfied() raises:
    """Tests implies + required_if when the requirement is satisfied."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output path").long("output"))
    command.implies("debug", "verbose")
    command.required_if("output", "verbose")

    var args: List[String] = ["test", "--debug", "--output", "/tmp/log"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(result.get_flag("verbose"), msg="verbose should be implied")
    assert_equal(result.get_string("output"), "/tmp/log")
    print("  ✓ test_implies_with_required_if_satisfied")


fn test_implies_with_mutually_exclusive() raises:
    """Tests that implies does not override mutual exclusion checks.
    If debug implies verbose, and verbose is exclusive with quiet,
    then --debug --quiet should fail."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    command.add_argument(
        Argument("quiet", help="Quiet mode").long("quiet").flag()
    )
    command.implies("debug", "verbose")
    var excl: List[String] = ["verbose", "quiet"]
    command.mutually_exclusive(excl^)

    var args: List[String] = ["test", "--debug", "--quiet"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
    assert_true(caught, msg="debug implies verbose, which conflicts with quiet")
    print("  ✓ test_implies_with_mutually_exclusive")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
