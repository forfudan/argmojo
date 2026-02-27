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

from argmojo import Argument, Command


fn main() raises:
    var command = Command(
        "sou",
        (
            "A CJK-aware text search tool that supports Pinyin and Yuhao Input"
            " Methods."
        ),
        version="0.1.0",
    )

    # ── Positional arguments ─────────────────────────────────────────────
    command.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    command.add_argument(
        Argument("path", help="Search path").positional().default(".")
    )

    # ── Boolean flags ────────────────────────────────────────────────────
    command.add_argument(
        Argument("ling", help="Use Lingming IME (靈明輸入法) for encoding")
        .long("ling")
        .short("l")
        .flag()
    )
    command.add_argument(
        Argument("ignore-case", help="Case-insensitive search")
        .long("ignore-case")
        .short("i")
        .flag()
    )

    # ── Count flag (verbosity) ───────────────────────────────────────────
    # Use -v, -vv, -vvv or --verbose --verbose to increase verbosity.
    command.add_argument(
        Argument("verbose", help="Increase verbosity (-v, -vv, -vvv)")
        .long("verbose")
        .short("v")
        .count()
    )

    # ── Key-value option with metavar ────────────────────────────────────
    command.add_argument(
        Argument("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
        .metavar("N")
        .range(1, 100)  # Numeric range validation
    )

    # ── Choices validation ───────────────────────────────────────────────
    var formats: List[String] = ["json", "csv", "table"]
    command.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(formats^)
        .default("table")
    )

    # ── Negatable flag ────────────────────────────────────────────────────
    # --color enables colour, --no-color disables it.
    command.add_argument(
        Argument("color", help="Enable colored output")
        .long("color")
        .flag()
        .negatable()
    )

    # ── Mutually exclusive + one-required group ────────────────────────
    # Only one of --json / --yaml / --xml may be used,
    # but at least one is required.
    command.add_argument(
        Argument("json", help="Output as JSON").long("json").flag()
    )
    command.add_argument(
        Argument("yaml", help="Output as YAML").long("yaml").flag()
    )
    command.add_argument(
        Argument("xml", help="Output as XML").long("xml").flag()
    )
    var format_excl: List[String] = ["json", "yaml", "xml"]
    var format_req: List[String] = ["json", "yaml", "xml"]
    command.mutually_exclusive(format_excl^)
    command.one_required(format_req^)

    # ── Hidden argument (internal / debug) ───────────────────────────────
    command.add_argument(
        Argument("debug-index", help="Dump internal index (debug only)")
        .long("debug-index")
        .flag()
        .hidden()
    )

    # ── Append / collect action ──────────────────────────────────────────
    # --tag can be used multiple times; values are collected into a list.
    command.add_argument(
        Argument("tag", help="Add a tag (repeatable)")
        .long("tag")
        .short("t")
        .append()
    )

    # ── Value delimiter ──────────────────────────────────────────────────
    # --env accepts comma-separated values; each is split and collected.
    command.add_argument(
        Argument("env", help="Target environments (comma-separated)")
        .long("env")
        .short("e")
        .delimiter(",")
    )

    # ── Multi-value option (nargs) ───────────────────────────────────────
    # --point consumes exactly 2 values per occurrence (X Y coordinates).
    command.add_argument(
        Argument("point", help="X Y coordinate")
        .long("point")
        .short("P")
        .nargs(2)
        .metavar("N")
    )

    # ── Required-together group ──────────────────────────────────────────
    # --username and --password must both be provided, or neither.
    command.add_argument(
        Argument("username", help="Auth username").long("username").short("u")
    )
    command.add_argument(
        Argument("password", help="Auth password").long("password").short("p")
    )
    var auth_group: List[String] = ["username", "password"]
    command.required_together(auth_group^)

    # ── Conditional requirement ──────────────────────────────────────────
    # --output is required only when --save is provided.
    command.add_argument(
        Argument("save", help="Save search results to file")
        .long("save")
        .short("S")
        .flag()
    )
    command.add_argument(
        Argument("output", help="Output file path (required with --save)")
        .long("output")
        .short("O")
        .metavar("FILE")
    )
    command.required_if("output", "save")

    # ── Numeric range validation ─────────────────────────────────────────
    # --port only accepts values between 1 and 65535.
    command.add_argument(
        Argument("port", help="Listening port")
        .long("port")
        .range(1, 65535)
        .metavar("PORT")
    )

    # ── Key-value map option ─────────────────────────────────────────────
    # --define / -D collects key=value pairs into a dictionary.
    command.add_argument(
        Argument("define", help="Define a variable (key=value)")
        .long("define")
        .short("D")
        .map_option()
    )

    # ── Aliases ──────────────────────────────────────────────────────────
    # --colour and --color both resolve to the same argument.
    var colour_aliases: List[String] = ["color"]
    command.add_argument(
        Argument("colour", help="Colour theme")
        .long("colour")
        .aliases(colour_aliases^)
        .default("auto")
    )

    # ── Deprecated argument ──────────────────────────────────────────────
    # --format-old still works but emits a warning on stderr.
    command.add_argument(
        Argument("formatting", help="Legacy output format")
        .long("formatting")
        .deprecated("Use --format instead")
    )

    # ── Show tips ───────────────────────────────────────
    command.add_tip("Expressions starting with `-` are accepted.")
    command.add_tip("Use quotes if you use spaces in expressions.")

    # ── Show help when invoked with no arguments ─────────────────────────
    command.help_on_no_args()

    # ── Parse real argv ──────────────────────────────────────────────────
    var result = command.parse()

    # ── Display parsed results ───────────────────────────────────────────
    command.print_summary(result)
