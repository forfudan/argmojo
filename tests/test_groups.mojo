"""Tests for argmojo argument group features:
  • Mutually exclusive groups
  • Required-together groups
  • One-required groups
  • Conditional requirements (required_if)
  • Registration-time validation (unknown argument names)
  • Argument groups in help output
  • value_name wrapping (angle brackets)
  • Mutual implication (implies) and cycle detection
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult


# ═══════════════════════════════════════════════════════════════════════════════
# Mutually exclusive groups
# ═══════════════════════════════════════════════════════════════════════════════


def test_exclusive_one_provided() raises:
    """Tests that providing one arg from an exclusive group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    command.add_argument(
        Argument("toml", help="TOML output").long["toml"]().flag()
    )
    var group: List[String] = ["json", "yaml", "toml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("json"), msg="--json should be True")
    assert_false(result.get_flag("yaml"), msg="--yaml should be False")


def test_exclusive_none_provided() raises:
    """Tests that providing no arg from an exclusive group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    var group: List[String] = ["json", "yaml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.get_flag("json"), msg="--json should be False")
    assert_false(result.get_flag("yaml"), msg="--yaml should be False")


def test_exclusive_conflict() raises:
    """Tests that providing two args from an exclusive group raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    command.add_argument(
        Argument("toml", help="TOML output").long["toml"]().flag()
    )
    var group: List[String] = ["json", "yaml", "toml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json", "--yaml"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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


def test_exclusive_value_args() raises:
    """Tests mutually exclusive with value-taking args."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("input", help="Input file").long["input"]())
    command.add_argument(
        Argument("stdin", help="Read stdin").long["stdin"]().flag()
    )
    var group: List[String] = ["input", "stdin"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--input", "file.txt", "--stdin"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="Should have raised error for exclusive conflict")


# ═══════════════════════════════════════════════════════════════════════════════
# Required-together groups
# ═══════════════════════════════════════════════════════════════════════════════


def test_required_together_all_provided() raises:
    """Tests that providing all args from a required-together group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("username", help="User").long["username"]().short["u"]()
    )
    command.add_argument(
        Argument("password", help="Pass").long["password"]().short["p"]()
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
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("username"), "admin")
    assert_equal(result.get_string("password"), "secret")


def test_required_together_none_provided() raises:
    """Tests that providing none from a required-together group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("username", help="User").long["username"]().short["u"]()
    )
    command.add_argument(
        Argument("password", help="Pass").long["password"]().short["p"]()
    )
    var group: List[String] = ["username", "password"]
    command.required_together(group^)

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("username"), msg="username should not be set")
    assert_false(result.has("password"), msg="password should not be set")


def test_required_together_partial() raises:
    """Tests that providing only some from a required-together group raises an
    error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("username", help="User").long["username"]().short["u"]()
    )
    command.add_argument(
        Argument("password", help="Pass").long["password"]().short["p"]()
    )
    var group: List[String] = ["username", "password"]
    command.required_together(group^)

    var args: List[String] = ["test", "--username", "admin"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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


def test_required_together_three_args() raises:
    """Tests required-together with three arguments, only one provided."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("host", help="Host").long["host"]())
    command.add_argument(Argument("port", help="Port").long["port"]())
    command.add_argument(Argument("proto", help="Protocol").long["proto"]())
    var group: List[String] = ["host", "port", "proto"]
    command.required_together(group^)

    var args: List[String] = ["test", "--host", "localhost"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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


# ═══════════════════════════════════════════════════════════════════════════════
# One-required group tests
# ═══════════════════════════════════════════════════════════════════════════════


def test_one_required_one_provided() raises:
    """Tests one-required group when exactly one is provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    command.add_argument(
        Argument("toml", help="TOML output").long["toml"]().flag()
    )
    var group: List[String] = ["json", "yaml", "toml"]
    command.one_required(group^)

    var args: List[String] = ["test", "--yaml"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("yaml"), msg="--yaml should be True")
    assert_false(result.get_flag("json"), msg="--json should be False")
    assert_false(result.get_flag("toml"), msg="--toml should be False")


def test_one_required_multiple_provided() raises:
    """Tests one-required group when multiple from the group are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    command.one_required(["json", "yaml"])

    # Both provided — one_required is satisfied (it only requires at least one).
    var args: List[String] = ["test", "--json", "--yaml"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("json"), msg="--json should be True")
    assert_true(result.get_flag("yaml"), msg="--yaml should be True")


def test_one_required_none_provided() raises:
    """Tests one-required group when none from the group are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    command.one_required(["json", "yaml"])

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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


def test_one_required_with_value_args() raises:
    """Tests one-required group with value-taking arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input file").long["input"]().short["i"]()
    )
    command.add_argument(
        Argument("stdin", help="Read from stdin").long["stdin"]().flag()
    )
    command.one_required(["input", "stdin"])

    # Providing --input satisfies the group.
    var args: List[String] = ["test", "--input", "data.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("input"), "data.txt")


def test_one_required_with_short_option() raises:
    """Tests one-required with a short option satisfying the group."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().short["j"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().short["y"]().flag()
    )
    var group: List[String] = ["json", "yaml"]
    command.one_required(group^)

    var args: List[String] = ["test", "-j"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("json"), msg="-j should satisfy one_required")


def test_one_required_error_shows_display_names() raises:
    """Tests that the error message shows --long or -s names, not internal names.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output-json", help="JSON").long["json"]().flag()
    )
    command.add_argument(
        Argument("output-yaml", help="YAML").long["yaml"]().flag()
    )
    var group: List[String] = ["output-json", "output-yaml"]
    command.one_required(group^)

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        # Should show --json and --yaml, not output-json and output-yaml.
        assert_true("'--json'" in msg, msg="Should show '--json' in error")
        assert_true("'--yaml'" in msg, msg="Should show '--yaml' in error")
    assert_true(caught, msg="Should have raised error")


def test_one_required_combined_with_exclusive() raises:
    """Tests one-required combined with mutually exclusive (exactly one pattern).
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    command.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    # Must provide at least one, but not both.
    var excl_group: List[String] = ["json", "yaml"]
    var req_group: List[String] = ["json", "yaml"]
    command.mutually_exclusive(excl_group^)
    command.one_required(req_group^)

    # Providing one is fine.
    var args1: List[String] = ["test", "--json"]
    var result1 = command.parse_arguments(args1)
    assert_true(result1.get_flag("json"), msg="--json should be True")

    # Providing none fails (one-required).
    var caught_none = False
    var args2: List[String] = ["test"]
    try:
        _ = command.parse_arguments(args2)
    except:
        caught_none = True
    assert_true(caught_none, msg="Should error when none provided")

    # Providing both fails (mutually exclusive).
    var caught_both = False
    var args3: List[String] = ["test", "--json", "--yaml"]
    try:
        _ = command.parse_arguments(args3)
    except:
        caught_both = True
    assert_true(caught_both, msg="Should error when both provided")


def test_one_required_multiple_groups() raises:
    """Tests multiple one-required groups."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("json", help="JSON").long["json"]().flag())
    command.add_argument(Argument("yaml", help="YAML").long["yaml"]().flag())
    command.add_argument(Argument("input", help="Input file").long["input"]())
    command.add_argument(
        Argument("stdin", help="Read stdin").long["stdin"]().flag()
    )
    var format_group: List[String] = ["json", "yaml"]
    var source_group: List[String] = ["input", "stdin"]
    command.one_required(format_group^)
    command.one_required(source_group^)

    # Satisfying both groups.
    var args1: List[String] = ["test", "--yaml", "--input", "f.txt"]
    var result1 = command.parse_arguments(args1)
    assert_true(result1.get_flag("yaml"), msg="--yaml should be True")
    assert_equal(result1.get_string("input"), "f.txt")

    # Missing one group should error.
    var caught = False
    var args2: List[String] = ["test", "--json"]
    try:
        _ = command.parse_arguments(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "--input" in msg or "--stdin" in msg,
            msg="Error should mention missing group",
        )
    assert_true(caught, msg="Should error when second group unsatisfied")


def test_one_required_with_append_arg() raises:
    """Tests one-required group with an append-type argument."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().append()
    )
    command.add_argument(
        Argument("label", help="Add a label").long["label"]().append()
    )
    var group: List[String] = ["tag", "label"]
    command.one_required(group^)

    # Providing --tag satisfies the group.
    var args: List[String] = ["test", "--tag", "v1"]
    var result = command.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 1)
    assert_equal(tags[0], "v1")


# ═══════════════════════════════════════════════════════════════════════════════
# Conditional requirement tests
# ═══════════════════════════════════════════════════════════════════════════════


def test_conditional_req_satisfied() raises:
    """Tests that conditional requirement passes when both are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]().short["o"]()
    )
    command.required_if("output", "save")

    var args: List[String] = ["test", "--save", "--output", "out.txt"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("save"), msg="--save should be True")
    assert_equal(result.get_string("output"), "out.txt")


def test_conditional_req_condition_absent() raises:
    """Tests that conditional requirement is skipped when condition is absent.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]().short["o"]()
    )
    command.required_if("output", "save")

    # --save not provided → --output not required → should pass
    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("save"), msg="save should not be present")
    assert_false(result.has("output"), msg="output should not be present")


def test_conditional_req_violated() raises:
    """Tests that providing condition without target raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]().short["o"]()
    )
    command.required_if("output", "save")

    # --save provided but --output missing → error
    var args: List[String] = ["test", "--save"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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


def test_conditional_req_target_alone_ok() raises:
    """Tests that providing target without condition is fine."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]().short["o"]()
    )
    command.required_if("output", "save")

    # --output provided without --save → should be fine
    var args: List[String] = ["test", "--output", "out.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "out.txt")
    assert_false(result.has("save"), msg="save should not be present")


def test_conditional_req_multiple_rules() raises:
    """Tests multiple conditional requirements on the same command."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]()
    )
    command.add_argument(
        Argument("compress", help="Compress output").long["compress"]().flag()
    )
    command.add_argument(
        Argument("format", help="Compression format").long["format"]()
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
    var result1 = command.parse_arguments(args1)
    assert_equal(result1.get_string("output"), "out.txt")
    assert_equal(result1.get_string("format"), "gzip")

    # Providing --compress without --format → error
    var command2 = Command("test", "Test app")
    command2.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    command2.add_argument(
        Argument("output", help="Output path").long["output"]()
    )
    command2.add_argument(
        Argument("compress", help="Compress output").long["compress"]().flag()
    )
    command2.add_argument(
        Argument("format", help="Compression format").long["format"]()
    )
    command2.required_if("output", "save")
    command2.required_if("format", "compress")

    var args2: List[String] = ["test", "--compress"]
    var caught = False
    try:
        _ = command2.parse_arguments(args2)
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


def test_conditional_req_with_short_option() raises:
    """Tests conditional requirement works with short options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().short["s"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]().short["o"]()
    )
    command.required_if("output", "save")

    # Using short -s triggers the conditional requirement
    var args: List[String] = ["test", "-s"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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
    var result = command.parse_arguments(args2)
    assert_true(result.get_flag("save"), msg="-s should set save")
    assert_equal(result.get_string("output"), "out.txt")


def test_conditional_req_with_value_condition() raises:
    """Tests conditional requirement where condition is a value arg."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format").long["format"]()
    )
    command.add_argument(
        Argument("output", help="Output file").long["output"]()
    )
    # --output is required whenever --format is provided
    command.required_if("output", "format")

    var args: List[String] = ["test", "--format", "json"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("'--output'" in msg, msg="Error should mention --output")
        assert_true("'--format'" in msg, msg="Error should mention --format")
    assert_true(caught, msg="Value condition should trigger requirement")


def test_conditional_req_error_uses_display_names() raises:
    """Tests that error message uses --long names, not internal names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("do-save", help="Save results")
        .long["save"]()
        .short["s"]()
        .flag()
    )
    command.add_argument(
        Argument("out-path", help="Output path").long["output"]().short["o"]()
    )
    # Internal names differ from long names
    command.required_if("out-path", "do-save")

    var args: List[String] = ["test", "--save"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
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


# ═══════════════════════════════════════════════════════════════════════════════
# Registration-time validation: unknown argument names
# ═══════════════════════════════════════════════════════════════════════════════


def test_mutually_exclusive_unknown_arg() raises:
    """Tests that mutually_exclusive() rejects unknown argument names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )

    var caught = False
    try:
        var group: List[String] = ["json", "nonexistent"]
        command.mutually_exclusive(group^)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
        assert_true(
            "nonexistent" in msg,
            msg="error should mention the bad name",
        )
    assert_true(caught, msg="unknown arg should raise an error")


def test_required_together_unknown_arg() raises:
    """Tests that required_together() rejects unknown argument names."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("username", help="User").long["username"]())

    var caught = False
    try:
        var group: List[String] = ["username", "nonexistent"]
        command.required_together(group^)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
        assert_true(
            "nonexistent" in msg,
            msg="error should mention the bad name",
        )
    assert_true(caught, msg="unknown arg should raise an error")


def test_one_required_unknown_arg() raises:
    """Tests that one_required() rejects unknown argument names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )

    var caught = False
    try:
        command.one_required(["json", "nonexistent"])
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
        assert_true(
            "nonexistent" in msg,
            msg="error should mention the bad name",
        )
    assert_true(caught, msg="unknown arg should raise an error")


def test_required_if_unknown_target() raises:
    """Tests that required_if() rejects unknown target argument."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )

    var caught = False
    try:
        command.required_if("nonexistent", "save")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
        assert_true(
            "nonexistent" in msg,
            msg="error should mention the bad name",
        )
    assert_true(caught, msg="unknown target should raise an error")


def test_required_if_unknown_condition() raises:
    """Tests that required_if() rejects unknown condition argument."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output path").long["output"]()
    )

    var caught = False
    try:
        command.required_if("output", "nonexistent")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
        assert_true(
            "nonexistent" in msg,
            msg="error should mention the bad name",
        )
    assert_true(caught, msg="unknown condition should raise an error")


# ═══════════════════════════════════════════════════════════════════════════════
# Argument groups in help
# ═══════════════════════════════════════════════════════════════════════════════


def test_group_basic() raises:
    """Options with .group() appear under a group heading in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("host", help="Server host")
        .long["host"]()
        .short["H"]()
        .group["Network"]()
    )
    command.add_argument(
        Argument("port", help="Server port")
        .long["port"]()
        .short["p"]()
        .group["Network"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "Network:" in help,
        msg="help should contain 'Network:' group heading: " + help,
    )
    assert_true(
        "options:" in help,
        msg="help should contain 'options:' for ungrouped args: " + help,
    )


def test_group_ungrouped_separate_from_grouped() raises:
    """Ungrouped options appear under 'options:' and grouped under their
    own heading — they don't mix."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("host", help="Server host").long["host"]().group["Network"]()
    )

    var help = command._generate_help(color=False)
    # --verbose should appear before "Network:" heading.
    var opts_pos = help.find("options:")
    var net_pos = help.find("Network:")
    var verbose_pos = help.find("--verbose")
    var host_pos = help.find("--host")
    assert_true(opts_pos >= 0, msg="options: heading missing")
    assert_true(net_pos >= 0, msg="Network: heading missing")
    assert_true(
        verbose_pos < net_pos,
        msg="--verbose should appear before Network: heading",
    )
    assert_true(
        host_pos > net_pos,
        msg="--host should appear after Network: heading",
    )


def test_group_multiple_groups() raises:
    """Multiple groups each get their own heading, in first-appearance order."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("user", help="Username")
        .long["user"]()
        .group["Authentication"]()
    )
    command.add_argument(
        Argument("host", help="Server host").long["host"]().group["Network"]()
    )
    command.add_argument(
        Argument("pass", help="Password")
        .long["pass"]()
        .group["Authentication"]()
    )
    command.add_argument(
        Argument("port", help="Server port").long["port"]().group["Network"]()
    )

    var help = command._generate_help(color=False)
    var auth_pos = help.find("Authentication:")
    var net_pos = help.find("Network:")
    assert_true(auth_pos >= 0, msg="Authentication: heading missing")
    assert_true(net_pos >= 0, msg="Network: heading missing")
    # Authentication was registered first, so it should appear first.
    assert_true(
        auth_pos < net_pos,
        msg="Authentication: should appear before Network:",
    )
    # Both --user and --pass should be under Authentication.
    var user_pos = help.find("--user")
    var pass_pos = help.find("--pass")
    assert_true(
        user_pos > auth_pos, msg="--user should be under Authentication:"
    )
    assert_true(
        pass_pos > auth_pos, msg="--pass should be under Authentication:"
    )
    assert_true(
        user_pos < net_pos,
        msg="--user should be before Network:",
    )
    assert_true(
        pass_pos < net_pos,
        msg="--pass should be before Network:",
    )


def test_group_no_groups_unchanged() raises:
    """When no groups are used, help output is the same as before (only Options:).
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var help = command._generate_help(color=False)
    assert_true("options:" in help, msg="options: heading should exist")
    # Should have --verbose and --output under the same section.
    var verbose_pos = help.find("--verbose")
    var output_pos = help.find("--output")
    var options_pos = help.find("options:")
    assert_true(verbose_pos > options_pos, msg="--verbose under Options:")
    assert_true(output_pos > options_pos, msg="--output under Options:")


def test_group_builtin_options_ungrouped() raises:
    """Built-in --help and --version always appear under Options:, not in groups.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("host", help="Server host").long["host"]().group["Network"]()
    )

    var help = command._generate_help(color=False)
    var options_pos = help.find("options:")
    var network_pos = help.find("Network:")
    var help_pos = help.find("--help")
    var version_pos = help.find("--version")
    # --help and --version should be under Options:, before Network:.
    assert_true(
        help_pos > options_pos and help_pos < network_pos,
        msg="--help should be under options: before Network:",
    )
    assert_true(
        version_pos > options_pos and version_pos < network_pos,
        msg="--version should be under options: before Network:",
    )


def test_group_with_persistent() raises:
    """Persistent (global) args go under global options:, not under groups."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
        .persistent()
    )
    command.add_argument(
        Argument("host", help="Server host").long["host"]().group["Network"]()
    )

    var sub = Command("sub", "A subcommand")
    command.add_subcommand(sub^)

    var help = command._generate_help(color=False)
    assert_true("options:" in help, msg="options: heading missing")
    assert_true("Network:" in help, msg="Network: heading missing")
    assert_true(
        "global options:" in help, msg="global options: heading missing"
    )
    # --verbose should be under global options:, after Network:.
    var global_pos = help.find("global options:")
    var verbose_pos = help.find("--verbose")
    assert_true(
        verbose_pos > global_pos,
        msg="--verbose (persistent) should be under global options:",
    )


def test_group_independent_padding() raises:
    """Each group computes its own padding independently."""
    var command = Command("test", "Test app")
    # Group A: short names → small padding.
    command.add_argument(
        Argument("a", help="Alpha").long["a"]().flag().group["Short"]()
    )
    # Group B: long name → wider padding.
    command.add_argument(
        Argument("very-long-option-name", help="Beta")
        .long["very-long-option-name"]()
        .flag()
        .group["Long"]()
    )

    var help = command._generate_help(color=False)
    assert_true("Short:" in help, msg="Short: heading missing")
    assert_true("Long:" in help, msg="Long: heading missing")
    # Both option helptexts should be present and aligned within their sections.
    assert_true("Alpha" in help, msg="Alpha help text missing")
    assert_true("Beta" in help, msg="Beta help text missing")


def test_group_with_colored_output() raises:
    """Group headings use the same header_color styling as options:/arguments:.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("host", help="Server host").long["host"]().group["Network"]()
    )

    var help = command._generate_help(color=True)
    # The group heading should be present (with ANSI codes, so just check the name).
    assert_true(
        "Network:" in help,
        msg="Network: heading should be in coloured output: " + help,
    )


def test_group_hidden_arg_not_shown() raises:
    """Hidden args with a group are still excluded from help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("secret", help="Secret option")
        .long["secret"]()
        .group["Internal"]()
        .hidden()
    )
    command.add_argument(
        Argument("public", help="Public option")
        .long["public"]()
        .group["Internal"]()
    )

    var help = command._generate_help(color=False)
    assert_false("--secret" in help, msg="hidden arg should not appear in help")
    # If the only non-hidden arg in a group exists, the heading should show.
    assert_true("Internal:" in help, msg="Internal: heading should show")


def test_group_all_hidden_no_heading() raises:
    """If all args in a group are hidden, the group heading should not appear.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug1", help="Debug 1")
        .long["debug1"]()
        .group["Debug"]()
        .hidden()
    )
    command.add_argument(
        Argument("debug2", help="Debug 2")
        .long["debug2"]()
        .group["Debug"]()
        .hidden()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var help = command._generate_help(color=False)
    assert_false(
        "Debug:" in help,
        msg="group heading should not appear when all its args are hidden",
    )


def test_group_does_not_affect_parsing() raises:
    """Groups are purely cosmetic — they don't change parsing behavior."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("host", help="Host").long["host"]().group["Network"]()
    )
    command.add_argument(
        Argument("port", help="Port").long["port"]().group["Network"]()
    )

    var args: List[String] = ["test", "--host", "localhost", "--port", "8080"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("host"), "localhost")
    assert_equal(result.get_string("port"), "8080")


def test_group_with_subcommand_help() raises:
    """Group headings work correctly on subcommands too."""
    var app = Command("app", "App")
    var sub = Command("serve", "Start server")
    sub.add_argument(
        Argument("host", help="Server host").long["host"]().group["Network"]()
    )
    sub.add_argument(
        Argument("port", help="Server port").long["port"]().group["Network"]()
    )
    sub.add_argument(Argument("workers", help="Worker count").long["workers"]())
    app.add_subcommand(sub^)

    # Get the subcommand help directly (index 1; index 0 is auto-added 'help').
    var sub_help = app.subcommands[1].copy()._generate_help(color=False)
    assert_true(
        "Network:" in sub_help, msg="Network: heading in subcommand help"
    )
    assert_true(
        "options:" in sub_help, msg="options: heading in subcommand help"
    )


# ═══════════════════════════════════════════════════════════════════════════════
# value_name wrapping (angle brackets)
# ═══════════════════════════════════════════════════════════════════════════════


def test_value_name_wrapped_by_default() raises:
    """The value_name is wrapped in <> by default."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .value_name["FILE"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<FILE>" in help,
        msg="value_name should be wrapped in <> by default: " + help,
    )


def test_value_name_unwrapped() raises:
    """The value_name[False] displays without angle brackets."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .value_name["FILE", False]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        " FILE" in help,
        msg="value_name[False] should show bare FILE: " + help,
    )
    assert_false(
        "<FILE>" in help,
        msg="value_name[False] should NOT wrap in <>: " + help,
    )


def test_value_name_wrapped_explicit() raises:
    """The value_name[True] explicitly wraps in angle brackets."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("path", help="Path").long["path"]().value_name["DIR"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<DIR>" in help, msg="value_name[True] should show <DIR>: " + help
    )


def test_value_name_wrapped_with_append() raises:
    """Wrapped value_name shows <ENV>... for append args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("env", help="Target env")
        .long["env"]()
        .value_name["ENV"]()
        .append()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<ENV>..." in help,
        msg="append arg with wrapped value_name should show <ENV>...: " + help,
    )


def test_value_name_unwrapped_with_append() raises:
    """Unwrapped value_name shows ENV... for append args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("env", help="Target env")
        .long["env"]()
        .value_name["ENV", False]()
        .append()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "ENV..." in help,
        msg="append arg with unwrapped value_name should show ENV...: " + help,
    )
    assert_false(
        "<ENV>..." in help,
        msg="should not wrap when wrapped=False: " + help,
    )


def test_value_name_wrapped_with_nargs() raises:
    """Wrapped value_name with nargs repeats <N> <N>."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y")
        .long["point"]()
        .number_of_values[2]()
        .value_name["N"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<N> <N>" in help,
        msg="wrapped nargs should show '<N> <N>': " + help,
    )


def test_value_name_unwrapped_with_nargs() raises:
    """Unwrapped value_name with nargs repeats N N."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y")
        .long["point"]()
        .number_of_values[2]()
        .value_name["N", False]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "N N" in help,
        msg="unwrapped nargs should show 'N N': " + help,
    )
    assert_false(
        "<N>" in help,
        msg="should not wrap when wrapped=False: " + help,
    )


def test_value_name_wrapped_require_equals() raises:
    """Wrapped value_name with require_equals shows --output=<FILE>."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .require_equals()
        .value_name["FILE"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--output=<FILE>" in help,
        msg="require_equals + wrapped should show --output=<FILE>: " + help,
    )


def test_value_name_wrapped_default_if_no_value() raises:
    """Wrapped value_name with default_if_no_value shows --compress[=<ALGO>]."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("compress", help="Compression")
        .long["compress"]()
        .default_if_no_value["gzip"]()
        .value_name["ALGO"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "--compress[=<ALGO>]" in help,
        msg="default_if_no_value + wrapped should show --compress[=<ALGO>]: "
        + help,
    )


def test_value_name_no_wrapping_does_not_affect_default_placeholder() raises:
    """When no value_name is set, the default placeholder <name> is always used.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<output>" in help,
        msg="default placeholder should always use <name>: " + help,
    )


def test_value_name_colored_output_wrapped() raises:
    """Wrapped value_name works correctly in coloured output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .value_name["PATH"]()
    )

    var help = command._generate_help(color=True)
    assert_true(
        "<PATH>" in help,
        msg="wrapped value_name should appear in coloured output: " + help,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Combined — groups + value_name wrapping
# ═══════════════════════════════════════════════════════════════════════════════


def test_group_with_value_name_wrapped() raises:
    """Grouped option with wrapped value_name shows correctly."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("host", help="Server host")
        .long["host"]()
        .value_name["ADDR"]()
        .group["Network"]()
    )

    var help = command._generate_help(color=False)
    assert_true("Network:" in help, msg="Network: heading missing")
    assert_true(
        "<ADDR>" in help,
        msg="wrapped value_name should appear in grouped option: " + help,
    )


def test_group_with_value_name_unwrapped() raises:
    """Grouped option with unwrapped value_name shows bare text."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("host", help="Server host")
        .long["host"]()
        .value_name["ADDR", False]()
        .group["Network"]()
    )

    var help = command._generate_help(color=False)
    assert_true("Network:" in help, msg="Network: heading missing")
    assert_true(
        " ADDR" in help,
        msg="unwrapped value_name in group: " + help,
    )
    assert_false(
        "<ADDR>" in help,
        msg="should not wrap when wrapped=False: " + help,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Mutual implication (implies) feature
# ═══════════════════════════════════════════════════════════════════════════════


def test_implies_basic_flag() raises:
    """Tests that --debug implies --verbose (both flags)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(
        result.get_flag("verbose"), msg="verbose should be implied by debug"
    )


def test_implies_no_trigger() raises:
    """Tests that without --debug, --verbose is not auto-set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test"]
    var result = command.parse_arguments(args)
    assert_false(result.has("debug"), msg="debug should not be set")
    assert_false(result.has("verbose"), msg="verbose should not be set")


def test_implies_both_set_explicitly() raises:
    """Tests that both --debug --verbose works without conflict."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--debug", "--verbose"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(result.get_flag("verbose"), msg="verbose should be True")


def test_implies_unidirectional() raises:
    """Tests that implication is unidirectional: --verbose alone doesn't set --debug.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.implies("debug", "verbose")

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_arguments(args)
    assert_false(result.has("debug"), msg="debug should not be set")
    assert_true(result.get_flag("verbose"), msg="verbose should be True")


# ── Chained implication ──────────────────────────────────────────────────────


def test_implies_chain() raises:
    """Tests chained implication: --debug → --verbose → --log."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("log", help="Enable logging").long["log"]().flag()
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


def test_implies_chain_middle() raises:
    """Tests chain from middle: --verbose sets --log but not --debug."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("log", help="Enable logging").long["log"]().flag()
    )
    command.implies("debug", "verbose")
    command.implies("verbose", "log")

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_arguments(args)
    assert_false(result.has("debug"), msg="debug should NOT be set")
    assert_true(result.get_flag("verbose"), msg="verbose should be True")
    assert_true(result.get_flag("log"), msg="log should be implied by verbose")


# ── Multiple implications from same trigger ──────────────────────────────────


def test_implies_multiple_from_same_trigger() raises:
    """Tests that one trigger can imply multiple targets."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("log", help="Enable logging").long["log"]().flag()
    )
    command.implies("debug", "verbose")
    command.implies("debug", "log")

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(result.get_flag("verbose"), msg="verbose should be implied")
    assert_true(result.get_flag("log"), msg="log should be implied")


# ── Count arguments ──────────────────────────────────────────────────────────


def test_implies_count_argument() raises:
    """Tests that implication works with count-type arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long["verbose"]()
        .short["v"]()
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


def test_implies_count_already_set() raises:
    """Tests that explicit count is preserved when trigger is also set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long["verbose"]()
        .short["v"]()
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


# ── Cycle detection ──────────────────────────────────────────────────────────


def test_implies_self_cycle() raises:
    """Tests that A implies A is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
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


def test_implies_direct_cycle() raises:
    """Tests that A→B, B→A cycle is detected at registration."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("a", help="Flag A").long["a"]().flag())
    command.add_argument(Argument("b", help="Flag B").long["b"]().flag())
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


def test_implies_indirect_cycle() raises:
    """Tests that A→B→C, C→A cycle is detected at registration."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("a", help="Flag A").long["a"]().flag())
    command.add_argument(Argument("b", help="Flag B").long["b"]().flag())
    command.add_argument(Argument("c", help="Flag C").long["c"]().flag())
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


def test_implies_no_false_cycle() raises:
    """Tests that non-cyclic diamond shape is allowed: A→B, A→C, B→D, C→D."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("a", help="A").long["a"]().flag())
    command.add_argument(Argument("b", help="B").long["b"]().flag())
    command.add_argument(Argument("c", help="C").long["c"]().flag())
    command.add_argument(Argument("d", help="D").long["d"]().flag())
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


# ── Integration with other constraints ───────────────────────────────────────


def test_implies_with_required_if() raises:
    """Tests implies combined with required_if: debug implies verbose,
    verbose requires output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]()
    )
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


def test_implies_with_required_if_satisfied() raises:
    """Tests implies + required_if when the requirement is satisfied."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output path").long["output"]()
    )
    command.implies("debug", "verbose")
    command.required_if("output", "verbose")

    var args: List[String] = ["test", "--debug", "--output", "/tmp/log"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="debug should be True")
    assert_true(result.get_flag("verbose"), msg="verbose should be implied")
    assert_equal(result.get_string("output"), "/tmp/log")


def test_implies_with_mutually_exclusive() raises:
    """Tests that implies does not override mutual exclusion checks.
    If debug implies verbose, and verbose is exclusive with quiet,
    then --debug --quiet should fail."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("quiet", help="Quiet mode").long["quiet"]().flag()
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


# ── Registration validation ──────────────────────────────────────────────────


def test_implies_unknown_trigger() raises:
    """Tests that implies() rejects unknown trigger argument."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var caught = False
    try:
        command.implies("nonexistent", "verbose")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
    assert_true(caught, msg="unknown trigger should raise an error")


def test_implies_unknown_implied() raises:
    """Tests that implies() rejects unknown implied argument."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )

    var caught = False
    try:
        command.implies("debug", "nonexistent")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unknown" in String.lower(msg),
            msg="error should mention 'unknown'",
        )
    assert_true(caught, msg="unknown implied should raise an error")


def test_implies_rejects_value_taking_implied() raises:
    """Tests that implies() rejects value-taking argument as implied target."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long["output"]()
    )

    var caught = False
    try:
        command.implies("debug", "output")
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "flag" in String.lower(msg) or "count" in String.lower(msg),
            msg="error should mention flag or count",
        )
    assert_true(caught, msg="value-taking implied should raise an error")


# ═══════════════════════════════════════════════════════════════════════════════
# Test runner
# ═══════════════════════════════════════════════════════════════════════════════


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
