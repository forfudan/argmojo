"""Example: a mini CLI to demonstrate argmojo usage.

Showcases: positional args, flags, key-value options, choices,
count flags, hidden args, negatable flags, mutually exclusive groups,
required-together groups, long option prefix matching, append/collect,
one-required groups, value delimiter, multi-value options (nargs),
conditional requirements, numeric range validation, key-value map options,
aliases, and deprecated arguments.

Long option prefix matching allows abbreviated options:
  --verb  → --verbose
  --ling  → --ling      (exact match)
  --max   → --max-depth (unambiguous prefix)
"""

from argmojo import Arg, Command


fn main() raises:
    var cmd = Command(
        "sou",
        (
            "A CJK-aware text search tool that supports Pinyin and Yuhao Input"
            " Methods."
        ),
        version="0.1.0",
    )

    # ── Positional arguments ─────────────────────────────────────────────
    cmd.add_arg(Arg("pattern", help="Search pattern").positional().required())
    cmd.add_arg(Arg("path", help="Search path").positional().default("."))

    # ── Boolean flags ────────────────────────────────────────────────────
    cmd.add_arg(
        Arg("ling", help="Use Lingming IME (靈明輸入法) for encoding")
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
        .range(1, 100)  # Numeric range validation
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

    # ── Mutually exclusive + one-required group ────────────────────────
    # Only one of --json / --yaml / --xml may be used,
    # but at least one is required.
    cmd.add_arg(Arg("json", help="Output as JSON").long("json").flag())
    cmd.add_arg(Arg("yaml", help="Output as YAML").long("yaml").flag())
    cmd.add_arg(Arg("xml", help="Output as XML").long("xml").flag())
    var format_excl: List[String] = ["json", "yaml", "xml"]
    var format_req: List[String] = ["json", "yaml", "xml"]
    cmd.mutually_exclusive(format_excl^)
    cmd.one_required(format_req^)

    # ── Hidden argument (internal / debug) ───────────────────────────────
    cmd.add_arg(
        Arg("debug-index", help="Dump internal index (debug only)")
        .long("debug-index")
        .flag()
        .hidden()
    )

    # ── Append / collect action ──────────────────────────────────────────
    # --tag can be used multiple times; values are collected into a list.
    cmd.add_arg(
        Arg("tag", help="Add a tag (repeatable)")
        .long("tag")
        .short("t")
        .append()
    )

    # ── Value delimiter ──────────────────────────────────────────────────
    # --env accepts comma-separated values; each is split and collected.
    cmd.add_arg(
        Arg("env", help="Target environments (comma-separated)")
        .long("env")
        .short("e")
        .delimiter(",")
    )

    # ── Multi-value option (nargs) ───────────────────────────────────────
    # --point consumes exactly 2 values per occurrence (X Y coordinates).
    cmd.add_arg(
        Arg("point", help="X Y coordinate")
        .long("point")
        .short("P")
        .nargs(2)
        .metavar("N")
    )

    # ── Required-together group ──────────────────────────────────────────
    # --username and --password must both be provided, or neither.
    cmd.add_arg(
        Arg("username", help="Auth username").long("username").short("u")
    )
    cmd.add_arg(
        Arg("password", help="Auth password").long("password").short("p")
    )
    var auth_group: List[String] = ["username", "password"]
    cmd.required_together(auth_group^)

    # ── Conditional requirement ──────────────────────────────────────────
    # --output is required only when --save is provided.
    cmd.add_arg(
        Arg("save", help="Save search results to file")
        .long("save")
        .short("S")
        .flag()
    )
    cmd.add_arg(
        Arg("output", help="Output file path (required with --save)")
        .long("output")
        .short("O")
        .metavar("FILE")
    )
    cmd.required_if("output", "save")

    # ── Numeric range validation ─────────────────────────────────────────
    # --port only accepts values between 1 and 65535.
    cmd.add_arg(
        Arg("port", help="Listening port")
        .long("port")
        .range(1, 65535)
        .metavar("PORT")
    )

    # ── Key-value map option ─────────────────────────────────────────────
    # --define / -D collects key=value pairs into a dictionary.
    cmd.add_arg(
        Arg("define", help="Define a variable (key=value)")
        .long("define")
        .short("D")
        .map_option()
    )

    # ── Aliases ──────────────────────────────────────────────────────────
    # --colour and --color both resolve to the same argument.
    var colour_aliases: List[String] = ["color"]
    cmd.add_arg(
        Arg("colour", help="Colour theme")
        .long("colour")
        .aliases(colour_aliases^)
        .default("auto")
    )

    # ── Deprecated argument ──────────────────────────────────────────────
    # --format-old still works but emits a warning on stderr.
    cmd.add_arg(
        Arg("formatting", help="Legacy output format")
        .long("formatting")
        .deprecated("Use --format instead")
    )

    # ── Show help when invoked with no arguments ─────────────────────────
    cmd.help_on_no_args()

    # ── Parse real argv ──────────────────────────────────────────────────
    var result = cmd.parse()

    # ── Display parsed results ───────────────────────────────────────────
    cmd.print_summary(result)
