"""Tests for declarative wrapper types: Option, Flag, Positional, Count.

Verifies default initialization, copy/move semantics, and Flag.__bool__().
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite
from argmojo import Option, Flag, Positional, Count


# ── Option defaults ──────────────────────────────────────────────────────────


def test_option_string_default() raises:
    """Option[String] defaults to empty string."""
    var opt = Option[String, long="output", short="o", help="Output file"]()
    assert_equal(opt.value, "")


def test_option_int_default() raises:
    """Option[Int] defaults to 0."""
    var opt = Option[Int, long="port", help="Port number"]()
    assert_equal(opt.value, 0)


def test_option_string_copy() raises:
    """Option[String] copy preserves value."""
    var a = Option[String, long="name"]()
    a.value = String("hello")
    var b = Option[String, long="name"](copy=a)
    assert_equal(b.value, "hello")
    assert_equal(a.value, "hello")


def test_option_int_copy() raises:
    """Option[Int] copy preserves value."""
    var a = Option[Int, long="count"]()
    a.value = 42
    var b = Option[Int, long="count"](copy=a)
    assert_equal(b.value, 42)


def test_option_move() raises:
    """Option[String] move transfers ownership."""
    var a = Option[String, long="path"]()
    a.value = String("moved")
    var b = Option[String, long="path"](take=a^)
    assert_equal(b.value, "moved")


# ── Flag defaults & bool ─────────────────────────────────────────────────────


def test_flag_default_false() raises:
    """Flag defaults to False."""
    var f = Flag[short="v", help="Verbose"]()
    assert_false(f.value)
    assert_false(f.__bool__())


def test_flag_init_true() raises:
    """Flag can be initialised to True."""
    var f = Flag[long="color"](True)
    assert_true(f.value)
    assert_true(f.__bool__())


def test_flag_bool_conversion() raises:
    """Flag.__bool__() enables `if flag:` syntax."""
    var f = Flag[long="debug"]()
    assert_false(f.__bool__())
    f.value = True
    assert_true(f.__bool__())


def test_flag_copy() raises:
    """Flag copy preserves value."""
    var a = Flag[short="f"](True)
    var b = Flag[short="f"](copy=a)
    assert_true(b.value)
    assert_true(a.value)


def test_flag_move() raises:
    """Flag move transfers ownership."""
    var a = Flag[long="force"](True)
    var b = Flag[long="force"](take=a^)
    assert_true(b.value)


# ── Positional defaults ──────────────────────────────────────────────────────


def test_positional_string_default() raises:
    """Positional[String] defaults to empty string."""
    var p = Positional[String, help="Input file"]()
    assert_equal(p.value, "")


def test_positional_int_default() raises:
    """Positional[Int] defaults to 0."""
    var p = Positional[Int, help="Count"]()
    assert_equal(p.value, 0)


def test_positional_copy() raises:
    """Positional[String] copy preserves value."""
    var a = Positional[String, help="Path"]()
    a.value = String("test.txt")
    var b = Positional[String, help="Path"](copy=a)
    assert_equal(b.value, "test.txt")
    assert_equal(a.value, "test.txt")


def test_positional_move() raises:
    """Positional[String] move transfers ownership."""
    var a = Positional[String, help="Path"]()
    a.value = String("foo.txt")
    var b = Positional[String, help="Path"](take=a^)
    assert_equal(b.value, "foo.txt")


# ── Count defaults ───────────────────────────────────────────────────────────


def test_count_default_zero() raises:
    """Count defaults to 0."""
    var c = Count[short="v", help="Verbosity"]()
    assert_equal(c.value, 0)


def test_count_init_value() raises:
    """Count can be initialised with an explicit value."""
    var c = Count[short="d", help="Debug level"](3)
    assert_equal(c.value, 3)


def test_count_copy() raises:
    """Count copy preserves value."""
    var a = Count[short="v"](5)
    var b = Count[short="v"](copy=a)
    assert_equal(b.value, 5)
    assert_equal(a.value, 5)


def test_count_move() raises:
    """Count move transfers ownership."""
    var a = Count[long="debug"](7)
    var b = Count[long="debug"](take=a^)
    assert_equal(b.value, 7)


# ── Entry point ──────────────────────────────────────────────────────────────


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
