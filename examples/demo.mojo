"""Example: a mini CLI to demonstrate argmojo usage.

Showcases: positional args, flags, key-value options, choices,
count flags, hidden args, negatable flags, mutually exclusive groups,
and required-together groups.
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

    # ── Negatable flag ────────────────────────────────────────────────────
    # --color enables colour, --no-color disables it.
    cmd.add_arg(
        Arg("color", help="Enable colored output")
        .long("color")
        .flag()
        .negatable()
    )

    # ── Mutually exclusive group ─────────────────────────────────────────
    # Only one of --json / --yaml may be used at a time.
    cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
    cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
    var format_excl: List[String] = ["json", "yaml"]
    cmd.mutually_exclusive(format_excl^)

    # ── Hidden argument (internal / debug) ───────────────────────────────
    cmd.add_arg(
        Arg("debug-index", help="Dump internal index (debug only)")
        .long("debug-index")
        .flag()
        .hidden()
    )

    # ── Required-together group ──────────────────────────────────────────
    # --username and --password must both be provided, or neither.
    cmd.add_arg(Arg("username", help="Auth username").long("username").short("u"))
    cmd.add_arg(Arg("password", help="Auth password").long("password").short("p"))
    var auth_group: List[String] = ["username", "password"]
    cmd.required_together(auth_group^)

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
    if result.has("json") or result.has("yaml"):
        print("  --json:       ", result.get_flag("json"))
        print("  --yaml:       ", result.get_flag("yaml"))
    if result.has("max-depth"):
        print("  --max-depth:  ", result.get_string("max-depth"))
    else:
        print("  --max-depth:   (not set)")
    if result.get_flag("debug-index"):
        print("  [debug] index dump enabled")
    if result.has("username"):
        print("  --username:   ", result.get_string("username"))
        print("  --password:   ", result.get_string("password"))
