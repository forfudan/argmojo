"""Testss for argmojo — command-line argument parser."""

from testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import Arg, Command, ParseResult


fn test_flag_long() raises:
    """Tests parsing a long flag (--verbose)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "--verbose"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="--verbose should be True")
    print("  ✓ test_flag_long")


fn test_flag_short() raises:
    """Tests parsing a short flag (-v)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "-v"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("verbose"), msg="-v should be True")
    print("  ✓ test_flag_short")


fn test_flag_default_false() raises:
    """Tests that an unset flag defaults to False."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_false(result.get_flag("verbose"), msg="unset flag should be False")
    print("  ✓ test_flag_default_false")


fn test_key_value_long_space() raises:
    """Tests parsing --key value (space separated)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "--output", "file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_space")


fn test_key_value_long_equals() raises:
    """Tests parsing --key=value (equals separated)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "--output=file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_long_equals")


fn test_key_value_short() raises:
    """Tests parsing -o value (short option with value)."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output file").long("output").short("o"))

    var args: List[String] = ["test", "-o", "file.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_key_value_short")


fn test_positional_args() raises:
    """Tests parsing positional arguments."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    var args: List[String] = ["test", "hello", "./src"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
    print("  ✓ test_positional_args")


fn test_positional_with_default() raises:
    """Tests that positional arguments use defaults when not provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    var args: List[String] = ["test", "hello"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), ".")
    print("  ✓ test_positional_with_default")


fn test_mixed_args() raises:
    """Tests parsing a mix of positional args and options."""
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
    """Tests that '--' stops option parsing."""
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
    """Tests the has() method."""
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
    """Tests that -abc is expanded to -a -b -c for flags."""
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
    """Tests that -ab only sets those two flags, leaving -c unset."""
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
    """Tests -avo file.txt where -a and -v are flags, -o takes a value."""
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
    """Tests -ofile.txt where -o takes 'file.txt' as attached value."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("output", help="Output").short("o"))

    var args: List[String] = ["test", "-ofile.txt"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("output"), "file.txt")
    print("  ✓ test_attached_short_value")


fn test_merged_flags_with_attached_value() raises:
    """Tests -abofile.txt where -a,-b are flags, -o takes 'file.txt' inline."""
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
    """Tests that a valid choice is accepted."""
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
    """Tests that an invalid choice raises an error."""
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
    """Tests choices validation with attached short value like -fxml."""
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
    """Tests that hidden arguments are excluded from help output."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )
    cmd.add_arg(
        Arg("debug", help="Debug mode").long("debug").short("d").flag().hidden()
    )

    var help = cmd._generate_help()
    assert_true("verbose" in help, msg="visible arg should be in help")
    assert_false("debug" in help, msg="hidden arg should NOT be in help")
    print("  ✓ test_hidden_not_in_help")


fn test_hidden_still_works() raises:
    """Tests that hidden arguments can still be used at the command line."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("debug", help="Debug mode").long("debug").short("d").flag().hidden()
    )

    var args: List[String] = ["test", "--debug"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("debug"), msg="hidden --debug should work")
    print("  ✓ test_hidden_still_works")


# ── Phase 2: Metavar ─────────────────────────────────────────────────────────


fn test_metavar_in_help() raises:
    """Tests that metavar appears in help output."""
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
    """Tests that choices are displayed in help when no metavar."""
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


# ── Phase 2: Count action ────────────────────────────────────────────────────


fn test_count_single() raises:
    """Tests that -v sets count to 1."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "-v"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_count("verbose"), 1)
    print("  ✓ test_count_single")


fn test_count_triple() raises:
    """Tests that -vvv sets count to 3."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "-vvv"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_count("verbose"), 3)
    print("  ✓ test_count_triple")


fn test_count_long_repeated() raises:
    """Tests that --verbose --verbose sets count to 2."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "--verbose", "--verbose"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_count("verbose"), 2)
    print("  ✓ test_count_long_repeated")


fn test_count_mixed_short_long() raises:
    """Tests that -vv --verbose sets count to 3."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test", "-vv", "--verbose"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_count("verbose"), 3)
    print("  ✓ test_count_mixed_short_long")


fn test_count_default_zero() raises:
    """Tests that an unprovided count arg returns 0."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(
        Arg("verbose", help="Verbosity level")
        .long("verbose")
        .short("v")
        .count()
    )

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_count("verbose"), 0)
    print("  ✓ test_count_default_zero")


# ── Phase 2: Positional arg count validation ─────────────────────────────────


fn test_too_many_positionals() raises:
    """Tests that extra positional args raise an error."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Pattern").positional().required())

    var args: List[String] = ["test", "hello", "extra1", "extra2"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
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
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("pattern", help="Pattern").positional().required())
    cmd.add_arg(Arg("path", help="Path").positional().default("."))

    var args: List[String] = ["test", "hello", "./src"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), "./src")
    print("  ✓ test_exact_positionals_ok")


# ── Phase 3: Mutually exclusive groups ────────────────────────────────────────


fn test_exclusive_one_provided() raises:
    """Tests that providing one arg from an exclusive group is fine."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("json", help="JSON output").long("json").flag())
    cmd.add_arg(Arg("yaml", help="YAML output").long("yaml").flag())
    cmd.add_arg(Arg("toml", help="TOML output").long("toml").flag())
    var group: List[String] = ["json", "yaml", "toml"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json"]
    var result = cmd.parse_args(args)
    assert_true(result.get_flag("json"), msg="--json should be True")
    assert_false(result.get_flag("yaml"), msg="--yaml should be False")
    print("  ✓ test_exclusive_one_provided")


fn test_exclusive_none_provided() raises:
    """Tests that providing no arg from an exclusive group is fine."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("json", help="JSON output").long("json").flag())
    cmd.add_arg(Arg("yaml", help="YAML output").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_false(result.get_flag("json"), msg="--json should be False")
    assert_false(result.get_flag("yaml"), msg="--yaml should be False")
    print("  ✓ test_exclusive_none_provided")


fn test_exclusive_conflict() raises:
    """Tests that providing two args from an exclusive group raises an error."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("json", help="JSON output").long("json").flag())
    cmd.add_arg(Arg("yaml", help="YAML output").long("yaml").flag())
    cmd.add_arg(Arg("toml", help="TOML output").long("toml").flag())
    var group: List[String] = ["json", "yaml", "toml"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json", "--yaml"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
        assert_true(
            "--json" in msg,
            msg="Error should mention --json",
        )
        assert_true(
            "--yaml" in msg,
            msg="Error should mention --yaml",
        )
    assert_true(caught, msg="Should have raised error for exclusive conflict")
    print("  ✓ test_exclusive_conflict")


fn test_exclusive_value_args() raises:
    """Tests mutually exclusive with value-taking args."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("input", help="Input file").long("input"))
    cmd.add_arg(Arg("stdin", help="Read stdin").long("stdin").flag())
    var group: List[String] = ["input", "stdin"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["test", "--input", "file.txt", "--stdin"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="Should have raised error for exclusive conflict")
    print("  ✓ test_exclusive_value_args")


# ── Phase 3: Required-together groups ─────────────────────────────────────────


fn test_required_together_all_provided() raises:
    """Tests that providing all args from a required-together group is fine."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("username", help="User").long("username").short("u"))
    cmd.add_arg(Arg("password", help="Pass").long("password").short("p"))
    var group: List[String] = ["username", "password"]
    cmd.required_together(group^)

    var args: List[String] = ["test", "--username", "admin", "--password", "secret"]
    var result = cmd.parse_args(args)
    assert_equal(result.get_string("username"), "admin")
    assert_equal(result.get_string("password"), "secret")
    print("  ✓ test_required_together_all_provided")


fn test_required_together_none_provided() raises:
    """Tests that providing none from a required-together group is fine."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("username", help="User").long("username").short("u"))
    cmd.add_arg(Arg("password", help="Pass").long("password").short("p"))
    var group: List[String] = ["username", "password"]
    cmd.required_together(group^)

    var args: List[String] = ["test"]
    var result = cmd.parse_args(args)
    assert_false(result.has("username"), msg="username should not be set")
    assert_false(result.has("password"), msg="password should not be set")
    print("  ✓ test_required_together_none_provided")


fn test_required_together_partial() raises:
    """Tests that providing only some from a required-together group raises an error."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("username", help="User").long("username").short("u"))
    cmd.add_arg(Arg("password", help="Pass").long("password").short("p"))
    var group: List[String] = ["username", "password"]
    cmd.required_together(group^)

    var args: List[String] = ["test", "--username", "admin"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "required together" in msg,
            msg="Error should mention required together",
        )
        assert_true(
            "--password" in msg,
            msg="Error should mention --password",
        )
    assert_true(caught, msg="Should have raised error for partial group")
    print("  ✓ test_required_together_partial")


fn test_required_together_three_args() raises:
    """Tests required-together with three arguments, only one provided."""
    var cmd = Command("test", "Test app")
    cmd.add_arg(Arg("host", help="Host").long("host"))
    cmd.add_arg(Arg("port", help="Port").long("port"))
    cmd.add_arg(Arg("proto", help="Protocol").long("proto"))
    var group: List[String] = ["host", "port", "proto"]
    cmd.required_together(group^)

    var args: List[String] = ["test", "--host", "localhost"]
    var caught = False
    try:
        _ = cmd.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "--port" in msg,
            msg="Error should mention --port",
        )
        assert_true(
            "--proto" in msg,
            msg="Error should mention --proto",
        )
    assert_true(caught, msg="Should have raised error for partial group")
    print("  ✓ test_required_together_three_args")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
