"""Demo: subcommand data model & API surface (Phase 4 — Step 1).

This demo shows how to build a multi-subcommand CLI structure using
``add_subcommand()``.  The routing logic (Step 2) is not yet implemented,
so ``parse_args()`` still behaves as a single-command parser; this file
focuses on demonstrating the new data model: registering subcommands,
inspecting the ``Command.subcommands`` list, and reading the new
``ParseResult.subcommand`` field.

Run with:
    pixi run package && mojo run -I src examples/demo_subcommands.mojo
"""

from argmojo import Arg, Command, ParseResult


fn main() raises:
    # ── Build the root command ───────────────────────────────────────────
    var app = Command(
        "kido",
        "A fast project scaffold tool.",
        version="0.3.0",
    )

    # Root-level flag (will become persistent in Step 3).
    app.add_arg(
        Arg("verbose", help="Verbose output").long("verbose").short("v").flag()
    )

    # ── Build subcommands ────────────────────────────────────────────────

    # "search" subcommand
    var search = Command("search", "Search for patterns in source files")
    search.add_arg(
        Arg("pattern", help="Search pattern (regex)").positional().required()
    )
    search.add_arg(Arg("path", help="Search path").positional().default("."))
    search.add_arg(
        Arg("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
        .metavar("N")
        .range(1, 100)
    )
    search.add_arg(
        Arg("ignore-case", help="Case-insensitive match")
        .long("ignore-case")
        .short("i")
        .flag()
    )

    # "init" subcommand
    var init = Command("init", "Initialise a new project from a template")
    init.add_arg(Arg("name", help="Project name").required().positional())
    init.add_arg(
        Arg("template", help="Template name")
        .long("template")
        .short("t")
        .default("default")
    )
    init.add_arg(
        Arg("dry-run", help="Preview changes without writing files")
        .long("dry-run")
        .flag()
    )

    # "build" subcommand
    var build = Command("build", "Compile and package the project")
    build.add_arg(
        Arg("release", help="Enable release optimisations")
        .long("release")
        .flag()
    )
    var targets: List[String] = ["native", "wasm", "arm"]
    build.add_arg(
        Arg("target", help="Compilation target")
        .long("target")
        .choices(targets^)
        .default("native")
    )

    # ── Register subcommands on root ─────────────────────────────────────
    app.add_subcommand(search^)
    app.add_subcommand(init^)
    app.add_subcommand(build^)

    # ── Inspect the registered data model ───────────────────────────────
    print("Root command   : " + app.name + " v" + app.version)
    print("Subcommands    : " + String(len(app.subcommands)))
    for i in range(len(app.subcommands)):
        print(
            "  ["
            + String(i)
            + "] "
            + app.subcommands[i].name
            + " — "
            + app.subcommands[i].description
            + " ("
            + String(len(app.subcommands[i].args))
            + " arg(s))"
        )

    # ── ParseResult data model: subcommand fields ────────────────────────
    print("")
    print("ParseResult data model:")
    var r = ParseResult()
    print("  r.subcommand           = '" + r.subcommand + "'")
    print("  r.has_subcommand_result() = " + String(r.has_subcommand_result()))

    # Simulate what Step 2 (parse routing) will populate:
    var child = ParseResult()
    child.values["pattern"] = "fn main"
    child.positionals.append("fn main")
    r.subcommand = "search"
    r._subcommand_results.append(child^)

    print("  (after simulated routing)")
    print("  r.subcommand           = '" + r.subcommand + "'")
    print("  r.has_subcommand_result() = " + String(r.has_subcommand_result()))
    var sub_result = r.get_subcommand_result()
    print("  sub.get_string('pattern') = " + sub_result.get_string("pattern"))
    print("  str(r)                 = " + String(r))

    # ── Existing single-command parse is unaffected ──────────────────────
    print("")
    print("Single-command parse (subcommand routing not yet active):")
    var cmd = Command("sou", "Search tool")
    cmd.add_arg(Arg("pattern", help="Pattern").positional().required())
    cmd.add_arg(
        Arg("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    var args: List[String] = ["sou", "hello", "--verbose"]
    var result = cmd.parse_args(args)
    print("  pattern  = " + result.get_string("pattern"))
    print("  verbose  = " + String(result.get_flag("verbose")))
    print("  subcommand = '" + result.subcommand + "'")
    print("  has_subcommand_result = " + String(result.has_subcommand_result()))
