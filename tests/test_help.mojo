"""Tests for argmojo — help output formatting and colours."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Hidden arguments ──────────────────────────────────────────────────────────────


fn test_hidden_not_in_help() raises:
    """Tests that hidden arguments are excluded from help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    command.add_argument(
        Argument("debug", help="Debug mode")
        .long("debug")
        .short("d")
        .flag()
        .hidden()
    )

    var help = command._generate_help()
    assert_true("verbose" in help, msg="visible arg should be in help")
    assert_false("debug" in help, msg="hidden arg should NOT be in help")
    print("  ✓ test_hidden_not_in_help")


fn test_hidden_still_works() raises:
    """Tests that hidden arguments can still be used at the command line."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("debug", help="Debug mode")
        .long("debug")
        .short("d")
        .flag()
        .hidden()
    )

    var args: List[String] = ["test", "--debug"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("debug"), msg="hidden --debug should work")
    print("  ✓ test_hidden_still_works")


# ── Metavar ──────────────────────────────────────────────────────────────────────


fn test_metavar_in_help() raises:
    """Tests that metavar appears in help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long("output")
        .short("o")
        .metavar("FILE")
    )

    var help = command._generate_help()
    assert_true("FILE" in help, msg="metavar 'FILE' should appear in help")
    # Should NOT show the default "<output>" form.
    assert_false(
        "<output>" in help,
        msg="default placeholder should not appear when metavar is set",
    )
    print("  ✓ test_metavar_in_help")


fn test_choices_in_help() raises:
    """Tests that choices are displayed in help when no metavar."""
    var command = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var help = command._generate_help()
    assert_true(
        "{json,csv,table}" in help,
        msg="choices should appear in help as {json,csv,table}",
    )
    print("  ✓ test_choices_in_help")


# ── Count action ──────────────────────────────────────────────────────────────────


fn test_negatable_in_help() raises:
    """Test that negatable flags show --X / --no-X in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Colored output")
        .long("color")
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
    print("  ✓ test_negatable_in_help")


fn test_append_in_help() raises:
    """Tests that append args show ... suffix in help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("tag", help="Add a tag").long("tag").short("t").append()
    )
    command.add_argument(
        Argument("env", help="Target env").long("env").metavar("ENV").append()
    )

    var help = command._generate_help()
    assert_true(
        "<tag>..." in help,
        msg="append arg without metavar should show <tag>... in help",
    )
    assert_true(
        "ENV..." in help,
        msg="append arg with metavar should show ENV... in help",
    )
    print("  ✓ test_append_in_help")


# ===------------------------------------------------------------------=== #
# Help system improvements
# ===------------------------------------------------------------------=== #


fn test_help_question_mark_in_help_output() raises:
    """Tests that -h, --help appears in the generated help text."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )

    var help = command._generate_help(color=False)
    assert_true(
        "-h, --help" in help,
        msg="help output should show -h, --help",
    )
    print("  ✓ test_help_question_mark_in_help_output")


fn test_dynamic_padding_short_options() raises:
    """Tests that help padding adapts to short option names."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("v", help="Verbose").long("verbose").short("v").flag()
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
    print("  ✓ test_dynamic_padding_short_options")


fn test_dynamic_padding_long_options() raises:
    """Tests that padding grows when a very long option is present."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("very-long-option-name", help="Description").long(
            "very-long-option-name"
        )
    )
    command.add_argument(
        Argument("short", help="Short one").long("short").short("s")
    )

    var help = command._generate_help(color=False)
    # The longest user arg is "--very-long-option-name <very-long-option-name>"
    # The help descriptions should still be aligned.
    var desc_col_long: Int = -1
    var desc_col_short: Int = -1
    var lines = help.splitlines()
    for idx in range(len(lines)):
        if "--very-long-option-name" in lines[idx]:
            desc_col_long = lines[idx].find("Description")
        if "-s, --short" in lines[idx]:
            desc_col_short = lines[idx].find("Short one")
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
    print("  ✓ test_dynamic_padding_long_options")


fn test_help_and_version_aligned() raises:
    """Tests that built-in -h and -V lines align with user options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
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
    print("  ✓ test_help_and_version_aligned")


fn test_help_on_no_args_disabled_by_default() raises:
    """Tests that parse_args works with no args when help_on_no_args is off."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test"]
    # Should NOT exit — just parse with defaults.
    var result = command.parse_args(args)
    assert_false(result.get_flag("verbose"), msg="verbose should be False")
    print("  ✓ test_help_on_no_args_disabled_by_default")


fn test_positional_args_aligned_in_help() raises:
    """Tests that positional arguments are dynamically aligned in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("output-directory", help="Output dir")
        .positional()
        .default(".")
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
    print("  ✓ test_positional_args_aligned_in_help")


fn test_help_contains_ansi_colors() raises:
    """Tests that colored help output contains ANSI escape codes."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
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
        "Options:" in colored, msg="colored help should have 'Options:'"
    )
    assert_true("Options:" in plain, msg="plain help should have 'Options:'")
    print("  ✓ test_help_contains_ansi_colors")


fn test_help_color_false_no_codes() raises:
    """Tests that color=False produces identical output to pre-color era."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var help = command._generate_help(color=False)
    # Section headers should appear without any escape sequences.
    assert_true("Usage: test" in help, msg="Usage line should be plain")
    assert_true("Options:\n" in help, msg="Options header should be plain")
    # No escape character anywhere.
    assert_false("\x1b" in help, msg="No escape chars in plain mode")
    print("  ✓ test_help_color_false_no_codes")


fn test_custom_header_color() raises:
    """Setting header_color changes the header ANSI code in help output."""
    var command = Command("app", "My app")
    command.add_argument(Argument("file", help="Input file").long("file"))
    command.header_color("RED")

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
    print("  ✓ test_custom_header_color")


fn test_custom_arg_color() raises:
    """Setting arg_color changes the arg-name ANSI code in help output."""
    var command = Command("app", "My app")
    command.add_argument(
        Argument("verbose", help="Be verbose").long("verbose").flag()
    )
    command.arg_color("GREEN")

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
    print("  ✓ test_custom_arg_color")


fn test_custom_both_colors() raises:
    """Setting both header_color and arg_color at the same time."""
    var command = Command("app", "My app")
    command.add_argument(Argument("file", help="Input").long("file"))
    command.header_color("BLUE")
    command.arg_color("GREEN")

    var help = command._generate_help(color=True)
    assert_true("\x1b[94m" in help, msg="Header should be blue (94)")
    assert_true("\x1b[92m" in help, msg="Args should be green (92)")
    # Bold+underline should still appear for headers.
    assert_true(
        "\x1b[1;4m" in help, msg="Bold+underline should still be present"
    )
    print("  ✓ test_custom_both_colors")


fn test_default_colors_unchanged() raises:
    """Without any setter, help uses default yellow headers + magenta args."""
    var command = Command("app", "My app")
    command.add_argument(Argument("name", help="Your name").long("name"))

    var help = command._generate_help(color=True)
    # Default header = yellow \x1b[93m , default arg = magenta \x1b[95m
    assert_true("\x1b[93m" in help, msg="Default header should be yellow (93)")
    assert_true("\x1b[95m" in help, msg="Default arg should be magenta (95)")
    print("  ✓ test_default_colors_unchanged")


fn test_color_case_insensitive() raises:
    """Colour names are case-insensitive: 'green', 'Green', 'GREEN' all work."""
    var command1 = Command("a", "A")
    command1.add_argument(Argument("x", help="x").long("x"))
    command1.header_color("green")
    var h1 = command1._generate_help(color=True)
    assert_true("\x1b[92m" in h1, msg="'green' lowercase should resolve")

    var command2 = Command("a", "A")
    command2.add_argument(Argument("x", help="x").long("x"))
    command2.header_color("Green")
    var h2 = command2._generate_help(color=True)
    assert_true("\x1b[92m" in h2, msg="'Green' mixed case should resolve")

    var command3 = Command("a", "A")
    command3.add_argument(Argument("x", help="x").long("x"))
    command3.header_color("GREEN")
    var h3 = command3._generate_help(color=True)
    assert_true("\x1b[92m" in h3, msg="'GREEN' uppercase should resolve")
    print("  ✓ test_color_case_insensitive")


fn test_pink_alias_for_magenta() raises:
    """'PINK' is an alias for MAGENTA (\\x1b[95m)."""
    var command = Command("app", "My app")
    command.add_argument(Argument("f", help="File").long("file"))
    command.arg_color("PINK")

    var help = command._generate_help(color=True)
    assert_true(
        "\x1b[95m" in help,
        msg="PINK alias should produce magenta ANSI code",
    )
    print("  ✓ test_pink_alias_for_magenta")


fn test_invalid_color_raises() raises:
    """An unrecognised colour name should raise an Error."""
    var command = Command("app", "My app")
    var raised = False
    try:
        command.header_color("PURPLE")
    except e:
        raised = True
        assert_true(
            "Unknown colour" in String(e),
            msg="Error message should mention 'Unknown colour'",
        )
    assert_true(raised, msg="header_color('PURPLE') should raise an error")

    raised = False
    try:
        command.arg_color("LIME")
    except e:
        raised = True
        assert_true(
            "Unknown colour" in String(e),
            msg="Error message should mention 'Unknown colour'",
        )
    assert_true(raised, msg="arg_color('LIME') should raise an error")
    print("  ✓ test_invalid_color_raises")


fn test_custom_color_plain_mode_unaffected() raises:
    """Custom colours should not leak into plain (color=False) output."""
    var command = Command("app", "My app")
    command.add_argument(Argument("x", help="X option").long("x"))
    command.header_color("RED")
    command.arg_color("BLUE")

    var help = command._generate_help(color=False)
    assert_false("\x1b" in help, msg="Plain mode should have no ANSI codes")
    assert_true("Options:" in help, msg="Plain mode should still have content")
    print("  ✓ test_custom_color_plain_mode_unaffected")


# ===------------------------------------------------------------------=== #
# Nargs (multi-value per option) tests
# ===------------------------------------------------------------------=== #


fn test_nargs_in_help() raises:
    """Tests that nargs options show repeated placeholders in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("point", help="X Y coords").long("point").nargs(2)
    )
    command.add_argument(
        Argument("rgb", help="RGB colour").long("rgb").nargs(3).metavar("N")
    )

    var help = command._generate_help(color=False)
    # --point should show <point> <point>
    assert_true(
        "<point> <point>" in help,
        msg="nargs(2) should show '<point> <point>' in help",
    )
    # --rgb should show N N N
    assert_true(
        "N N N" in help, msg="nargs(3) with metavar should show 'N N N'"
    )
    # Neither should have "..." since they are nargs, not plain append.
    assert_false(
        "<point>..." in help,
        msg="nargs should NOT show '...' suffix",
    )
    print("  ✓ test_nargs_in_help")


fn test_nargs_with_metavar() raises:
    """Tests nargs with a custom metavar in help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("size", help="Width and height")
        .long("size")
        .nargs(2)
        .metavar("PX")
    )

    var help = command._generate_help(color=False)
    assert_true(
        "PX PX" in help,
        msg="nargs(2) with metavar PX should show 'PX PX'",
    )
    print("  ✓ test_nargs_with_metavar")


# ── Subcommand help UX ───────────────────────────────────────────────────────────


fn test_root_help_shows_commands_section() raises:
    """Tests that root help includes a Commands: section when subcommands are registered.
    """
    var app = Command("app", "My CLI tool")
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    var search = Command("search", "Search for patterns")
    var init = Command("init", "Initialize a new project")
    app.add_subcommand(search^)
    app.add_subcommand(init^)

    var help = app._generate_help(color=False)
    assert_true("Commands:" in help, msg="Help should have Commands: section")
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
    print("  ✓ test_root_help_shows_commands_section")


fn test_root_help_no_commands_when_no_subcommands() raises:
    """Tests that Commands: section is omitted when no subcommands are registered.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )

    var help = command._generate_help(color=False)
    assert_false("Commands:" in help, msg="No Commands: without subcommands")
    print("  ✓ test_root_help_no_commands_when_no_subcommands")


fn test_root_help_commands_excludes_help_sub() raises:
    """Tests that the auto-inserted 'help' subcommand is not listed in Commands.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)
    # 'help' subcommand is auto-added.

    var help = app._generate_help(color=False)
    assert_true("Commands:" in help, msg="Should have Commands: section")
    assert_true("search" in help, msg="search should appear")
    # Check that 'help' doesn't appear as a listed command entry.
    # (It may appear in other contexts like --help, but not as a subcommand line.)
    var lines = help.split("\n")
    var found_help_cmd = False
    var in_commands = False
    for i in range(len(lines)):
        if lines[i].startswith("Commands:"):
            in_commands = True
            continue
        if in_commands:
            # End of section if we hit a blank line or another heading.
            if not lines[i] or (len(lines[i]) > 0 and lines[i][0:1] != " "):
                in_commands = False
                continue
            # Check for '  help' as a subcommand entry.
            var stripped = String("")
            for c in range(len(lines[i])):
                if lines[i][c : c + 1] != " ":
                    stripped = String(lines[i][c:])
                    break
            if stripped.startswith("help"):
                found_help_cmd = True
    assert_false(
        found_help_cmd, msg="'help' sub should not appear in Commands:"
    )
    print("  ✓ test_root_help_commands_excludes_help_sub")


fn test_root_help_usage_shows_command_placeholder() raises:
    """Tests that usage line includes <COMMAND> when subcommands are registered.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)

    var help = app._generate_help(color=False)
    assert_true(
        "<COMMAND>" in help,
        msg="Usage should show <COMMAND> placeholder",
    )
    print("  ✓ test_root_help_usage_shows_command_placeholder")


fn test_root_help_usage_no_command_placeholder_without_subs() raises:
    """Tests that usage line does NOT include <COMMAND> when no subcommands."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )

    var help = command._generate_help(color=False)
    assert_false(
        "<COMMAND>" in help,
        msg="Usage should NOT show <COMMAND> without subcommands",
    )
    print("  ✓ test_root_help_usage_no_command_placeholder_without_subs")


fn test_persistent_args_under_global_options() raises:
    """Tests that persistent args appear under a 'Global Options:' heading."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    app.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )
    app.add_subcommand(Command("search", "Search")^)

    var help = app._generate_help(color=False)
    assert_true(
        "Global Options:" in help,
        msg="Should have Global Options: section",
    )
    assert_true("Options:" in help, msg="Should have Options: section")
    # --output should be under Options, --verbose under Global Options.
    # Check ordering: Options comes before Global Options.
    var opt_pos = help.find("Options:")
    var global_pos = help.find("Global Options:")
    assert_true(
        opt_pos < global_pos,
        msg="Options: should come before Global Options:",
    )
    print("  ✓ test_persistent_args_under_global_options")


fn test_no_global_options_without_persistent() raises:
    """Tests that Global Options: section is absent when no persistent args."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )
    app.add_subcommand(Command("search", "Search")^)

    var help = app._generate_help(color=False)
    assert_false(
        "Global Options:" in help,
        msg="No Global Options: without persistent args",
    )
    print("  ✓ test_no_global_options_without_persistent")


fn test_child_help_shows_full_command_path() raises:
    """Tests that child help shows full command path (e.g. 'app search')."""
    var app = Command("app", "My app")
    var search = Command("search", "Search for patterns")
    search.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    app.add_subcommand(search^)

    # Simulate: app search --help
    # The child copy gets name set to "app search", so --help would
    # show "Usage: app search ..." in help.
    # We test indirectly by checking what parse_args sets on the child copy.
    # Create the child copy as parse_args would.
    # Note: subcommands[0] is auto-added 'help'; search is at index 1.
    var search_idx = app._find_subcommand("search")
    var child_copy = app.subcommands[search_idx].copy()
    child_copy.name = "app search"
    var help = child_copy._generate_help(color=False)
    assert_true(
        "app search" in help,
        msg="Child help should show full command path",
    )
    print("  ✓ test_child_help_shows_full_command_path")


fn test_child_help_shows_inherited_persistent_args() raises:
    """Tests that child help includes inherited persistent args under Global Options.
    """
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var search = Command("search", "Search for patterns")
    search.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    search.add_argument(
        Argument("max-depth", help="Max depth").long("max-depth").short("d")
    )
    app.add_subcommand(search^)

    # Simulate child copy with injected persistent args.
    # Note: subcommands[0] is auto-added 'help'; search is at index 1.
    var search_idx = app._find_subcommand("search")
    var child_copy = app.subcommands[search_idx].copy()
    child_copy.name = "app search"
    child_copy.args.append(app.args[0].copy())  # Inject --verbose

    var help = child_copy._generate_help(color=False)
    assert_true(
        "Global Options:" in help,
        msg="Child help should have Global Options:",
    )
    assert_true(
        "--verbose" in help,
        msg="Inherited --verbose should appear in child help",
    )
    assert_true(
        "--max-depth" in help,
        msg="Local --max-depth should appear in child help",
    )
    print("  ✓ test_child_help_shows_inherited_persistent_args")


fn test_add_tip_appears_in_help() raises:
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
    print("  ✓ test_add_tip_appears_in_help")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
