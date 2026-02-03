"""Tests for argmojo — command-line argument parser."""

from testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import Arg, Command, ParseResult


fn test_flag_long() raises:
    """Test parsing a long flag (--verbose)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "--verbose"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")
    print("  ✓ test_flag_long")


fn test_flag_short() raises:
    """Test parsing a short flag (-v)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "-v"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    print("  ✓ test_flag_short")


fn test_flag_default_false() raises:
    """Test that an unset flag defaults to False."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_false(result.get_flag("verbose"), msg="unset flag should be False")
    print("  ✓ test_flag_default_false")


fn test_key_value_long_space() raises:
    """Test parsing --key value (space separated)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "--output", "file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_space")


fn test_key_value_long_equals() raises:
    """Test parsing --key=value (equals separated)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "--output=file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_equals")


fn test_key_value_short() raises:
    """Test parsing -o value (short option with value)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "-o", "file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_short")


fn test_positional_args() raises:
    """Test parsing positional arguments."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    var args: List[String] = ["test", "hello", "./src"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
    print("  ✓ test_positional_args")


fn test_positional_with_default() raises:
    """Test that positional arguments use defaults when not provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    var args: List[String] = ["test", "hello"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), ".")
    print("  ✓ test_positional_with_default")


fn test_mixed_args() raises:
    """Test parsing a mix of positional args and options."""
    var cmd = Command("sou", "Search tool")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))
    cmd.add_arg(
        Arg("ling", help="Use Lingming encoding").long("ling").short("l").flag()
    )
    cmd.add_arg(
        Arg("ignore-case", help="Case insensitive")
        .long("ignore-case")
        .short("i")
        .flag()
    )
    cmd.add_arg(
        Arg("max-depth", help="Max directory depth")
        .long("max-depth")
        .short("d")
    )

    var args: List[String] = [
        "sou",
        "zhong",
        "./src",
        "--ling",
        "-i",
        "--max-depth",
        "3",
    ]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "zhong")
    assert_equal(result.get_string("path"), "./src")
    assert_true(result.get_flag("ling"), msg="--ling should be True")
    assert_true(result.get_flag("ignore-case"), msg="-i should be True")
    assert_equal(result.get_string("max-depth"), "3")
    print("  ✓ test_mixed_args")


fn test_double_dash_stop() raises:
    """Test that '--' stops option parsing."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("verbose").long("verbose").short("v").flag())

    var args: List[String] = ["test", "--", "--verbose"]
    var result = cmd.parse_args(args)
    assert_false(
        result.get_flag("verbose"),
        msg="--verbose after -- should not be parsed as flag",
    )
    assert_equal(len(result.positionals), 1)
    assert_equal(result.positionals[0], "--verbose")
    print("  ✓ test_double_dash_stop")


fn test_has() raises:
    """Test the has() method."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("verbose").long("verbose").flag())
    cmd.add_arg(Arg("output").long("output"))

    var args: List[String] = ["test", "--verbose"]
    var result = cmd.parse_args(args)
    assert_true(result.has("verbose"), msg="verbose should exist")
    assert_false(result.has("output"), msg="output should not exist")
    print("  ✓ test_has")


# ── Phase 2: Short flag merging ──────────────────────────────────────────────


fn test_merged_short_flags() raises:
    """Test that -abc is expanded to -a -b -c for flags."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("all", help="All").short("a").flag())
    cmd.add_arg(Arg("brief", help="Brief").short("b").flag())
    cmd.add_arg(Arg("color", help="Color").short("c").flag())

    var args: List[String] = ["test", "-abc"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True from -abc")
    assert_true(result.get_flag("brief"), msg="-b should be True from -abc")
    assert_true(result.get_flag("color"), msg="-c should be True from -abc")
    print("  ✓ test_merged_short_flags")


fn test_merged_flags_partial() raises:
    """Test that -ab only sets those two flags, leaving -c unset."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("all", help="All").short("a").flag())
    cmd.add_arg(Arg("brief", help="Brief").short("b").flag())
    cmd.add_arg(Arg("color", help="Color").short("c").flag())

    var args: List[String] = ["test", "-ab"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True from -ab")
    assert_true(result.get_flag("brief"), msg="-b should be True from -ab")
    assert_false(result.get_flag("color"), msg="-c should be False (not given)")
    print("  ✓ test_merged_flags_partial")


fn test_merged_flags_with_trailing_value() raises:
    """Test -avo file.txt where -a and -v are flags, -o takes a value."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("all", help="All").short("a").flag())
    cmd.add_arg(Arg("verbose", help="Verbose").short("v").flag())
    cmd.add_arg(Arg("output", help="Output").short("o"))

    var args: List[String] = ["test", "-avo", "file.txt"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True")
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_merged_flags_with_trailing_value")


# ── Phase 2: Attached short value ────────────────────────────────────────────


fn test_attached_short_value() raises:
    """Test -ofile.txt where -o takes 'file.txt' as attached value."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output").short("o"))

    var args: List[String] = ["test", "-ofile.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_attached_short_value")


fn test_merged_flags_with_attached_value() raises:
    """Test -abofile.txt where -a,-b are flags, -o takes 'file.txt' inline."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("all", help="All").short("a").flag())
    cmd.add_arg(Arg("brief", help="Brief").short("b").flag())
    cmd.add_arg(Arg("output", help="Output").short("o"))

    var args: List[String] = ["test", "-abofile.txt"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True")
    assert_true(result.get_flag("brief"), msg="-b should be True")
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_merged_flags_with_attached_value")


# ── Phase 2: Choices validation ──────────────────────────────────────────────


fn test_choices_valid() raises:
    """Test that a valid choice is accepted."""
    var cmd = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    cmd.add_arg(
        Arg("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var args: List[String] = ["test", "--format", "json"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("format"), "json")
    print("  ✓ test_choices_valid")


fn test_choices_invalid() raises:
    """Test that an invalid choice raises an error."""
    var cmd = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    cmd.add_arg(
        Arg("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var args: List[String] = ["test", "--format", "xml"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Invalid value" in msg,
            msg="Error should mention invalid value",
        )
        assert_true(
            "xml" in msg, msg="Error should mention the bad value 'xml'"
        )
    assert_true(caught, msg="Should have raised an error for invalid choice")
    print("  ✓ test_choices_invalid")


fn test_choices_with_short_attached() raises:
    """Test choices validation with attached short value like -fxml."""
    var cmd = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    cmd.add_arg(
        Arg("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var args: List[String] = ["test", "-fjson"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("format"), "json")
    print("  ✓ test_choices_with_short_attached")


# ── Phase 2: Hidden arguments ────────────────────────────────────────────────


fn test_hidden_not_in_help() raises:
    """Test that hidden arguments are excluded from help output."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )
    cmd.add_arg(
        Arg("debug", help="Debug mode")
        .long("debug")
        .short("d")
        .flag()
        .hidden()
    )

    var help = cmd._generate_help()
    assert_true("verbose" in help, msg="visible arg should be in help")
    assert_false("debug" in help, msg="hidden arg should NOT be in help")
    print("  ✓ test_hidden_not_in_help")


fn test_hidden_still_works() raises:
    """Test that hidden arguments can still be used at the command line."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("debug", help="Debug mode")
        .long("debug")
        .short("d")
        .flag()
        .hidden()
    )

    var args: List[String] = ["test", "--debug"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("debug"), msg="hidden --debug should work")
    print("  ✓ test_hidden_still_works")


# ── Phase 2: Metavar ─────────────────────────────────────────────────────────


fn test_metavar_in_help() raises:
    """Test that metavar appears in help output."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("output", help="Output file")
        .long("output")
        .short("o")
        .metavar("FILE")
    )

    var help = cmd._generate_help()
    assert_true("FILE" in help, msg="metavar 'FILE' should appear in help")
    # Should NOT show the default "<output>" form.
    assert_false(
        "<output>" in help,
        msg="default placeholder should not appear when metavar is set",
    )
    print("  ✓ test_metavar_in_help")


fn test_choices_in_help() raises:
    """Test that choices are displayed in help when no metavar."""
    var cmd = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    cmd.add_arg(
        Arg("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var help = cmd._generate_help()
    assert_true(
        "{json,csv,table}" in help,
        msg="choices should appear in help as {json,csv,table}",
    )
    print("  ✓ test_choices_in_help")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
