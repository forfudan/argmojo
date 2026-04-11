#!/usr/bin/env bash
# examples/build.sh — Build (with timing) and run argmojo examples.
#
# Called via pixi:
#   pixi run build            Build ALL examples, time each, run with --help
#   pixi run build <name>     Build one example, then run it with --help
#
# Can also be called directly:
#   ./examples/build.sh                  Build all
#   ./examples/build.sh mgit             Build & run mgit only
#   ./examples/build.sh --list           List available examples

set -eo pipefail
cd "$(dirname "$0")/.."

# ── Example registry (name  source  helparg) ────────────────────────────
#   helparg: argument(s) passed when running the binary after build.
#   Uses --help so examples with required positional args exit cleanly.
NAMES=(  mgrep   mgit   demo   yu   search   deploy   convert   jomo  )
SOURCES=(
    "examples/mgrep.mojo"
    "examples/mgit.mojo"
    "examples/demo.mojo"
    "examples/yu.mojo"
    "examples/declarative/search.mojo"
    "examples/declarative/deploy.mojo"
    "examples/declarative/convert.mojo"
    "examples/declarative/jomo.mojo"
)

resolve() {
    local i
    for i in "${!NAMES[@]}"; do
        if [ "${NAMES[$i]}" = "$1" ]; then
            echo "${SOURCES[$i]}"
            return 0
        fi
    done
    return 1
}

list_examples() {
    echo "Available examples:"
    local i
    for i in "${!NAMES[@]}"; do
        printf "  %-10s %s\n" "${NAMES[$i]}" "${SOURCES[$i]}"
    done
}

# ── Build + time one example ─────────────────────────────────────────────
#   build_one <name> <source>
#   Sets TIMES[name]=seconds
build_one() {
    local name="$1" src="$2"
    local t0 t1 elapsed
    t0=$(date +%s)
    mojo build -I src "$src" -o "$name"
    t1=$(date +%s)
    elapsed=$((t1 - t0))
    TIMES+=("$name:${elapsed}s")
}

# ── Run one example (--help) ─────────────────────────────────────────────
run_one() {
    local name="$1"
    echo ""
    echo "── ./$name --help ──"
    ./"$name" --help
}

# ── Print timing summary ─────────────────────────────────────────────────
print_summary() {
    echo ""
    echo "┌──────────────────────────────────────────┐"
    echo "│         Build time summary               │"
    echo "├────────────┬─────────────────────────────┤"
    printf "│ %-10s │ %-27s │\n" "Example" "Compile time"
    echo "├────────────┼─────────────────────────────┤"
    local entry
    for entry in "${TIMES[@]}"; do
        local n="${entry%%:*}"
        local t="${entry#*:}"
        printf "│ %-10s │ %27s │\n" "$n" "$t"
    done
    echo "└────────────┴─────────────────────────────┘"
}

# ═════════════════════════════════════════════════════════════════════════

TIMES=()

# ── --list ───────────────────────────────────────────────────────────────
if [ "${1:-}" = "--list" ]; then
    list_examples
    exit 0
fi

# ── Package first ────────────────────────────────────────────────────────
echo "Packaging argmojo..."
pixi run package
echo ""

# ── Single example ───────────────────────────────────────────────────────
if [ $# -ge 1 ]; then
    name="$1"
    src=$(resolve "$name" 2>/dev/null) || {
        echo "Error: unknown example '$name'" >&2
        list_examples >&2
        exit 1
    }
    echo "Building $name ($src)..."
    build_one "$name" "$src"
    run_one "$name"
    print_summary
    exit 0
fi

# ── All examples ─────────────────────────────────────────────────────────
echo "Building all examples..."
echo ""
for i in "${!NAMES[@]}"; do
    name="${NAMES[$i]}"
    src="${SOURCES[$i]}"
    echo "  [$((i+1))/${#NAMES[@]}] $name ($src)"
    build_one "$name" "$src"
done

echo ""
echo "Running all examples (--help)..."
for name in "${NAMES[@]}"; do
    run_one "$name"
done

print_summary