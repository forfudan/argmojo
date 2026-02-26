"""Tests for argmojo — core parsing (flags, values, positionals, shorts, count, negatable, prefix)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult


fn test_flag_long() raises:
    """Tests parsing a long flag (--verbose)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")
    print("  ✓ test_flag_long")


fn test_flag_short() raises:
    """Tests parsing a short flag (-v)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )

    var args: List[String] = ["test", "-v"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    print("  ✓ test_flag_short")


fn test_flag_default_false() raises:
    """Tests that an unset flag defaults to False."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )

    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_false(result.get_flag("verbose"), msg="unset flag should be False")
    print("  ✓ test_flag_default_false")


fn test_key_value_long_space() raises:
    """Tests parsing --key value (space separated)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "--output", "file.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_space")


fn test_key_value_long_equals() raises:
    """Tests parsing --key=value (equals separated)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "--output=file.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_equals")


fn test_key_value_short() raises:
    """Tests parsing -o value (short option with value)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "-o", "file.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_short")


fn test_positional_args() raises:
    """Tests parsing positional arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("path", help="Search path").positional().default(".")
    )

    var args: List[String] = ["test", "hello", "./src"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
    print("  ✓ test_positional_args")


fn test_positional_with_default() raises:
    """Tests that positional arguments use defaults when not provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("path", help="Search path").positional().default(".")
    )

    var args: List[String] = ["test", "hello"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), ".")
    print("  ✓ test_positional_with_default")


fn test_mixed_args() raises:
    """Tests parsing a mix of positional args and options."""
    var command = Command("sou", "Search tool")
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("path", help="Search path").positional().default(".")
    )
    command.add_argument(
        Argument("ling", help="Use Lingming encoding")
        .long("ling")
        .short("l")
        .flag()
    )
    command.add_argument(
        Argument("ignore-case", help="Case insensitive")
        .long("ignore-case")
        .short("i")
        .flag()
    )
    command.add_argument(
        Argument("max-depth", help="Max directory depth")
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
    var result = command.parse_args(args)
    assert_equal(result.get_string("pattern"), "zhong")
    assert_equal(result.get_string("path"), "./src")
    assert_true(result.get_flag("ling"), msg="--ling should be True")
    assert_true(result.get_flag("ignore-case"), msg="-i should be True")
    assert_equal(result.get_string("max-depth"), "3")
    print("  ✓ test_mixed_args")


fn test_double_dash_stop() raises:
    """Tests that '--' stops option parsing."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("verbose").long("verbose").short("v").flag())

    var args: List[String] = ["test", "--", "--verbose"]
    var result = command.parse_args(args)
    assert_false(
        result.get_flag("verbose"),
        msg="--verbose after -- should not be parsed as flag",
    )
    assert_equal(len(result.positionals), 1)
    assert_equal(result.positionals[0], "--verbose")
    print("  ✓ test_double_dash_stop")


fn test_has() raises:
    """Tests the has() method."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("verbose").long("verbose").flag())
    command.add_argument(Argument("output").long("output"))

    var args: List[String] = ["test", "--verbose"]
    var result = command.parse_args(args)
    assert_true(result.has("verbose"), msg="verbose should exist")
    assert_false(result.has("output"), msg="output should not exist")
    print("  ✓ test_has")


# ── Phase 2: Short flag merging ──────────────────────────────────────────────


# ── Phase 2: Short flag merging ──────────────────────────────────────────────


fn test_merged_short_flags() raises:
    """Tests that -abc is expanded to -a -b -c for flags."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("all", help="All").short("a").flag())
    command.add_argument(Argument("brief", help="Brief").short("b").flag())
    command.add_argument(Argument("color", help="Color").short("c").flag())

    var args: List[String] = ["test", "-abc"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True from -abc")
    assert_true(result.get_flag("brief"), msg="-b should be True from -abc")
    assert_true(result.get_flag("color"), msg="-c should be True from -abc")
    print("  ✓ test_merged_short_flags")


fn test_merged_flags_partial() raises:
    """Tests that -ab only sets those two flags, leaving -c unset."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("all", help="All").short("a").flag())
    command.add_argument(Argument("brief", help="Brief").short("b").flag())
    command.add_argument(Argument("color", help="Color").short("c").flag())

    var args: List[String] = ["test", "-ab"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True from -ab")
    assert_true(result.get_flag("brief"), msg="-b should be True from -ab")
    assert_false(result.get_flag("color"), msg="-c should be False (not given)")
    print("  ✓ test_merged_flags_partial")


fn test_merged_flags_with_trailing_value() raises:
    """Tests -avo file.txt where -a and -v are flags, -o takes a value."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("all", help="All").short("a").flag())
    command.add_argument(Argument("verbose", help="Verbose").short("v").flag())
    command.add_argument(Argument("output", help="Output").short("o"))

    var args: List[String] = ["test", "-avo", "file.txt"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True")
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_merged_flags_with_trailing_value")


# ── Phase 2: Attached short value ────────────────────────────────────────────


# ── Phase 2: Attached short value ────────────────────────────────────────────


fn test_attached_short_value() raises:
    """Tests -ofile.txt where -o takes 'file.txt' as attached value."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("output", help="Output").short("o"))

    var args: List[String] = ["test", "-ofile.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_attached_short_value")


fn test_merged_flags_with_attached_value() raises:
    """Tests -abofile.txt where -a,-b are flags, -o takes 'file.txt' inline."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("all", help="All").short("a").flag())
    command.add_argument(Argument("brief", help="Brief").short("b").flag())
    command.add_argument(Argument("output", help="Output").short("o"))

    var args: List[String] = ["test", "-abofile.txt"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("all"), msg="-a should be True")
    assert_true(result.get_flag("brief"), msg="-b should be True")
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_merged_flags_with_attached_value")


# ── Phase 2: Choices validation ──────────────────────────────────────────────


# ── Phase 2: Choices validation ──────────────────────────────────────────────


fn test_choices_valid() raises:
    """Tests that a valid choice is accepted."""
    var command = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var args: List[String] = ["test", "--format", "json"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("format"), "json")
    print("  ✓ test_choices_valid")


fn test_choices_invalid() raises:
    """Tests that an invalid choice raises an error."""
    var command = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var args: List[String] = ["test", "--format", "xml"]
    var caught = False
    try:
        _ = command.parse_args(args)
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
    """Tests choices validation with attached short value like -fxml."""
    var command = Command("test", "Test app")
    var fmts: List[String] = ["json", "csv", "table"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
    )

    var args: List[String] = ["test", "-fjson"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("format"), "json")
    print("  ✓ test_choices_with_short_attached")


# ── Phase 2: Hidden arguments ────────────────────────────────────────────────


# ── Phase 2: Count action ────────────────────────────────────────────────────


fn test_count_single() raises:
    """Tests that -v sets count to 1."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "-v"]
    var result = command.parse_args(args)
    assert_equal(result.get_count("verbose"), 1)
    print("  ✓ test_count_single")


fn test_count_triple() raises:
    """Tests that -vvv sets count to 3."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "-vvv"]
    var result = command.parse_args(args)
    assert_equal(result.get_count("verbose"), 3)
    print("  ✓ test_count_triple")


fn test_count_long_repeated() raises:
    """Tests that --verbose --verbose sets count to 2."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "--verbose", "--verbose"]
    var result = command.parse_args(args)
    assert_equal(result.get_count("verbose"), 2)
    print("  ✓ test_count_long_repeated")


fn test_count_mixed_short_long() raises:
    """Tests that -vv --verbose sets count to 3."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "-vv", "--verbose"]
    var result = command.parse_args(args)
    assert_equal(result.get_count("verbose"), 3)
    print("  ✓ test_count_mixed_short_long")


fn test_count_default_zero() raises:
    """Tests that an unprovided count arg returns 0."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_equal(result.get_count("verbose"), 0)
    print("  ✓ test_count_default_zero")


# ── Phase 2: Positional arg count validation ─────────────────────────────────


# ── Phase 2: Positional arg count validation ─────────────────────────────────


fn test_too_many_positionals() raises:
    """Tests that extra positional args raise an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )

    var args: List[String] = ["test", "hello", "extra1", "extra2"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Too many positional" in msg,
            msg="Error should mention too many positional args",
        )
    assert_true(
        caught, msg="Should have raised error for extra positional args"
    )
    print("  ✓ test_too_many_positionals")


fn test_exact_positionals_ok() raises:
    """Tests that the exact number of positional args is accepted."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    command.add_argument(
        Argument("path", help="Path").positional().default(".")
    )

    var args: List[String] = ["test", "hello", "./src"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
    print("  ✓ test_exact_positionals_ok")


# ── Phase 3: Mutually exclusive groups ────────────────────────────────────────


# ── Phase 3: Negatable flags (--no-X) ────────────────────────────────────────


fn test_negatable_positive() raises:
    """Test that --color sets a negatable flag to True."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Colored output")
        .long("color")
        .flag()
        .negatable()
    )

    var args: List[String] = ["test", "--color"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("color"), msg="--color should be True")
    print("  ✓ test_negatable_positive")


fn test_negatable_negative() raises:
    """Test that --no-color sets a negatable flag to False."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Colored output")
        .long("color")
        .flag()
        .negatable()
    )

    var args: List[String] = ["test", "--no-color"]
    var result = command.parse_args(args)
    assert_false(result.get_flag("color"), msg="--no-color should be False")
    assert_true(
        result.has("color"), msg="color should be present after --no-color"
    )
    print("  ✓ test_negatable_negative")


fn test_negatable_default() raises:
    """Test that an unset negatable flag defaults to False (not present)."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Colored output")
        .long("color")
        .flag()
        .negatable()
    )

    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_false(
        result.get_flag("color"), msg="unset negatable should be False"
    )
    assert_false(
        result.has("color"), msg="unset negatable should not be present"
    )
    print("  ✓ test_negatable_default")


fn test_non_negatable_rejects_no_prefix() raises:
    """Test that --no-X fails for a non-negatable flag."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output").long("verbose").flag()
    )

    var args: List[String] = ["test", "--no-verbose"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown option" in msg,
            msg="Error should mention unknown option",
        )
    assert_true(
        caught, msg="Should have raised error for --no-verbose on non-negatable"
    )
    print("  ✓ test_non_negatable_rejects_no_prefix")


fn test_prefix_match_unambiguous() raises:
    """Test that --verb resolves to --verbose when unambiguous."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "--verb"]
    var result = command.parse_args(args)
    assert_true(
        result.get_flag("verbose"), msg="--verb should resolve to --verbose"
    )
    print("  ✓ test_prefix_match_unambiguous")


fn test_prefix_match_value() raises:
    """Test that prefix matching works for value-taking options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "--out", "file.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_prefix_match_value")


fn test_prefix_match_equals() raises:
    """Test that prefix matching works with --key=value syntax."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").short("o")
    )

    var args: List[String] = ["test", "--out=file.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_prefix_match_equals")


fn test_prefix_match_ambiguous() raises:
    """Test that ambiguous prefix raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )
    command.add_argument(
        Argument("version-info", help="Version info")
        .long("version-info")
        .flag()
    )

    var args: List[String] = ["test", "--ver"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true("Ambiguous" in msg, msg="Error should mention ambiguity")
    assert_true(caught, msg="Should have raised error for ambiguous prefix")
    print("  ✓ test_prefix_match_ambiguous")


fn test_prefix_match_exact_preferred() raises:
    """Test that exact match is preferred over prefix match."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Color mode").long("color").flag()
    )
    command.add_argument(
        Argument("colorize", help="Colorize output").long("colorize").flag()
    )

    # --color should exactly match 'color', not be ambiguous.
    var args: List[String] = ["test", "--color"]
    var result = command.parse_args(args)
    assert_true(
        result.get_flag("color"),
        msg="--color should exactly match 'color'",
    )
    assert_false(
        result.get_flag("colorize"),
        msg="--colorize should not be set",
    )
    print("  ✓ test_prefix_match_exact_preferred")


fn test_prefix_match_negatable() raises:
    """Test that --no-col resolves to --no-color when unambiguous."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("color", help="Colored output")
        .long("color")
        .flag()
        .negatable()
    )

    var args: List[String] = ["test", "--no-col"]
    var result = command.parse_args(args)
    assert_false(result.get_flag("color"), msg="--no-col should negate color")
    assert_true(
        result.has("color"), msg="color should be present after --no-col"
    )
    print("  ✓ test_prefix_match_negatable")


# ── Phase 3: Append / collect action ─────────────────────────────────────────


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
