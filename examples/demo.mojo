"""Example: a full CLI to demonstrate argmojo usage with subcommands.

Showcases: subcommands, persistent (global) flags, per-command arguments,
positional args, flags, key-value options, choices, count flags, hidden
args, negatable flags, mutually exclusive groups, required-together groups,
long option prefix matching, append/collect, one-required groups, value
delimiter, multi-value options (nargs), conditional requirements, numeric
range validation, key-value map options, aliases, deprecated arguments,
custom tips, Commands section in help, Global Options heading, full
command path in child help/errors, and unknown subcommand error.

Try these:
  demo --help                   # root help (Commands + Global Options)
  demo search --help            # child help (full path + inherited globals)
  demo -vv search --ling "fn main" ./src
  demo init my-project --template minimal
  demo export --json --save --output out.txt
"""

from argmojo import Argument, Command


fn main() raises:
    var app = Command(
        "demo",
        (
            "A CJK-aware text search tool that supports Pinyin and Yuhao Input"
            " Methods."
        ),
        version="0.2.0",
    )

    # ── Persistent (global) flags ────────────────────────────────────────
    # These are available on ALL subcommands and can appear before or after
    # the subcommand token.  In the help output they appear under a
    # separate "Global Options:" heading.
    app.add_argument(
        Argument("verbose", help="Increase verbosity (-v, -vv, -vvv)")
        .long("verbose")
        .short("v")
        .count()
        .persistent()
    )
    app.add_argument(
        Argument("color", help="Enable colored output")
        .long("color")
        .flag()
        .negatable()
        .persistent()
    )

    # ── Custom tips ───────────────────────────────────────────────────────────
    app.add_tip("Expressions starting with `-` are accepted as positionals.")
    app.add_tip("Use quotes if you use spaces in expressions.")

    # ── search subcommand ─────────────────────────────────────────────────────
    var search = Command("search", "Search for patterns in source files")

    # Positional arguments
    search.add_argument(
        Argument("pattern", help="Search pattern").positional().required()
    )
    search.add_argument(
        Argument("path", help="Search path").positional().default(".")
    )

    # Boolean flags
    search.add_argument(
        Argument("ling", help="Use Lingming IME (靈明輸入法) for encoding")
        .long("ling")
        .short("l")
        .flag()
    )
    search.add_argument(
        Argument("ignore-case", help="Case-insensitive search")
        .long("ignore-case")
        .short("i")
        .flag()
    )

    # Key-value option with metavar + numeric range
    search.add_argument(
        Argument("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
        .metavar("N")
        .range(1, 100)
    )

    # Choices validation
    var formats: List[String] = ["json", "csv", "table"]
    search.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(formats^)
        .default("table")
    )

    # Append / collect action
    search.add_argument(
        Argument("tag", help="Add a tag (repeatable)")
        .long("tag")
        .short("t")
        .append()
    )

    # Value delimiter
    search.add_argument(
        Argument("env", help="Target environments (comma-separated)")
        .long("env")
        .short("e")
        .delimiter(",")
    )

    # Hidden argument (internal / debug)
    search.add_argument(
        Argument("debug-index", help="Dump internal index (debug only)")
        .long("debug-index")
        .flag()
        .hidden()
    )

    app.add_subcommand(search^)

    # ── init subcommand ──────────────────────────────────────────────────
    var init = Command("init", "Initialise a new project from a template")
    init.add_argument(
        Argument("name", help="Project name").positional().required()
    )

    var templates: List[String] = ["default", "minimal", "full"]
    init.add_argument(
        Argument("template", help="Template name")
        .long("template")
        .short("t")
        .choices(templates^)
        .default("default")
    )
    init.add_argument(
        Argument("dry-run", help="Preview changes without writing files")
        .long("dry-run")
        .flag()
    )

    # Required-together group
    init.add_argument(
        Argument("username", help="Auth username").long("username").short("u")
    )
    init.add_argument(
        Argument("password", help="Auth password").long("password").short("p")
    )
    var auth_group: List[String] = ["username", "password"]
    init.required_together(auth_group^)

    app.add_subcommand(init^)

    # ── export subcommand ────────────────────────────────────────────────
    var export_cmd = Command("export", "Export search results to a file")

    # Mutually exclusive + one-required (exactly-one pattern)
    export_cmd.add_argument(
        Argument("json", help="Output as JSON").long("json").flag()
    )
    export_cmd.add_argument(
        Argument("yaml", help="Output as YAML").long("yaml").flag()
    )
    export_cmd.add_argument(
        Argument("xml", help="Output as XML").long("xml").flag()
    )
    var excl: List[String] = ["json", "yaml", "xml"]
    var req: List[String] = ["json", "yaml", "xml"]
    export_cmd.mutually_exclusive(excl^)
    export_cmd.one_required(req^)

    # Conditional requirement
    export_cmd.add_argument(
        Argument("save", help="Save results to file")
        .long("save")
        .short("S")
        .flag()
    )
    export_cmd.add_argument(
        Argument("output", help="Output file (required with --save)")
        .long("output")
        .short("O")
        .metavar("FILE")
    )
    export_cmd.required_if("output", "save")

    # Key-value map option
    export_cmd.add_argument(
        Argument("define", help="Define a variable (key=value)")
        .long("define")
        .short("D")
        .map_option()
    )

    # Multi-value option (nargs)
    export_cmd.add_argument(
        Argument("point", help="X Y coordinate")
        .long("point")
        .short("P")
        .nargs(2)
        .metavar("N")
    )

    # Aliases
    var colour_aliases: List[String] = ["color"]
    export_cmd.add_argument(
        Argument("colour", help="Colour theme")
        .long("colour")
        .aliases(colour_aliases^)
        .default("auto")
    )

    # Deprecated argument
    export_cmd.add_argument(
        Argument("formatting", help="Legacy output format")
        .long("formatting")
        .deprecated("Use --json/--yaml/--xml instead")
    )

    # Numeric range validation
    export_cmd.add_argument(
        Argument("port", help="Listening port")
        .long("port")
        .range(1, 65535)
        .metavar("PORT")
    )

    app.add_subcommand(export_cmd^)

    # ── Show help when invoked with no arguments ─────────────────────────
    app.help_on_no_args()

    # ── Parse real argv ──────────────────────────────────────────────────
    var result = app.parse()

    # ── Display parsed results ───────────────────────────────────────────
    app.print_summary(result)
