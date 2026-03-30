"""Example: Declarative + Builder Hybrid (granular control with Command API)

Try it out with:

```sh
pixi run mojo build -I src ./examples/declarative/deploy.mojo
./deploy "./file" --force --tag "v1.0" --replicas 1000
./deploy --help
```
"""

from argmojo import Command, Argument
from argmojo import Parsable, Option, Flag, Positional


struct Deploy(Parsable):
    var target: Positional[
        String, help="Deploy target", required=True, choices="staging,prod"
    ]
    var force: Flag[short="f", help="Force deploy without checks"]
    var validated: Flag[
        long="validated", help="Only deploy if validation passes"
    ]
    var dry_run: Flag[long="dry-run", help="Simulate without changes"]
    var tag: Option[String, long="tag", short="t", help="Release tag"]
    var replicas: Option[
        Int,
        long="replicas",
        short="r",
        help="Number of replicas",
        default="3",
        has_range=True,
        range_min=1,
        range_max=100,
        clamp=True,
    ]

    @staticmethod
    def description() -> String:
        return "Deploy application to target environment."


def main() raises:
    # to_command() returns an owned Command for further customization
    var command = Deploy.to_command()

    # Add more granular control with Command API
    command.mutually_exclusive(["force", "dry_run"])
    command.implies("force", "validated")  # force implies validated
    command.confirmation_option["Deploy to production?"]()
    command.add_tip("Use --dry-run to preview changes first")
    command.header_color["CYAN"]()
    command.help_on_no_arguments()  # Show help if no arguments are provided

    # from_command() parses the customized command and returns a populated Deploy instance
    var deploy = Deploy.from_command(command^)

    # Print the parsed arguments
    print("target:", deploy.target.value)
    print("force:", deploy.force.value)
    print("validated:", deploy.validated.value)
    print("dry_run:", deploy.dry_run.value)
    print("tag:", deploy.tag.value)
    print("replicas:", deploy.replicas.value)
