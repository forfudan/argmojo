"""Declarative subcommand tests.

Tests Parsable structs as subcommand participants:
  - Flat subcommands: parent Parsable + Parsable children via subcommands() hook
  - Nested subcommands (2+ levels) with mid-level flags
  - Root customization + dual return (typed Self + raw ParseResult)
  - run() dispatch pattern for leaf command execution
  - Child.from_result() write-back from subcommand ParseResult

Note: from_command(), parse_split(), and from_command_split() call
cmd.parse() which reads sys.argv(), so they cannot be exercised in
unit tests with synthetic argument lists.  The testable equivalents
(to_command + parse_arguments + from_result) exercise identical logic.
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import (
    Argument,
    Command,
    Parsable,
    Option,
    Flag,
    Positional,
    Count,
)


# =====================================================================
# Section 1: Flat subcommand structs
# =====================================================================


struct SearchCmd(Parsable):
    """Declarative child: search subcommand."""

    var pattern: Positional[String, help="Search pattern", required=True]
    var case_sensitive: Flag[long="case-sensitive", help="Case sensitive"]

    @staticmethod
    def name() -> String:
        return "search"

    @staticmethod
    def description() -> String:
        return "Search for patterns"

    def run(self) raises:
        """Verify we can read parsed fields."""
        if not self.pattern.value:
            raise Error("No pattern provided")


struct ListCmd(Parsable):
    """Declarative child: list subcommand."""

    var all: Flag[long="all", short="a", help="Show all items"]
    var format: Option[
        String, long="format", short="f", help="Output format", default="table"
    ]

    @staticmethod
    def name() -> String:
        return "list"

    @staticmethod
    def description() -> String:
        return "List items"


struct AppRoot(Parsable):
    """Declarative root with two Parsable child subcommands."""

    var verbose: Flag[short="v", help="Verbose output"]
    var config: Option[String, long="config", short="c", help="Config file"]

    @staticmethod
    def name() -> String:
        return "app"

    @staticmethod
    def description() -> String:
        return "My CLI application"

    @staticmethod
    def subcommands(mut cmd: Command) raises:
        cmd.add_subcommand(SearchCmd.to_command())
        cmd.add_subcommand(ListCmd.to_command())


# =====================================================================
# Section 2: Nested subcommand structs (2+ levels)
# =====================================================================


struct RemoteAddCmd(Parsable):
    """Leaf: git remote add <name> <url>."""

    var rname: Positional[String, help="Remote name", required=True]
    var url: Positional[String, help="Remote URL", required=True]
    var fetch: Flag[long="fetch", short="f", help="Fetch after adding"]

    @staticmethod
    def name() -> String:
        return "add"

    @staticmethod
    def description() -> String:
        return "Add a remote"

    def run(self) raises:
        if not self.rname.value:
            raise Error("No remote name")
        if not self.url.value:
            raise Error("No remote URL")


struct RemoteRemoveCmd(Parsable):
    """Leaf: git remote remove <name>."""

    var rname: Positional[String, help="Remote name", required=True]
    var force: Flag[long="force", help="Force removal"]

    @staticmethod
    def name() -> String:
        return "remove"

    @staticmethod
    def description() -> String:
        return "Remove a remote"


struct RemoteCmd(Parsable):
    """Mid-level: git remote [--verbose] <add|remove>."""

    var verbose: Flag[long="verbose", short="v", help="Be verbose"]

    @staticmethod
    def name() -> String:
        return "remote"

    @staticmethod
    def description() -> String:
        return "Manage remotes"

    @staticmethod
    def subcommands(mut cmd: Command) raises:
        cmd.add_subcommand(RemoteAddCmd.to_command())
        cmd.add_subcommand(RemoteRemoveCmd.to_command())


struct GitApp(Parsable):
    """Root: git [--verbose] <remote>."""

    var verbose: Flag[short="v", help="Verbose"]

    @staticmethod
    def name() -> String:
        return "git"

    @staticmethod
    def description() -> String:
        return "Git-like tool"

    @staticmethod
    def subcommands(mut cmd: Command) raises:
        cmd.add_subcommand(RemoteCmd.to_command())


# =====================================================================
# Section 3: run() dispatch struct
# =====================================================================


struct RunTestRoot(Parsable):
    """Root command whose run() is a no-op."""

    var debug: Flag[long="debug", short="d", help="Debug mode"]

    @staticmethod
    def name() -> String:
        return "runner"

    @staticmethod
    def description() -> String:
        return "Run-dispatch test"

    @staticmethod
    def subcommands(mut cmd: Command) raises:
        cmd.add_subcommand(RunLeafCmd.to_command())

    def run(self) raises:
        """Root run does nothing (like printing help)."""
        pass


struct RunLeafCmd(Parsable):
    """Leaf whose run() validates a parsed field."""

    var target: Positional[String, help="Build target", required=True]
    var release: Flag[long="release", short="r", help="Release mode"]

    @staticmethod
    def name() -> String:
        return "build"

    @staticmethod
    def description() -> String:
        return "Build a target"

    def run(self) raises:
        """Verifiable: raises if target is empty."""
        if not self.target.value:
            raise Error("target must not be empty")


# =====================================================================
# Section 1 Tests: Flat declarative subcommands
# =====================================================================


def test_flat_dispatch_search() raises:
    """Dispatch to 'search' subcommand with root flag."""
    var cmd = AppRoot.to_command()
    var args: List[String] = [
        "app",
        "--verbose",
        "search",
        "--case-sensitive",
        "hello",
    ]
    var result = cmd.parse_arguments(args)
    var root = AppRoot.from_result(result)

    assert_true(root.verbose.value)
    assert_equal(result.subcommand, "search")
    assert_true(result.has_subcommand_result())

    var sub = result.get_subcommand_result()
    var search = SearchCmd.from_result(sub)
    assert_equal(search.pattern.value, "hello")
    assert_true(search.case_sensitive.value)


def test_flat_dispatch_list() raises:
    """Dispatch to 'list' subcommand with its own flags."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "list", "--all", "-f", "json"]
    var result = cmd.parse_arguments(args)

    assert_equal(result.subcommand, "list")
    var sub = result.get_subcommand_result()
    var lst = ListCmd.from_result(sub)
    assert_true(lst.all.value)
    assert_equal(lst.format.value, "json")


def test_flat_dispatch_list_default_format() raises:
    """List subcommand with default format value."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "list"]
    var result = cmd.parse_arguments(args)

    assert_equal(result.subcommand, "list")
    var sub = result.get_subcommand_result()
    var lst = ListCmd.from_result(sub)
    assert_false(lst.all.value)
    assert_equal(lst.format.value, "table")


def test_flat_root_only_no_subcommand() raises:
    """Root flags only, no subcommand dispatched."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "--verbose", "-c", "myconfig.toml"]
    var result = cmd.parse_arguments(args)
    var root = AppRoot.from_result(result)

    assert_true(root.verbose.value)
    assert_equal(root.config.value, "myconfig.toml")
    assert_equal(result.subcommand, "")
    assert_false(result.has_subcommand_result())


def test_flat_root_config_with_search() raises:
    """Root config option + search subcommand."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "-c", "prod.toml", "search", "pattern"]
    var result = cmd.parse_arguments(args)
    var root = AppRoot.from_result(result)

    assert_equal(root.config.value, "prod.toml")
    assert_equal(result.subcommand, "search")
    var sub = result.get_subcommand_result()
    var search = SearchCmd.from_result(sub)
    assert_equal(search.pattern.value, "pattern")


def test_flat_free_function_to_command() raises:
    """Use trait static method AppRoot.to_command() to build Command."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "search", "test"]
    var result = cmd.parse_arguments(args)

    assert_equal(result.subcommand, "search")
    var sub = result.get_subcommand_result()
    var search = SearchCmd.from_result(sub)
    assert_equal(search.pattern.value, "test")


# =====================================================================
# Section 2 Tests: Nested subcommands (2+ levels)
# =====================================================================


def test_nested_remote_add() raises:
    """Nested: git --verbose remote add origin https://example.com."""
    var cmd = GitApp.to_command()
    var args: List[String] = [
        "git",
        "--verbose",
        "remote",
        "add",
        "origin",
        "https://example.com",
    ]
    var result = cmd.parse_arguments(args)
    var root = GitApp.from_result(result)

    assert_true(root.verbose.value)
    assert_equal(result.subcommand, "remote")
    assert_true(result.has_subcommand_result())

    # Level 2: remote
    var remote_result = result.get_subcommand_result()
    var remote = RemoteCmd.from_result(remote_result)
    assert_false(remote.verbose.value)  # remote's own verbose not set
    assert_equal(remote_result.subcommand, "add")
    assert_true(remote_result.has_subcommand_result())

    # Level 3: add
    var add_result = remote_result.get_subcommand_result()
    var add_cmd = RemoteAddCmd.from_result(add_result)
    assert_equal(add_cmd.rname.value, "origin")
    assert_equal(add_cmd.url.value, "https://example.com")
    assert_false(add_cmd.fetch.value)


def test_nested_remote_add_with_fetch() raises:
    """Nested: git remote add --fetch origin https://example.com."""
    var cmd = GitApp.to_command()
    var args: List[String] = [
        "git",
        "remote",
        "add",
        "--fetch",
        "origin",
        "https://example.com",
    ]
    var result = cmd.parse_arguments(args)

    var remote_result = result.get_subcommand_result()
    var add_result = remote_result.get_subcommand_result()
    var add_cmd = RemoteAddCmd.from_result(add_result)
    assert_equal(add_cmd.rname.value, "origin")
    assert_equal(add_cmd.url.value, "https://example.com")
    assert_true(add_cmd.fetch.value)


def test_nested_mid_level_flag() raises:
    """Mid-level flag: git remote --verbose add origin https://example.com."""
    var cmd = GitApp.to_command()
    var args: List[String] = [
        "git",
        "remote",
        "--verbose",
        "add",
        "origin",
        "https://example.com",
    ]
    var result = cmd.parse_arguments(args)

    var remote_result = result.get_subcommand_result()
    var remote = RemoteCmd.from_result(remote_result)
    assert_true(remote.verbose.value)  # mid-level flag set

    var add_result = remote_result.get_subcommand_result()
    var add_cmd = RemoteAddCmd.from_result(add_result)
    assert_equal(add_cmd.rname.value, "origin")


def test_nested_remote_remove() raises:
    """Nested: git remote remove --force origin."""
    var cmd = GitApp.to_command()
    var args: List[String] = ["git", "remote", "remove", "--force", "origin"]
    var result = cmd.parse_arguments(args)

    assert_equal(result.subcommand, "remote")
    var remote_result = result.get_subcommand_result()
    assert_equal(remote_result.subcommand, "remove")

    var rm_result = remote_result.get_subcommand_result()
    var rm_cmd = RemoteRemoveCmd.from_result(rm_result)
    assert_equal(rm_cmd.rname.value, "origin")
    assert_true(rm_cmd.force.value)


def test_nested_remote_remove_no_force() raises:
    """Nested: git remote remove origin (no --force)."""
    var cmd = GitApp.to_command()
    var args: List[String] = ["git", "remote", "remove", "origin"]
    var result = cmd.parse_arguments(args)

    var remote_result = result.get_subcommand_result()
    var rm_result = remote_result.get_subcommand_result()
    var rm_cmd = RemoteRemoveCmd.from_result(rm_result)
    assert_equal(rm_cmd.rname.value, "origin")
    assert_false(rm_cmd.force.value)


def test_nested_root_and_mid_verbose() raises:
    """Both levels verbose: git -v remote -v add origin https://example.com."""
    var cmd = GitApp.to_command()
    var args: List[String] = [
        "git",
        "-v",
        "remote",
        "-v",
        "add",
        "origin",
        "https://example.com",
    ]
    var result = cmd.parse_arguments(args)
    var root = GitApp.from_result(result)
    assert_true(root.verbose.value)

    var remote_result = result.get_subcommand_result()
    var remote = RemoteCmd.from_result(remote_result)
    assert_true(remote.verbose.value)

    var add_result = remote_result.get_subcommand_result()
    var add_cmd = RemoteAddCmd.from_result(add_result)
    assert_equal(add_cmd.rname.value, "origin")


# =====================================================================
# Section 3 Tests: Root customization + dual return
# =====================================================================


def test_root_customization_builder_child() raises:
    """Root to_command() + add extra builder subcommand + parse."""
    var cmd = AppRoot.to_command()
    # Add an extra builder-only subcommand beyond the declarative ones
    var info = Command("info", "Show information")
    info.add_argument(Argument("topic", help="Info topic").positional())
    cmd.add_subcommand(info^)

    var args: List[String] = ["app", "info", "version"]
    var result = cmd.parse_arguments(args)

    assert_equal(result.subcommand, "info")
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("topic"), "version")


def test_dual_return_root_and_subcommand() raises:
    """Simulate parse_split: get typed root + raw result for dispatch."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "--verbose", "search", "hello"]
    var result = cmd.parse_arguments(args)

    # Typed root
    var root = AppRoot.from_result(result)
    assert_true(root.verbose.value)

    # Raw result for subcommand dispatch
    assert_equal(result.subcommand, "search")
    assert_true(result.has_subcommand_result())
    var sub = result.get_subcommand_result()

    # Typed child from raw sub-result
    var search = SearchCmd.from_result(sub)
    assert_equal(search.pattern.value, "hello")


def test_dual_return_nested() raises:
    """Dual return through nested subcommands."""
    var cmd = GitApp.to_command()
    var args: List[String] = [
        "git",
        "-v",
        "remote",
        "-v",
        "add",
        "--fetch",
        "origin",
        "https://x.com",
    ]
    var result = cmd.parse_arguments(args)

    # Root typed
    var root = GitApp.from_result(result)
    assert_true(root.verbose.value)

    # Mid-level typed
    var remote_result = result.get_subcommand_result()
    var remote = RemoteCmd.from_result(remote_result)
    assert_true(remote.verbose.value)

    # Leaf typed
    var add_result = remote_result.get_subcommand_result()
    var add_cmd = RemoteAddCmd.from_result(add_result)
    assert_equal(add_cmd.rname.value, "origin")
    assert_equal(add_cmd.url.value, "https://x.com")
    assert_true(add_cmd.fetch.value)


def test_from_result_child_only() raises:
    """Extract child directly from sub-result via ChildParsable.from_result().
    """
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "list", "--all", "-f", "csv"]
    var result = cmd.parse_arguments(args)

    var sub = result.get_subcommand_result()
    var lst = ListCmd.from_result(sub)
    assert_true(lst.all.value)
    assert_equal(lst.format.value, "csv")


# =====================================================================
# Section 4 Tests: run() dispatch pattern
# =====================================================================


def test_run_default_noop() raises:
    """Default run() does nothing and does not raise."""
    var cmd = AppRoot.to_command()
    var args: List[String] = ["app", "--verbose"]
    var result = cmd.parse_arguments(args)
    var root = AppRoot.from_result(result)
    root.run()  # Should complete without error


def test_run_leaf_reads_fields() raises:
    """Leaf run() can read parsed fields."""
    var cmd = RunTestRoot.to_command()
    var args: List[String] = ["runner", "build", "--release", "myapp"]
    var result = cmd.parse_arguments(args)

    var sub = result.get_subcommand_result()
    var leaf = RunLeafCmd.from_result(sub)
    assert_equal(leaf.target.value, "myapp")
    assert_true(leaf.release.value)
    leaf.run()  # Should not raise — target is non-empty


def test_run_dispatch_full_pattern() raises:
    """Full dispatch: parse root → check subcommand → from_result → run().

    This is the canonical pattern for declarative subcommand dispatch:
    1. Build root Command via to_command()
    2. Parse arguments
    3. Extract root typed fields via from_result
    4. Check result.subcommand
    5. Extract child typed fields via from_result on sub-result
    6. Call child.run()
    """
    var cmd = RunTestRoot.to_command()
    var args: List[String] = [
        "runner",
        "--debug",
        "build",
        "--release",
        "myapp",
    ]
    var result = cmd.parse_arguments(args)

    # Step 3: root typed
    var root = RunTestRoot.from_result(result)
    assert_true(root.debug.value)

    # Step 4-5: dispatch
    assert_equal(result.subcommand, "build")
    var sub = result.get_subcommand_result()
    var build = RunLeafCmd.from_result(sub)

    # Step 6: run
    assert_equal(build.target.value, "myapp")
    assert_true(build.release.value)
    build.run()  # Validates target is non-empty


def test_run_nested_dispatch() raises:
    """Nested dispatch: root → mid → leaf.run()."""
    var cmd = GitApp.to_command()
    var args: List[String] = [
        "git",
        "remote",
        "add",
        "origin",
        "https://example.com",
    ]
    var result = cmd.parse_arguments(args)

    # Navigate to leaf
    var remote_result = result.get_subcommand_result()
    var add_result = remote_result.get_subcommand_result()
    var add_cmd = RemoteAddCmd.from_result(add_result)

    # Leaf run() validates rname and url are non-empty
    add_cmd.run()


def test_run_root_noop_when_subcommand_dispatched() raises:
    """Root run() is no-op even when a subcommand was dispatched."""
    var cmd = RunTestRoot.to_command()
    var args: List[String] = ["runner", "--debug", "build", "myapp"]
    var result = cmd.parse_arguments(args)

    var root = RunTestRoot.from_result(result)
    root.run()  # Root's run() is a no-op, doesn't interfere


# =====================================================================
# Section 5 Tests: Declarative child with parse_args free function
# =====================================================================


def test_parse_args_with_subcommands() raises:
    """Free function parse_args works when subcommands are registered."""
    var args: List[String] = ["app", "-v", "search", "hello"]
    var root = AppRoot.parse_args(args)
    assert_true(root.verbose.value)
    # parse_args returns only typed root — subcommand info is in raw result
    # (This tests that parse_args doesn't crash with subcommands)


def test_parse_args_nested() raises:
    """Free function parse_args works through nested subcommand dispatch."""
    var args: List[String] = [
        "git",
        "-v",
        "remote",
        "add",
        "origin",
        "https://x.com",
    ]
    var root = GitApp.parse_args(args)
    assert_true(root.verbose.value)


# =====================================================================
# Entry point
# =====================================================================


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
