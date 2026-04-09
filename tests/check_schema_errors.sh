#!/bin/bash
# check_schema_errors.sh — verify that invalid schemas produce compile errors.
#
# Each test writes a small .mojo file that should FAIL to compile.
# If it compiles, the test fails (the schema check is missing).
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
    echo "$code" > "$file"

    if pixi run mojo run -I src "$file" 2>"$TMPDIR/${name}.err"; then
        echo "FAIL  $name — expected compile error but compilation succeeded"
        FAIL=$((FAIL + 1))
    else
        if grep -q "$expect_msg" "$TMPDIR/${name}.err"; then
            echo "PASS  $name"
            PASS=$((PASS + 1))
        else
            echo "FAIL  $name — compiled failed but error message not found:"
            echo "      expected: $expect_msg"
            echo "      got:      $(head -5 "$TMPDIR/${name}.err")"
            FAIL=$((FAIL + 1))
        fi
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

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
