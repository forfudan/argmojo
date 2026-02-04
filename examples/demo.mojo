"""Example: a mini CLI to demonstrate argmojo usage."""

from argmojo import Arg, Command


fn main() raises:
    var cmd = Command("demo", "A CJK-aware text search tool", version="0.1.0")

    # Positional arguments
    # demo "hello" ./src
    cmd.add_arg(
        Arg("pattern", help="Search pattern").positional().required()
    )  
    cmd.add_arg(
        Arg("path", help="Search path").positional().default(".")
    )

    # Options
    cmd.add_arg(
        Arg("ling", help="Use Lingming IME for encoding")
        .long("ling")
        .short("l")
        .flag()
    )
    cmd.add_arg(
        Arg("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
    )
    
    # Parse real argv
    var result = cmd.parse()

    # Print what we got
    print("=== Parsed Arguments ===")
    print("  pattern:     ", result.get_string("pattern"))
    print("  path:        ", result.get_string("path"))
    print("  --ling:      ", result.get_flag("ling"))
    if result.has("max-depth"):
        print("  --max-depth: ", result.get_string("max-depth"))
    else:
        print("  --max-depth:  (not set)")
