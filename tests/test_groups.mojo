"""Tests for argmojo — argument group constraints (exclusive, required-together, one-required)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Phase 3: Mutually exclusive groups ────────────────────────────────────────


fn test_exclusive_one_provided() raises:
    """Tests that providing one arg from an exclusive group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    command.add_argument(
        Argument("toml", help="TOML output").long("toml").flag()
    )
    var group: List[String] = ["json", "yaml", "toml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("json"), msg="--json should be True")
    assert_false(result.get_flag("yaml"), msg="--yaml should be False")
    print("  ✓ test_exclusive_one_provided")


fn test_exclusive_none_provided() raises:
    """Tests that providing no arg from an exclusive group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    var group: List[String] = ["json", "yaml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_false(result.get_flag("json"), msg="--json should be False")
    assert_false(result.get_flag("yaml"), msg="--yaml should be False")
    print("  ✓ test_exclusive_none_provided")


fn test_exclusive_conflict() raises:
    """Tests that providing two args from an exclusive group raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    command.add_argument(
        Argument("toml", help="TOML output").long("toml").flag()
    )
    var group: List[String] = ["json", "yaml", "toml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json", "--yaml"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
        assert_true(
            "--json" in msg,
            msg="Error should mention --json",
        )
        assert_true(
            "--yaml" in msg,
            msg="Error should mention --yaml",
        )
    assert_true(caught, msg="Should have raised error for exclusive conflict")
    print("  ✓ test_exclusive_conflict")


fn test_exclusive_value_args() raises:
    """Tests mutually exclusive with value-taking args."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("input", help="Input file").long("input"))
    command.add_argument(
        Argument("stdin", help="Read stdin").long("stdin").flag()
    )
    var group: List[String] = ["input", "stdin"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--input", "file.txt", "--stdin"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="Should have raised error for exclusive conflict")
    print("  ✓ test_exclusive_value_args")


# ── Phase 3: Required-together groups ─────────────────────────────────────────


# ── Phase 3: Required-together groups ─────────────────────────────────────────


fn test_required_together_all_provided() raises:
    """Tests that providing all args from a required-together group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("username", help="User").long("username").short("u")
    )
    command.add_argument(
        Argument("password", help="Pass").long("password").short("p")
    )
    var group: List[String] = ["username", "password"]
    command.required_together(group^)

    var args: List[String] = [
        "test",
        "--username",
        "admin",
        "--password",
        "secret",
    ]
    var result = command.parse_args(args)
    assert_equal(result.get_string("username"), "admin")
    assert_equal(result.get_string("password"), "secret")
    print("  ✓ test_required_together_all_provided")


fn test_required_together_none_provided() raises:
    """Tests that providing none from a required-together group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("username", help="User").long("username").short("u")
    )
    command.add_argument(
        Argument("password", help="Pass").long("password").short("p")
    )
    var group: List[String] = ["username", "password"]
    command.required_together(group^)

    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_false(result.has("username"), msg="username should not be set")
    assert_false(result.has("password"), msg="password should not be set")
    print("  ✓ test_required_together_none_provided")


fn test_required_together_partial() raises:
    """Tests that providing only some from a required-together group raises an
    error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("username", help="User").long("username").short("u")
    )
    command.add_argument(
        Argument("password", help="Pass").long("password").short("p")
    )
    var group: List[String] = ["username", "password"]
    command.required_together(group^)

    var args: List[String] = ["test", "--username", "admin"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "required together" in msg,
            msg="Error should mention required together",
        )
        assert_true(
            "--password" in msg,
            msg="Error should mention --password",
        )
    assert_true(caught, msg="Should have raised error for partial group")
    print("  ✓ test_required_together_partial")


fn test_required_together_three_args() raises:
    """Tests required-together with three arguments, only one provided."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("host", help="Host").long("host"))
    command.add_argument(Argument("port", help="Port").long("port"))
    command.add_argument(Argument("proto", help="Protocol").long("proto"))
    var group: List[String] = ["host", "port", "proto"]
    command.required_together(group^)

    var args: List[String] = ["test", "--host", "localhost"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "--port" in msg,
            msg="Error should mention --port",
        )
        assert_true(
            "--proto" in msg,
            msg="Error should mention --proto",
        )
    assert_true(caught, msg="Should have raised error for partial group")
    print("  ✓ test_required_together_three_args")


# ── Phase 3: Negatable flags (--no-X) ────────────────────────────────────────


# ===------------------------------------------------------------------=== #
# One-required group tests
# ===------------------------------------------------------------------=== #


fn test_one_required_one_provided() raises:
    """Tests one-required group when exactly one is provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    command.add_argument(
        Argument("toml", help="TOML output").long("toml").flag()
    )
    var group: List[String] = ["json", "yaml", "toml"]
    command.one_required(group^)

    var args: List[String] = ["test", "--yaml"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("yaml"), msg="--yaml should be True")
    assert_false(result.get_flag("json"), msg="--json should be False")
    assert_false(result.get_flag("toml"), msg="--toml should be False")
    print("  ✓ test_one_required_one_provided")


fn test_one_required_multiple_provided() raises:
    """Tests one-required group when multiple from the group are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    var group: List[String] = ["json", "yaml"]
    command.one_required(group^)

    # Both provided — one_required is satisfied (it only requires at least one).
    var args: List[String] = ["test", "--json", "--yaml"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("json"), msg="--json should be True")
    assert_true(result.get_flag("yaml"), msg="--yaml should be True")
    print("  ✓ test_one_required_multiple_provided")


fn test_one_required_none_provided() raises:
    """Tests one-required group when none from the group are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    var group: List[String] = ["json", "yaml"]
    command.one_required(group^)

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "At least one" in msg,
            msg="Error should mention 'At least one'",
        )
        assert_true(
            "--json" in msg,
            msg="Error should mention '--json'",
        )
        assert_true(
            "--yaml" in msg,
            msg="Error should mention '--yaml'",
        )
    assert_true(caught, msg="Should have raised error for one-required group")
    print("  ✓ test_one_required_none_provided")


fn test_one_required_with_value_args() raises:
    """Tests one-required group with value-taking arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input file").long("input").short("i")
    )
    command.add_argument(
        Argument("stdin", help="Read from stdin").long("stdin").flag()
    )
    var group: List[String] = ["input", "stdin"]
    command.one_required(group^)

    # Providing --input satisfies the group.
    var args: List[String] = ["test", "--input", "data.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("input"), "data.txt")
    print("  ✓ test_one_required_with_value_args")


fn test_one_required_with_short_option() raises:
    """Tests one-required with a short option satisfying the group."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").short("j").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").short("y").flag()
    )
    var group: List[String] = ["json", "yaml"]
    command.one_required(group^)

    var args: List[String] = ["test", "-j"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("json"), msg="-j should satisfy one_required")
    print("  ✓ test_one_required_with_short_option")


fn test_one_required_error_shows_display_names() raises:
    """Tests that the error message shows --long or -s names, not internal names.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output-json", help="JSON").long("json").flag()
    )
    command.add_argument(
        Argument("output-yaml", help="YAML").long("yaml").flag()
    )
    var group: List[String] = ["output-json", "output-yaml"]
    command.one_required(group^)

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        # Should show --json and --yaml, not output-json and output-yaml.
        assert_true("'--json'" in msg, msg="Should show '--json' in error")
        assert_true("'--yaml'" in msg, msg="Should show '--yaml' in error")
    assert_true(caught, msg="Should have raised error")
    print("  ✓ test_one_required_error_shows_display_names")


fn test_one_required_combined_with_exclusive() raises:
    """Tests one-required combined with mutually exclusive (exactly one pattern).
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long("yaml").flag()
    )
    # Must provide at least one, but not both.
    var excl_group: List[String] = ["json", "yaml"]
    var req_group: List[String] = ["json", "yaml"]
    command.mutually_exclusive(excl_group^)
    command.one_required(req_group^)

    # Providing one is fine.
    var args1: List[String] = ["test", "--json"]
    var result1 = command.parse_args(args1)
    assert_true(result1.get_flag("json"), msg="--json should be True")

    # Providing none fails (one-required).
    var caught_none = False
    var args2: List[String] = ["test"]
    try:
        _ = command.parse_args(args2)
    except:
        caught_none = True
    assert_true(caught_none, msg="Should error when none provided")

    # Providing both fails (mutually exclusive).
    var caught_both = False
    var args3: List[String] = ["test", "--json", "--yaml"]
    try:
        _ = command.parse_args(args3)
    except:
        caught_both = True
    assert_true(caught_both, msg="Should error when both provided")
    print("  ✓ test_one_required_combined_with_exclusive")


fn test_one_required_multiple_groups() raises:
    """Tests multiple one-required groups."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("json", help="JSON").long("json").flag())
    command.add_argument(Argument("yaml", help="YAML").long("yaml").flag())
    command.add_argument(Argument("input", help="Input file").long("input"))
    command.add_argument(
        Argument("stdin", help="Read stdin").long("stdin").flag()
    )
    var format_group: List[String] = ["json", "yaml"]
    var source_group: List[String] = ["input", "stdin"]
    command.one_required(format_group^)
    command.one_required(source_group^)

    # Satisfying both groups.
    var args1: List[String] = ["test", "--yaml", "--input", "f.txt"]
    var result1 = command.parse_args(args1)
    assert_true(result1.get_flag("yaml"), msg="--yaml should be True")
    assert_equal(result1.get_string("input"), "f.txt")

    # Missing one group should error.
    var caught = False
    var args2: List[String] = ["test", "--json"]
    try:
        _ = command.parse_args(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "--input" in msg or "--stdin" in msg,
            msg="Error should mention missing group",
        )
    assert_true(caught, msg="Should error when second group unsatisfied")
    print("  ✓ test_one_required_multiple_groups")


fn test_one_required_with_append_arg() raises:
    """Tests one-required group with an append-type argument."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("tag", help="Add a tag").long("tag").append())
    command.add_argument(
        Argument("label", help="Add a label").long("label").append()
    )
    var group: List[String] = ["tag", "label"]
    command.one_required(group^)

    # Providing --tag satisfies the group.
    var args: List[String] = ["test", "--tag", "v1"]
    var result = command.parse_args(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 1)
    assert_equal(tags[0], "v1")
    print("  ✓ test_one_required_with_append_arg")


# ===------------------------------------------------------------------=== #
# Conditional requirement tests
# ===------------------------------------------------------------------=== #


fn test_conditional_req_satisfied() raises:
    """Tests that conditional requirement passes when both are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long("save").flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long("output").short("o")
    )
    command.required_if("output", "save")

    var args: List[String] = ["test", "--save", "--output", "out.txt"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("save"), msg="--save should be True")
    assert_equal(result.get_string("output"), "out.txt")
    print("  ✓ test_conditional_req_satisfied")


fn test_conditional_req_condition_absent() raises:
    """Tests that conditional requirement is skipped when condition is absent.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long("save").flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long("output").short("o")
    )
    command.required_if("output", "save")

    # --save not provided → --output not required → should pass
    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_false(result.has("save"), msg="save should not be present")
    assert_false(result.has("output"), msg="output should not be present")
    print("  ✓ test_conditional_req_condition_absent")


fn test_conditional_req_violated() raises:
    """Tests that providing condition without target raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long("save").flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long("output").short("o")
    )
    command.required_if("output", "save")

    # --save provided but --output missing → error
    var args: List[String] = ["test", "--save"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'--output'" in msg,
            msg="Error should mention '--output'",
        )
        assert_true(
            "'--save'" in msg,
            msg="Error should mention '--save'",
        )
        assert_true(
            "is required when" in msg,
            msg="Error should say 'is required when'",
        )
    assert_true(caught, msg="Should raise error for missing conditional arg")
    print("  ✓ test_conditional_req_violated")


fn test_conditional_req_target_alone_ok() raises:
    """Tests that providing target without condition is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long("save").flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long("output").short("o")
    )
    command.required_if("output", "save")

    # --output provided without --save → should be fine
    var args: List[String] = ["test", "--output", "out.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "out.txt")
    assert_false(result.has("save"), msg="save should not be present")
    print("  ✓ test_conditional_req_target_alone_ok")


fn test_conditional_req_multiple_rules() raises:
    """Tests multiple conditional requirements on the same command."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long("save").flag()
    )
    command.add_argument(Argument("output", help="Output path").long("output"))
    command.add_argument(
        Argument("compress", help="Compress output").long("compress").flag()
    )
    command.add_argument(
        Argument("format", help="Compression format").long("format")
    )
    # --output required when --save, --format required when --compress
    command.required_if("output", "save")
    command.required_if("format", "compress")

    # Providing --save + --output + --compress + --format → OK
    var args1: List[String] = [
        "test",
        "--save",
        "--output",
        "out.txt",
        "--compress",
        "--format",
        "gzip",
    ]
    var result1 = command.parse_args(args1)
    assert_equal(result1.get_string("output"), "out.txt")
    assert_equal(result1.get_string("format"), "gzip")

    # Providing --compress without --format → error
    var command2 = Command("test", "Test app")
    command2.add_argument(
        Argument("save", help="Save results").long("save").flag()
    )
    command2.add_argument(Argument("output", help="Output path").long("output"))
    command2.add_argument(
        Argument("compress", help="Compress output").long("compress").flag()
    )
    command2.add_argument(
        Argument("format", help="Compression format").long("format")
    )
    command2.required_if("output", "save")
    command2.required_if("format", "compress")

    var args2: List[String] = ["test", "--compress"]
    var caught = False
    try:
        _ = command2.parse_args(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'--format'" in msg,
            msg="Error should mention '--format'",
        )
        assert_true(
            "'--compress'" in msg,
            msg="Error should mention '--compress'",
        )
    assert_true(caught, msg="Should raise error for second conditional rule")
    print("  ✓ test_conditional_req_multiple_rules")


fn test_conditional_req_with_short_option() raises:
    """Tests conditional requirement works with short options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long("save").short("s").flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long("output").short("o")
    )
    command.required_if("output", "save")

    # Using short -s triggers the conditional requirement
    var args: List[String] = ["test", "-s"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "'--output'" in msg,
            msg="Error should mention '--output'",
        )
    assert_true(caught, msg="Short -s should trigger conditional requirement")

    # Using -s -o file.txt satisfies it
    var args2: List[String] = ["test", "-s", "-o", "out.txt"]
    var result = command.parse_args(args2)
    assert_true(result.get_flag("save"), msg="-s should set save")
    assert_equal(result.get_string("output"), "out.txt")
    print("  ✓ test_conditional_req_with_short_option")


fn test_conditional_req_with_value_condition() raises:
    """Tests conditional requirement where condition is a value arg."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format").long("format")
    )
    command.add_argument(Argument("output", help="Output file").long("output"))
    # --output is required whenever --format is provided
    command.required_if("output", "format")

    var args: List[String] = ["test", "--format", "json"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("'--output'" in msg, msg="Error should mention --output")
        assert_true("'--format'" in msg, msg="Error should mention --format")
    assert_true(caught, msg="Value condition should trigger requirement")
    print("  ✓ test_conditional_req_with_value_condition")


fn test_conditional_req_error_uses_display_names() raises:
    """Tests that error message uses --long names, not internal names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("do-save", help="Save results").long("save").short("s").flag()
    )
    command.add_argument(
        Argument("out-path", help="Output path").long("output").short("o")
    )
    # Internal names differ from long names
    command.required_if("out-path", "do-save")

    var args: List[String] = ["test", "--save"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        # Should show --output and --save, not out-path and do-save
        assert_true(
            "'--output'" in msg,
            msg="Should show '--output' not 'out-path'",
        )
        assert_true(
            "'--save'" in msg,
            msg="Should show '--save' not 'do-save'",
        )
    assert_true(caught, msg="Should raise error")
    print("  ✓ test_conditional_req_error_uses_display_names")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
