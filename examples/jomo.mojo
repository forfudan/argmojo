"""Example: a Mojo CLI lookalike using the declarative API.

Simulates the interface of the ``mojo`` command-line tool:

    jomo run hello.mojo
    jomo build -o hello hello.mojo
    jomo package src/mylib -o mylib.mojopkg
    jomo format --line-length 100 src/*.mojo
    jomo doc src/mylib/__init__.mojo

No actual compilation happens — only argument parsing and a summary.
This demo starts simple and will grow as more declarative features land.

Showcases:
  - Declarative root struct with ``Parsable`` trait
  - Global options via ``Option`` and ``Flag`` wrappers
  - Auto-naming (underscore → hyphen in long names)
  - The ``subcommands()`` hook to register builder-API child commands
  - Hybrid approach: declarative root + builder subcommands
  - ``parse_split`` for subcommand dispatch

Try these (build first with: pixi run mojo build -I src -o jomo examples/jomo.mojo):

  jomo --help
  jomo --version
  jomo run hello.mojo
  jomo run -O0 -I src hello.mojo -- arg1 arg2
  jomo build -o hello hello.mojo
  jomo build --emit llvm hello.mojo
  jomo package src/mylib -o mylib.mojopkg
  jomo format --line-length 100 src/main.mojo
  jomo format -q src/main.mojo
  jomo doc src/mylib/__init__.mojo
"""


from argmojo import (
    Argument,
    Command,
    Parsable,
    Option,
    Flag,
    Count,
    to_command,
    from_result,
)


# =====================================================================
# Root: jomo (declarative)
# =====================================================================


struct Jomo(Parsable):
    """Root command — global options shared across all subcommands."""

    var verbose: Count[short="v", help="Increase verbosity", persistent=True]

    @staticmethod
    def description() -> String:
        return String("The Jomo command line interface.")

    @staticmethod
    def version() -> String:
        return String("2026.3.1")

    @staticmethod
    def name() -> String:
        return String("jomo")

    @staticmethod
    def subcommands(mut cmd: Command) raises:
        """Register all subcommands using the builder API."""
        cmd.add_subcommand(_build_run())
        cmd.add_subcommand(_build_build())
        cmd.add_subcommand(_build_package())
        cmd.add_subcommand(_build_format())
        cmd.add_subcommand(_build_doc())

    def run(self) raises:
        print("Jomo -- run a subcommand. Try: jomo --help")


# =====================================================================
# Subcommands (builder API — declarative subcommands are Phase 2)
# =====================================================================


def _shared_compilation_options(mut cmd: Command) raises:
    """Add options shared by `run` and `build`."""
    cmd.add_argument(
        Argument("optimization-level", help="Optimization level (0-3)")
        .long["optimization-level"]()
        .short["O"]()
        .default["3"]()
        .range[0, 3]()
        .value_name["LEVEL"]()
        .group["Compilation options"]()
    )
    cmd.add_argument(
        Argument("include-path", help="Append to the module search path")
        .long["include-path"]()
        .short["I"]()
        .append()
        .value_name["PATH"]()
        .group["Compilation options"]()
    )
    cmd.add_argument(
        Argument("define", help="Define a compile-time key=value (-D key=val)")
        .long["define"]()
        .short["D"]()
        .append()
        .value_name["KEY=VALUE"]()
        .group["Compilation options"]()
    )
    cmd.add_argument(
        Argument(
            "debug-level", help="Debug info level: none, line-tables, full"
        )
        .long["debug-level"]()
        .short["g"]()
        .default["none"]()
        .choice["none"]()
        .choice["line-tables"]()
        .choice["full"]()
        .value_name["LEVEL"]()
        .group["Compilation options"]()
    )
    cmd.add_argument(
        Argument("num-threads", help="Max threads for compilation (0 = all)")
        .long["num-threads"]()
        .short["j"]()
        .default["0"]()
        .range[0, 1024]()
        .value_name["NUM"]()
        .group["Compilation options"]()
    )


def _shared_target_options(mut cmd: Command) raises:
    """Add target options shared by `run` and `build`."""
    cmd.add_argument(
        Argument("target-triple", help="Compilation target triple")
        .long["target-triple"]()
        .value_name["TRIPLE"]()
        .group["Target options"]()
    )
    cmd.add_argument(
        Argument("target-cpu", help="Compilation target CPU")
        .long["target-cpu"]()
        .value_name["CPU"]()
        .group["Target options"]()
    )
    cmd.add_argument(
        Argument("target-features", help="Compilation target CPU features")
        .long["target-features"]()
        .value_name["FEATURES"]()
        .group["Target options"]()
    )


def _build_run() raises -> Command:
    var cmd = Command("run", "Builds and executes a Mojo file.")
    _shared_compilation_options(cmd)
    _shared_target_options(cmd)
    cmd.add_argument(
        Argument("path", help="Path to the Mojo source file")
        .positional()
        .required()
        .value_name["PATH"]()
    )
    cmd.add_argument(
        Argument("args", help="Arguments passed to the Mojo program")
        .positional()
        .remainder()
        .value_name["ARGS"]()
    )
    cmd.help_on_no_arguments()
    return cmd^


def _build_build() raises -> Command:
    var cmd = Command("build", "Builds an executable from a Mojo file.")
    _shared_compilation_options(cmd)
    _shared_target_options(cmd)
    cmd.add_argument(
        Argument("output", help="Output path for the executable")
        .long["output"]()
        .short["o"]()
        .value_name["PATH"]()
        .group["Output options"]()
    )
    cmd.add_argument(
        Argument(
            "emit", help="Output file type: exe, shared-lib, object, llvm, asm"
        )
        .long["emit"]()
        .default["exe"]()
        .choice["exe"]()
        .choice["shared-lib"]()
        .choice["object"]()
        .choice["llvm"]()
        .choice["llvm-bitcode"]()
        .choice["asm"]()
        .value_name["FILE_TYPE"]()
        .group["Output options"]()
    )
    cmd.add_argument(
        Argument("path", help="Path to the Mojo source file")
        .positional()
        .required()
        .value_name["PATH"]()
    )
    cmd.help_on_no_arguments()
    return cmd^


def _build_package() raises -> Command:
    var cmd = Command("package", "Compiles a Mojo package.")
    cmd.add_argument(
        Argument("path", help="Path to the package directory")
        .positional()
        .required()
        .value_name["PATH"]()
    )
    cmd.add_argument(
        Argument("output", help="Output path (.mojopkg)")
        .long["output"]()
        .short["o"]()
        .value_name["PATH"]()
        .group["Output options"]()
    )
    cmd.add_argument(
        Argument("include-path", help="Append to the module search path")
        .long["include-path"]()
        .short["I"]()
        .append()
        .value_name["PATH"]()
    )
    cmd.help_on_no_arguments()
    return cmd^


def _build_format() raises -> Command:
    var cmd = Command("format", "Formats Mojo source files.")
    cmd.add_argument(
        Argument("line-length", help="Max character line length")
        .long["line-length"]()
        .short["l"]()
        .default["80"]()
        .range[1, 200]()
        .value_name["INTEGER"]()
        .group["Format options"]()
    )
    cmd.add_argument(
        Argument("quiet", help="Disables non-error messages")
        .long["quiet"]()
        .short["q"]()
        .flag()
        .group["Diagnostic options"]()
    )
    cmd.add_argument(
        Argument("source", help="Mojo source file to format")
        .positional()
        .required()
        .value_name["SOURCE"]()
    )
    cmd.help_on_no_arguments()
    return cmd^


def _build_doc() raises -> Command:
    var cmd = Command("doc", "Compiles docstrings from a Mojo file.")
    cmd.add_argument(
        Argument("path", help="Path to the Mojo source file")
        .positional()
        .required()
        .value_name["PATH"]()
    )
    cmd.add_argument(
        Argument("output", help="Output path for generated docs")
        .long["output"]()
        .short["o"]()
        .value_name["PATH"]()
        .group["Output options"]()
    )
    cmd.help_on_no_arguments()
    return cmd^


# =====================================================================
# Entry point
# =====================================================================


def main() raises:
    # Build the command tree: declarative root + builder subcommands.
    var cmd = to_command[Jomo]()

    # Parse argv.
    var result = cmd.parse()

    # Populate the declarative root struct.
    var jomo = from_result[Jomo](result)

    # Show what we got.
    if jomo.verbose.value > 0:
        print("Verbosity level:", jomo.verbose.value)

    result.print_summary()
