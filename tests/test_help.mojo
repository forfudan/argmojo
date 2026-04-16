"""Tests for argmojo help and display features:
  • Help output formatting (hidden args, value_name, padding, alignment)
  • ANSI colour customisation (header_color, argument_color, etc.)
  • Subcommand help (Commands section, aliases, hidden subs, tips)
  • CJK-aware help alignment (_display_width)
  • NO_COLOR environment variable
  • Custom usage line
  • Full-width → half-width auto-correction (CJK/Unicode)
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult
from argmojo.utils import (
    _display_width,
    _correct_cjk_punctuation,
    _has_fullwidth_chars,
    _fullwidth_to_halfwidth,
    _split_on_fullwidth_spaces,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Hidden arguments
# ═══════════════════════════════════════════════════════════════════════════════


def test_hidden_not_in_help() raises:
    """Tests that hidden arguments are excluded from help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("debug", help="Debug mode")
        .long["debug"]()
        .short["d"]()
        .flag()
        .hidden()
    )

    var help = command._generate_help()
    assert_true("verbose" in help, msg="visible arg should be in help")
    assert_false("debug" in help, msg="hidden arg should NOT be in help")


def test_hidden_still_works() raises:
    """Tests that hidden arguments can still be used at the command line."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode")
        .long["debug"]()
        .short["d"]()
        .flag()
        .hidden()
    )

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("debug"), msg="hidden --debug should work")


# ═══════════════════════════════════════════════════════════════════════════════
# Value Name
# ═══════════════════════════════════════════════════════════════════════════════


def test_value_name_in_help() raises:
    """Tests that value_name appears in help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .value_name["FILE"]()
    )

    var help = command._generate_help()
    assert_true("FILE" in help, msg="value_name 'FILE' should appear in help")
    # Should NOT show the default "<output>" form.
    assert_false(
        "<output>" in help,
        msg="default placeholder should not appear when value_name is set",
    )


def test_choices_in_help() raises:
    """Tests that choices are displayed in help when no value_name."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .short["f"]()
        .choice["json"]()
        .choice["csv"]()
        .choice["table"]()
    )

    var help = command._generate_help()
    assert_true(
        "{json,csv,table}" in help,
        msg="choices should appear in help as {json,csv,table}",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Negatable / append in help
# ═══════════════════════════════════════════════════════════════════════════════


def test_negatable_in_help() raises:
    """Test that negatable flags show --X / --no-X in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Colored output")
        .long["color"]()
        .flag()
        .negatable()
    )

    var args: List[String] = ["test", "--help"]
    _ = args
    var help = command._generate_help(color=False)
    assert_true(
        "--color / --no-color" in help,
        msg="Help should show --color / --no-color",
    )


def test_append_in_help() raises:
    """Tests that append args show ... suffix in help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long["tag"]().short["t"]().append()
    )
    command.add_argument(
        Argument("env", help="Target env")
        .long["env"]()
        .value_name["ENV"]()
        .append()
    )

    var help = command._generate_help()
    assert_true(
        "<tag>..." in help,
        msg="append arg without value_name should show <tag>... in help",
    )
    assert_true(
        "<ENV>..." in help,
        msg="append arg with value_name should show <ENV>... in help",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Help system improvements
# ═══════════════════════════════════════════════════════════════════════════════


def test_help_question_mark_in_help_output() raises:
    """Tests that -h, --help appears in the generated help text."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "-h, --help" in help,
        msg="help output should show -h, --help",
    )


def test_dynamic_padding_short_options() raises:
    """Tests that help padding adapts to short option names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("v", help="Verbose").long["verbose"]().short["v"]().flag()
    )

    var help = command._generate_help()
    # The longest left side is "  -?, -h, --help" (16 chars),
    # so padding = 16 + 4 = 20.  The "-v, --verbose" line (15 chars)
    # should be padded to 20 and then followed by "Verbose".
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "-v, --verbose" in lines[idx]:
            assert_true(
                "Verbose" in lines[idx],
                msg="-v line should contain help text",
            )
            break


def test_dynamic_padding_long_options() raises:
    """Tests that a very long option overflows and its description wraps
    to the next line, aligned at the fixed description column."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("very-long-option-name", help="Description").long[
            "very-long-option-name"
        ]()
    )
    command.add_argument(
        Argument("short", help="Short one").long["short"]().short["s"]()
    )

    var help = command._generate_help(color=False)
    # The longest user arg is "--very-long-option-name <very-long-option-name>"
    # which overflows the 24-char option column. Its description should appear
    # on the next line, aligned with other descriptions.
    var desc_col_long: Int = -1
    var desc_col_short: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "--very-long-option-name" in lines[idx]:
            # Description overflows to next line.
            if idx + 1 < len(lines):
                desc_col_long = String(lines[idx + 1]).find("Description")
        if "-s, --short" in lines[idx]:
            desc_col_short = String(lines[idx]).find("Short one")
    assert_true(
        desc_col_long > 0,
        msg="Description should appear in long option line",
    )
    assert_true(
        desc_col_short > 0,
        msg="Short one should appear in short option line",
    )
    assert_equal(
        desc_col_long,
        desc_col_short,
        msg="Help descriptions should be aligned at the same column",
    )


def test_help_and_version_aligned() raises:
    """Tests that built-in -h and -V lines align with user options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var help = command._generate_help(color=False)
    var desc_col_output: Int = -1
    var desc_col_help: Int = -1
    var desc_col_version: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "-o, --output" in lines[idx]:
            desc_col_output = lines[idx].find("Output file")
        if "-h, --help" in lines[idx]:
            desc_col_help = lines[idx].find("Show this help message")
        if "-V, --version" in lines[idx]:
            desc_col_version = lines[idx].find("Show version")
    assert_true(desc_col_output > 0, msg="Output file should be present")
    assert_true(
        desc_col_help > 0, msg="Show this help message should be present"
    )
    assert_true(desc_col_version > 0, msg="Show version should be present")
    assert_equal(
        desc_col_output,
        desc_col_help,
        msg="output and help should be aligned",
    )
    assert_equal(
        desc_col_output,
        desc_col_version,
        msg="output and version should be aligned",
    )


def test_help_on_no_arguments_disabled_by_default() raises:
    """Tests that parse_arguments works with no args when help_on_no_arguments is off.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var args: List[String] = ["test"]
    # Should NOT exit — just parse with defaults.
    var result = command.parse_arguments(args)
    assert_false(result.get_flag("verbose"), msg="verbose should be False")


def test_positional_args_aligned_in_help() raises:
    """Tests that positional arguments are dynamically aligned in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("output-directory", help="Output dir")
        .positional()
        .default["."]()
    )

    var help = command._generate_help()
    var desc_col_short: Int = -1
    var desc_col_long: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "pattern" in lines[idx] and "Search pattern" in lines[idx]:
            desc_col_short = lines[idx].find("Search pattern")
        if "output-directory" in lines[idx] and "Output dir" in lines[idx]:
            desc_col_long = lines[idx].find("Output dir")
    assert_true(desc_col_short > 0, msg="Search pattern should be present")
    assert_true(desc_col_long > 0, msg="Output dir should be present")
    assert_equal(
        desc_col_short,
        desc_col_long,
        msg="positional arg descriptions should be aligned",
    )


def test_help_contains_ansi_colors() raises:
    """Tests that colored help output contains ANSI escape codes."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var colored = command._generate_help(color=True)
    var plain = command._generate_help(color=False)

    # Colored output should contain ANSI escape codes.
    assert_true(
        "\x1b[" in colored,
        msg="Colored help should contain ANSI escape codes",
    )
    # Plain output should NOT contain ANSI escape codes.
    assert_false(
        "\x1b[" in plain,
        msg="Plain help should not contain ANSI escape codes",
    )
    # Both should contain the actual content.
    assert_true("verbose" in colored, msg="colored help should have 'verbose'")
    assert_true("verbose" in plain, msg="plain help should have 'verbose'")
    assert_true(
        "options:" in colored, msg="colored help should have 'options:'"
    )
    assert_true("options:" in plain, msg="plain help should have 'options:'")


def test_help_color_false_no_codes() raises:
    """Tests that color=False produces identical output to pre-color era."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var help = command._generate_help(color=False)
    # Section headers should appear without any escape sequences.
    assert_true("usage: test" in help, msg="Usage line should be plain")
    assert_true("options:\n" in help, msg="Options header should be plain")
    # No escape character anywhere.
    assert_false("\x1b" in help, msg="No escape chars in plain mode")


def test_custom_header_color() raises:
    """Setting header_color changes the header ANSI code in help output."""
    var command = Command("app", "My app")
    command.add_argument(Argument("file", help="Input file").long["file"]())
    command.header_color["RED"]()

    var help = command._generate_help(color=True)
    # RED = \x1b[91m ; bold+underline = \x1b[1;4m
    assert_true(
        "\x1b[91m" in help,
        msg="Header should use red ANSI code \\x1b[91m",
    )
    # The default header colour (yellow) should NOT appear.
    assert_false(
        "\x1b[93m" in help,
        msg="Default yellow header code should be absent",
    )


def test_custom_arg_color() raises:
    """Setting argument_color changes the arg-name ANSI code in help output."""
    var command = Command("app", "My app")
    command.add_argument(
        Argument("verbose", help="Be verbose").long["verbose"]().flag()
    )
    command.argument_color["GREEN"]()

    var help = command._generate_help(color=True)
    # GREEN = \x1b[92m
    assert_true(
        "\x1b[92m" in help,
        msg="Argument names should use green ANSI code \\x1b[92m",
    )
    # The default arg colour (magenta) should NOT appear.
    assert_false(
        "\x1b[95m" in help,
        msg="Default magenta arg code should be absent",
    )


def test_custom_both_colors() raises:
    """Setting both header_color and argument_color at the same time."""
    var command = Command("app", "My app")
    command.add_argument(Argument("file", help="Input").long["file"]())
    command.header_color["BLUE"]()
    command.argument_color["GREEN"]()

    var help = command._generate_help(color=True)
    assert_true("\x1b[94m" in help, msg="Header should be blue (94)")
    assert_true("\x1b[92m" in help, msg="Args should be green (92)")
    # Bold+underline should still appear for headers.
    assert_true(
        "\x1b[1;4m" in help, msg="Bold+underline should still be present"
    )


def test_default_colors_unchanged() raises:
    """Without any setter, help uses default yellow headers + distinct arg colors.
    """
    var command = Command("app", "My app")
    command.add_argument(Argument("name", help="Your name").long["name"]())

    var help = command._generate_help(color=True)
    # Default header = yellow \x1b[93m
    assert_true("\x1b[93m" in help, msg="Default header should be yellow (93)")
    # Default short_opt = bold green \x1b[1;32m
    assert_true(
        "\x1b[1;32m" in help,
        msg="Default short opt should be bold green (1;32)",
    )
    # Default long_opt = bold cyan \x1b[1;36m
    assert_true(
        "\x1b[1;36m" in help,
        msg="Default long opt should be bold cyan (1;36)",
    )
    # Default prog = bold magenta \x1b[1;35m
    assert_true(
        "\x1b[1;35m" in help,
        msg="Default prog should be bold magenta (1;35)",
    )


def test_color_uppercase_only() raises:
    """Colour names must be uppercase: 'GREEN' works."""
    var command = Command("a", "A")
    command.add_argument(Argument("x", help="x").long["x"]())
    command.header_color["GREEN"]()
    var h = command._generate_help(color=True)
    assert_true("\x1b[92m" in h, msg="'GREEN' uppercase should resolve")


def test_pink_alias_for_magenta() raises:
    """'PINK' is an alias for MAGENTA (\\x1b[95m)."""
    var command = Command("app", "My app")
    command.add_argument(Argument("f", help="File").long["file"]())
    command.argument_color["PINK"]()

    var help = command._generate_help(color=True)
    assert_true(
        "\x1b[95m" in help,
        msg="PINK alias should produce magenta ANSI code",
    )


def test_invalid_color_caught_at_compile_time() raises:
    """Invalid colour names are caught at compile time via constrained[].

    This test simply verifies the valid path works.  An invalid name
    like ``command.header_color["PURPLE"]()`` would fail to compile.
    """
    var command = Command("app", "My app")
    command.header_color["RED"]()
    command.argument_color["GREEN"]()
    command.warn_color["YELLOW"]()
    command.error_color["MAGENTA"]()

    # Verify that the valid names actually configure the expected ANSI codes.
    assert_equal(
        command._header_color,
        "\x1b[91m",
        msg="Header color 'RED' should map to bright red (ANSI 91)",
    )
    assert_equal(
        command._argument_color,
        "\x1b[92m",
        msg="Arg color 'GREEN' should map to bright green (ANSI 92)",
    )
    assert_equal(
        command._warn_color,
        "\x1b[93m",
        msg="Warn color 'YELLOW' should map to bright yellow (ANSI 93)",
    )
    assert_equal(
        command._error_color,
        "\x1b[95m",
        msg="Error color 'MAGENTA' should map to bright magenta (ANSI 95)",
    )


def test_custom_color_plain_mode_unaffected() raises:
    """Custom colours should not leak into plain (color=False) output."""
    var command = Command("app", "My app")
    command.add_argument(Argument("x", help="X option").long["x"]())
    command.header_color["RED"]()
    command.argument_color["BLUE"]()

    var help = command._generate_help(color=False)
    assert_false("\x1b" in help, msg="Plain mode should have no ANSI codes")
    assert_true("options:" in help, msg="Plain mode should still have content")


# ═══════════════════════════════════════════════════════════════════════════════
# Nargs (multi-value per option) in help
# ═══════════════════════════════════════════════════════════════════════════════


def test_nargs_in_help() raises:
    """Tests that nargs options show repeated placeholders in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y coords")
        .long["point"]()
        .number_of_values[2]()
    )
    command.add_argument(
        Argument("rgb", help="RGB colour")
        .long["rgb"]()
        .number_of_values[3]()
        .value_name["N"]()
    )

    var help = command._generate_help(color=False)
    # --point should show <point> <point>
    assert_true(
        "<point> <point>" in help,
        msg="number_of_values(2) should show '<point> <point>' in help",
    )
    # --rgb should show <N> <N> <N>
    assert_true(
        "<N> <N> <N>" in help,
        msg="number_of_values(3) with value_name should show '<N> <N> <N>'",
    )
    # Neither should have "..." since they are nargs, not plain append.
    assert_false(
        "<point>..." in help,
        msg="nargs should NOT show '...' suffix",
    )


def test_nargs_with_value_name() raises:
    """Tests nargs with a custom value_name in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("size", help="Width and height")
        .long["size"]()
        .number_of_values[2]()
        .value_name["PX"]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "<PX> <PX>" in help,
        msg="number_of_values(2) with value_name PX should show '<PX> <PX>'",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Subcommand help UX
# ═══════════════════════════════════════════════════════════════════════════════


def test_root_help_shows_commands_section() raises:
    """Tests that root help includes a commands: section when subcommands are registered.
    """
    var app = Command("app", "My CLI tool")
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var search = Command("search", "Search for patterns")
    var init = Command("init", "Initialize a new project")
    app.add_subcommand(search^)
    app.add_subcommand(init^)

    var help = app._generate_help(color=False)
    assert_true("commands:" in help, msg="Help should have commands: section")
    assert_true("search" in help, msg="Help should list 'search' subcommand")
    assert_true("init" in help, msg="Help should list 'init' subcommand")
    assert_true(
        "Search for patterns" in help,
        msg="Help should include subcommand description",
    )
    assert_true(
        "Initialize a new project" in help,
        msg="Help should include init description",
    )


def test_root_help_no_commands_when_no_subcommands() raises:
    """Tests that commands: section is omitted when no subcommands are registered.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var help = command._generate_help(color=False)
    assert_false("commands:" in help, msg="No commands: without subcommands")


def test_root_help_commands_excludes_help_sub() raises:
    """Tests that the auto-inserted 'help' subcommand is not listed in Commands.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search"))
    # 'help' subcommand is auto-added.

    var help = app._generate_help(color=False)
    assert_true("commands:" in help, msg="Should have commands: section")
    assert_true("search" in help, msg="search should appear")
    # Check that 'help' doesn't appear as a listed command entry.
    # (It may appear in other contexts like --help, but not as a subcommand line.)
    var lines = help.split("\n")
    var found_help_cmd = False
    var in_commands = False
    for i in range(len(lines)):
        if lines[i].startswith("commands:"):
            in_commands = True
            continue
        if in_commands:
            # End of section if we hit a blank line or another heading.
            if not lines[i] or (
                len(lines[i]) > 0 and not lines[i].startswith(" ")
            ):
                in_commands = False
                continue
            # Check for '  help' as a subcommand entry.
            var stripped = String("")
            for c in range(len(lines[i])):
                if lines[i].as_bytes()[c] != 32:
                    stripped = String(lines[i][byte=c:])
                    break
            if stripped.startswith("help"):
                found_help_cmd = True
    assert_false(
        found_help_cmd, msg="'help' sub should not appear in Commands:"
    )


def test_root_help_usage_shows_command_placeholder() raises:
    """Tests that usage line includes <COMMAND> when subcommands are registered.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search"))

    var help = app._generate_help(color=False)
    assert_true(
        "<COMMAND>" in help,
        msg="Usage should show <COMMAND> placeholder",
    )


def test_root_help_usage_no_command_placeholder_without_subs() raises:
    """Tests that usage line does NOT include <COMMAND> when no subcommands."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var help = command._generate_help(color=False)
    assert_false(
        "<COMMAND>" in help,
        msg="Usage should NOT show <COMMAND> without subcommands",
    )


def test_persistent_args_under_global_options() raises:
    """Tests that persistent args appear under a 'global options:' heading."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
        .persistent()
    )
    app.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )
    app.add_subcommand(Command("search", "Search"))

    var help = app._generate_help(color=False)
    assert_true(
        "global options:" in help,
        msg="Should have global options: section",
    )
    assert_true("options:" in help, msg="Should have options: section")
    # --output should be under Options, --verbose under Global Options.
    # Check ordering: Options comes before Global Options.
    var opt_pos = help.find("options:")
    var global_pos = help.find("global options:")
    assert_true(
        opt_pos < global_pos,
        msg="options: should come before global options:",
    )


def test_no_global_options_without_persistent() raises:
    """Tests that global options: section is absent when no persistent args."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    app.add_subcommand(Command("search", "Search"))

    var help = app._generate_help(color=False)
    assert_false(
        "global options:" in help,
        msg="No global options: without persistent args",
    )


def test_child_help_shows_full_command_path() raises:
    """Tests that child help shows full command path (e.g. 'app search')."""
    var app = Command("app", "My app")
    var search = Command("search", "Search for patterns")
    search.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    app.add_subcommand(search^)

    # Simulate: app search --help
    # The child copy gets name set to "app search", so --help would
    # show "usage: app search ..." in help.
    # We test indirectly by checking what parse_arguments sets on the child copy.
    # Create the child copy as parse_arguments would.
    # Note: subcommands[0] is auto-added 'help'; search is at index 1.
    var search_idx = app._find_subcommand("search")
    var child_copy = app.subcommands[search_idx].copy()
    child_copy.name = "app search"
    var help = child_copy._generate_help(color=False)
    assert_true(
        "app search" in help,
        msg="Child help should show full command path",
    )


def test_child_help_shows_inherited_persistent_args() raises:
    """Tests that child help includes inherited persistent args under Global Options.
    """
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
        .persistent()
    )
    var search = Command("search", "Search for patterns")
    search.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    search.add_argument(
        Argument("max-depth", help="Max depth").long["max-depth"]().short["d"]()
    )
    app.add_subcommand(search^)

    # Simulate child copy with injected persistent arguments.
    # Note: subcommands[0] is auto-added 'help'; search is at index 1.
    var search_idx = app._find_subcommand("search")
    var child_copy = app.subcommands[search_idx].copy()
    child_copy.name = "app search"
    child_copy.arguments.append(app.arguments[0].copy())  # Inject --verbose

    var help = child_copy._generate_help(color=False)
    assert_true(
        "global options:" in help,
        msg="Child help should have global options:",
    )
    assert_true(
        "--verbose" in help,
        msg="Inherited --verbose should appear in child help",
    )
    assert_true(
        "--max-depth" in help,
        msg="Local --max-depth should appear in child help",
    )


def test_add_tip_appears_in_help() raises:
    """Tests that custom tips appear in help output."""
    var command = Command("test", "Test app")
    command.add_tip("Set DEBUG=1 for debug logging.")
    command.add_tip("Config: ~/.config/test/config.toml")

    var help = command._generate_help(color=False)
    assert_true(
        "Set DEBUG=1 for debug logging." in help,
        msg="First tip should appear in help",
    )
    assert_true(
        "Config: ~/.config/test/config.toml" in help,
        msg="Second tip should appear in help",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Alias in help output
# ═══════════════════════════════════════════════════════════════════════════════


def test_alias_shown_inline_in_help() raises:
    """Tests that subcommand aliases appear inline in help output."""
    var app = Command("app", "Test app")
    var clone = Command("clone", "Clone a repo")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)

    var help = app._generate_help(color=False)
    assert_true(
        "clone, cl" in help,
        msg="Help should show alias inline: 'clone, cl'",
    )


def test_multiple_aliases_shown_in_help() raises:
    """Tests that multiple aliases are all shown inline in help."""
    var app = Command("app", "Test app")
    var commit = Command("commit", "Record changes")
    var aliases: List[String] = ["ci", "cm"]
    commit.command_aliases(aliases^)
    app.add_subcommand(commit^)

    var help = app._generate_help(color=False)
    assert_true(
        "commit, ci, cm" in help,
        msg="Help should show all aliases: 'commit, ci, cm'",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Hidden subcommands
# ═══════════════════════════════════════════════════════════════════════════════


def test_hidden_subcommand_not_in_help() raises:
    """Tests that hidden subcommands are excluded from help output."""
    var app = Command("app", "Test app")
    var clone = Command("clone", "Clone a repository")
    app.add_subcommand(clone^)
    var debug = Command("debug", "Internal debug command")
    debug.hidden()
    app.add_subcommand(debug^)

    var help = app._generate_help(color=False)
    assert_true("clone" in help, msg="visible sub should be in help")
    assert_false("debug" in help, msg="hidden sub should NOT be in help")


def test_hidden_subcommand_not_in_usage_line() raises:
    """Tests that usage line omits [command] if all subs are hidden."""
    var app = Command("app", "Test app")
    var debug = Command("debug", "Internal debug command")
    debug.hidden()
    app.add_subcommand(debug^)

    var help = app._generate_help(color=False)
    assert_false(
        "<COMMAND>" in help,
        msg="usage line should not show <COMMAND> when only subs are hidden",
    )


def test_hidden_subcommand_usage_line_with_visible() raises:
    """Tests that usage line shows [command] when visible subs remain."""
    var app = Command("app", "Test app")
    var clone = Command("clone", "Clone a repository")
    app.add_subcommand(clone^)
    var debug = Command("debug", "Internal debug command")
    debug.hidden()
    app.add_subcommand(debug^)

    var help = app._generate_help(color=False)
    assert_true(
        "<COMMAND>" in help,
        msg="usage line should show <COMMAND> when visible subs exist",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# NO_COLOR
# ═══════════════════════════════════════════════════════════════════════════════


def test_no_color_env_static_method() raises:
    """Tests _no_color_env() returns the correct value based on environment."""
    # We can't set env vars from Mojo easily, so just verify the method
    # exists and returns a Bool without crashing.
    var result = Command._no_color_env()
    # In the test environment NO_COLOR is typically unset → False.
    # We just verify it returns without error (type-level check).
    if result:
        print("  ✓ test_no_color_env_static_method (NO_COLOR is set)")
    else:
        print("  ✓ test_no_color_env_static_method (NO_COLOR is not set)")


# ═══════════════════════════════════════════════════════════════════════════════
# CJK-aware help alignment
# ═══════════════════════════════════════════════════════════════════════════════


def test_cjk_options_aligned() raises:
    """Tests that CJK help text doesn't break column alignment."""
    var command = Command("test", "測試應用")
    command.add_argument(
        Argument("verbose", help="顯示詳細資訊").long["verbose"]().short["v"]().flag()
    )
    command.add_argument(
        Argument("output", help="輸出路徑").long["output"]().short["o"]()
    )

    var help = command._generate_help(color=False)
    # Both help descriptions should start at the same display column.
    var col_verbose: Int = -1
    var col_output: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "--verbose" in lines[idx]:
            var bp = lines[idx].find("顯示詳細資訊")
            col_verbose = _display_width(String(lines[idx][byte=0:bp]))
        if "--output" in lines[idx]:
            var bp = lines[idx].find("輸出路徑")
            col_output = _display_width(String(lines[idx][byte=0:bp]))
    assert_true(col_verbose > 0, msg="verbose help should appear")
    assert_true(col_output > 0, msg="output help should appear")
    assert_equal(
        col_verbose,
        col_output,
        msg="CJK help descriptions should be aligned at the same column",
    )


def test_cjk_subcommands_aligned() raises:
    """Tests that CJK subcommand descriptions align correctly."""
    var app = Command("工具", "一個命令行工具")
    var init = Command("初始化", "建立新項目")
    app.add_subcommand(init^)
    var build = Command("構建", "編譯項目")
    app.add_subcommand(build^)

    var help = app._generate_help(color=False)
    var col_init: Int = -1
    var col_build: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "初始化" in lines[idx] and "建立新項目" in lines[idx]:
            var bp = lines[idx].find("建立新項目")
            col_init = _display_width(String(lines[idx][byte=0:bp]))
        if "構建" in lines[idx] and "編譯項目" in lines[idx]:
            var bp = lines[idx].find("編譯項目")
            col_build = _display_width(String(lines[idx][byte=0:bp]))
    assert_true(col_init > 0, msg="init description should appear")
    assert_true(col_build > 0, msg="build description should appear")
    assert_equal(
        col_init,
        col_build,
        msg="CJK subcommand descriptions should be aligned",
    )


def test_cjk_positionals_aligned() raises:
    """Tests that CJK positional argument help aligns correctly."""
    var command = Command("test", "測試")
    command.add_argument(Argument("檔案", help="輸入檔案路徑"))
    command.add_argument(Argument("目標", help="輸出目標位置"))

    var help = command._generate_help(color=False)
    var col_file: Int = -1
    var col_target: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "檔案" in lines[idx] and "輸入檔案路徑" in lines[idx]:
            var bp = lines[idx].find("輸入檔案路徑")
            col_file = _display_width(String(lines[idx][byte=0:bp]))
        if "目標" in lines[idx] and "輸出目標位置" in lines[idx]:
            var bp = lines[idx].find("輸出目標位置")
            col_target = _display_width(String(lines[idx][byte=0:bp]))
    assert_true(col_file > 0, msg="file help should appear")
    assert_true(col_target > 0, msg="target help should appear")
    assert_equal(
        col_file,
        col_target,
        msg="CJK positional descriptions should be aligned",
    )


def test_mixed_ascii_cjk_aligned() raises:
    """Tests alignment when mixing ASCII and CJK option names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output path").long["output"]().short["o"]()
    )
    command.add_argument(Argument("編碼", help="設定編碼").long["編碼"]())

    var help = command._generate_help(color=False)
    var col_output: Int = -1
    var col_enc: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "--output" in lines[idx]:
            var bp = lines[idx].find("Output path")
            col_output = _display_width(String(lines[idx][byte=0:bp]))
        if "--編碼" in lines[idx]:
            var bp = lines[idx].find("設定編碼")
            col_enc = _display_width(String(lines[idx][byte=0:bp]))
    assert_true(col_output > 0, msg="output help should appear")
    assert_true(col_enc > 0, msg="encoding help should appear")
    assert_equal(
        col_output,
        col_enc,
        msg="Mixed ASCII/CJK option help should be aligned",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Custom usage line
# ═══════════════════════════════════════════════════════════════════════════════


def test_custom_usage_in_plain_help() raises:
    """Tests that custom usage appears in plain help output."""
    var command = Command("git", "The stupid content tracker")
    command.usage("git [-v | --version] [-C <path>] <command> [<args>]")

    var help = command._generate_help(color=False)
    assert_true(
        "usage: git [-v | --version] [-C <path>] <command> [<args>]" in help,
        msg="Custom usage should appear in plain help: " + help,
    )


def test_custom_usage_in_colored_help() raises:
    """Tests that custom usage appears in colored help output."""
    var command = Command("git", "The stupid content tracker")
    command.usage("git [-v | --version] [-C <path>] <command> [<args>]")

    var help = command._generate_help(color=True)
    # The custom text should appear (wrapped in ANSI codes for "usage:")
    assert_true(
        "git [-v | --version]" in help,
        msg="Custom usage text should appear in colored help: " + help,
    )


def test_custom_usage_replaces_auto_generated() raises:
    """Tests that custom usage replaces the auto-generated positionals."""
    var command = Command("myapp", "My app")
    command.add_argument(
        Argument("file", help="Input file").positional().required()
    )
    command.add_argument(
        Argument("output", help="Output file").long["output"]()
    )
    command.usage("myapp FILE [--output FILE]")

    var help = command._generate_help(color=False)
    assert_true(
        "usage: myapp FILE [--output FILE]" in help,
        msg="Custom usage should replace auto-generated: " + help,
    )
    # The auto-generated "<file> [OPTIONS]" should NOT appear in usage line
    var lines = help.split("\n")
    for i in range(len(lines)):
        if "usage:" in lines[i]:
            assert_false(
                "<file>" in lines[i],
                msg="Auto-generated positional should not appear in usage line",
            )
            break


def test_default_usage_when_no_custom() raises:
    """Tests that auto-generated usage is used when no custom is set."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="Input file").positional().required()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "usage: test <file> [OPTIONS]" in help,
        msg="Default usage should show auto-generated format: " + help,
    )


def test_default_usage_with_optional_positional() raises:
    """Tests auto-generated usage for optional positional."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("path", help="Search path").positional().default["."]()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "usage: test [path] [OPTIONS]" in help,
        msg="Optional positional should be in brackets: " + help,
    )


def test_default_usage_with_subcommands() raises:
    """Tests auto-generated usage with subcommands."""
    var app = Command("app", "My app")
    var sub = Command("deploy", "Deploy something")
    app.add_subcommand(sub^)

    var help = app._generate_help(color=False)
    assert_true(
        "usage: app <COMMAND> [OPTIONS]" in help,
        msg="Subcommand usage should show <COMMAND>: " + help,
    )


def test_custom_usage_preserved_in_copy() raises:
    """Tests that custom usage is preserved when copying a Command."""
    var original = Command("git", "Git")
    original.usage("git [options] <command> [<args>]")

    var copied = original.copy()
    var help = copied._generate_help(color=False)
    assert_true(
        "usage: git [options] <command> [<args>]" in help,
        msg="Custom usage should be preserved in copy: " + help,
    )


def test_custom_usage_with_subcommands() raises:
    """Tests custom usage with subcommands registered."""
    var app = Command("app", "My app")
    app.usage("app [-v] <command>")
    var sub = Command("deploy", "Deploy something")
    app.add_subcommand(sub^)

    var help = app._generate_help(color=False)
    assert_true(
        "usage: app [-v] <command>" in help,
        msg="Custom usage should override even with subcommands: " + help,
    )
    # Auto-generated <COMMAND> should NOT appear
    assert_false(
        "<COMMAND>" in help,
        msg="Auto-generated <COMMAND> should not appear with custom usage",
    )


def test_custom_usage_description_still_shown() raises:
    """Tests that description is still shown above custom usage."""
    var command = Command("myapp", "A great application")
    command.usage("myapp [options]")

    var help = command._generate_help(color=False)
    assert_true(
        "A great application" in help,
        msg="Description should still appear: " + help,
    )
    assert_true(
        "usage: myapp [options]" in help,
        msg="Custom usage should appear after description: " + help,
    )


def test_custom_usage_parsing_still_works() raises:
    """Tests that custom usage doesn't affect parsing behavior."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="Input file").positional().required()
    )
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    command.usage("test FILE [--verbose]")

    var args: List[String] = ["test", "input.txt", "--verbose"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("file"), "input.txt")
    assert_true(result.get_flag("verbose"), msg="--verbose should work")


def test_custom_usage_in_plain_usage_hint() raises:
    """Tests that custom usage appears in the plain usage hint (_plain_usage).
    """
    var command = Command("git", "The stupid content tracker")
    command.usage("git [-v | --version] [-C <path>] <command> [<args>]")

    # _plain_usage is used for error/usage hints; ensure it reflects custom usage.
    var usage = command._plain_usage()
    assert_true(
        "git [-v | --version] [-C <path>] <command> [<args>]" in usage,
        msg="Custom usage should appear in plain usage hint: " + usage,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Full-width → half-width auto-correction (CJK/Unicode)
# ═══════════════════════════════════════════════════════════════════════════════

# U+3000 = IDEOGRAPHIC SPACE (fullwidth space)
# U+2003 = EM SPACE


# ── Unit tests for utility functions ─────────────────────────────────────────


def test_has_fullwidth_chars_ascii() raises:
    """Tests that plain ASCII strings have no fullwidth characters."""
    assert_false(
        _has_fullwidth_chars("--verbose"),
        msg="plain ASCII should not have fullwidth chars",
    )
    assert_false(
        _has_fullwidth_chars("-v"),
        msg="short option should not have fullwidth chars",
    )
    assert_false(
        _has_fullwidth_chars("hello world"),
        msg="regular text should not have fullwidth chars",
    )


def test_has_fullwidth_chars_cjk() raises:
    """Tests that CJK ideographs are NOT detected as fullwidth ASCII."""
    # CJK ideographs are NOT in the fullwidth ASCII range FF01-FF5E.
    assert_false(
        _has_fullwidth_chars("漢字"),
        msg="CJK ideographs are not fullwidth ASCII",
    )


def test_has_fullwidth_chars_fullwidth_ascii() raises:
    """Tests that fullwidth ASCII characters are detected."""
    # U+FF0D = fullwidth hyphen-minus ＝ －
    assert_true(
        _has_fullwidth_chars("－－ｖｅｒｂｏｓｅ"),
        msg="fullwidth ASCII should be detected",
    )
    assert_true(
        _has_fullwidth_chars("ｈｅｌｌｏ"),
        msg="fullwidth Latin should be detected",
    )


def test_has_fullwidth_chars_fullwidth_space() raises:
    """Tests that fullwidth space U+3000 is detected."""
    var fw_space = chr(0x3000)
    assert_true(
        _has_fullwidth_chars("hello" + fw_space + "world"),
        msg="fullwidth space should be detected",
    )


def test_has_fullwidth_chars_fullwidth_equals() raises:
    """Tests that fullwidth equals sign U+FF1D is detected."""
    assert_true(
        _has_fullwidth_chars("--key＝value"),
        msg="fullwidth equals should be detected",
    )


def test_fullwidth_to_halfwidth_no_change() raises:
    """Tests that strings without fullwidth chars are unchanged."""
    assert_equal(
        _fullwidth_to_halfwidth("--verbose"),
        "--verbose",
    )
    assert_equal(
        _fullwidth_to_halfwidth("hello"),
        "hello",
    )


def test_fullwidth_to_halfwidth_option() raises:
    """Tests fullwidth option name correction."""
    assert_equal(
        _fullwidth_to_halfwidth("－－ｖｅｒｂｏｓｅ"),
        "--verbose",
    )


def test_fullwidth_to_halfwidth_short_option() raises:
    """Tests fullwidth short option correction."""
    assert_equal(
        _fullwidth_to_halfwidth("－ｖ"),
        "-v",
    )


def test_fullwidth_to_halfwidth_equals() raises:
    """Tests fullwidth equals sign in --key=value."""
    assert_equal(
        _fullwidth_to_halfwidth("－－ｋｅｙ＝ｖａｌｕｅ"),
        "--key=value",
    )


def test_fullwidth_to_halfwidth_space() raises:
    """Tests fullwidth space U+3000 conversion."""
    var fw_space = chr(0x3000)
    assert_equal(
        _fullwidth_to_halfwidth("hello" + fw_space + "world"),
        "hello world",
    )


def test_fullwidth_to_halfwidth_mixed() raises:
    """Tests mixed fullwidth ASCII with CJK characters."""
    # CJK characters should be preserved, only fullwidth ASCII converted.
    var result = _fullwidth_to_halfwidth("－－ｎａｍｅ＝宇浩")
    assert_true(
        result.startswith("--name="),
        msg="fullwidth ASCII prefix should convert: got '" + result + "'",
    )
    assert_true(
        "宇浩" in result,
        msg="CJK characters should be preserved: got '" + result + "'",
    )


def test_split_on_fullwidth_spaces_no_spaces() raises:
    """Tests that tokens without fullwidth spaces return a single element."""
    var parts = _split_on_fullwidth_spaces("--verbose")
    assert_equal(len(parts), 1)
    assert_equal(parts[0], "--verbose")


def test_split_on_fullwidth_spaces_with_spaces() raises:
    """Tests splitting on fullwidth spaces."""
    var fw_space = chr(0x3000)
    var token = "－－ｎａｍｅ" + fw_space + "ｙｕｈａｏ" + fw_space + "－－ｖｅｒｂｏｓｅ"
    var parts = _split_on_fullwidth_spaces(token)
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "--name")
    assert_equal(parts[1], "yuhao")
    assert_equal(parts[2], "--verbose")


# ── Unit tests for CJK punctuation correction ──────────────────────────────────


def test_correct_cjk_punctuation_no_change() raises:
    """Tests that strings without CJK punctuation are unchanged."""
    assert_equal(_correct_cjk_punctuation("--verbose"), "--verbose")
    assert_equal(_correct_cjk_punctuation("hello"), "hello")


def test_correct_cjk_punctuation_em_dash() raises:
    """Tests em-dash (U+2014) → hyphen-minus conversion."""
    # Two em-dashes + "verbose" should become "--verbose".
    var double_em_dash = String(chr(0x2014)) + chr(0x2014)
    assert_equal(
        _correct_cjk_punctuation(double_em_dash + "verbose"),
        "--verbose",
    )


def test_correct_cjk_punctuation_preserves_cjk() raises:
    """Tests that CJK ideographs are preserved."""
    assert_equal(_correct_cjk_punctuation("宇浩"), "宇浩")


# ── Integration tests: parsing with fullwidth correction ─────────────────────


def test_fullwidth_long_flag() raises:
    """Tests that a fullwidth --verbose flag is auto-corrected and parsed."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var args: List[String] = ["test", "－－ｖｅｒｂｏｓｅ"]
    var result = command.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="fullwidth --verbose should be corrected and parsed",
    )


def test_fullwidth_short_flag() raises:
    """Tests that a fullwidth -v flag is auto-corrected and parsed."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var args: List[String] = ["test", "－ｖ"]
    var result = command.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="fullwidth -v should be corrected and parsed",
    )


def test_fullwidth_key_value_equals() raises:
    """Tests fullwidth --key＝value auto-correction."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .takes_value()
    )

    var args: List[String] = ["test", "－－ｏｕｔｐｕｔ＝ｆｉｌｅ．ｔｘｔ"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("output"),
        "file.txt",
        msg="fullwidth = syntax should be corrected",
    )


def test_fullwidth_key_space_value() raises:
    """Tests fullwidth --key with space-separated value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long["output"]()
        .short["o"]()
        .takes_value()
    )

    var args: List[String] = ["test", "－－ｏｕｔｐｕｔ", "file.txt"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("output"),
        "file.txt",
        msg="fullwidth option name with halfwidth value should work",
    )


def test_fullwidth_embedded_space() raises:
    """Tests that fullwidth spaces in a single token cause splitting."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("name", help="Name").long["name"]().short["n"]().takes_value()
    )

    var fw_space = chr(0x3000)
    var token = "－－ｎａｍｅ" + fw_space + "ｙｕｈａｏ" + fw_space + "－－ｖｅｒｂｏｓｅ"
    var args: List[String] = ["test", token]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("name"),
        "yuhao",
        msg="embedded fullwidth space should split: name",
    )
    assert_true(
        result.get_flag("verbose"),
        msg="embedded fullwidth space should split: verbose",
    )


def test_positional_fullwidth_converted() raises:
    """Tests that fullwidth positional values are converted but stay positional.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("query", help="Search query").positional().required()
    )

    # Fullwidth text as a positional is still converted to halfwidth,
    # but since it doesn't start with `-` after conversion, no warning
    # is shown and it goes through as a positional.
    var args: List[String] = ["test", "ｈｅｌｌｏ"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("query"),
        "hello",
        msg="fullwidth positional should be converted to halfwidth",
    )


def test_disable_fullwidth_correction() raises:
    """Tests that disable_fullwidth_correction() prevents auto-correction."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.disable_fullwidth_correction()

    # With correction disabled, fullwidth "--verbose" is not recognised.
    var args: List[String] = ["test", "－－ｖｅｒｂｏｓｅ"]
    # It should be treated as a positional (or cause an error for unknown option).
    # Since the command has no positional args defined, it becomes a positional.
    var result = command.parse_arguments(args)
    assert_false(
        result.get_flag("verbose"),
        msg="with correction disabled, fullwidth should NOT parse as --verbose",
    )


def test_fullwidth_with_choices() raises:
    """Tests fullwidth correction combined with choices validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .short["f"]()
        .takes_value()
        .choice["json"]()
        .choice["yaml"]()
        .choice["csv"]()
    )

    var args: List[String] = ["test", "－－ｆｏｒｍａｔ＝ｊｓｏｎ"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("format"),
        "json",
        msg="fullwidth --format=json should be corrected and validated",
    )


def test_fullwidth_merged_short_flags() raises:
    """Tests fullwidth merged short flags like -abc."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("all", help="Show all").long["all"]().short["a"]().flag()
    )
    command.add_argument(
        Argument("brief", help="Brief output")
        .long["brief"]()
        .short["b"]()
        .flag()
    )
    command.add_argument(
        Argument("color", help="Colorize").long["color"]().short["c"]().flag()
    )

    var args: List[String] = ["test", "－ａｂｃ"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("all"), msg="fullwidth -a should work")
    assert_true(result.get_flag("brief"), msg="fullwidth -b should work")
    assert_true(result.get_flag("color"), msg="fullwidth -c should work")


def test_fullwidth_with_subcommand() raises:
    """Tests fullwidth option correction with subcommand dispatch."""
    var app = Command("test", "Test app")
    app.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
        .persistent()
    )

    var sub = Command("build", "Build project")
    sub.add_argument(
        Argument("target", help="Build target").positional().required()
    )
    app.add_subcommand(sub^)

    var args: List[String] = ["test", "－－ｖｅｒｂｏｓｅ", "build", "release"]
    var result = app.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="fullwidth --verbose before subcommand should work",
    )
    assert_equal(result.subcommand, "build")
    var sub_result = result.get_subcommand_result()
    assert_equal(sub_result.get_string("target"), "release")


def test_fullwidth_parse_known_arguments() raises:
    """Tests fullwidth correction works with parse_known_arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )

    var args: List[String] = ["test", "－－ｖｅｒｂｏｓｅ"]
    var result = command.parse_known_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="fullwidth should work with parse_known_arguments",
    )


def test_fullwidth_cjk_positional_preserved() raises:
    """Tests that CJK characters in positional values are preserved."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("query", help="Search query").positional().required()
    )

    var args: List[String] = ["test", "宇浩輸入法"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("query"),
        "宇浩輸入法",
        msg="CJK positional values should be untouched",
    )


def test_fullwidth_punctuation_em_dash_correction() raises:
    """Tests that em-dash is auto-corrected to hyphen-minus in pre-parse."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var double_em_dash = chr(0x2014) + chr(0x2014)
    var args: List[String] = ["test", double_em_dash + "verbose"]
    var result = command.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="em-dash '——verbose' should be corrected to '--verbose'",
    )


def test_fullwidth_punctuation_disabled() raises:
    """Tests that disable_punctuation_correction() prevents correction."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.disable_punctuation_correction()
    var double_em_dash = chr(0x2014) + chr(0x2014)
    var args: List[String] = ["test", double_em_dash + "verbose"]
    var result = command.parse_arguments(args)
    assert_false(
        result.get_flag("verbose"),
        msg="With correction disabled, em-dash should NOT be corrected",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Test runner
# ═══════════════════════════════════════════════════════════════════════════════


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
