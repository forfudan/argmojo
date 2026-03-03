"""Tests for argmojo — shell completion script generation (bash, zsh, fish)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command


# ── generate_completion() dispatch ───────────────────────────────────────────


fn test_fish_dispatch() raises:
    """Tests that generate_completion('fish') returns Fish syntax."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    var script = command.generate_completion("fish")
    assert_true(
        "complete -c myapp" in script,
        msg="Fish script should contain 'complete -c myapp'",
    )
    print("  ✓ test_fish_dispatch")


fn test_zsh_dispatch() raises:
    """Tests that generate_completion('zsh') returns Zsh syntax."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    var script = command.generate_completion("zsh")
    assert_true(
        "#compdef myapp" in script,
        msg="Zsh script should start with '#compdef myapp'",
    )
    assert_true(
        "compdef _myapp myapp" in script,
        msg="Zsh script should register with 'compdef'",
    )
    print("  ✓ test_zsh_dispatch")


fn test_bash_dispatch() raises:
    """Tests that generate_completion('bash') returns Bash syntax."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    var script = command.generate_completion("bash")
    assert_true(
        "complete -F _myapp_completion myapp" in script,
        msg="Bash script should register with 'complete -F'",
    )
    print("  ✓ test_bash_dispatch")


fn test_case_insensitive_shell() raises:
    """Tests that shell name is case-insensitive."""
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
    print("  ✓ test_case_insensitive_shell")


fn test_unknown_shell_raises() raises:
    """Tests that an unknown shell name raises an error."""
    var command = Command("myapp", "A test app")
    var raised = False
    try:
        _ = command.generate_completion("powershell")
    except:
        raised = True
    assert_true(raised, msg="Unknown shell should raise an error")
    print("  ✓ test_unknown_shell_raises")


# ── Fish completion details ──────────────────────────────────────────────────


fn test_fish_long_option() raises:
    """Tests that Fish script includes long options."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )
    var script = command.generate_completion("fish")
    assert_true(
        "-l output" in script,
        msg="Fish script should contain '-l output'",
    )
    assert_true(
        "-s o" in script,
        msg="Fish script should contain '-s o'",
    )
    print("  ✓ test_fish_long_option")


fn test_fish_flag_no_require_value() raises:
    """Tests that Fish flags do NOT have -r (require value)."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    var script = command.generate_completion("fish")
    # Find the line with --verbose
    var lines = script.split("\n")
    for i in range(len(lines)):
        if "-l verbose" in lines[i]:
            assert_false(
                " -r" in lines[i],
                msg="Flag should not have -r in Fish completion",
            )
            print("  ✓ test_fish_flag_no_require_value")
            return
    assert_true(False, msg="Should have found --verbose in Fish output")


fn test_fish_value_option_has_require() raises:
    """Tests that Fish value-taking options have -r (require value)."""
    var command = Command("myapp", "A test app")
    command.add_argument(Argument("output", help="Output file").long("output"))
    var script = command.generate_completion("fish")
    var lines = script.split("\n")
    for i in range(len(lines)):
        if "-l output" in lines[i]:
            assert_true(
                " -r" in lines[i],
                msg="Value option should have -r in Fish completion",
            )
            print("  ✓ test_fish_value_option_has_require")
            return
    assert_true(False, msg="Should have found --output in Fish output")


fn test_fish_choices() raises:
    """Tests that Fish script includes choices with -a."""
    var command = Command("myapp", "A test app")
    var choices: List[String] = ["json", "csv", "table"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .choices(choices^)
    )
    var script = command.generate_completion("fish")
    assert_true(
        "-a 'json csv table'" in script,
        msg="Fish script should list choices with -a",
    )
    print("  ✓ test_fish_choices")


fn test_fish_help_text() raises:
    """Tests that Fish script includes description with -d."""
    var command = Command("myapp", "A test app")
    command.add_argument(Argument("output", help="Output file").long("output"))
    var script = command.generate_completion("fish")
    assert_true(
        "-d 'Output file'" in script,
        msg="Fish script should include help text with -d",
    )
    print("  ✓ test_fish_help_text")


fn test_fish_hidden_excluded() raises:
    """Tests that hidden args are excluded from Fish completion."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("internal", help="Internal flag")
        .long("internal")
        .flag()
        .hidden()
    )
    command.add_argument(
        Argument("visible", help="Visible flag").long("visible").flag()
    )
    var script = command.generate_completion("fish")
    assert_false(
        "-l internal" in script,
        msg="Hidden args should not appear in Fish completion",
    )
    assert_true(
        "-l visible" in script,
        msg="Visible args should appear in Fish completion",
    )
    print("  ✓ test_fish_hidden_excluded")


fn test_fish_builtin_help_version() raises:
    """Tests that Fish script includes built-in --help and --version."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion("fish")
    assert_true(
        "-l help" in script,
        msg="Fish script should include --help",
    )
    assert_true(
        "-l version" in script,
        msg="Fish script should include --version",
    )
    print("  ✓ test_fish_builtin_help_version")


fn test_fish_subcommands() raises:
    """Tests that Fish script registers subcommand completions."""
    var app = Command("myapp", "A test app")
    var sub = Command("search", "Search for patterns")
    sub.add_argument(
        Argument("query", help="Search query").positional().required()
    )
    sub.add_argument(
        Argument("max-depth", help="Maximum depth").long("max-depth")
    )
    app.add_subcommand(sub^)
    var script = app.generate_completion("fish")
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
    print("  ✓ test_fish_subcommands")


fn test_fish_escape_single_quote() raises:
    """Tests that single quotes in help text are escaped for Fish."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("test", help="It's a test").long("test").flag()
    )
    var script = command.generate_completion("fish")
    assert_true(
        "It\\'s a test" in script,
        msg="Fish script should escape single quotes",
    )
    print("  ✓ test_fish_escape_single_quote")


# ── Zsh completion details ───────────────────────────────────────────────────


fn test_zsh_simple_flag() raises:
    """Tests that Zsh script includes flag specs."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Enable verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    var script = command.generate_completion("zsh")
    assert_true(
        "--verbose" in script,
        msg="Zsh script should contain --verbose",
    )
    assert_true(
        "-v" in script,
        msg="Zsh script should contain -v",
    )
    print("  ✓ test_zsh_simple_flag")


fn test_zsh_choices() raises:
    """Tests that Zsh script includes choices in value spec."""
    var command = Command("myapp", "A test app")
    var choices: List[String] = ["json", "csv"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .choices(choices^)
    )
    var script = command.generate_completion("zsh")
    assert_true(
        "json csv" in script,
        msg="Zsh script should include choice values",
    )
    print("  ✓ test_zsh_choices")


fn test_zsh_subcommands() raises:
    """Tests that Zsh script handles subcommand dispatch."""
    var app = Command("myapp", "A test app")
    var sub = Command("build", "Build the project")
    sub.add_argument(
        Argument("release", help="Release mode").long("release").flag()
    )
    app.add_subcommand(sub^)
    var script = app.generate_completion("zsh")
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
    print("  ✓ test_zsh_subcommands")


fn test_zsh_escape_brackets() raises:
    """Tests that brackets in help text are escaped for Zsh specs."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("test", help="Test [option]").long("test").flag()
    )
    var script = command.generate_completion("zsh")
    assert_true(
        "Test \\[option\\]" in script,
        msg="Zsh script should escape brackets",
    )
    print("  ✓ test_zsh_escape_brackets")


fn test_zsh_escape_colon() raises:
    """Tests that colons in help text are escaped for Zsh specs."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("test", help="Key: value").long("test").flag()
    )
    var script = command.generate_completion("zsh")
    assert_true(
        "Key\\: value" in script,
        msg="Zsh script should escape colons",
    )
    print("  ✓ test_zsh_escape_colon")


fn test_zsh_builtin_help() raises:
    """Tests that Zsh script includes built-in help/version."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion("zsh")
    assert_true(
        "--help" in script,
        msg="Zsh script should include --help",
    )
    assert_true(
        "--version" in script,
        msg="Zsh script should include --version",
    )
    print("  ✓ test_zsh_builtin_help")


# ── Bash completion details ──────────────────────────────────────────────────


fn test_bash_simple_options() raises:
    """Tests that Bash script includes all options in COMPREPLY."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )
    var script = command.generate_completion("bash")
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
    print("  ✓ test_bash_simple_options")


fn test_bash_subcommands() raises:
    """Tests that Bash script handles subcommand detection."""
    var app = Command("myapp", "A test app")
    var sub = Command("deploy", "Deploy the app")
    sub.add_argument(Argument("target", help="Deploy target").long("target"))
    app.add_subcommand(sub^)
    var script = app.generate_completion("bash")
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
    print("  ✓ test_bash_subcommands")


fn test_bash_choices_prev() raises:
    """Tests that Bash script completes choices based on $prev."""
    var command = Command("myapp", "A test app")
    var choices: List[String] = ["debug", "info", "warn"]
    command.add_argument(
        Argument("level", help="Log level").long("level").choices(choices^)
    )
    var script = command.generate_completion("bash")
    assert_true(
        "case $prev in" in script,
        msg="Bash script should have case $prev block",
    )
    assert_true(
        "debug info warn" in script,
        msg="Bash script should include choice values",
    )
    print("  ✓ test_bash_choices_prev")


fn test_bash_hidden_excluded() raises:
    """Tests that hidden args are excluded from Bash completion."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("secret", help="Secret").long("secret").flag().hidden()
    )
    command.add_argument(
        Argument("public", help="Public").long("public").flag()
    )
    var script = command.generate_completion("bash")
    assert_false(
        "--secret" in script,
        msg="Hidden args should not appear in Bash completion",
    )
    assert_true(
        "--public" in script,
        msg="Visible args should appear in Bash completion",
    )
    print("  ✓ test_bash_hidden_excluded")


fn test_bash_builtin_help_version() raises:
    """Tests that Bash script includes --help and --version."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion("bash")
    assert_true(
        "--help" in script,
        msg="Bash script should include --help",
    )
    assert_true(
        "--version" in script,
        msg="Bash script should include --version",
    )
    print("  ✓ test_bash_builtin_help_version")


# ── Cross-shell consistency ──────────────────────────────────────────────────


fn test_all_shells_include_same_options() raises:
    """Tests that all three shells list the same user-defined options."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )
    var choices: List[String] = ["json", "csv"]
    command.add_argument(
        Argument("format", help="Format").long("format").choices(choices^)
    )

    var fish = command.generate_completion("fish")
    var zsh = command.generate_completion("zsh")
    var bash = command.generate_completion("bash")

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
    print("  ✓ test_all_shells_include_same_options")


fn test_count_option_no_value() raises:
    """Tests that count options are treated like flags (no value required)."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )
    # Fish: should NOT have -r
    var fish = command.generate_completion("fish")
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
    print("  ✓ test_count_option_no_value")


fn test_persistent_flags_in_root() raises:
    """Tests that persistent flags appear in root-level completion."""
    var app = Command("myapp", "A test app")
    app.add_argument(
        Argument("debug", help="Debug mode").long("debug").flag().persistent()
    )
    var sub = Command("run", "Run something")
    app.add_subcommand(sub^)

    var fish = app.generate_completion("fish")
    assert_true(
        "-l debug" in fish,
        msg="Persistent flag should appear in Fish root completions",
    )
    print("  ✓ test_persistent_flags_in_root")


fn test_positional_excluded() raises:
    """Tests that positional args are NOT listed as completable options."""
    var command = Command("myapp", "A test app")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    var fish = command.generate_completion("fish")
    var zsh = command.generate_completion("zsh")
    var bash = command.generate_completion("bash")
    # Positional should not appear as -l or -- option.
    assert_false(
        "-l pattern" in fish,
        msg="Positional args should not appear as Fish options",
    )
    assert_false(
        "--pattern" in bash,
        msg="Positional args should not appear as Bash options",
    )
    print("  ✓ test_positional_excluded")


fn test_generated_by_comment() raises:
    """Tests that all scripts have 'Generated by ArgMojo' comment."""
    var command = Command("myapp", "A test app")
    var fish = command.generate_completion("fish")
    var zsh = command.generate_completion("zsh")
    var bash = command.generate_completion("bash")
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
    print("  ✓ test_generated_by_comment")


# ── Built-in --completions flag ───────────────────────────────────────────────


fn test_fish_builtin_completions() raises:
    """Tests that Fish script includes the built-in --completions option."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion("fish")
    assert_true(
        "-l completions" in script,
        msg="Fish script should include -l completions",
    )
    assert_true(
        "bash zsh fish" in script,
        msg="Fish script should list 'bash zsh fish' as completion choices",
    )
    print("  ✓ test_fish_builtin_completions")


fn test_zsh_builtin_completions() raises:
    """Tests that Zsh script includes the built-in --completions option."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion("zsh")
    assert_true(
        "--completions" in script,
        msg="Zsh script should include --completions",
    )
    assert_true(
        "(bash zsh fish)" in script,
        msg="Zsh script should list '(bash zsh fish)' as choices",
    )
    print("  ✓ test_zsh_builtin_completions")


fn test_bash_builtin_completions() raises:
    """Tests that Bash script includes the built-in --completions option."""
    var command = Command("myapp", "A test app")
    var script = command.generate_completion("bash")
    assert_true(
        "--completions" in script,
        msg="Bash script should include --completions",
    )
    assert_true(
        "bash zsh fish" in script,
        msg="Bash script should list 'bash zsh fish' as prev-case choices",
    )
    print("  ✓ test_bash_builtin_completions")


fn test_disable_default_completions_not_in_script() raises:
    """Tests that disable_default_completions() removes --completions from all scripts.
    """
    var command = Command("myapp", "A test app")
    command.disable_default_completions()
    var fish = command.generate_completion("fish")
    var zsh = command.generate_completion("zsh")
    var bash = command.generate_completion("bash")
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
    print("  ✓ test_disable_default_completions_not_in_script")


fn test_disable_default_completions_not_in_help() raises:
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
    print("  ✓ test_disable_default_completions_not_in_help")


fn test_completions_in_help_by_default() raises:
    """Tests that --completions appears in the Options section of help by default.
    """
    var command = Command("myapp", "A test app")
    var help_text = command._generate_help(color=False)
    assert_true(
        "--completions" in help_text,
        msg="Help text should include --completions by default",
    )
    assert_true(
        "bash,zsh,fish" in help_text or "{bash,zsh,fish}" in help_text,
        msg="Help text should show shell choices for --completions",
    )
    print("  ✓ test_completions_in_help_by_default")


# ── completions_name() ──────────────────────────────────────────────────────


fn test_completions_custom_name_in_scripts() raises:
    """Tests that completions_name() changes the trigger in all scripts."""
    var command = Command("myapp", "A test app")
    command.completions_name("autocomp")
    var fish = command.generate_completion("fish")
    var zsh = command.generate_completion("zsh")
    var bash = command.generate_completion("bash")
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
    print("  ✓ test_completions_custom_name_in_scripts")


fn test_completions_custom_name_in_help() raises:
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
    print("  ✓ test_completions_custom_name_in_help")


fn test_completions_custom_name_in_bash_prev() raises:
    """Tests that completions_name() updates bash prev-case pattern."""
    var command = Command("myapp", "A test app")
    command.completions_name("gen-comp")
    var bash = command.generate_completion("bash")
    assert_true(
        "--gen-comp)" in bash,
        msg="Bash prev-case should use '--gen-comp)' after rename",
    )
    assert_false(
        "--completions)" in bash,
        msg="Bash prev-case should NOT have '--completions)' after rename",
    )
    print("  ✓ test_completions_custom_name_in_bash_prev")


# ── completions_as_subcommand() ─────────────────────────────────────────────


fn test_completions_as_subcommand_in_help() raises:
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
    print("  ✓ test_completions_as_subcommand_in_help")


fn test_completions_as_subcommand_in_fish() raises:
    """Tests that completions_as_subcommand() appears as subcommand in Fish."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var fish = command.generate_completion("fish")
    # Should NOT appear as an option.
    assert_false(
        "-l completions" in fish,
        msg=(
            "Fish script should NOT have '-l completions' option"
            " in subcommand mode"
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
    print("  ✓ test_completions_as_subcommand_in_fish")


fn test_completions_as_subcommand_in_zsh() raises:
    """Tests that completions_as_subcommand() appears as subcommand in Zsh."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var zsh = command.generate_completion("zsh")
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
    print("  ✓ test_completions_as_subcommand_in_zsh")


fn test_completions_as_subcommand_in_bash() raises:
    """Tests that completions_as_subcommand() appears as subcommand in Bash."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_as_subcommand()
    var bash = command.generate_completion("bash")
    # Should NOT appear as --completions option.
    assert_false(
        " --completions" in bash,
        msg=(
            "Bash script should NOT list '--completions' option"
            " in subcommand mode"
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
    print("  ✓ test_completions_as_subcommand_in_bash")


fn test_completions_custom_name_with_subcommand() raises:
    """Tests combining completions_name() with completions_as_subcommand()."""
    var command = Command("myapp", "A test app")
    var sub = Command("serve", "Start the server")
    command.add_subcommand(sub^)
    command.completions_name("comp")
    command.completions_as_subcommand()
    var help_text = command._generate_help(color=False)
    var fish = command.generate_completion("fish")
    var zsh = command.generate_completion("zsh")
    var bash = command.generate_completion("bash")
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
    print("  ✓ test_completions_custom_name_with_subcommand")


# ── Alias in completion scripts ──────────────────────────────────────────────


fn test_fish_completion_includes_alias() raises:
    """Tests that Fish completion lists alias as a completable name."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)
    var script = app.generate_completion("fish")
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
    print("  ✓ test_fish_completion_includes_alias")


fn test_zsh_completion_includes_alias() raises:
    """Tests that Zsh completion lists alias entries."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)
    var script = app.generate_completion("zsh")
    assert_true(
        "'cl:" in script,
        msg="Zsh script should list alias 'cl' in commands array",
    )
    assert_true(
        "clone|cl)" in script,
        msg="Zsh script should dispatch clone|cl pattern",
    )
    print("  ✓ test_zsh_completion_includes_alias")


fn test_bash_completion_includes_alias() raises:
    """Tests that Bash completion includes alias in dispatch pattern."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    var aliases: List[String] = ["cl"]
    clone.command_aliases(aliases^)
    app.add_subcommand(clone^)
    var script = app.generate_completion("bash")
    assert_true(
        "clone|cl)" in script,
        msg="Bash script should have clone|cl) case pattern",
    )
    # Alias should also appear in the subcommand list for root completion.
    assert_true(
        "clone cl" in script,
        msg="Bash should list alias in subcommand names",
    )
    print("  ✓ test_bash_completion_includes_alias")


# ── Hidden subcommands in completions ─────────────────────────────────────────


fn _make_app_with_hidden_sub() raises -> Command:
    """Helper: app with 'clone' visible and 'debug' hidden."""
    var app = Command("myapp", "A test app")
    var clone = Command("clone", "Clone a repository")
    clone.add_argument(Argument("url", help="Repo URL").long("url"))
    app.add_subcommand(clone^)
    var debug = Command("debug", "Internal debug")
    debug.hidden()
    debug.add_argument(Argument("level", help="Level").long("level"))
    app.add_subcommand(debug^)
    return app^


fn test_fish_hidden_sub_excluded() raises:
    """Tests that hidden subcommands are absent from Fish completion."""
    var app = _make_app_with_hidden_sub()
    var script = app.generate_completion("fish")
    assert_true(
        "clone" in script,
        msg="Fish script should include visible sub 'clone'",
    )
    assert_false(
        "debug" in script,
        msg="Fish script should NOT include hidden sub 'debug'",
    )
    print("  ✓ test_fish_hidden_sub_excluded")


fn test_zsh_hidden_sub_excluded() raises:
    """Tests that hidden subcommands are absent from Zsh completion."""
    var app = _make_app_with_hidden_sub()
    var script = app.generate_completion("zsh")
    assert_true(
        "'clone:" in script,
        msg="Zsh script should include visible sub 'clone'",
    )
    assert_false(
        "'debug:" in script,
        msg="Zsh script should NOT include hidden sub 'debug'",
    )
    print("  ✓ test_zsh_hidden_sub_excluded")


fn test_bash_hidden_sub_excluded() raises:
    """Tests that hidden subcommands are absent from Bash completion."""
    var app = _make_app_with_hidden_sub()
    var script = app.generate_completion("bash")
    assert_true(
        "clone" in script,
        msg="Bash script should include visible sub 'clone'",
    )
    assert_false(
        "debug" in script,
        msg="Bash script should NOT include hidden sub 'debug'",
    )
    print("  ✓ test_bash_hidden_sub_excluded")


fn test_all_hidden_no_subcommand_completion() raises:
    """Tests that when all subs are hidden, completion is simple (no subs)."""
    var app = Command("myapp", "A test app")
    app.add_argument(Argument("verbose", help="Verbose").long("verbose").flag())
    var debug = Command("debug", "Internal debug")
    debug.hidden()
    app.add_subcommand(debug^)

    # Fish: should NOT contain subcommand-related directives.
    var fish = app.generate_completion("fish")
    assert_false(
        "__fish_seen_subcommand_from" in fish,
        msg="Fish should not have subcommand dispatching when all subs hidden",
    )

    # Bash: should not have case/subcmd detection.
    var bash = app.generate_completion("bash")
    assert_false(
        "subcmd" in bash,
        msg="Bash should not have subcmd logic when all subs hidden",
    )
    print("  ✓ test_all_hidden_no_subcommand_completion")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
