"""End-to-end test for the declarative Parsable API (Phase 1).

Tests _reflect_and_register / _from_result via the public
to_command / parse_args / from_result functions.
"""
from argmojo import (
    Command,
    Parsable,
    Option,
    Flag,
    Positional,
    Count,
    to_command,
    parse_args,
    from_result,
)
from argmojo.parse_result import ParseResult


# =======================================================================
# Test struct
# =======================================================================


struct Grep(Parsable):
    var output: Option[String, long="output", short="o", help="Output file"]
    var verbose: Flag[short="v", help="Verbose mode"]
    var pattern: Positional[String, help="Search pattern", required=True]
    var debug_level: Count[long="debug", short="d", help="Debug level", max=3]

    def __init__(out self):
        self.output = Option[String, long="output", short="o", help="Output file"]()
        self.verbose = Flag[short="v", help="Verbose mode"]()
        self.pattern = Positional[String, help="Search pattern", required=True]()
        self.debug_level = Count[long="debug", short="d", help="Debug level", max=3]()

    fn __init__(out self, *, deinit take: Self):
        self.output = take.output^
        self.verbose = take.verbose^
        self.pattern = take.pattern^
        self.debug_level = take.debug_level^

    @staticmethod
    def description() -> String:
        return String("Search for patterns in files.")

    @staticmethod
    def name() -> String:
        return String("grep")


# =======================================================================
# Tests
# =======================================================================


def test_to_command() raises:
    """Test that to_command registers all arguments correctly."""
    print("=== test_to_command ===")
    var cmd = to_command[Grep]()

    # Should have 4 arguments.
    print("  arg count:", len(cmd.args))
    assert_true(len(cmd.args) == 4, "expected 4 args, got " + String(len(cmd.args)))

    for i in range(len(cmd.args)):
        print("  [" + String(i) + "]", cmd.args[i].name,
              "long:", cmd.args[i]._long_name,
              "short:", cmd.args[i]._short_name,
              "help:", cmd.args[i].help_text,
              "flag:", cmd.args[i]._is_flag,
              "positional:", cmd.args[i]._is_positional,
              "count:", cmd.args[i]._is_count)

    # Check output option.
    assert_true(cmd.args[0].name == "output", "arg0 name")
    assert_true(cmd.args[0]._long_name == "output", "arg0 long")
    assert_true(cmd.args[0]._short_name == "o", "arg0 short")

    # Check verbose flag.
    assert_true(cmd.args[1]._is_flag, "arg1 flag")
    assert_true(cmd.args[1]._short_name == "v", "arg1 short")

    # Check pattern positional.
    assert_true(cmd.args[2]._is_positional, "arg2 positional")
    assert_true(cmd.args[2]._is_required, "arg2 required")

    # Check debug count.
    assert_true(cmd.args[3]._is_count, "arg3 count")
    assert_true(cmd.args[3]._short_name == "d", "arg3 short")

    print("  PASSED\n")


def test_parse_args() raises:
    """Test full parse + write-back flow."""
    print("=== test_parse_args ===")

    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("result.txt"))
    args.append(String("-v"))
    args.append(String("-ddd"))
    args.append(String("hello.*world"))

    var grep = parse_args[Grep](args)

    print("  output:", grep.output.value)
    print("  verbose:", grep.verbose.value)
    print("  pattern:", grep.pattern.value)
    print("  debug:", grep.debug_level.value)

    assert_true(grep.output.value == "result.txt", "output value")
    assert_true(grep.verbose.value, "verbose value")
    assert_true(grep.pattern.value == "hello.*world", "pattern value")
    assert_true(grep.debug_level.value == 3, "debug_level value")

    print("  PASSED\n")


def test_from_result() raises:
    """Test from_result writes back from an existing ParseResult."""
    print("=== test_from_result ===")

    var cmd = to_command[Grep]()
    var args = List[String]()
    args.append(String("grep"))
    args.append(String("--output"))
    args.append(String("out.txt"))
    args.append(String("pattern_str"))

    var result = cmd.parse_arguments(args)
    var grep = from_result[Grep](result)

    print("  output:", grep.output.value)
    print("  verbose:", grep.verbose.value)
    print("  pattern:", grep.pattern.value)

    assert_true(grep.output.value == "out.txt", "output")
    assert_true(not grep.verbose.value, "verbose should be false")
    assert_true(grep.pattern.value == "pattern_str", "pattern")

    print("  PASSED\n")


struct AutoNameArgs(Parsable):
    var no_color: Flag[help="Disable color"]
    var max_depth: Option[Int, help="Max depth"]

    def __init__(out self):
        self.no_color = Flag[help="Disable color"]()
        self.max_depth = Option[Int, help="Max depth"]()

    fn __init__(out self, *, deinit take: Self):
        self.no_color = take.no_color^
        self.max_depth = take.max_depth^

    @staticmethod
    def description() -> String:
        return String("Auto-naming test.")


def test_auto_naming() raises:
    """Test that underscore field names auto-convert to hyphen long names."""
    print("=== test_auto_naming ===")

    var cmd = to_command[AutoNameArgs]()
    print("  arg0 long:", cmd.args[0]._long_name)
    print("  arg1 long:", cmd.args[1]._long_name)

    assert_true(cmd.args[0]._long_name == "no-color", "no_color -> no-color")
    assert_true(cmd.args[1]._long_name == "max-depth", "max_depth -> max-depth")

    print("  PASSED\n")


# =======================================================================
# Helpers
# =======================================================================


def assert_true(cond: Bool, msg: String = "") raises:
    if not cond:
        raise Error("Assertion failed: " + msg)


# =======================================================================
# Main
# =======================================================================


def main() raises:
    test_to_command()
    test_parse_args()
    test_from_result()
    test_auto_naming()
    print("All Phase 1 tests passed!")
