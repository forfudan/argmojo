"""Demo: subcommand routing (Phase 4 — Step 2 + Step 2b auto-help).

Demonstrates ``add_subcommand()`` and parse-time routing: a root command
with three subcommands (search / init / build).  The demo drives a set of
fixed argument lists so it can be run directly without a real terminal.

Step 2b shows the auto-registered 'help' subcommand (strategy B): after
the first add_subcommand() call a 'help' pseudo-subcommand is automatically
inserted.  ``kido help search`` routes to search's help page and exits; the
demo cannot run that case directly, but inspects the registration state.

Usage:
    pixi run demo_subcommands
"""

from argmojo import Argument, Command, ParseResult


fn build_app() raises -> Command:
    """Constructs the complete app command tree."""
    var app = Command("kido", "A fast project scaffold tool.", version="0.3.0")

    # Root-level flag (future: will become persistent in Step 3).
    app.add_argument(
        Argument("verbose", help="Verbose output")
        .long("verbose")
        .short("v")
        .flag()
    )

    # ── search subcommand ────────────────────────────────────────────────
    var search = Command("search", "Search for patterns in source files")
    search.add_argument(
        Argument("pattern", help="Search pattern (regex)")
        .positional()
        .required()
    )
    search.add_argument(
        Argument("path", help="Search path").positional().default(".")
    )
    search.add_argument(
        Argument("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
        .metavar("N")
        .range(1, 100)
    )
    search.add_argument(
        Argument("ignore-case", help="Case-insensitive match")
        .long("ignore-case")
        .short("i")
        .flag()
    )

    # ── init subcommand ──────────────────────────────────────────────────
    var init = Command("init", "Initialise a new project from a template")
    init.add_argument(
        Argument("name", help="Project name").required().positional()
    )
    init.add_argument(
        Argument("template", help="Template name")
        .long("template")
        .short("t")
        .default("default")
    )
    init.add_argument(
        Argument("dry-run", help="Preview changes without writing files")
        .long("dry-run")
        .flag()
    )

    # ── build subcommand ─────────────────────────────────────────────────
    var build = Command("build", "Compile and package the project")
    build.add_argument(
        Argument("release", help="Enable release optimisations")
        .long("release")
        .flag()
    )
    var targets: List[String] = ["native", "wasm", "arm"]
    build.add_argument(
        Argument("target", help="Compilation target")
        .long("target")
        .choices(targets^)
        .default("native")
    )

    app.add_subcommand(search^)
    app.add_subcommand(init^)
    app.add_subcommand(build^)
    return app^


fn hr():
    print("─" * 56)


fn run_case(args: List[String]) raises:
    """Parses args with a fresh app, then prints a formatted summary."""
    hr()
    var display = String("$ kido")
    for k in range(1, len(args)):
        display += " " + args[k]
    print(display)
    var app = build_app()
    var result = app.parse_args(args)
    print("  subcommand : '" + result.subcommand + "'")
    print("  verbose    : " + String(result.get_flag("verbose")))
    if result.has_subcommand_result():
        var sub = result.get_subcommand_result()
        for k in range(len(sub._positional_names)):
            if k < len(sub.positionals):
                print(
                    "    ."
                    + sub._positional_names[k]
                    + " = '"
                    + sub.positionals[k]
                    + "'"
                )
        for entry in sub.values.items():
            print("    ." + entry.key + " = '" + entry.value + "'")
        for entry in sub.flags.items():
            if entry.value:
                print("    ." + entry.key + " = True")
    else:
        for k in range(len(result._positional_names)):
            if k < len(result.positionals):
                print(
                    "    ."
                    + result._positional_names[k]
                    + " = '"
                    + result.positionals[k]
                    + "'"
                )


fn main() raises:
    print("=== kido subcommand routing demo (Step 2 + Step 2b) ===")
    print()

    # Case 1: basic search dispatch
    var c1: List[String] = ["kido", "search", "fn main"]
    run_case(c1)

    # Case 2: search with flags + positionals
    var c2: List[String] = [
        "kido",
        "search",
        "--ignore-case",
        "-d",
        "5",
        "fn main",
        "./src",
    ]
    run_case(c2)

    # Case 3: root flag before subcommand
    var c3: List[String] = ["kido", "--verbose", "search", "TODO"]
    run_case(c3)

    # Case 4: init subcommand with --dry-run
    var c4: List[String] = ["kido", "init", "my-project", "--dry-run"]
    run_case(c4)

    # Case 5: build with --release (target defaults to "native")
    var c5: List[String] = ["kido", "build", "--release"]
    run_case(c5)

    # Case 6: -- stops subcommand dispatch
    hr()
    print(
        "$ kido -- search   (-- stops dispatch; 'search' is a root positional)"
    )
    var app6 = build_app()
    app6.allow_positional_with_subcommands()
    app6.add_argument(
        Argument("fallback", help="Fallback positional").positional()
    )
    var a6: List[String] = ["kido", "--", "search"]
    var r6 = app6.parse_args(a6)
    print("  subcommand : '" + r6.subcommand + "'  (empty)")
    print("  fallback   : '" + r6.get_string("fallback") + "'")

    # Case 7: inspect auto-registered 'help' subcommand (strategy B)
    hr()
    print("$ kido (inspect registered subcommands)")
    var app7 = build_app()
    print(
        "  registered subcommands ("
        + String(len(app7.subcommands))
        + " total):"
    )
    for i in range(len(app7.subcommands)):
        var marker = String(" [auto-help]") if app7.subcommands[
            i
        ]._is_help_subcommand else String("")
        print("    " + app7.subcommands[i].name + marker)
    print("  → 'kido help search' would print search's help page then exit(0).")
    print("  → 'kido help' (no target) would print root help then exit(0).")

    # Case 8: disable_help_subcommand() removes the auto entry
    hr()
    print("$ kido (after disable_help_subcommand)")
    var app8 = build_app()
    app8.disable_help_subcommand()
    print(
        "  registered subcommands ("
        + String(len(app8.subcommands))
        + " total):"
    )
    for i in range(len(app8.subcommands)):
        print("    " + app8.subcommands[i].name)
    print("  → 'kido help search' now routes: 'help' → root positional.")

    hr()
    print()
    print("All cases complete.")
