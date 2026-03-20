"""Tests for argmojo — argument parents (shared argument definitions)."""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Basic inheritance ────────────────────────────────────────────────────────


def test_parent_flag_inherited() raises:
    """Tests that a flag argument from a parent is inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "--verbose"]
    var result = child.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")


def test_parent_flag_short() raises:
    """Tests that short flags from a parent work."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "-v"]
    var result = child.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="-v should set verbose True")


def test_parent_value_arg_inherited() raises:
    """Tests that a value-taking argument from a parent is inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .short["f"]()
        .choice["json"]()
        .choice["yaml"]()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "--format", "json"]
    var result = child.parse_arguments(args)
    assert_equal(result.get_string("format"), "json")


def test_parent_default_inherited() raises:
    """Tests that default values from parent arguments are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .default["json"]()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child"]
    var result = child.parse_arguments(args)
    assert_equal(result.get_string("format"), "json")


def test_parent_positional_inherited() raises:
    """Tests that positional arguments from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("input", help="Input file").positional().required()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "myfile.txt"]
    var result = child.parse_arguments(args)
    assert_equal(result.get_string("input"), "myfile.txt")


# ── Multiple parents ─────────────────────────────────────────────────────────


def test_multiple_parents() raises:
    """Tests that arguments from multiple parents are all inherited."""
    var parent_a = Command("_shared_a")
    parent_a.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var parent_b = Command("_shared_b")
    parent_b.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent_a)
    child.add_parent(parent_b)

    var args: List[String] = ["child", "-v", "-o", "out.txt"]
    var result = child.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    assert_equal(result.get_string("output"), "out.txt")


# ── Parent with own arguments ────────────────────────────────────────────────


def test_parent_plus_child_args() raises:
    """Tests that parent args coexist with child's own arguments."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)
    child.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var args: List[String] = ["child", "-v", "--output", "out.txt"]
    var result = child.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    assert_equal(result.get_string("output"), "out.txt")


# ── Group constraint inheritance ─────────────────────────────────────────────


def test_parent_exclusive_group_inherited() raises:
    """Tests that mutually exclusive groups from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    parent.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    var excl: List[String] = ["json", "yaml"]
    parent.mutually_exclusive(excl^)

    var child = Command("child", "Child command")
    child.add_parent(parent)

    # Should fail — exclusive group inherited.
    var args: List[String] = ["child", "--json", "--yaml"]
    var caught = False
    try:
        _ = child.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="exclusive group from parent should be enforced")


def test_parent_required_together_inherited() raises:
    """Tests that required-together groups from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(Argument("user", help="Username").long["user"]())
    parent.add_argument(Argument("pass", help="Password").long["pass"]())
    var together: List[String] = ["user", "pass"]
    parent.required_together(together^)

    var child = Command("child", "Child command")
    child.add_parent(parent)

    # Providing only --user should fail.
    var args: List[String] = ["child", "--user", "admin"]
    var caught = False
    try:
        _ = child.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "required together" in msg or "must be provided together" in msg,
            msg="Error should mention required together",
        )
    assert_true(caught, msg="required-together from parent should be enforced")


def test_parent_one_required_inherited() raises:
    """Tests that one-required groups from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    parent.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    var one_req: List[String] = ["json", "yaml"]
    parent.one_required(one_req^)

    var child = Command("child", "Child command")
    child.add_parent(parent)

    # Providing neither should fail.
    var args: List[String] = ["child"]
    var caught = False
    try:
        _ = child.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "At least one" in msg,
            msg="Error should mention At least one",
        )
    assert_true(caught, msg="one-required from parent should be enforced")


def test_parent_one_required_satisfied() raises:
    """Tests that one-required group from parent passes when satisfied."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("json", help="JSON output").long["json"]().flag()
    )
    parent.add_argument(
        Argument("yaml", help="YAML output").long["yaml"]().flag()
    )
    var one_req: List[String] = ["json", "yaml"]
    parent.one_required(one_req^)

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "--json"]
    var result = child.parse_arguments(args)
    assert_true(result.get_flag("json"), msg="--json should be True")


def test_parent_conditional_req_inherited() raises:
    """Tests that conditional requirements from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("save", help="Save results").long["save"]().flag()
    )
    parent.add_argument(Argument("output", help="Output path").long["output"]())
    parent.required_if("output", "save")

    var child = Command("child", "Child command")
    child.add_parent(parent)

    # --save without --output should fail.
    var args: List[String] = ["child", "--save"]
    var caught = False
    try:
        _ = child.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "output" in msg and "save" in msg,
            msg="Error should mention output and save",
        )
    assert_true(
        caught, msg="conditional requirement from parent should be enforced"
    )


def test_parent_implies_inherited() raises:
    """Tests that implications from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag()
    )
    parent.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    parent.implies("debug", "verbose")

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "--debug"]
    var result = child.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="--debug should be True")
    assert_true(
        result.get_flag("verbose"),
        msg="--verbose should be True via implication",
    )


# ── Parent shared across multiple children ───────────────────────────────────


def test_parent_shared_across_children() raises:
    """Tests that the same parent can be shared across multiple children."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var child_a = Command("cmd_a", "First command")
    child_a.add_parent(parent)

    var child_b = Command("cmd_b", "Second command")
    child_b.add_parent(parent)

    # child_a parses independently.
    var args_a: List[String] = ["cmd_a", "-v"]
    var result_a = child_a.parse_arguments(args_a)
    assert_true(result_a.get_flag("verbose"), msg="cmd_a -v should work")

    # child_b parses independently.
    var args_b: List[String] = ["cmd_b", "--verbose"]
    var result_b = child_b.parse_arguments(args_b)
    assert_true(result_b.get_flag("verbose"), msg="cmd_b --verbose should work")


# ── Parent with append/count/range ───────────────────────────────────────────


def test_parent_count_arg_inherited() raises:
    """Tests that count arguments from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Verbosity level")
        .long["verbose"]()
        .short["v"]()
        .count()
        .max[3]()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "-vvv"]
    var result = child.parse_arguments(args)
    assert_equal(result.get_count("verbose"), 3)


def test_parent_append_arg_inherited() raises:
    """Tests that append arguments from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("tag", help="Tags").long["tag"]().short["t"]().append()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "--tag", "a", "--tag", "b"]
    var result = child.parse_arguments(args)
    var tags = result.get_list("tag")
    assert_equal(len(tags), 2)
    assert_equal(tags[0], "a")
    assert_equal(tags[1], "b")


def test_parent_range_arg_inherited() raises:
    """Tests that range-validated arguments from a parent are inherited."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("port", help="Port number").long["port"]().range[1, 65535]()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child", "--port", "8080"]
    var result = child.parse_arguments(args)
    assert_equal(result.get_int("port"), 8080)


# ── Edge cases ───────────────────────────────────────────────────────────────


def test_parent_no_args() raises:
    """Tests that inheriting from a parent with no arguments is a no-op."""
    var parent = Command("_empty")

    var child = Command("child", "Child command")
    child.add_parent(parent)

    var args: List[String] = ["child"]
    var result = child.parse_arguments(args)
    assert_equal(result.subcommand, "")


def test_parent_does_not_modify_parent() raises:
    """Tests that add_parent does not mutate the parent Command."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )

    var child = Command("child", "Child command")
    child.add_parent(parent)
    child.add_argument(Argument("output", help="Output").long["output"]())

    # Parent should still have only 1 arg.
    assert_equal(len(parent.args), 1)
    # Child should have 2 args (1 inherited + 1 own).
    assert_equal(len(child.args), 2)


def test_parent_with_subcommands() raises:
    """Tests that parent args work on a command with subcommands."""
    var parent = Command("_shared")
    parent.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
        .persistent()
    )

    var app = Command("app", "App")
    app.add_parent(parent)

    var sub = Command("run", "Run something")
    sub.add_argument(Argument("target", help="Target").positional().required())
    app.add_subcommand(sub^)

    var args: List[String] = ["app", "-v", "run", "main"]
    var result = app.parse_arguments(args)
    assert_true(result.get_flag("verbose"), msg="global -v should be True")
    assert_equal(result.subcommand, "run")
    var sub_result = result.get_subcommand_result()
    assert_equal(sub_result.get_string("target"), "main")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
