"""Tests for argmojo auto-dispatch (set_run_function / _execute_with_arguments).

Tests:
  • Root command dispatch (no subcommands).
  • Subcommand dispatch (single level).
  • Nested subcommand dispatch (multi-level).
  • Error when no run function registered.
  • set_run_function replaces previous handler.
  • Persistent flags accessible in dispatched handler.
  • Subcommand aliases with dispatch.
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
from argmojo import Argument, Command, ParseResult


# ═══════════════════════════════════════════════════════════════════════════════
# Handler functions
# ═══════════════════════════════════════════════════════════════════════════════
# Since Mojo does not support global mutable vars or closures, handlers
# either succeed silently (happy path) or raise with a known marker that
# we catch and inspect.


def _handler_noop(result: ParseResult) raises:
    """Handler that does nothing — used to verify dispatch reaches it."""
    pass


def _handler_assert_verbose(result: ParseResult) raises:
    """Handler that asserts --verbose was set."""
    assert_true(result.get_flag("verbose"), "Expected verbose=True")


def _handler_assert_target(result: ParseResult) raises:
    """Handler that asserts target positional."""
    assert_equal(result.get_string("target"), "mylib")


def _handler_assert_target_default(result: ParseResult) raises:
    """Handler that asserts target default."""
    assert_equal(result.get_string("target"), "all")


def _handler_assert_filter(result: ParseResult) raises:
    """Handler that asserts filter option."""
    assert_equal(result.get_string("filter"), "unit_*")


def _handler_assert_remote_name(result: ParseResult) raises:
    """Handler that asserts remote name positional."""
    assert_equal(result.get_string("name"), "origin")


def _handler_raise_marker(result: ParseResult) raises:
    """Handler that raises a known marker error."""
    raise Error("MARKER:replaced")


# ═══════════════════════════════════════════════════════════════════════════════
# Root command dispatch
# ═══════════════════════════════════════════════════════════════════════════════


def test_root_dispatch_no_subcommands() raises:
    """Root command with set_run_function dispatches to its handler."""
    var app = Command("app", "Test app")
    app.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    app.set_run_function(_handler_assert_verbose)
    var args: List[String] = ["app", "--verbose"]
    app._execute_with_arguments(args)  # Asserts inside handler


def test_root_dispatch_noop() raises:
    """Root command dispatch to a no-op handler succeeds."""
    var app = Command("app", "Test app")
    app.set_run_function(_handler_noop)
    var args: List[String] = ["app"]
    app._execute_with_arguments(args)


def test_root_dispatch_with_result_values() raises:
    """Handler receives correct parsed values."""
    var app = Command("build", "Build tool")
    app.add_argument(
        Argument("target", help="Target").positional().default["all"]()
    )
    app.set_run_function(_handler_assert_target)
    var args: List[String] = ["build", "mylib"]
    app._execute_with_arguments(args)


# ═══════════════════════════════════════════════════════════════════════════════
# Subcommand dispatch (single level)
# ═══════════════════════════════════════════════════════════════════════════════


def test_subcommand_dispatch_build() raises:
    """Subcommand dispatch routes to the correct handler."""
    var app = Command("app", "Test app")

    var build = Command("build", "Build")
    build.add_argument(
        Argument("target", help="Target").positional().default["all"]()
    )
    build.set_run_function(_handler_assert_target)
    app.add_subcommand(build^)

    var test_cmd = Command("test", "Test")
    test_cmd.add_argument(
        Argument("filter", help="Filter").long["filter"]().default["*"]()
    )
    test_cmd.set_run_function(_handler_assert_filter)
    app.add_subcommand(test_cmd^)

    var args: List[String] = ["app", "build", "mylib"]
    app._execute_with_arguments(args)


def test_subcommand_dispatch_test() raises:
    """Second subcommand dispatch works correctly."""
    var app = Command("app", "Test app")

    var build = Command("build", "Build")
    build.add_argument(
        Argument("target", help="Target").positional().default["all"]()
    )
    build.set_run_function(_handler_assert_target)
    app.add_subcommand(build^)

    var test_cmd = Command("test", "Test")
    test_cmd.add_argument(
        Argument("filter", help="Filter").long["filter"]().default["*"]()
    )
    test_cmd.set_run_function(_handler_assert_filter)
    app.add_subcommand(test_cmd^)

    var args: List[String] = ["app", "test", "--filter", "unit_*"]
    app._execute_with_arguments(args)


def test_subcommand_default_values() raises:
    """Subcommand handler receives default values when args are omitted."""
    var app = Command("app", "Test app")

    var build = Command("build", "Build")
    build.add_argument(
        Argument("target", help="Target").positional().default["all"]()
    )
    build.set_run_function(_handler_assert_target_default)
    app.add_subcommand(build^)

    var args: List[String] = ["app", "build"]
    app._execute_with_arguments(args)


# ═══════════════════════════════════════════════════════════════════════════════
# Nested subcommand dispatch (multi-level)
# ═══════════════════════════════════════════════════════════════════════════════


def test_nested_subcommand_dispatch() raises:
    """Nested subcommand (app remote add) dispatches to leaf handler."""
    var app = Command("app", "Test app")

    var remote = Command("remote", "Remote management")
    remote.set_run_function(_handler_noop)

    var remote_add = Command("add", "Add a remote")
    remote_add.add_argument(
        Argument("name", help="Remote name").positional().required()
    )
    remote_add.set_run_function(_handler_assert_remote_name)
    remote.add_subcommand(remote_add^)

    app.add_subcommand(remote^)

    var args: List[String] = ["app", "remote", "add", "origin"]
    app._execute_with_arguments(args)


# ═══════════════════════════════════════════════════════════════════════════════
# Error cases
# ═══════════════════════════════════════════════════════════════════════════════


def test_no_handler_raises_error() raises:
    """Raises error when root has no run function."""
    var app = Command("app", "Test app")

    var caught = False
    var args: List[String] = ["app"]
    try:
        app._execute_with_arguments(args)
    except e:
        caught = True
        assert_true("No run function registered" in String(e))
    assert_true(caught, "Expected error for missing run function")


def test_no_handler_on_subcommand_raises_error() raises:
    """Raises error when subcommand has no run function."""
    var app = Command("app", "Test app")

    var build = Command("build", "Build")
    # Deliberately NOT calling set_run_function on build
    app.add_subcommand(build^)

    var caught = False
    var args: List[String] = ["app", "build"]
    try:
        app._execute_with_arguments(args)
    except e:
        caught = True
        assert_true("No run function registered" in String(e))
    assert_true(caught, "Expected error for missing handler on subcommand")


# ═══════════════════════════════════════════════════════════════════════════════
# set_run_function replaces previous handler
# ═══════════════════════════════════════════════════════════════════════════════


def test_set_run_replaces_handler() raises:
    """Calling set_run_function a second time replaces the previous handler."""
    var app = Command("app", "Test app")
    app.set_run_function(_handler_noop)
    app.set_run_function(_handler_raise_marker)  # Replace

    var caught = False
    var args: List[String] = ["app"]
    try:
        app._execute_with_arguments(args)
    except e:
        caught = True
        assert_true("MARKER:replaced" in String(e))
    assert_true(caught, "Expected replaced handler to execute")


# ═══════════════════════════════════════════════════════════════════════════════
# Persistent flags in dispatch
# ═══════════════════════════════════════════════════════════════════════════════


def test_persistent_flags_in_subcommand_dispatch() raises:
    """Persistent flags are available to dispatched subcommand handlers."""
    var app = Command("app", "Test app")
    app.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
        .persistent()
    )

    var build = Command("build", "Build")
    build.add_argument(
        Argument("target", help="Target").positional().default["all"]()
    )
    build.set_run_function(_handler_assert_target)
    app.add_subcommand(build^)

    # --verbose before subcommand
    var args: List[String] = ["app", "--verbose", "build", "mylib"]
    app._execute_with_arguments(args)


# ═══════════════════════════════════════════════════════════════════════════════
# Subcommand aliases with dispatch
# ═══════════════════════════════════════════════════════════════════════════════


def test_subcommand_alias_dispatch() raises:
    """Subcommand aliases are resolved correctly during dispatch."""
    var app = Command("app", "Test app")

    var build = Command("build", "Build")
    build.add_argument(
        Argument("target", help="Target").positional().default["all"]()
    )
    build.set_run_function(_handler_assert_target)
    var aliases: List[String] = ["b"]
    build.command_aliases(aliases^)
    app.add_subcommand(build^)

    # Use alias "b"
    var args: List[String] = ["app", "b", "mylib"]
    app._execute_with_arguments(args)


# ═══════════════════════════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════════════════════════


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
