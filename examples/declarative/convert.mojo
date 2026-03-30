"""Example: Split Parse (declarative + extra builder fields)

Try it out with:

```sh
pixi run mojo build -I src ./examples/declarative/convert.mojo
./convert func.txt -o output.txt --format yaml --indent 4
./convert
```
"""

from argmojo import Command, Argument
from argmojo import Parsable, Positional, Option


struct Convert(Parsable):
    var input: Positional[String, help="Input file", required=True]
    var output: Option[String, long="output", short="o", help="Output file"]

    @staticmethod
    def description() -> String:
        return "File format converter."


def main() raises:
    # to_command() returns an owned Command for further customization
    var command = Convert.to_command()

    # Add more arguments that are too complex for the declarative API
    command.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .short["f"]()
        .choice["json"]()
        .choice["yaml"]()
        .choice["toml"]()
        .default["json"]()
    )
    command.add_argument(
        Argument("indent", help="Indent level")
        .long["indent"]()
        .range[0, 8]()
        .default["2"]()
    )

    # Add more granular control with Command API
    command.header_color["GREEN"]()  # Set the help header color to green
    command.help_on_no_arguments()  # Show help if no arguments are provided

    # parse_with_command() returns BOTH the typed struct AND the raw ParseResult
    var result = Convert.parse_with_command(command^)
    ref args = result[0]  # typed Convert
    ref raw = result[1]  # untyped ParseResult

    # Declarative fields: typed access
    print("Input:", args.input.value)
    print("Output:", args.output.value)

    # Builder fields: ParseResult access
    var format = raw.get_string("format")
    var indent = raw.get_int("indent")

    print("Format:", format)
    print("Indent:", indent)
