"""Tests for argmojo — response file (@args.txt) expansion."""

from testing import assert_true, assert_false, assert_equal, TestSuite
from os import remove
import argmojo
from argmojo import Argument, Command, ParseResult


# ── Helpers ──────────────────────────────────────────────────────────────────


fn _write_file(path: String, content: String) raises:
    """Write a string to a file (overwrite)."""
    with open(path, "w") as f:
        f.write(content)


fn _remove_file(path: String):
    """Remove a file, ignoring errors."""
    try:
        remove(path)
    except:
        pass


fn _make_command() -> Command:
    """Create a simple command with response_file_prefix enabled."""
    var command = Command("test", "Test app")
    command.response_file_prefix()  # default '@'
    return command^


# ── Basic expansion ──────────────────────────────────────────────────────────


fn test_response_file_basic() raises:
    """@args.txt expands file lines as arguments."""
    var path = "/tmp/_argmojo_test_rf_basic.txt"
    _write_file(path, "--verbose\n--output=file.txt\n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "file.txt")
    _remove_file(path)


fn test_response_file_mixed_with_direct_args() raises:
    """Response file args are mixed with direct CLI args."""
    var path = "/tmp/_argmojo_test_rf_mixed.txt"
    _write_file(path, "--output=file.txt\n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "--verbose", "@" + path]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "file.txt")
    _remove_file(path)


fn test_response_file_positional_args() raises:
    """Response file can contain positional arguments."""
    var path = "/tmp/_argmojo_test_rf_pos.txt"
    _write_file(path, "hello\nworld\n")

    var command = _make_command()
    command.add_argument(Argument("word1", help="First word").positional())
    command.add_argument(Argument("word2", help="Second word").positional())

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("word1"), "hello")
    assert_equal(result.get_string("word2"), "world")
    _remove_file(path)


# ── Comments and blank lines ────────────────────────────────────────────────


fn test_response_file_comments_and_blanks() raises:
    """Lines starting with # and blank lines are skipped."""
    var path = "/tmp/_argmojo_test_rf_comments.txt"
    _write_file(
        path,
        "# This is a comment\n"
        + "--verbose\n"
        + "\n"
        + "  \n"
        + "# Another comment\n"
        + "--output=result.txt\n",
    )

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "result.txt")
    _remove_file(path)


fn test_response_file_whitespace_stripped() raises:
    """Leading/trailing whitespace per line is stripped."""
    var path = "/tmp/_argmojo_test_rf_ws.txt"
    _write_file(path, "  --verbose  \n  --output=file.txt  \n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "file.txt")
    _remove_file(path)


# ── Escape doubled prefix ───────────────────────────────────────────────────


fn test_response_file_escape_cli() raises:
    """@@literal on the CLI is treated as @literal (not a file)."""
    var command = _make_command()
    command.add_argument(Argument("user", help="User").positional())

    var args: List[String] = ["test", "@@admin"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("user"), "@admin")


fn test_response_file_escape_in_file() raises:
    """@@literal inside a response file is treated as @literal."""
    var path = "/tmp/_argmojo_test_rf_escape.txt"
    _write_file(path, "@@admin\n")

    var command = _make_command()
    command.add_argument(Argument("user", help="User").positional())

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("user"), "@admin")
    _remove_file(path)


# ── Recursive (nested) response files ───────────────────────────────────────


fn test_response_file_recursive() raises:
    """Response files can reference other response files."""
    var path1 = "/tmp/_argmojo_test_rf_r1.txt"
    var path2 = "/tmp/_argmojo_test_rf_r2.txt"
    _write_file(path1, "--verbose\n@" + path2 + "\n")
    _write_file(path2, "--output=nested.txt\n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "@" + path1]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "nested.txt")
    _remove_file(path1)
    _remove_file(path2)


# ── Error cases ──────────────────────────────────────────────────────────────


fn test_response_file_not_found() raises:
    """Error when response file does not exist."""
    var command = _make_command()

    var args: List[String] = ["test", "@/tmp/_argmojo_nonexistent_file.txt"]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "not found" in msg.lower() or "Response file" in msg,
            msg="error should mention file not found: " + msg,
        )
    assert_true(caught, msg="Should have raised for missing response file")


fn test_response_file_max_depth() raises:
    """Error when nesting depth exceeds the limit."""
    var path = "/tmp/_argmojo_test_rf_loop.txt"
    # File references itself — would loop forever without depth limit.
    _write_file(path, "@" + path + "\n")

    var command = _make_command()
    command.response_file_max_depth(3)

    var args: List[String] = ["test", "@" + path]
    var caught = False
    try:
        _ = command.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "too deep" in msg.lower() or "nesting" in msg.lower(),
            msg="error should mention nesting depth: " + msg,
        )
    assert_true(caught, msg="Should have raised for excessive nesting")
    _remove_file(path)


# ── Disabled by default ─────────────────────────────────────────────────────


fn test_response_file_disabled_by_default() raises:
    """Without response_file_prefix(), @token is treated as a regular positional.
    """
    var command = Command("test", "Test app")
    command.add_argument(Argument("item", help="Item").positional())

    var args: List[String] = ["test", "@foo.txt"]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("item"), "@foo.txt")


# ── Custom prefix ────────────────────────────────────────────────────────────


fn test_response_file_custom_prefix() raises:
    """A custom prefix (e.g. '+') can be used instead of '@'."""
    var path = "/tmp/_argmojo_test_rf_custom.txt"
    _write_file(path, "--verbose\n")

    var command = Command("test", "Test app")
    command.response_file_prefix("+")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )

    var args: List[String] = ["test", "+" + path]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    _remove_file(path)


# ── Multiple response files ─────────────────────────────────────────────────


fn test_response_file_multiple() raises:
    """Multiple @file arguments are all expanded."""
    var path1 = "/tmp/_argmojo_test_rf_m1.txt"
    var path2 = "/tmp/_argmojo_test_rf_m2.txt"
    _write_file(path1, "--verbose\n")
    _write_file(path2, "--output=multi.txt\n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "@" + path1, "@" + path2]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "multi.txt")
    _remove_file(path1)
    _remove_file(path2)


# ── Response file with short options ─────────────────────────────────────────


fn test_response_file_short_options() raises:
    """Response file can contain short options."""
    var path = "/tmp/_argmojo_test_rf_short.txt"
    _write_file(path, "-v\n-o\nfile.txt\n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    command.add_argument(
        Argument("output", help="Output").long("output").short("o")
    )

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.get_string("output"), "file.txt")
    _remove_file(path)


# ── Response file with values containing spaces ─────────────────────────────


fn test_response_file_value_one_per_line() raises:
    """Each line becomes one argument, allowing values with spaces within the line.
    """
    var path = "/tmp/_argmojo_test_rf_oneline.txt"
    _write_file(path, "--output=my file.txt\n")

    var command = _make_command()
    command.add_argument(Argument("output", help="Output").long("output"))

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_equal(result.get_string("output"), "my file.txt")
    _remove_file(path)


# ── Empty response file ─────────────────────────────────────────────────────


fn test_response_file_empty() raises:
    """Empty response file contributes no arguments."""
    var path = "/tmp/_argmojo_test_rf_empty.txt"
    _write_file(path, "")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )

    var args: List[String] = ["test", "@" + path]
    var result = command.parse_arguments(args)
    assert_false(result.has("verbose"))
    _remove_file(path)


# ── Response file preserves argv[0] ─────────────────────────────────────────


fn test_response_file_preserves_argv0() raises:
    """Tests argv[0] (program name) is never expanded even if it starts with @.
    """
    var path = "/tmp/_argmojo_test_rf_argv0.txt"
    _write_file(path, "--verbose\n")

    var command = _make_command()
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").flag()
    )
    command.add_argument(Argument("output", help="Output").long("output"))

    # Set argv[0] to a token starting with '@'.  Expansion must NOT
    # touch it — it should remain as the program name verbatim.
    var args: List[String] = ["@" + path, "--output=hello"]
    var result = command.parse_arguments(args)
    # --verbose comes from the file; if argv[0] were expanded, --verbose
    # would appear *before* argv[0] and be lost.  Assert it is NOT set.
    assert_false(result.has("verbose"), msg="argv[0] must not be expanded")
    assert_equal(result.get_string("output"), "hello")
    _remove_file(path)


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
