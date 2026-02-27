"""Example: a grep-like CLI to demonstrate argmojo without subcommands.

Simulates the interface of GNU grep.  Only argument parsing is performed;
no actual file searching is implemented.

Showcases: positional args, long/short options, boolean flags, count flags,
negatable flags, choices, default values, required arguments, metavar,
hidden arguments, short flag merging, attached short values, append/collect,
value delimiter, multi-value options (nargs), mutually exclusive groups,
one-required groups, required-together groups, conditional requirements,
numeric range validation, key-value map options, aliases, deprecated
arguments, prefix matching, negative-number passthrough, `--` stop marker,
and custom tips.

Try these:
  grep --help
  grep --version
  grep "fn main" ./src
  grep -rnic "TODO" ./src --max-depth 5
  grep "pattern" --format json --tag fixme --tag urgent
  grep -E "foo|bar" ./src --color --max-depth 3
  grep -- "-pattern-with-dashes" ./src
"""

from argmojo import Argument, Command


fn main() raises:
    var app = Command(
        "grep",
        "Search for PATTERN in each FILE.",
        version="1.0.0",
    )

    # ── Positional arguments ─────────────────────────────────────────────
    app.add_argument(
        Argument("pattern", help="Search pattern (regex or fixed string)")
        .positional()
        .required()
    )
    app.add_argument(
        Argument("path", help="Files or directories to search")
        .positional()
        .default(".")
    )

    # ── Matching control ─────────────────────────────────────────────────
    app.add_argument(
        Argument("ignore-case", help="Ignore case distinctions in patterns")
        .long("ignore-case")
        .short("i")
        .flag()
    )
    app.add_argument(
        Argument("invert-match", help="Select non-matching lines")
        .long("invert-match")
        .short("v")
        .flag()
    )
    app.add_argument(
        Argument("word-regexp", help="Match only whole words")
        .long("word-regexp")
        .short("w")
        .flag()
    )
    app.add_argument(
        Argument("line-regexp", help="Match only whole lines")
        .long("line-regexp")
        .short("x")
        .flag()
    )

    # ── Mutually exclusive: regex type ───────────────────────────────────
    app.add_argument(
        Argument(
            "extended-regexp", help="PATTERN is an extended regular expression"
        )
        .long("extended-regexp")
        .short("E")
        .flag()
    )
    app.add_argument(
        Argument("fixed-strings", help="PATTERN is a fixed string")
        .long("fixed-strings")
        .short("F")
        .flag()
    )
    app.add_argument(
        Argument("perl-regexp", help="PATTERN is a Perl regular expression")
        .long("perl-regexp")
        .short("P")
        .flag()
    )
    var regex_type: List[String] = [
        "extended-regexp",
        "fixed-strings",
        "perl-regexp",
    ]
    app.mutually_exclusive(regex_type^)

    # ── Output control ───────────────────────────────────────────────────
    app.add_argument(
        Argument("count", help="Print only a count of matching lines")
        .long("count")
        .short("c")
        .flag()
    )
    app.add_argument(
        Argument(
            "files-with-matches", help="Print only names of files with matches"
        )
        .long("files-with-matches")
        .short("l")
        .flag()
    )
    app.add_argument(
        Argument("line-number", help="Prefix each line with its line number")
        .long("line-number")
        .short("n")
        .flag()
    )

    # ── Negatable flag ───────────────────────────────────────────────────
    app.add_argument(
        Argument("color", help="Highlight matching text")
        .long("color")
        .flag()
        .negatable()
    )

    # ── Directory control ────────────────────────────────────────────────
    app.add_argument(
        Argument("recursive", help="Search directories recursively")
        .long("recursive")
        .short("r")
        .flag()
    )
    app.add_argument(
        Argument("max-depth", help="Maximum directory depth")
        .long("max-depth")
        .short("d")
        .metavar("N")
        .range(0, 999)
    )

    # ── Context control (nargs) ──────────────────────────────────────────
    app.add_argument(
        Argument("context", help="Print B lines before and A lines after match")
        .long("context")
        .short("C")
        .nargs(2)
        .metavar("N")
    )

    # ── Output format (choices) ──────────────────────────────────────────
    var fmts: List[String] = ["text", "json", "csv"]
    app.add_argument(
        Argument("format", help="Output format")
        .long("format")
        .short("f")
        .choices(fmts^)
        .default("text")
    )

    # ── Append / collect ─────────────────────────────────────────────────
    app.add_argument(
        Argument("tag", help="Add a tag (repeatable)")
        .long("tag")
        .short("t")
        .append()
    )

    # ── Value delimiter ──────────────────────────────────────────────────
    app.add_argument(
        Argument("exclude-dir", help="Skip directories (comma-separated)")
        .long("exclude-dir")
        .delimiter(",")
    )

    # ── Required-together group ──────────────────────────────────────────
    app.add_argument(
        Argument("username", help="Auth username").long("username").short("u")
    )
    app.add_argument(
        Argument("password", help="Auth password").long("password").short("p")
    )
    var auth: List[String] = ["username", "password"]
    app.required_together(auth^)

    # ── Conditional requirement ──────────────────────────────────────────
    app.add_argument(
        Argument("save", help="Save results to file")
        .long("save")
        .short("S")
        .flag()
    )
    app.add_argument(
        Argument("output", help="Output file path (required with --save)")
        .long("output")
        .short("o")
        .metavar("FILE")
    )
    app.required_if("output", "save")

    # ── Key-value map option ─────────────────────────────────────────────
    app.add_argument(
        Argument("define", help="Define a variable (key=value, repeatable)")
        .long("define")
        .short("D")
        .map_option()
    )

    # ── Aliases ──────────────────────────────────────────────────────────
    var colour_aliases: List[String] = ["color-mode"]
    app.add_argument(
        Argument("colour", help="Colour theme")
        .long("colour")
        .aliases(colour_aliases^)
        .default("auto")
    )

    # ── Deprecated argument ──────────────────────────────────────────────
    app.add_argument(
        Argument("mmap", help="Use memory-mapped I/O (legacy)")
        .long("mmap")
        .flag()
        .deprecated("Memory-mapping is now automatic")
    )

    # ── Hidden argument ──────────────────────────────────────────────────
    app.add_argument(
        Argument("debug-index", help="Dump internal index (debug only)")
        .long("debug-index")
        .flag()
        .hidden()
    )

    # ── Negative number passthrough ──────────────────────────────────────
    app.allow_negative_numbers()

    # ── Custom tips ──────────────────────────────────────────────────────
    app.add_tip('Use quotes for patterns with spaces: grep "fn main" ./src')

    # ── Show help when invoked with no arguments ─────────────────────────
    app.help_on_no_args()

    # ── Parse & display ──────────────────────────────────────────────────
    var result = app.parse()
    app.print_summary(result)
