"""Example: a feature showcase to demonstrate argmojo capabilities.

This demo is designed to cover features NOT shown in mgrep.mojo (single-
command) or mgit.mojo (subcommand-based), and to make it easy to try
them interactively from the command line.

Showcases: count ceiling (.count().max(N)), range clamping (.range().clamp()),
one-required groups, mutually exclusive groups, required-together groups,
conditional requirements, negatable flags, color customisation
(header_color, argument_color), numeric range validation, append with range
clamping, value delimiter, nargs, key-value map, aliases, deprecated args,
negative number passthrough, allow_positional_with_subcommands, custom tips,
help_on_no_arguments, default_if_no_value, require_equals, response files,
remainder positionals, allow_hyphen_values, parse_known_arguments,
argument groups in help (.group()), value_name wrapping control
(.value_name["NAME"]() or .value_name["NAME", False]()), and interactive
prompting (.prompt(), .prompt["..."]()).

Note: This demo looks very strange, but useful :D

Try these (build first with: pixi run package && mojo build -I src -o demo examples/demo.mojo):

  # ── Root command ─────────────────────────────────────────────────────
  ./demo --help
  ./demo --version

  # count ceiling: -vvvvv caps at 3
  ./demo input.txt -vvvvv
  ./demo input.txt -vv

  # range clamping: --level 20 clamps to 9; --level -5 clamps to 0
  ./demo input.txt --level 20
  ./demo input.txt --level -5
  ./demo input.txt --level 5

  # negatable flag: --color / --no-color
  ./demo input.txt --color
  ./demo input.txt --no-color

  # required-together: --host and --port must appear together
  ./demo input.txt --host localhost --port 8080
  ./demo input.txt --host localhost           # error: --port required

  # conditional requirement: --output required when --save is set
  ./demo input.txt --save --output results.json
  ./demo input.txt --save                     # error: --output required

  # append with range clamping: each --port value clamped to [1, 65535]
  ./demo input.txt --host localhost --port 80 --port 99999

  # nargs: --point takes exactly 3 values (x y z)
  ./demo input.txt --point 1.0 2.5 3.7

  # value delimiter: --tags a,b,c splits by comma
  ./demo input.txt --tags feat,fix,docs

  # key-value map: -D key=value (repeatable)
  ./demo input.txt -D env=prod -D region=us-east

  # aliases: --colour is an alias for --color-theme
  ./demo input.txt --colour monokai
  ./demo input.txt --color-theme dracula

  # deprecated argument: --legacy prints a warning
  ./demo input.txt --legacy

  # default_if_no_value: --compress alone uses "gzip"
  ./demo input.txt --compress
  ./demo input.txt --compress=bzip2
  ./demo input.txt -c
  ./demo input.txt -cbzip2

  # require equals: --separator=X only, --separator X is rejected
  ./demo input.txt --separator="|"
  ./demo input.txt --separator "|"            # error: requires '=' syntax

  # response file: put arguments in a file and reference with @
  echo '--verbose\n--level=5\n--color' > /tmp/demo_args.txt
  ./demo input.txt @/tmp/demo_args.txt

  # negative number passthrough
  ./demo -- -42

  # kitchen sink
  ./demo input.txt -vvvvv --level 20 --color --host 127.0.0.1 --port 80 --port 443 --point 1 2 3 --tags a,b,c -D x=1 -D y=2

  # ── Subcommand: export (one-required + mutually exclusive) ───────────
  ./demo export --help
  ./demo export data.csv --json               # ok
  ./demo export data.csv --json --yaml        # error: mutually exclusive
  ./demo export data.csv                      # error: one of --json/--yaml/--toml required

  # ── Subcommand: analyze (range clamping on subcommand) ───────────────
  ./demo analyze --help
  ./demo analyze data.csv --workers 4 --threshold 95
  ./demo analyze data.csv --workers 999       # clamped to 32

  # ── Subcommand: run (remainder + allow_hyphen_values) ────────────────
  ./demo run myapp --verbose -x --output=foo.txt
  ./demo run -                                # stdin convention via allow_hyphen_values
  ./demo run myapp                            # no extra args → empty remainder

  # ── Subcommand: login (interactive prompting) ────────────────────────
  ./demo login                                # prompts for user, token, and pin
  ./demo login --user alice --token s --pin 1 # no prompts needed
  ./demo login --user alice                   # prompts for token (hidden) and pin (****)
"""

from argmojo import Argument, Command


def main() raises:
    var app = Command(
        "demo",
        (
            "ArgMojo feature showcase — demonstrates capabilities not covered"
            " by mgrep or mgit."
        ),
        version="0.3.0",
    )

    # ── Color customisation ──────────────────────────────────────────────
    app.header_color["CYAN"]()
    app.argument_color["GREEN"]()

    # ── Response file support ────────────────────────────────────────────
    app.response_file_prefix()  # enables @args.txt expansion

    # ── Positional arguments ─────────────────────────────────────────────
    app.add_argument(
        Argument("input", help="Input file to process")
        .positional()
        .default["stdin"]()
    )

    # ── Count flag with ceiling ──────────────────────────────────────────
    # -vvvvv caps at 3; emits a warning when exceeded.
    app.add_argument(
        Argument("verbose", help="Increase verbosity (capped at 3)")
        .long["verbose"]()
        .short["v"]()
        .count()
        .max[3]()
    )

    # ── Numeric range with clamping ──────────────────────────────────────
    # --level 20 → clamped to 9 with a warning; --level -5 → clamped to 0.
    app.add_argument(
        Argument("level", help="Processing level [0–9]")
        .long["level"]()
        .short["l"]()
        .range[0, 9]()
        .clamp()
    )

    # ── Negatable flag ───────────────────────────────────────────────────
    app.add_argument(
        Argument("color", help="Enable colored output")
        .long["color"]()
        .flag()
        .negatable()
    )

    # ── Required-together group ──────────────────────────────────────────
    # --host and --port must both appear or both be absent.
    app.add_argument(
        Argument("host", help="Server hostname")
        .long["host"]()
        .short["H"]()
        .value_name["ADDR"]()
        .group["Network"]()
    )
    app.add_argument(
        Argument(
            "port", help="Server port(s), repeatable, clamped to [1, 65535]"
        )
        .long["port"]()
        .short["P"]()
        .append()
        .range[1, 65535]()
        .clamp()
        .group["Network"]()
    )
    var net_group: List[String] = ["host", "port"]
    app.required_together(net_group^)

    # ── Conditional requirement ──────────────────────────────────────────
    # --output is required when --save is present.
    app.add_argument(
        Argument("save", help="Save results to a file")
        .long["save"]()
        .short["S"]()
        .flag()
        .group["Output"]()
    )
    app.add_argument(
        Argument("output", help="Output file path (required with --save)")
        .long["output"]()
        .short["o"]()
        .value_name["FILE"]()
        .group["Output"]()
    )
    app.required_if("output", "save")

    # ── Nargs: consumes exactly 3 values ─────────────────────────────────
    app.add_argument(
        Argument("point", help="A 3D point (X Y Z)")
        .long["point"]()
        .number_of_values[3]()
        .value_name["COORD"]()
        .group["Data"]()
    )

    # ── Value delimiter ──────────────────────────────────────────────────
    app.add_argument(
        Argument("tags", help="Comma-separated tags")
        .long["tags"]()
        .short["t"]()
        .delimiter[","]()
        .group["Data"]()
    )

    # ── Key-value map ────────────────────────────────────────────────────
    app.add_argument(
        Argument("define", help="Define a variable (key=value, repeatable)")
        .long["define"]()
        .short["D"]()
        .map_option()
        .group["Data"]()
    )

    # ── Aliases ──────────────────────────────────────────────────────────
    app.add_argument(
        Argument("color-theme", help="Color theme name")
        .long["color-theme"]()
        .alias_name["colour"]()
        .default["auto"]()
    )

    # ── Deprecated argument ──────────────────────────────────────────────
    app.add_argument(
        Argument("legacy", help="Enable legacy mode (deprecated)")
        .long["legacy"]()
        .flag()
        .deprecated[
            "Legacy mode will be removed in v1.0; use --level 0 instead"
        ]()
    )

    # ── default_if_no_value ───────────────────────────────────────────────────
    # --compress → "gzip" (default-if-no-value); --compress=bzip2 → "bzip2" (explicit).
    app.add_argument(
        Argument("compress", help="Compression algorithm")
        .long["compress"]()
        .short["c"]()
        .default_if_no_value["gzip"]()
        .value_name["ALGO"]()
        .group["Output"]()
    )

    # ── Require equals (standalone) ──────────────────────────────────────
    # --separator=X only; --separator X is rejected.
    app.add_argument(
        Argument("separator", help="Field separator (must use = syntax)")
        .long["separator"]()
        .require_equals()
        .value_name["CHAR"]()
        .default[","]()
        .group["Output"]()
    )

    # ── Hidden argument ──────────────────────────────────────────────────
    app.add_argument(
        Argument("debug-internals", help="Dump internal state (debug)")
        .long["debug-internals"]()
        .flag()
        .hidden()
    )

    # ── Negative number passthrough ──────────────────────────────────────
    app.allow_negative_numbers()

    # ── Allow positional args alongside subcommands ──────────────────────
    app.allow_positional_with_subcommands()

    # ── Custom tips ──────────────────────────────────────────────────────
    app.add_tip("Count ceiling: try -vvvvv and observe the warning.")
    app.add_tip("Range clamping: try --level 20 or --level -5.")
    app.add_tip("Negatable: --color enables, --no-color disables.")
    app.add_tip("Delimiter: --tags a,b,c splits into [a, b, c].")

    # ── Subcommand: export ───────────────────────────────────────────────
    # Demonstrates one-required + mutually exclusive on a subcommand.
    var export = Command("export", "Export data in a chosen format")
    export.add_argument(
        Argument("file", help="File to export").positional().required()
    )
    export.add_argument(
        Argument("json", help="Export as JSON").long["json"]().flag()
    )
    export.add_argument(
        Argument("yaml", help="Export as YAML").long["yaml"]().flag()
    )
    export.add_argument(
        Argument("toml", help="Export as TOML").long["toml"]().flag()
    )
    export.one_required(["json", "yaml", "toml"])
    export.mutually_exclusive(["json", "yaml", "toml"])
    export.help_on_no_arguments()
    export.command_aliases(["ex"])
    app.add_subcommand(export^)

    # ── Subcommand: analyze ──────────────────────────────────────────────
    # Demonstrates range clamping on a subcommand.
    var analyze = Command("analyze", "Run analysis on input data")
    analyze.add_argument(
        Argument("data", help="Data file to analyze").positional().required()
    )
    analyze.add_argument(
        Argument("workers", help="Number of parallel workers [1-32]")
        .long["workers"]()
        .short["w"]()
        .range[1, 32]()
        .clamp()
        .default["4"]()
    )
    analyze.add_argument(
        Argument("threshold", help="Confidence threshold [0-100]")
        .long["threshold"]()
        .value_name["PCT"]()
        .range[0, 100]()
        .clamp()
    )
    analyze.help_on_no_arguments()
    analyze.command_aliases(["an", "ana"])
    app.add_subcommand(analyze^)

    # ── Subcommand: run (remainder + allow_hyphen_values) ────────────────
    # Demonstrates .remainder() for forwarding args and .allow_hyphen_values()
    # for accepting stdin convention "-".
    var run = Command("run", "Run a program and forward extra arguments")
    run.add_argument(
        Argument("program", help="Program to run (use - for stdin)")
        .positional()
        .required()
        .allow_hyphen_values()
    )
    run.add_argument(
        Argument("args", help="Arguments forwarded to the program").remainder()
    )
    run.help_on_no_arguments()
    app.add_subcommand(run^)

    # ── Subcommand: login (interactive prompting + password) ─────────────
    # Demonstrates .prompt(), .prompt["..."](), and .password() /
    # .password[True]() for interactive input.  Missing arguments are
    # prompted for interactively.
    #   token    → fully hidden  (.password())       — no echo at all
    #   pin      → asterisk mode (.password[True]()) — echoes * per key
    var login = Command("login", "Authenticate with the service")
    login.add_argument(
        Argument("user", help="Username")
        .long["user"]()
        .short["u"]()
        .required()
        .prompt()
    )
    login.add_argument(
        Argument("token", help="API token")
        .long["token"]()
        .short["t"]()
        .required()
        .prompt["Enter your API token"]()
        .password()  # fully hidden: no echo at all
    )
    login.add_argument(
        Argument("pin", help="Security PIN")
        .long["pin"]()
        .short["p"]()
        .required()
        .prompt["Enter your security PIN"]()
        .password[True]()  # asterisk mode: echoes * for each keystroke
    )
    login.add_argument(
        Argument("region", help="Server region")
        .long["region"]()
        .choice["us"]()
        .choice["eu"]()
        .choice["ap"]()
        .default["us"]()
        .prompt()
    )
    app.add_subcommand(login^)

    # ── Show help when invoked with no arguments ─────────────────────────
    app.help_on_no_arguments()

    # ── Parse & display ──────────────────────────────────────────────────
    var result = app.parse()
    result.print_summary()
