"""Tests for argmojo — argument groups in help output and value_name wrapping."""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult


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
        "Options:" in help,
        msg="help should contain 'Options:' for ungrouped args: " + help,
    )


def test_group_ungrouped_separate_from_grouped() raises:
    """Ungrouped options appear under 'Options:' and grouped under their
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
    var opts_pos = help.find("Options:")
    var net_pos = help.find("Network:")
    var verbose_pos = help.find("--verbose")
    var host_pos = help.find("--host")
    assert_true(opts_pos >= 0, msg="Options: heading missing")
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
    assert_true("Options:" in help, msg="Options: heading should exist")
    # Should have --verbose and --output under the same section.
    var verbose_pos = help.find("--verbose")
    var output_pos = help.find("--output")
    var options_pos = help.find("Options:")
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
    var options_pos = help.find("Options:")
    var network_pos = help.find("Network:")
    var help_pos = help.find("--help")
    var version_pos = help.find("--version")
    # --help and --version should be under Options:, before Network:.
    assert_true(
        help_pos > options_pos and help_pos < network_pos,
        msg="--help should be under Options: before Network:",
    )
    assert_true(
        version_pos > options_pos and version_pos < network_pos,
        msg="--version should be under Options: before Network:",
    )


def test_group_with_persistent() raises:
    """Persistent (global) args go under Global Options:, not under groups."""
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
    assert_true("Options:" in help, msg="Options: heading missing")
    assert_true("Network:" in help, msg="Network: heading missing")
    assert_true(
        "Global Options:" in help, msg="Global Options: heading missing"
    )
    # --verbose should be under Global Options:, after Network:.
    var global_pos = help.find("Global Options:")
    var verbose_pos = help.find("--verbose")
    assert_true(
        verbose_pos > global_pos,
        msg="--verbose (persistent) should be under Global Options:",
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
    """Group headings use the same header_color styling as Options:/Arguments:.
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
        "Options:" in sub_help, msg="Options: heading in subcommand help"
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
# Test runner
# ═══════════════════════════════════════════════════════════════════════════════


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
