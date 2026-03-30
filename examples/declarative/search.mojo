"""Example: Pure Declarative (simple tool)

Try it out with:

```sh
pixi run mojo build -I src ./examples/declarative/search.mojo
./search "text" ./ --ignore-case --max-count 1000 -vvvvvvv --ext "txt" --ext "md"
./search --help
```
"""

from argmojo import Parsable, Option, Flag, Positional, Count


struct Search(Parsable):
    """Search for patterns in files."""

    var pattern: Positional[String, help="Search pattern", required=True]
    var path: Positional[String, help="File or directory", default="."]
    var ignore_case: Flag[short="i", help="Case-insensitive search"]
    var count_only: Flag[short="c", long="count", help="Only print match count"]
    var max_count: Option[
        Int,
        short="m",
        long="max-count",
        help="Stop after N matches",
        default="0",
        has_range=True,
        range_max=100,  # The max value of matches
        clamp=True,  # The value will be clamped to the range if it exceeds the limits
    ]
    var verbose: Count[
        short="v",
        help="Increase verbosity",
        max=3,  # The max level of verbosity, e.g. -vvvv will be treated as -vvv
    ]
    var ext: Option[
        List[String], short="e", long="ext", help="File extensions", append=True
    ]

    @staticmethod
    def description() -> String:
        return "Search for patterns in files."

    @staticmethod
    def version() -> String:
        return "1.0.0"


def main() raises:
    # Just one line to parse the arguments into a typed struct
    var args = Search.parse()

    # Print the parsed arguments
    print("pattern:", args.pattern.value)
    print("path:", args.path.value)
    print("ignore_case:", args.ignore_case.value)
    print("count_only:", args.count_only.value)
    print("max_count:", args.max_count.value)
    print("verbose:", args.verbose.value)
    print("ext:", args.ext.value)
