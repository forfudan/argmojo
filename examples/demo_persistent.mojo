"""Demo: persistent (global) flags with argmojo.

Persistent flags are declared with .persistent() on the Argument builder.
They are automatically injected into every subcommand so the user can
place them either BEFORE or AFTER the subcommand token — both work.

Usage examples shown below:
  app --verbose search pattern          # flag before subcommand
  app search --verbose pattern          # flag after subcommand  (same result)
  app -v search pattern                 # short form also works
  app --output=json search pattern      # persistent value option, before
  app search pattern --output=json      # persistent value option, after

Run one of them:
  pixi run demo_persistent
  pixi run demo_persistent -- search --verbose query
"""

from sys import argv
from argmojo import Argument, Command


fn build_app() raises -> Command:
    """Build and return the configured app command."""
    var app = Command("app", "Demo app with persistent flags", version="0.1.0")

    # ── Persistent flags (available everywhere) ──────────────────────────
    app.add_argument(
        Argument("verbose", help="Enable verbose/debug output")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    app.add_argument(
        Argument("output", help="Output format (json|text|yaml)")
        .long("output")
        .short("o")
        .choices(["json", "text", "yaml"])
        .default("text")
        .persistent()
    )

    # ── sub: search ──────────────────────────────────────────────────────
    var search = Command("search", "Search for a pattern in files")
    search.add_argument(
        Argument("pattern", help="Pattern to search for")
        .positional()
        .required()
    )
    search.add_argument(
        Argument("case-insensitive", help="Ignore case")
        .long("case-insensitive")
        .short("i")
        .flag()
    )
    app.add_subcommand(search^)

    # ── sub: index ───────────────────────────────────────────────────────
    var index = Command("index", "Build or update the search index")
    index.add_argument(
        Argument("path", help="Directory to index").positional().default(".")
    )
    index.add_argument(
        Argument("force", help="Force full re-index")
        .long("force")
        .short("f")
        .flag()
    )
    app.add_subcommand(index^)

    return app^


fn demo_before_subcommand(app: Command) raises:
    print("")
    print("─── Demo 1: --verbose BEFORE subcommand ─────────────────────")
    print("    input: app --verbose search my_query")
    var r = app.copy().parse_args(["app", "--verbose", "search", "my_query"])
    print("    root  result: verbose =", r.get_flag("verbose"))
    print("    root  result: output  =", r.get_string("output"))
    var sub = r.get_subcommand_result()
    print("    child result: verbose =", sub.get_flag("verbose"))
    print("    child result: output  =", sub.get_string("output"))


fn demo_after_subcommand(app: Command) raises:
    print("")
    print("─── Demo 2: --verbose AFTER subcommand ──────────────────────")
    print("    input: app search --verbose my_query")
    var r = app.copy().parse_args(["app", "search", "--verbose", "my_query"])
    print("    root  result: verbose =", r.get_flag("verbose"))
    var sub = r.get_subcommand_result()
    print("    child result: verbose =", sub.get_flag("verbose"))


fn demo_short_flag(app: Command) raises:
    print("")
    print("─── Demo 3: short form -v after subcommand ──────────────────")
    print("    input: app search -v my_query")
    var r = app.copy().parse_args(["app", "search", "-v", "my_query"])
    print("    root  result: verbose =", r.get_flag("verbose"))
    var sub = r.get_subcommand_result()
    print("    child result: verbose =", sub.get_flag("verbose"))


fn demo_value_option(app: Command) raises:
    print("")
    print("─── Demo 4: persistent value option before subcommand ───────")
    print("    input: app --output json search my_query")
    var r = app.copy().parse_args(
        ["app", "--output", "json", "search", "my_query"]
    )
    print("    root  result: output =", r.get_string("output"))
    var sub = r.get_subcommand_result()
    print("    child result: output =", sub.get_string("output"))


fn demo_value_option_after(app: Command) raises:
    print("")
    print("─── Demo 5: persistent value option after subcommand ────────")
    print("    input: app search --output yaml my_query")
    var r = app.copy().parse_args(
        ["app", "search", "--output", "yaml", "my_query"]
    )
    print("    root  result: output =", r.get_string("output"))
    var sub = r.get_subcommand_result()
    print("    child result: output =", sub.get_string("output"))


fn demo_absent(app: Command) raises:
    print("")
    print("─── Demo 6: persistent flag absent ─────────────────────────")
    print("    input: app search my_query")
    var r = app.copy().parse_args(["app", "search", "my_query"])
    print("    root  result: verbose =", r.get_flag("verbose"))
    var sub = r.get_subcommand_result()
    print("    child result: verbose =", sub.get_flag("verbose"))


fn demo_conflict_detection() raises:
    print("")
    print("─── Demo 7: conflict detection at registration time ─────────")
    print(
        "    Registering a subcommand that conflicts with a persistent flag..."
    )
    var app2 = Command("app", "")
    app2.add_argument(
        Argument("verbose", help="")
        .long("verbose")
        .short("v")
        .flag()
        .persistent()
    )
    var conflict_child = Command("sub", "")
    conflict_child.add_argument(
        Argument("verbose", help="local --verbose").long("verbose").flag()
    )
    var caught = False
    try:
        app2.add_subcommand(conflict_child^)
    except e:
        caught = True
        print("    Caught conflict error (expected):", e)
    if not caught:
        print("    ERROR: should have raised but didn't!")
    else:
        print("    ✓ Conflict correctly detected at add_subcommand time")


fn main() raises:
    var app = build_app()

    demo_before_subcommand(app)
    demo_after_subcommand(app)
    demo_short_flag(app)
    demo_value_option(app)
    demo_value_option_after(app)
    demo_absent(app)
    demo_conflict_detection()

    print("")
    print("All demos complete.")
