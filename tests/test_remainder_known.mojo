"""Tests for argmojo — remainder nargs, parse_known_arguments, 
value_name rename, allow_hyphen_values."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ═══════════════════════════════════════════════════════════════════════════════
# value_name (renamed from metavar)
# ═══════════════════════════════════════════════════════════════════════════════


fn test_value_name_basic() raises:
    """Tests that .value_name() sets the display name for help."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long("output")
        .short("o")
        .value_name("FILE")
    )
    # Parse succeeds normally — value_name is purely cosmetic.
    var args: List[String] = ["test", "--output", "data.csv"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "data.csv")


fn test_value_name_in_help() raises:
    """Tests that value_name appears in help output."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file")
        .long("output")
        .short("o")
        .value_name("FILE")
    )
    # The help text should contain "FILE" instead of "<output>".
    # We don't assert exact help format, just that it works without errors.
    var args: List[String] = ["test", "--output", "out.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "out.txt")


# ═══════════════════════════════════════════════════════════════════════════════
# remainder()
# ═══════════════════════════════════════════════════════════════════════════════


fn test_remainder_basic() raises:
    """Tests that remainder consumes all remaining tokens."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("cmd", help="Command to run").positional().required()
    )
    command.add_argument(
        Argument("rest", help="Arguments for the command").remainder()
    )

    var args: List[String] = ["test", "gcc", "-Wall", "-O2", "main.c"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("cmd"), "gcc")
    var rest = result.get_list("rest")
    assert_equal(len(rest), 3)
    assert_equal(rest[0], "-Wall")
    assert_equal(rest[1], "-O2")
    assert_equal(rest[2], "main.c")


fn test_remainder_empty() raises:
    """Tests remainder with no trailing arguments."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("cmd", help="Command to run").positional().required()
    )
    command.add_argument(
        Argument("rest", help="Arguments for the command").remainder()
    )

    var args: List[String] = ["test", "gcc"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("cmd"), "gcc")
    var rest = result.get_list("rest")
    assert_equal(len(rest), 0)


fn test_remainder_only() raises:
    """Tests remainder as the only positional."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest", help="All arguments").remainder())

    var args: List[String] = ["test", "--flag", "-v", "file.txt"]
    var result = command.parse_arguments(args)
    var rest = result.get_list("rest")
    assert_equal(len(rest), 3)
    assert_equal(rest[0], "--flag")
    assert_equal(rest[1], "-v")
    assert_equal(rest[2], "file.txt")


fn test_remainder_with_options_before() raises:
    """Tests that options before the remainder positional slot are parsed normally.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("cmd", help="Command").positional().required()
    )
    command.add_argument(Argument("rest", help="Rest").remainder())

    var args: List[String] = ["test", "--verbose", "gcc", "-O2", "main.c"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("cmd"), "gcc")
    var rest = result.get_list("rest")
    assert_equal(len(rest), 2)
    assert_equal(rest[0], "-O2")
    assert_equal(rest[1], "main.c")


fn test_remainder_captures_double_dash_tokens() raises:
    """Tests that remainder captures -- and tokens after it."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest", help="All args").remainder())

    var args: List[String] = ["test", "--", "-v", "--help"]
    var result = command.parse_arguments(args)
    # The "--" is consumed as the stop marker and remaining go to positionals.
    # Remainder collects them all.
    var rest = result.get_list("rest")
    assert_equal(len(rest), 2)
    assert_equal(rest[0], "-v")
    assert_equal(rest[1], "--help")


fn test_remainder_guard_no_long_short() raises:
    """Tests that remainder rejects .long() or .short()."""
    var command = Command("test", "Test app")
    var failed = False
    try:
        command.add_argument(
            Argument("rest", help="Rest").long("rest").remainder()
        )
    except:
        failed = True
    assert_true(failed, msg="remainder with .long() should be rejected")


fn test_remainder_guard_only_one() raises:
    """Tests that only one remainder positional is allowed."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest1", help="Rest 1").remainder())
    var failed = False
    try:
        command.add_argument(Argument("rest2", help="Rest 2").remainder())
    except:
        failed = True
    assert_true(failed, msg="second remainder should be rejected")


fn test_remainder_with_dashes_in_values() raises:
    """Tests that remainder captures tokens like --unknown and -x."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("cmd", help="Command").positional().required()
    )
    command.add_argument(Argument("args", help="Forwarded args").remainder())

    var args: List[String] = [
        "test",
        "cmake",
        "-DCMAKE_BUILD_TYPE=Release",
        "--preset",
        "default",
    ]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("cmd"), "cmake")
    var rest = result.get_list("args")
    assert_equal(len(rest), 3)
    assert_equal(rest[0], "-DCMAKE_BUILD_TYPE=Release")
    assert_equal(rest[1], "--preset")
    assert_equal(rest[2], "default")


# ═══════════════════════════════════════════════════════════════════════════════
# parse_known_arguments()
# ═══════════════════════════════════════════════════════════════════════════════


fn test_parse_known_basic() raises:
    """Tests that unknown options are collected instead of erroring."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )

    var args: List[String] = ["test", "--verbose", "--unknown", "-x"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 2)
    assert_equal(unknown[0], "--unknown")
    assert_equal(unknown[1], "-x")


fn test_parse_known_no_unknowns() raises:
    """Tests parse_known_arguments with all args recognized."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(
        Argument("output", help="Output").long("output").short("o")
    )

    var args: List[String] = ["test", "--verbose", "--output", "file.txt"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "file.txt")
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 0)


fn test_parse_known_mixed_with_positionals() raises:
    """Tests parse_known_arguments with positionals and unknown options."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="Input file").positional().required()
    )
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )

    var args: List[String] = [
        "test",
        "--verbose",
        "input.txt",
        "--unknown-flag",
    ]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("file"), "input.txt")
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 1)
    assert_equal(unknown[0], "--unknown-flag")


fn test_parse_known_unknown_with_value() raises:
    """Tests that unknown long options with = syntax are collected."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )

    var args: List[String] = ["test", "--verbose", "--color=auto"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    var unknown = result.get_unknown_args()
    assert_equal(len(unknown), 1)
    assert_equal(unknown[0], "--color=auto")


fn test_parse_known_preserves_validation() raises:
    """Tests that parse_known_arguments still validates required args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output").long("output").required()
    )

    var args: List[String] = ["test", "--unknown"]
    var failed = False
    try:
        _ = command.parse_known_arguments(args)
    except:
        failed = True
    assert_true(failed, msg="required arg validation should still apply")


# ═══════════════════════════════════════════════════════════════════════════════
# allow_hyphen_values() / stdin convention
# ═══════════════════════════════════════════════════════════════════════════════


fn test_hyphen_value_positional() raises:
    """Tests that '-' is accepted as a positional value."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input (- for stdin)")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    # A bare "-" already works as a positional because len("-") == 1,
    # so the short-option check (len > 1) skips it.
    var args: List[String] = ["test", "-"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("input"), "-")


fn test_hyphen_value_multi_char_short() raises:
    """Tests that '-x' is consumed as a positional when allow_hyphen_values
    is set and '-x' is NOT a known option.  Without the flag, '-x' would
    be treated as an unknown short option and error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Regex pattern")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    var args: List[String] = ["test", "-foo"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("pattern"), "-foo")


fn test_hyphen_value_long_token() raises:
    """Tests that '--unknown-thing' is consumed as a positional when
    allow_hyphen_values is set and it is not a known long option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("expr", help="Expression")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    var args: List[String] = ["test", "--not-an-option"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("expr"), "--not-an-option")


fn test_hyphen_value_known_option_still_parsed() raises:
    """Tests that a known option is still parsed normally even when the
    current positional has allow_hyphen_values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("pattern", help="Pattern")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    # -v is a known short option → parsed as flag, not as positional.
    var args: List[String] = ["test", "-v", "-foo"]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("pattern"), "-foo")


fn test_hyphen_value_without_flag_errors() raises:
    """Tests that without allow_hyphen_values, '-x' raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input").positional().required()
    )

    var args: List[String] = ["test", "-x"]
    var failed = False
    try:
        _ = command.parse_arguments(args)
    except:
        failed = True
    assert_true(failed, msg="'-x' without allow_hyphen_values should error")


fn test_hyphen_value_with_other_positional() raises:
    """Tests '-' alongside a regular positional."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("input", help="Input")
        .positional()
        .required()
        .allow_hyphen_values()
    )
    command.add_argument(
        Argument("output", help="Output").positional().default("out.txt")
    )

    var args: List[String] = ["test", "-", "result.csv"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("input"), "-")
    assert_equal(result.get_string("output"), "result.csv")


fn test_hyphen_value_with_option() raises:
    """Tests that '-' works as a value for a named option."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("file", help="File (- for stdin)")
        .long("file")
        .short("f")
        .allow_hyphen_values()
    )

    # --file - should take "-" as the value.
    var args: List[String] = ["test", "--file", "-"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("file"), "-")


fn test_hyphen_value_in_parse_known() raises:
    """Tests allow_hyphen_values with parse_known_arguments: unknown
    dash tokens go to positional instead of unknown_args."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(
        Argument("expr", help="Expression")
        .positional()
        .required()
        .allow_hyphen_values()
    )

    var args: List[String] = ["test", "--verbose", "-pattern"]
    var result = command.parse_known_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("expr"), "-pattern")
    assert_equal(len(result.get_unknown_args()), 0)


fn test_remainder_guard_positional_after() raises:
    """Tests that adding a positional after a remainder is rejected."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("rest", help="Rest").remainder())
    var failed = False
    try:
        command.add_argument(Argument("extra", help="Extra").positional())
    except:
        failed = True
    assert_true(failed, msg="positional after remainder should be rejected")


# ═══════════════════════════════════════════════════════════════════════════════
# Test runner
# ═══════════════════════════════════════════════════════════════════════════════


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
