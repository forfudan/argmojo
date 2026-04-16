"""Tests for argmojo completion and suggestion features:
  • Shell completion script generation (Fish, Zsh, Bash)
  • Built-in --completions flag
  • completions_name() / completions_as_subcommand()
  • Alias in completion scripts
  • Hidden subcommands in completions
  • Typo suggestions (Levenshtein distance for options and subcommands)
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult


# ═══════════════════════════════════════════════════════════════════════════════
# generate_completion[] dispatch (compile-time)
# ═══════════════════════════════════════════════════════════════════════════════


def test_fish_dispatch() raises:
    """Tests that generate_completion["fish"]() returns Fish syntax."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var script = command.generate_completion["fish"]()
    assert_true(
        "complete -c myapp" in script,
        msg="Fish script should contain 'complete -c myapp'",
    )


def test_zsh_dispatch() raises:
    """Tests that generate_completion["zsh"]() returns Zsh syntax."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var script = command.generate_completion["zsh"]()
    assert_true(
        "#compdef myapp" in script,
        msg="Zsh script should start with '#compdef myapp'",
    )
    assert_true(
        "compdef _myapp myapp" in script,
        msg="Zsh script should register with 'compdef'",
    )


def test_bash_dispatch() raises:
    """Tests that generate_completion["bash"]() returns Bash syntax."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var script = command.generate_completion["bash"]()
    assert_true(
        "complete -F _myapp_completion myapp" in script,
        msg="Bash script should register with 'complete -F'",
    )


def test_case_insensitive_shell_runtime() raises:
    """Runtime overload accepts case-insensitive shell names."""
    var command = Command("myapp", "A test app")
    var fish_upper = command.generate_completion("FISH")
    assert_true(
        "complete -c myapp" in fish_upper,
        msg="FISH (uppercase) should work",
    )
    var zsh_mixed = command.generate_completion("Zsh")
    assert_true(
        "#compdef myapp" in zsh_mixed,
        msg="Zsh (mixed case) should work",
    )
    var bash_mixed = command.generate_completion("Bash")
    assert_true(
        "complete -F" in bash_mixed,
        msg="Bash (mixed case) should work",
    )


def test_unknown_shell_raises_runtime() raises:
    """Runtime overload raises for unknown shell names."""
    var command = Command("myapp", "A test app")
    var raised = False
    try:
        _ = command.generate_completion("powershell")
    except:
        raised = True
    assert_true(raised, msg="Unknown shell should raise an error")


def test_invalid_shell_caught_at_compile_time() raises:
    """Invalid shell names are caught at compile time via constrained[].

    This test verifies the valid paths work.  An invalid name
    like ``command.generate_completion["powershell"]()`` would fail to compile.
    """
    var command = Command("myapp", "A test app")
    var fish = command.generate_completion["fish"]()
    assert_true(
        "complete -c myapp" in fish, msg="fish should produce Fish script"
    )
    var zsh = command.generate_completion["zsh"]()
    assert_true("#compdef myapp" in zsh, msg="zsh should produce Zsh script")
    var bash = command.generate_completion["bash"]()
    assert_true("complete -F" in bash, msg="bash should produce Bash script")


# ═══════════════════════════════════════════════════════════════════════════════
# Fish completion details
# ═══════════════════════════════════════════════════════════════════════════════


def test_fish_long_option() raises:
    """Tests that Fish script includes long options."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )
    var script = command.generate_completion["fish"]()
    assert_true(
        "-l output" in script,
        msg="Fish script should contain '-l output'",
    )
    assert_true(
        "-s o" in script,
        msg="Fish script should contain '-s o'",
    )


def test_fish_flag_no_require_value() raises:
    """Tests that Fish flags do NOT have -r (require value)."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    var script = command.generate_completion["fish"]()
    # Find the line with --verbose
    var lines = script.split("\n")
    for i in range(len(lines)):
        if "-l verbose" in lines[i]:
            assert_false(
                " -r" in lines[i],
                msg="Flag should not have -r in Fish completion",
            )

            return
    assert_true(False, msg="Should have found --verbose in Fish output")


def test_fish_value_option_has_require() raises:
    """Tests that Fish value-taking options have -r (require value)."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]()
    )
    var script = command.generate_completion["fish"]()
    var lines = script.split("\n")
    for i in range(len(lines)):
        if "-l output" in lines[i]:
            assert_true(
                " -r" in lines[i],
                msg="Value option should have -r in Fish completion",
            )

            return
    assert_true(False, msg="Should have found --output in Fish output")


def test_fish_choices() raises:
    """Tests that Fish script includes choices with -a."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .choice["json"]()
        .choice["csv"]()
        .choice["table"]()
    )
    var script = command.generate_completion["fish"]()
    assert_true(
        "-a 'json csv table'" in script,
        msg="Fish script should list choices with -a",
    )


def test_fish_help_text() raises:
    """Tests that Fish script includes description with -d."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]()
    )
    var script = command.generate_completion["fish"]()
    assert_true(
        "-d 'Output file'" in script,
        msg="Fish script should include help text with -d",
    )


def test_fish_hidden_excluded() raises:
    """Tests that hidden args are excluded from Fish completion."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("internal", help="Internal flag")
        .long["internal"]()
        .flag()
        .hidden()
    )
    command.add_argument(
        Argument("visible", help="Visible flag").long["visible"]().flag()
    )
    var script = command.generate_completion["fish"]()
    assert_false(
        "-l internal" in script,
        msg="Hidden args should not appear in Fish completion",
    )
    assert_true(
        "-l visible" in script,
        msg="Visible args should appear in Fish completion",
    )


def test_fish_builtin_help_version() raises:
    """Tests that Fish script includes built-in --help and --version."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion["fish"]()
    assert_true(
        "-l help" in script,
        msg="Fish script should include --help",
    )
    assert_true(
        "-l version" in script,
        msg="Fish script should include --version",
    )


def test_fish_subcommands() raises:
    """Tests that Fish script registers subcommand completions."""
    var app = Command("myapp", "A test app")
    var sub = Command("search", "Search for patterns")
    sub.add_argument(
        Argument("query", help="Search query").positional().required()
    )
    sub.add_argument(
        Argument("max-depth", help="Maximum depth").long["max-depth"]()
    )
    app.add_subcommand(sub^)
    var script = app.generate_completion["fish"]()
    # Subcommand should be listed.
    assert_true(
        "-a 'search'" in script,
        msg="Fish script should list 'search' subcommand",
    )
    # Subcommand-specific option scoped by condition.
    assert_true(
        "__fish_seen_subcommand_from search" in script,
        msg="Fish script should scope subcommand options",
    )
    assert_true(
        "-l max-depth" in script,
        msg="Fish script should include subcommand options",
    )


def test_fish_escape_single_quote() raises:
    """Tests that single quotes in help text are escaped for Fish."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("test", help="It's a test").long["test"]().flag()
    )
    var script = command.generate_completion["fish"]()
    assert_true(
        "It\\'s a test" in script,
        msg="Fish script should escape single quotes",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Zsh completion details
# ═══════════════════════════════════════════════════════════════════════════════


def test_zsh_simple_flag() raises:
    """Tests that Zsh script includes flag specs."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var script = command.generate_completion["zsh"]()
    assert_true(
        "--verbose" in script,
        msg="Zsh script should contain --verbose",
    )
    assert_true(
        "-v" in script,
        msg="Zsh script should contain -v",
    )


def test_zsh_choices() raises:
    """Tests that Zsh script includes choices in value spec."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .choice["json"]()
        .choice["csv"]()
    )
    var script = command.generate_completion["zsh"]()
    assert_true(
        "json csv" in script,
        msg="Zsh script should include choice values",
    )


def test_zsh_subcommands() raises:
    """Tests that Zsh script handles subcommand dispatch."""
    var app = Command("myapp", "A test app")
    var sub = Command("build", "Build the project")
    sub.add_argument(
        Argument("release", help="Release mode").long["release"]().flag()
    )
    app.add_subcommand(sub^)
    var script = app.generate_completion["zsh"]()
    assert_true(
        "'build:" in script,
        msg="Zsh script should list subcommand 'build'",
    )
    assert_true(
        "case $words[1] in" in script,
        msg="Zsh script should dispatch on subcommand",
    )
    assert_true(
        "--release" in script,
        msg="Zsh script should include subcommand options",
    )


def test_zsh_escape_brackets() raises:
    """Tests that brackets in help text are escaped for Zsh specs."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("test", help="Test [option]").long["test"]().flag()
    )
    var script = command.generate_completion["zsh"]()
    assert_true(
        "Test \\[option\\]" in script,
        msg="Zsh script should escape brackets",
    )


def test_zsh_escape_colon() raises:
    """Tests that colons in help text are escaped for Zsh specs."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("test", help="Key: value").long["test"]().flag()
    )
    var script = command.generate_completion["zsh"]()
    assert_true(
        "Key\\: value" in script,
        msg="Zsh script should escape colons",
    )


def test_zsh_builtin_help() raises:
    """Tests that Zsh script includes built-in help/version."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion["zsh"]()
    assert_true(
        "--help" in script,
        msg="Zsh script should include --help",
    )
    assert_true(
        "--version" in script,
        msg="Zsh script should include --version",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Bash completion details
# ═══════════════════════════════════════════════════════════════════════════════


def test_bash_simple_options() raises:
    """Tests that Bash script includes all options in COMPREPLY."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )
    var script = command.generate_completion["bash"]()
    assert_true(
        "--verbose" in script,
        msg="Bash script should contain --verbose",
    )
    assert_true(
        "--output" in script,
        msg="Bash script should contain --output",
    )
    assert_true(
        "-v" in script,
        msg="Bash script should contain -v",
    )
    assert_true(
        "-o" in script,
        msg="Bash script should contain -o",
    )


def test_bash_subcommands() raises:
    """Tests that Bash script handles subcommand detection."""
    var app = Command("myapp", "A test app")
    var sub = Command("deploy", "Deploy the app")
    sub.add_argument(Argument("target", help="Deploy target").long["target"]())
    app.add_subcommand(sub^)
    var script = app.generate_completion["bash"]()
    assert_true(
        "deploy" in script,
        msg="Bash script should reference 'deploy' subcommand",
    )
    assert_true(
        "--target" in script,
        msg="Bash script should include subcommand options",
    )
    assert_true(
        "subcmd" in script,
        msg="Bash script should detect subcommand",
    )


def test_bash_choices_prev() raises:
    """Tests that Bash script completes choices based on $prev."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("level", help="Log level")
        .long["level"]()
        .choice["debug"]()
        .choice["info"]()
        .choice["warn"]()
    )
    var script = command.generate_completion["bash"]()
    assert_true(
        "case $prev in" in script,
        msg="Bash script should have case $prev block",
    )
    assert_true(
        "debug info warn" in script,
        msg="Bash script should include choice values",
    )


def test_bash_hidden_excluded() raises:
    """Tests that hidden args are excluded from Bash completion."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("secret", help="Secret").long["secret"]().flag().hidden()
    )
    command.add_argument(
        Argument("public", help="Public").long["public"]().flag()
    )
    var script = command.generate_completion["bash"]()
    assert_false(
        "--secret" in script,
        msg="Hidden args should not appear in Bash completion",
    )
    assert_true(
        "--public" in script,
        msg="Visible args should appear in Bash completion",
    )


def test_bash_builtin_help_version() raises:
    """Tests that Bash script includes --help and --version."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion["bash"]()
    assert_true(
        "--help" in script,
        msg="Bash script should include --help",
    )
    assert_true(
        "--version" in script,
        msg="Bash script should include --version",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Cross-shell consistency
# ═══════════════════════════════════════════════════════════════════════════════


def test_all_shells_include_same_options() raises:
    """Tests that all three shells list the same user-defined options."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbose")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )
    command.add_argument(
        Argument("format", help="Format")
        .long["format"]()
        .choice["json"]()
        .choice["csv"]()
    )

    var fish = command.generate_completion["fish"]()
    var zsh = command.generate_completion["zsh"]()
    var bash = command.generate_completion["bash"]()

    # Fish uses -l/--long form syntax, not --verbose directly.
    assert_true("-l verbose" in fish, msg="fish should include -l verbose")
    assert_true("-l output" in fish, msg="fish should include -l output")
    assert_true("-l format" in fish, msg="fish should include -l format")
    # Zsh
    assert_true("--verbose" in zsh, msg="zsh should include --verbose")
    assert_true("--output" in zsh, msg="zsh should include --output")
    assert_true("--format" in zsh, msg="zsh should include --format")
    # Bash
    assert_true("--verbose" in bash, msg="bash should include --verbose")
    assert_true("--output" in bash, msg="bash should include --output")
    assert_true("--format" in bash, msg="bash should include --format")


def test_count_option_no_value() raises:
    """Tests that count options are treated like flags (no value required)."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long["verbose"]()
        .short["v"]()
        .count()
    )
    # Fish: should NOT have -r
    var fish = command.generate_completion["fish"]()
    var lines = fish.split("\n")
    var found = False
    for i in range(len(lines)):
        if "-l verbose" in lines[i]:
            found = True
            assert_false(
                " -r" in lines[i],
                msg="Count option should not have -r in Fish",
            )
            break
    assert_true(found, msg="Fish script should contain '-l verbose' line")


def test_persistent_flags_in_root() raises:
    """Tests that persistent flags appear in root-level completion."""
    var app = Command("myapp", "A test app")
    app.add_argument(
        Argument("debug", help="Debug mode").long["debug"]().flag().persistent()
    )
    var sub = Command("run", "Run something")
    app.add_subcommand(sub^)

    var fish = app.generate_completion["fish"]()
    assert_true(
        "-l debug" in fish,
        msg="Persistent flag should appear in Fish root completions",
    )


def test_positional_excluded() raises:
    """Tests that positional args are NOT listed as completable options."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    var fish = command.generate_completion["fish"]()
    var _zsh = command.generate_completion["zsh"]()
    var bash = command.generate_completion["bash"]()
    # Positional should not appear as -l or -- option.
    assert_false(
        "-l pattern" in fish,
        msg="Positional args should not appear as Fish options",
    )
    assert_false(
        "--pattern" in bash,
        msg="Positional args should not appear as Bash options",
    )


def test_generated_by_comment() raises:
    """Tests that all scripts have 'Generated by ArgMojo' comment."""
    var command = Command("myapp", "A test app")
    var fish = command.generate_completion["fish"]()
    var zsh = command.generate_completion["zsh"]()
    var bash = command.generate_completion["bash"]()
    assert_true(
        "Generated by ArgMojo" in fish,
        msg="Fish script should have ArgMojo attribution",
    )
    assert_true(
        "Generated by ArgMojo" in zsh,
        msg="Zsh script should have ArgMojo attribution",
    )
    assert_true(
        "Generated by ArgMojo" in bash,
        msg="Bash script should have ArgMojo attribution",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Built-in --completions flag
# ═══════════════════════════════════════════════════════════════════════════════


def test_fish_builtin_completions() raises:
    """Tests that Fish script includes the built-in --completions option."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion["fish"]()
    assert_true(
        "-l completions" in script,
        msg="Fish script should include -l completions",
    )
    assert_true(
        "bash zsh fish" in script,
        msg="Fish script should list 'bash zsh fish' as completion choices",
    )


def test_zsh_builtin_completions() raises:
    """Tests that Zsh script includes the built-in --completions option."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion["zsh"]()
    assert_true(
        "--completions" in script,
        msg="Zsh script should include --completions",
    )
    assert_true(
        "(bash zsh fish)" in script,
        msg="Zsh script should list '(bash zsh fish)' as choices",
    )


def test_bash_builtin_completions() raises:
    """Tests that Bash script includes the built-in --completions option."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion["bash"]()
    assert_true(
        "--completions" in script,
        msg="Bash script should include --completions",
    )
    assert_true(
        "bash zsh fish" in script,
        msg="Bash script should list 'bash zsh fish' as prev-case choices",
    )


def test_disable_default_completions_not_in_script() raises:
    """Tests that disable_default_completions() removes --completions from all scripts.
    """
    var command = Command("myapp", "A test app")
    command.disable_default_completions()
    var fish = command.generate_completion["fish"]()
    var zsh = command.generate_completion["zsh"]()
    var bash = command.generate_completion["bash"]()
    assert_false(
        "-l completions" in fish,
        msg=(
            "Fish script should NOT include -l completions after"
            " disable_default_completions()"
        ),
    )
    assert_false(
        "--completions" in zsh,
        msg=(
            "Zsh script should NOT include --completions after"
            " disable_default_completions()"
        ),
    )
    assert_false(
        "--completions" in bash,
        msg=(
            "Bash script should NOT include --completions after"
            " disable_default_completions()"
        ),
    )


def test_disable_default_completions_not_in_help() raises:
    """Tests that disable_default_completions() hides --completions from help.
    """
    var command = Command("myapp", "A test app")
    command.disable_default_completions()
    var help_text = command._generate_help(color=False)
    assert_false(
        "--completions" in help_text,
        msg=(
            "Help text should NOT include --completions after"
            " disable_default_completions()"
        ),
    )


def test_completions_in_help_by_default() raises:
    """Tests that --completions appears in the Options section of help by default.
    """
    var command = Command("myapp", "A test app")
    var help_text = command._generate_help(color=False)
    assert_true(
        "--completions" in help_text,
        msg="Help text should include --completions by default",
    )
    assert_true(
        "<SHELL>" in help_text,
        msg="Help text should show <SHELL> placeholder for --completions",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# completions_name()
# ═══════════════════════════════════════════════════════════════════════════════


def test_completions_custom_name_in_scripts() raises:
    """Tests that completions_name() changes the trigger in all scripts."""
    var command = Command("myapp", "A test app")
    command.completions_name("autocomp")
    var fish = command.generate_completion["fish"]()
    var zsh = command.generate_completion["zsh"]()
    var bash = command.generate_completion["bash"]()
    assert_true(
        "-l autocomp" in fish,
        msg="Fish script should use '-l autocomp' after completions_name()",
    )
    assert_false(
        "-l completions" in fish,
        msg="Fish script should NOT have '-l completions' after rename",
    )
    assert_true(
        "--autocomp[" in zsh,
        msg="Zsh script should use '--autocomp[' after completions_name()",
    )
    assert_true(
        "--autocomp" in bash,
        msg="Bash script should use '--autocomp' after completions_name()",
    )
    assert_false(
        "--completions" in bash,
        msg="Bash script should NOT have '--completions' after rename",
    )


def test_completions_custom_name_in_help() raises:
    """Tests that completions_name() changes the trigger shown in help."""
    var command = Command("myapp", "A test app")
    command.completions_name("autocomp")
    var help_text = command._generate_help(color=False)
    assert_true(
        "--autocomp" in help_text,
        msg="Help text should show '--autocomp' after completions_name()",
    )
    assert_false(
        "--completions" in help_text,
        msg="Help text should NOT show '--completions' after rename",
    )


def test_completions_custom_name_in_bash_prev() raises:
    """Tests that completions_name() updates bash prev-case pattern."""
    var command = Command("myapp", "A test app")
    command.completions_name("gen-comp")
    var bash = command.generate_completion["bash"]()
    assert_true(
        "--gen-comp)" in bash,
        msg="Bash prev-case should use '--gen-comp)' after rename",
    )
    assert_false(
        "--completions)" in bash,
        msg="Bash prev-case should NOT have '--completions)' after rename",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# completions_as_subcommand()
# ═══════════════════════════════════════════════════════════════════════════════


def test_completions_as_subcommand_in_help() raises:
    """Tests that completions_as_subcommand() shows it in Commands, not Options.
    """
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var help_text = command._generate_help(color=False)
    # Should NOT appear in Options section as --completions.
    assert_false(
        "--completions" in help_text,
        msg=(
            "Help text should NOT show '--completions' in Options"
            " when using subcommand mode"
        ),
    )
    # Should appear in Commands section.
    assert_true(
        "completions" in help_text,
        msg=(
            "Help text should show 'completions' in Commands section"
            " when using subcommand mode"
        ),
    )


def test_completions_as_subcommand_in_fish() raises:
    """Tests that completions_as_subcommand() appears as subcommand in Fish."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var fish = command.generate_completion["fish"]()
    # Should NOT appear as an option.
    assert_false(
        "-l completions" in fish,
        msg=(
            "Fish script should NOT have '-l completions' option in subcommand"
            " mode"
        ),
    )
    # Should appear as a subcommand candidate.
    assert_true(
        "-a 'completions'" in fish,
        msg=(
            "Fish script should include '-a completions' as subcommand"
            " in subcommand mode"
        ),
    )


def test_completions_as_subcommand_in_zsh() raises:
    """Tests that completions_as_subcommand() appears as subcommand in Zsh."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var zsh = command.generate_completion["zsh"]()
    # Should appear in commands array.
    assert_true(
        "'completions:" in zsh,
        msg="Zsh script should include completions in commands array",
    )
    # Should NOT appear as an option.
    assert_false(
        "'--completions[" in zsh,
        msg="Zsh script should NOT have '--completions[' option in sub mode",
    )
    # Should have a subcommand handler.
    assert_true(
        "completions)" in zsh,
        msg="Zsh script should have completions) case handler",
    )


def test_completions_as_subcommand_in_bash() raises:
    """Tests that completions_as_subcommand() appears as subcommand in Bash."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var bash = command.generate_completion["bash"]()
    # Should NOT appear as --completions option.
    assert_false(
        " --completions" in bash,
        msg=(
            "Bash script should NOT list '--completions' option in subcommand"
            " mode"
        ),
    )
    # Subcommand names should include completions.
    assert_true(
        "completions" in bash,
        msg=(
            "Bash script should include 'completions' in subcommand"
            " names in subcommand mode"
        ),
    )


def test_completions_custom_name_with_subcommand() raises:
    """Tests combining completions_name() with completions_as_subcommand()."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_name("comp")
    command.completions_as_subcommand()
    var help_text = command._generate_help(color=False)
    var fish = command.generate_completion["fish"]()
    var zsh = command.generate_completion["zsh"]()
    var bash = command.generate_completion["bash"]()
    # Help: 'comp' in Commands, not '--comp' in Options.
    assert_true(
        "comp" in help_text,
        msg="Help should show 'comp' in commands with custom name + sub mode",
    )
    assert_false(
        "--comp" in help_text,
        msg="Help should NOT show '--comp' in options in sub mode",
    )
    # Fish: subcommand entry.
    assert_true(
        "-a 'comp'" in fish,
        msg="Fish should include '-a comp' as subcommand with custom name",
    )
    # Zsh: commands array.
    assert_true(
        "'comp:" in zsh,
        msg="Zsh should include comp in commands array with custom name",
    )
    # Bash: subcommand name.
    assert_true(
        "comp)" in bash,
        msg="Bash should have 'comp)' case handler with custom name",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Alias in completion scripts
# ═══════════════════════════════════════════════════════════════════════════════


def test_fish_completion_includes_alias() raises:
    """Tests that Fish completion lists alias as a completable name."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)
    var script = app.generate_completion["fish"]()
    assert_true(
        "-a 'cl'" in script,
        msg="Fish script should list alias 'cl' as completable",
    )
    assert_true(
        "-a 'clone'" in script,
        msg="Fish script should still list primary name 'clone'",
    )
    # Alias should also be in the seen_subcommand_from condition.
    assert_true(
        "__fish_seen_subcommand_from clone cl" in script,
        msg="Fish should include alias in seen_subcommand_from",
    )


def test_zsh_completion_includes_alias() raises:
    """Tests that Zsh completion lists alias entries."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)
    var script = app.generate_completion["zsh"]()
    assert_true(
        "'cl:" in script,
        msg="Zsh script should list alias 'cl' in commands array",
    )
    assert_true(
        "clone|cl)" in script,
        msg="Zsh script should dispatch clone|cl pattern",
    )


def test_bash_completion_includes_alias() raises:
    """Tests that Bash completion includes alias in dispatch pattern."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)
    var script = app.generate_completion["bash"]()
    assert_true(
        "clone|cl)" in script,
        msg="Bash script should have clone|cl) case pattern",
    )
    # Alias should also appear in the subcommand list for root completion.
    assert_true(
        "clone cl" in script,
        msg="Bash should list alias in subcommand names",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Hidden subcommands in completions
# ═══════════════════════════════════════════════════════════════════════════════


def _make_app_with_hidden_sub() raises -> Command:
    """Helper: app with 'clone' visible and 'debug' hidden."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    clone.add_argument(Argument("url", help="Repo URL").long["url"]())
    app.add_subcommand(clone^)
    var debug = Command("debug", "Internal debug")
    debug.hidden()
    debug.add_argument(Argument("level", help="Level").long["level"]())
    app.add_subcommand(debug^)
    return app^


def test_fish_hidden_sub_excluded() raises:
    """Tests that hidden subcommands are absent from Fish completion."""
    var app = _make_app_with_hidden_sub()
    var script = app.generate_completion["fish"]()
    assert_true(
        "clone" in script,
        msg="Fish script should include visible sub 'clone'",
    )
    assert_false(
        "debug" in script,
        msg="Fish script should NOT include hidden sub 'debug'",
    )


def test_zsh_hidden_sub_excluded() raises:
    """Tests that hidden subcommands are absent from Zsh completion."""
    var app = _make_app_with_hidden_sub()
    var script = app.generate_completion["zsh"]()
    assert_true(
        "'clone:" in script,
        msg="Zsh script should include visible sub 'clone'",
    )
    assert_false(
        "'debug:" in script,
        msg="Zsh script should NOT include hidden sub 'debug'",
    )


def test_bash_hidden_sub_excluded() raises:
    """Tests that hidden subcommands are absent from Bash completion."""
    var app = _make_app_with_hidden_sub()
    var script = app.generate_completion["bash"]()
    assert_true(
        "clone" in script,
        msg="Bash script should include visible sub 'clone'",
    )
    assert_false(
        "debug" in script,
        msg="Bash script should NOT include hidden sub 'debug'",
    )


def test_all_hidden_no_subcommand_completion() raises:
    """Tests that when all subs are hidden, completion is simple (no subs)."""
    var app = Command("myapp", "A test app")
    app.add_argument(
        Argument("verbose", help="Verbose").long["verbose"]().flag()
    )
    var debug = Command("debug", "Internal debug")
    debug.hidden()
    app.add_subcommand(debug^)

    # Fish: should NOT contain subcommand-related directives.
    var fish = app.generate_completion["fish"]()
    assert_false(
        "__fish_seen_subcommand_from" in fish,
        msg="Fish should not have subcommand dispatching when all subs hidden",
    )

    # Bash: should not have case/subcmd detection.
    var bash = app.generate_completion["bash"]()
    assert_false(
        "subcmd" in bash,
        msg="Bash should not have subcmd logic when all subs hidden",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Typo suggestions (Levenshtein distance)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Long option typo suggestions ─────────────────────────────────────────────


def test_typo_long_option_suggests() raises:
    """Tests that a typo like --vrebose raises an error.

    The suggestion ('tip: a similar option exists') is printed to
    stderr in pixi style; the raised error only contains the
    'Unknown option' message.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )
    command.add_argument(
        Argument("version", help="Show version").long["version"]().flag()
    )

    # Use a more distant typo to test suggestion path.
    var args2: List[String] = ["test", "--vrebose"]
    var caught = False
    try:
        _ = command.parse_arguments(args2)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown option" in msg,
            msg="Error should say 'Unknown option'",
        )
        assert_true(
            "vrebose" in msg,
            msg="Error should contain the bad token 'vrebose'",
        )
    assert_true(caught, msg="Should have raised error for --vrebose")


def test_typo_long_option_no_suggestion() raises:
    """Tests that a completely unrelated option doesn't produce a suggestion."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long["verbose"]().flag()
    )

    var args: List[String] = ["test", "--zzzzzzz"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown option" in msg,
            msg="Error should say 'Unknown option'",
        )
    assert_true(caught, msg="Should have raised error for --zzzzzzz")


def test_typo_long_option_single_char_diff() raises:
    """Tests that a single character difference raises an error.

    The suggestion ('tip: a similar option exists') is printed to
    stderr in pixi style; the raised error only contains the
    'Unknown option' message.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long["output"]().short["o"]()
    )

    var args: List[String] = ["test", "--outptu", "file.txt"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown option" in msg,
            msg="Error should say 'Unknown option'",
        )
        assert_true(
            "outptu" in msg,
            msg="Error should contain the bad token 'outptu'",
        )
    assert_true(caught, msg="Should have raised error for --outptu")


# ── Subcommand typo suggestions ──────────────────────────────────────────────


def test_typo_subcommand_suggests() raises:
    """Tests that a typo subcommand like 'serach' raises an error.

    The suggestion ('tip: a similar subcommand exists') is printed to
    stderr in pixi style; the raised error only contains the
    'unrecognized subcommand' message.
    """
    var root = Command("app", "Test app")
    var search = Command("search", "Search items")
    var list_cmd = Command("list", "List items")
    root.add_subcommand(search^)
    root.add_subcommand(list_cmd^)

    var args: List[String] = ["app", "serach"]
    var caught = False
    try:
        _ = root.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unrecognized subcommand" in msg,
            msg="Error should say 'unrecognized subcommand'",
        )
        assert_true(
            "serach" in msg,
            msg="Error should contain the bad token 'serach'",
        )
    assert_true(caught, msg="Should have raised error for 'serach'")


def test_typo_subcommand_no_suggestion() raises:
    """Tests that a completely unrelated subcommand doesn't produce a suggestion.
    """
    var root = Command("app", "Test app")
    var search = Command("search", "Search items")
    root.add_subcommand(search^)

    var args: List[String] = ["app", "xxxxxxx"]
    var caught = False
    try:
        _ = root.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unrecognized subcommand" in msg,
            msg="Error should say 'unrecognized subcommand'",
        )
    assert_true(caught, msg="Should have raised error for 'xxxxxxx'")


# ── Alias typo suggestions ──────────────────────────────────────────────────


def test_typo_alias_suggests() raises:
    """Tests that a typo close to an alias raises an error.

    The suggestion ('tip: a similar option exists') is printed to
    stderr in pixi style; the raised error only contains the
    'Unknown option' message.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Enable colour output")
        .long["colour"]()
        .flag()
        .alias_name["color"]()
    )

    var args: List[String] = ["test", "--colro"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown option" in msg,
            msg="Error should say 'Unknown option'",
        )
    assert_true(caught, msg="Should have raised error for --colro")


def test_typo_subcommand_alias_suggests() raises:
    """Tests that a typo near a subcommand alias raises an error.

    The suggestion ('tip: a similar subcommand exists') is printed to
    stderr in pixi style; the raised error only contains the
    'unrecognized subcommand' message.
    """
    var root = Command("app", "Test app")
    var clone = Command("clone", "Clone a repo")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    root.add_subcommand(clone^)

    # "clon" is close to both "clone" and "cl"
    var args: List[String] = ["app", "clon"]
    var caught = False
    try:
        _ = root.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "unrecognized subcommand" in msg,
            msg="Error should say 'unrecognized subcommand'",
        )
        assert_true(
            "clon" in msg,
            msg="Error should contain the bad token 'clon'",
        )
    assert_true(caught, msg="Should have raised error for 'clon'")


def test_typo_hidden_subcommand_not_suggested() raises:
    """Tests that hidden subcommands are NOT included in typo suggestions."""
    var app = Command("app", "Test app")
    var clone = Command("clone", "Clone a repository")
    app.add_subcommand(clone^)
    var debug = Command("debug", "Internal debug")
    debug.hidden()
    app.add_subcommand(debug^)

    # 'debu' is close to 'debug', but debug is hidden so no suggestion.
    var args: List[String] = ["app", "debu"]
    var caught = False
    var err_msg = String("")
    try:
        _ = app.parse_arguments(args)
    except e:
        caught = True
        err_msg = String(e)
    assert_true(caught, msg="Should have raised error for 'debu'")
    assert_false(
        "debug" in err_msg,
        msg="Hidden sub 'debug' should NOT appear in typo suggestion",
    )
    # But the error message no longer contains available commands (they are
    # printed to stderr in multi-line format instead).
    assert_true(
        "unrecognized subcommand" in err_msg,
        msg="Should mention unrecognized subcommand",
    )
    assert_true(
        "debu" in err_msg,
        msg="Should mention the unrecognized 'debu'",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Test runner
# ═══════════════════════════════════════════════════════════════════════════════


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
