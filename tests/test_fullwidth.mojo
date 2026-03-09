"""Tests for argmojo — full-width → half-width auto-correction (Phase 6.2)."""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult
from argmojo.utils import (
    _correct_cjk_punctuation,
    _has_fullwidth_chars,
    _fullwidth_to_halfwidth,
    _split_on_fullwidth_spaces,
)


# U+3000 = IDEOGRAPHIC SPACE (fullwidth space)
# U+2003 = EM SPACE


# ── Unit tests for utility functions ─────────────────────────────────────────


fn test_has_fullwidth_chars_ascii() raises:
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


fn test_has_fullwidth_chars_cjk() raises:
    """Tests that CJK ideographs are NOT detected as fullwidth ASCII."""
    # CJK ideographs are NOT in the fullwidth ASCII range FF01-FF5E.
    assert_false(
        _has_fullwidth_chars("漢字"),
        msg="CJK ideographs are not fullwidth ASCII",
    )


fn test_has_fullwidth_chars_fullwidth_ascii() raises:
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


fn test_has_fullwidth_chars_fullwidth_space() raises:
    """Tests that fullwidth space U+3000 is detected."""
    var fw_space = chr(0x3000)
    assert_true(
        _has_fullwidth_chars("hello" + fw_space + "world"),
        msg="fullwidth space should be detected",
    )


fn test_has_fullwidth_chars_fullwidth_equals() raises:
    """Tests that fullwidth equals sign U+FF1D is detected."""
    assert_true(
        _has_fullwidth_chars("--key＝value"),
        msg="fullwidth equals should be detected",
    )


fn test_fullwidth_to_halfwidth_no_change() raises:
    """Tests that strings without fullwidth chars are unchanged."""
    assert_equal(
        _fullwidth_to_halfwidth("--verbose"),
        "--verbose",
    )
    assert_equal(
        _fullwidth_to_halfwidth("hello"),
        "hello",
    )


fn test_fullwidth_to_halfwidth_option() raises:
    """Tests fullwidth option name correction."""
    assert_equal(
        _fullwidth_to_halfwidth("－－ｖｅｒｂｏｓｅ"),
        "--verbose",
    )


fn test_fullwidth_to_halfwidth_short_option() raises:
    """Tests fullwidth short option correction."""
    assert_equal(
        _fullwidth_to_halfwidth("－ｖ"),
        "-v",
    )


fn test_fullwidth_to_halfwidth_equals() raises:
    """Tests fullwidth equals sign in --key=value."""
    assert_equal(
        _fullwidth_to_halfwidth("－－ｋｅｙ＝ｖａｌｕｅ"),
        "--key=value",
    )


fn test_fullwidth_to_halfwidth_space() raises:
    """Tests fullwidth space U+3000 conversion."""
    var fw_space = chr(0x3000)
    assert_equal(
        _fullwidth_to_halfwidth("hello" + fw_space + "world"),
        "hello world",
    )


fn test_fullwidth_to_halfwidth_mixed() raises:
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


fn test_split_on_fullwidth_spaces_no_spaces() raises:
    """Tests that tokens without fullwidth spaces return a single element."""
    var parts = _split_on_fullwidth_spaces("--verbose")
    assert_equal(len(parts), 1)
    assert_equal(parts[0], "--verbose")


fn test_split_on_fullwidth_spaces_with_spaces() raises:
    """Tests splitting on fullwidth spaces."""
    var fw_space = chr(0x3000)
    var token = "－－ｎａｍｅ" + fw_space + "ｙｕｈａｏ" + fw_space + "－－ｖｅｒｂｏｓｅ"
    var parts = _split_on_fullwidth_spaces(token)
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "--name")
    assert_equal(parts[1], "yuhao")
    assert_equal(parts[2], "--verbose")


# ── Unit tests for CJK punctuation correction ──────────────────────────────────


fn test_correct_cjk_punctuation_no_change() raises:
    """Tests that strings without CJK punctuation are unchanged."""
    assert_equal(_correct_cjk_punctuation("--verbose"), "--verbose")
    assert_equal(_correct_cjk_punctuation("hello"), "hello")


fn test_correct_cjk_punctuation_em_dash() raises:
    """Tests em-dash (U+2014) → hyphen-minus conversion."""
    # Two em-dashes + "verbose" should become "--verbose".
    var em_dash = chr(0x2014)
    assert_equal(
        _correct_cjk_punctuation(em_dash + em_dash + "verbose"),
        "--verbose",
    )


fn test_correct_cjk_punctuation_preserves_cjk() raises:
    """Tests that CJK ideographs are preserved."""
    assert_equal(_correct_cjk_punctuation("宇浩"), "宇浩")


# ── Integration tests: parsing with fullwidth correction ─────────────────────


fn test_fullwidth_long_flag() raises:
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


fn test_fullwidth_short_flag() raises:
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


fn test_fullwidth_key_value_equals() raises:
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


fn test_fullwidth_key_space_value() raises:
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


fn test_fullwidth_embedded_space() raises:
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


fn test_positional_fullwidth_converted() raises:
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


fn test_disable_fullwidth_correction() raises:
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


fn test_fullwidth_with_choices() raises:
    """Tests fullwidth correction combined with choices validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .short["f"]()
        .takes_value()
        .choices(["json", "yaml", "csv"])
    )

    var args: List[String] = ["test", "－－ｆｏｒｍａｔ＝ｊｓｏｎ"]
    var result = command.parse_arguments(args)
    assert_equal(
        result.get_string("format"),
        "json",
        msg="fullwidth --format=json should be corrected and validated",
    )


fn test_fullwidth_merged_short_flags() raises:
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


fn test_fullwidth_with_subcommand() raises:
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


fn test_fullwidth_parse_known_arguments() raises:
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


fn test_fullwidth_cjk_positional_preserved() raises:
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


fn test_fullwidth_punctuation_em_dash_correction() raises:
    """Tests that em-dash is auto-corrected to hyphen-minus in pre-parse."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    var em_dash = chr(0x2014)
    var args: List[String] = ["test", em_dash + em_dash + "verbose"]
    var result = command.parse_arguments(args)
    assert_true(
        result.get_flag("verbose"),
        msg="em-dash '——verbose' should be corrected to '--verbose'",
    )


fn test_fullwidth_punctuation_disabled() raises:
    """Tests that disable_punctuation_correction() prevents correction."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("verbose", help="Verbose output")
        .long["verbose"]()
        .short["v"]()
        .flag()
    )
    command.disable_punctuation_correction()
    var em_dash = chr(0x2014)
    var args: List[String] = ["test", em_dash + em_dash + "verbose"]
    var result = command.parse_arguments(args)
    assert_false(
        result.get_flag("verbose"),
        msg="With correction disabled, em-dash should NOT be corrected",
    )


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
