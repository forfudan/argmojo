"""Example: a mini CLI to demonstrate argmojo usage.

Showcases: positional args, flags, key-value options, choices,
count flags, hidden args, and mutually exclusive groups.
"""

from argmojo import Arg, Command


fn main() raises:
    var cmd = Command(
        "sou",
        "A CJK-aware text search tool supporting Pinyin and Yuhao IME",
        version="0.1.0",
    )

    # ── Positional arguments ─────────────────────────────────────────────
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    # ── Boolean flags ────────────────────────────────────────────────────
    cmd.add_arg(
        Arg("ling", help="Use Lingming IME for encoding")
        .long("ling")
        .short("l")
        .flag()
    )
    cmd.add_arg(
        Arg("ignore-case", help="Case-insensitive search")
        .long("ignore-case")
        .short("i")
        .flag()
    )

    # ── Count flag (verbosity) ───────────────────────────────────────────
    # Use -v, -vv, -vvv or --verbose --verbose to increase verbosity.
    cmd.add_arg(
        Arg("verbose", help="Increase verbosity (-v, -vv, -vvv)")
        .long("verbose")
        .short("v")
        .count()
    )

    # ── Key-value option with metavar ────────────────────────────────────
    cmd.add_arg(
        Arg("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
        .metavar("N")
    )

    # ── Choices validation ───────────────────────────────────────────────
    var formats: List[String] = ["json", "csv", "table"]
    cmd.add_arg(
        Arg("format", help="Output format")
        .long("format")
        .short("f")
        .choices(formats^)
        .default("table")
    )

    # ── Mutually exclusive group ─────────────────────────────────────────
    # Only one of --color / --no-color may be used at a time.
    cmd.add_arg(
        Arg("color", help="Force colored output")
        .long("color")
        .flag()
    )
    cmd.add_arg(
        Arg("no-color", help="Disable colored output")
        .long("no-color")
        .flag()
    )
    var color_group: List[String] = ["color", "no-color"]
    cmd.mutually_exclusive(color_group^)

    # ── Hidden argument (internal / debug) ───────────────────────────────
    cmd.add_arg(
        Arg("debug-index", help="Dump internal index (debug only)")
        .long("debug-index")
        .flag()
        .hidden()
    )

    # ── Parse real argv ──────────────────────────────────────────────────
    var result = cmd.parse()

    # ── Display parsed results ───────────────────────────────────────────
    print("=== Parsed Arguments ===")
    print("  pattern:      ", result.get_string("pattern"))
    print("  path:         ", result.get_string("path"))
    print("  --ling:       ", result.get_flag("ling"))
    print("  --ignore-case:", result.get_flag("ignore-case"))
    print("  --verbose:    ", result.get_count("verbose"))
    print("  --format:     ", result.get_string("format"))
    print("  --color:      ", result.get_flag("color"))
    print("  --no-color:   ", result.get_flag("no-color"))
    if result.has("max-depth"):
        print("  --max-depth:  ", result.get_string("max-depth"))
    else:
        print("  --max-depth:   (not set)")
    if result.get_flag("debug-index"):
        print("  [debug] index dump enabled")
