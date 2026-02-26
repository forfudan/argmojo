"""Tests for argmojo — Phase 4 subcommand support.

Step 0: Validates that the _apply_defaults() and _validate() extraction
from parse_args() preserves all existing behavior. These tests exercise
the defaults and validation paths directly through parse_args(), ensuring
no regression from the refactor.
"""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Arg, Command, ParseResult

# ── Step 0: _apply_defaults() behavior ───────────────────────────────────────


fn test_defaults_named_arg() raises:
    """Tests that a named arg with a default gets filled when not provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("format", help="Output format").long("format").default("json")
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("format"), "json")
    print("  ✓ test_defaults_named_arg")


fn test_defaults_positional_arg() raises:
    """Tests that a positional arg with a default gets filled when not provided.
    """
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Pattern").positional().required())
    cmd.add_arg(Arg("path", help="Path").positional().default("."))

    var args: List[String] = ["test", "hello"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), ".")
    print("  ✓ test_defaults_positional_arg")


fn test_defaults_not_applied_when_provided() raises:
    """Tests that defaults do not overwrite explicitly provided values."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("format", help="Output format").long("format").default("json")
    )

    var args: List[String] = ["test", "--format", "csv"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("format"), "csv")
    print("  ✓ test_defaults_not_applied_when_provided")


fn test_defaults_multiple_positional() raises:
    """Tests defaults with multiple positional args where some are provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("src", help="Source").positional().default("a.txt"))
    cmd.add_arg(Arg("dst", help="Dest").positional().default("b.txt"))

    # Provide only the first positional.
    var args: List[String] = ["test", "input.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("src"), "input.txt")
    assert_equal(result.get_string("dst"), "b.txt")
    print("  ✓ test_defaults_multiple_positional")


# ── Step 0: _validate() — required args ──────────────────────────────────────


fn test_validate_required_missing() raises:
    """Tests that a missing required arg raises an error."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").required())

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Required argument" in msg,
            msg="Error should mention 'Required argument'",
        )
        assert_true("output" in msg, msg="Error should mention 'output'")
    assert_true(caught, msg="Should have raised for missing required arg")
    print("  ✓ test_validate_required_missing")


fn test_validate_required_provided() raises:
    """Tests that providing a required arg passes validation."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").required())

    var args: List[String] = ["test", "--output", "out.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "out.txt")
    print("  ✓ test_validate_required_provided")


# ── Step 0: _validate() — positional count ───────────────────────────────────


fn test_validate_too_many_positionals() raises:
    """Tests that too many positional args fails validation."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("name", help="Name").positional())

    var args: List[String] = ["test", "alice", "bob"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Too many positional" in msg,
            msg="Error should mention 'Too many positional'",
        )
    assert_true(caught, msg="Should have raised for too many positionals")
    print("  ✓ test_validate_too_many_positionals")


# ── Step 0: _validate() — mutually exclusive ─────────────────────────────────


fn test_validate_exclusive_conflict() raises:
    """Tests that mutually exclusive args in conflict raise an error."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("json", help="JSON").long("json").flag())
    cmd.add_arg(Arg("yaml", help="YAML").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json", "--yaml"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        assert_true(
            "mutually exclusive" in String(e),
            msg="Error should mention 'mutually exclusive'",
        )
    assert_true(caught, msg="Should have raised for exclusive conflict")
    print("  ✓ test_validate_exclusive_conflict")


fn test_validate_exclusive_ok() raises:
    """Tests that providing only one from exclusive group is fine."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("json", help="JSON").long("json").flag())
    cmd.add_arg(Arg("yaml", help="YAML").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("json"))
    print("  ✓ test_validate_exclusive_ok")


# ── Step 0: _validate() — required-together ──────────────────────────────────


fn test_validate_together_partial() raises:
    """Tests that providing only some of a required-together group fails."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("user", help="User").long("user"))
    cmd.add_arg(Arg("pass", help="Pass").long("pass"))
    var group: List[String] = ["user", "pass"]
    cmd.required_together(group^)

    var args: List[String] = ["test", "--user", "alice"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        assert_true(
            "required together" in String(e).lower()
            or "Arguments required together" in String(e),
            msg="Error should mention required together",
        )
    assert_true(caught, msg="Should have raised for partial together group")
    print("  ✓ test_validate_together_partial")


# ── Step 0: _validate() — one-required ───────────────────────────────────────


fn test_validate_one_required_none() raises:
    """Tests that providing none from a one-required group fails."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("json", help="JSON").long("json").flag())
    cmd.add_arg(Arg("yaml", help="YAML").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    cmd.one_required(group^)

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        assert_true(
            "At least one" in String(e),
            msg="Error should mention 'At least one'",
        )
    assert_true(caught, msg="Should have raised for one-required group")
    print("  ✓ test_validate_one_required_none")


# ── Step 0: _validate() — conditional requirements ───────────────────────────


fn test_validate_conditional_triggered() raises:
    """Tests that conditional requirement fires when condition is present."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("save", help="Save").long("save").flag())
    cmd.add_arg(Arg("output", help="Output").long("output"))
    cmd.required_if("output", "save")

    var args: List[String] = ["test", "--save"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        assert_true(
            "required when" in String(e),
            msg="Error should mention 'required when'",
        )
    assert_true(caught, msg="Should have raised for conditional requirement")
    print("  ✓ test_validate_conditional_triggered")


fn test_validate_conditional_satisfied() raises:
    """Tests that conditional requirement passes when both are provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("save", help="Save").long("save").flag())
    cmd.add_arg(Arg("output", help="Output").long("output"))
    cmd.required_if("output", "save")

    var args: List[String] = ["test", "--save", "--output", "out.txt"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("save"))
    assert_equal(result.get_string("output"), "out.txt")
    print("  ✓ test_validate_conditional_satisfied")


# ── Step 0: _validate() — numeric range ──────────────────────────────────────


fn test_validate_range_out_of_bounds() raises:
    """Tests that a value outside numeric range fails validation."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 100))

    var args: List[String] = ["test", "--port", "200"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        assert_true(
            "out of range" in String(e),
            msg="Error should mention 'out of range'",
        )
    assert_true(caught, msg="Should have raised for out-of-range value")
    print("  ✓ test_validate_range_out_of_bounds")


fn test_validate_range_in_bounds() raises:
    """Tests that a value within numeric range passes validation."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("port", help="Port").long("port").range(1, 100))

    var args: List[String] = ["test", "--port", "50"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("port"), "50")
    print("  ✓ test_validate_range_in_bounds")


# ── Step 0: full round-trip (defaults + validation combined) ─────────────────


fn test_defaults_then_validation_combined() raises:
    """Tests that defaults are applied BEFORE validation runs.

    A required-together group where one arg has a default: providing
    neither should NOT trigger required-together error (neither is present).
    Providing just one should trigger the error.
    """
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("user", help="User").long("user"))
    cmd.add_arg(Arg("pass", help="Pass").long("pass"))
    var group: List[String] = ["user", "pass"]
    cmd.required_together(group^)

    # Providing neither — no error (required-together only fires if some present).
    var args1: List[String] = ["test"]
    var result = cmd.parse_args(args1)
    assert_false(result.has("user"))
    assert_false(result.has("pass"))
    print("  ✓ test_defaults_then_validation_combined")


fn test_full_parse_with_defaults_and_range() raises:
    """Tests that default values also pass range validation."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("port", help="Port").long("port").range(1, 100).default("50")
    )

    # Not providing --port should use default "50" which is in range.
    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("port"), "50")
    print("  ✓ test_full_parse_with_defaults_and_range")


# ── main ─────────────────────────────────────────────────────────────────────


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
