#!/bin/bash
# check_schema_errors.sh — verify that invalid schemas produce compile errors.
#
# Each test writes a small .mojo file that should FAIL to compile.
# If it compiles, the test fails (the schema check is missing).
# A second group checks that deprecated APIs still compile and run, and that
# they emit their deprecation warning.
#
# Usage:  bash tests/check_schema_errors.sh

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

check_compile_error() {
    local name="$1"
    local code="$2"
    local expect_msg="$3"

    local file="$TMPDIR/${name}.mojo"
    printf '%s\n' "$code" > "$file"

    if pixi run mojo run -I src "$file" 2>"$TMPDIR/${name}.err"; then
        echo "FAIL  $name — expected compile error but compilation succeeded"
        FAIL=$((FAIL + 1))
    else
        if grep -q "$expect_msg" "$TMPDIR/${name}.err"; then
            echo "PASS  $name"
            PASS=$((PASS + 1))
        else
            echo "FAIL  $name — compilation failed but error message not found:"
            echo "      expected: $expect_msg"
            echo "      got:      $(head -5 "$TMPDIR/${name}.err")"
            FAIL=$((FAIL + 1))
        fi
    fi
}

# Compiles and runs code that must SUCCEED while emitting a compiler warning.
# Used for deprecated APIs, which cannot be called from the regular test files
# without breaking their warning-free build.
check_compile_warning() {
    local name="$1"
    local code="$2"
    local expect_warning="$3"
    local expect_output="$4"

    local file="$TMPDIR/${name}.mojo"
    printf '%s\n' "$code" > "$file"

    if ! pixi run mojo run -I src "$file" >"$TMPDIR/${name}.out" 2>"$TMPDIR/${name}.err"; then
        echo "FAIL  $name — expected successful compilation and run:"
        echo "      got:      $(head -5 "$TMPDIR/${name}.err")"
        FAIL=$((FAIL + 1))
    elif ! grep -qF "$expect_warning" "$TMPDIR/${name}.err"; then
        echo "FAIL  $name — expected warning not found:"
        echo "      expected: $expect_warning"
        FAIL=$((FAIL + 1))
    elif ! grep -qxF "$expect_output" "$TMPDIR/${name}.out"; then
        echo "FAIL  $name — unexpected program output:"
        echo "      expected: $expect_output"
        echo "      got:      $(head -5 "$TMPDIR/${name}.out")"
        FAIL=$((FAIL + 1))
    else
        echo "PASS  $name"
        PASS=$((PASS + 1))
    fi
}

echo "=== Compile-time schema validation negative tests ==="
echo

# 1. Short flag too long (Option)
check_compile_error "option_short_too_long" '
from argmojo import Parsable, Option
struct Bad(Parsable):
    var x: Option[String, short="abc"]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "short flag must be exactly 1 character"

# 2. Short flag too long (Flag)
check_compile_error "flag_short_too_long" '
from argmojo import Parsable, Flag
struct Bad(Parsable):
    var x: Flag[short="vv"]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "short flag must be exactly 1 character"

# 3. Short flag too long (Count)
check_compile_error "count_short_too_long" '
from argmojo import Parsable, Count
struct Bad(Parsable):
    var x: Count[short="dd"]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "short flag must be exactly 1 character"

# 4. Default not in choices (Option)
check_compile_error "option_default_not_in_choices" '
from argmojo import Parsable, Option
struct Bad(Parsable):
    var fmt: Option[String, choices="json,yaml,csv", default="xml"]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "not in choices"

# 5. Default not in choices (Positional)
check_compile_error "positional_default_not_in_choices" '
from argmojo import Parsable, Positional
struct Bad(Parsable):
    var action: Positional[String, choices="start,stop", default="restart"]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "not in choices"

# 6. Range min > max (Option)
check_compile_error "option_range_inverted" '
from argmojo import Parsable, Option
struct Bad(Parsable):
    var port: Option[Int, has_range=True, range_min=100, range_max=10]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "range_min must be <= range_max"

# 7. Range min > max (Positional)
check_compile_error "positional_range_inverted" '
from argmojo import Parsable, Positional
struct Bad(Parsable):
    var level: Positional[Int, has_range=True, range_min=100, range_max=10]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "range_min must be <= range_max"

# 8. Range validation is integer-only, so Float64 + has_range is refused.
check_compile_error "option_float_range" '
from argmojo import Parsable, Option
struct Bad(Parsable):
    var ratio: Option[Float64, has_range=True, range_min=0, range_max=10]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "range validation is integer-only"

# 9. Same, for Positional.
check_compile_error "positional_float_range" '
from argmojo import Parsable, Positional
struct Bad(Parsable):
    var scale: Positional[Float64, has_range=True, range_min=0, range_max=10]
    @staticmethod
    def description() -> String:
        return String("bad")
def main() raises:
    _ = Bad.to_command()
' "range validation is integer-only"

echo
echo "=== Deprecated APIs: still work, but warn ==="
echo

# 10. .alias_name[]() forwards to .alias[]() and warns at compile time.
check_compile_warning "builder_alias_name_deprecated" '
from argmojo import Argument, Command
def main() raises:
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("colour", help="Colour mode")
        .long["colour"]()
        .alias_name["color"]()
    )
    var result = command.parse_arguments(["test", "--color", "red"])
    print("colour=" + result.get_string("colour"))
' '`.alias_name[]()` is renamed to `.alias[]()`' "colour=red"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
