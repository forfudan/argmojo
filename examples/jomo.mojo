"""Example: a Mojo CLI lookalike using the declarative API.

Simulates the interface of the ``mojo`` command-line tool:

    jomo run hello.mojo
    jomo build -o hello hello.mojo
    jomo package src/mylib -o mylib.mojopkg
    jomo format --line-length 100 src/*.mojo
    jomo doc src/mylib/__init__.mojo

No actual compilation happens — only argument parsing and a summary.

Showcases:
  - Declarative root struct with ``Parsable`` trait
  - Declarative subcommand structs (``format``, ``doc``, ``package``)
  - Builder subcommands (``run``, ``build``) for shared compilation options
  - Hybrid: declarative root + both declarative and builder children
  - ``subcommands()`` hook with ``ChildParsable.to_command()``
  - ``from_result[T]()`` write-back for typed subcommand dispatch
  - ``run()`` dispatch pattern

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
    Positional,
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
        """Register subcommands — mix of declarative and builder."""
        # Builder subcommands (share compilation/target option helpers)
        # `build_run()` and `build_build()` returns Command instances
        # that are defined with builder-style APIs (not Parsable structs).
        cmd.add_subcommand(build_run())
        cmd.add_subcommand(build_build())
        # Declarative subcommands
        var pkg = JomoPackage.to_command()
        pkg.help_on_no_arguments()
        cmd.add_subcommand(pkg^)
        var fmt = JomoFormat.to_command()
        fmt.help_on_no_arguments()
        cmd.add_subcommand(fmt^)
        var doc = JomoDoc.to_command()
        doc.help_on_no_arguments()
        cmd.add_subcommand(doc^)

    def run(self) raises:
        print("Jomo -- run a subcommand. Try: jomo --help")


# =====================================================================
# Declarative subcommands: format, doc, package (Parsable structs)
# =====================================================================


struct JomoFormat(Parsable):
    """Format Mojo source files."""

    var line_length: Option[
        Int,
        long="line-length",
        short="l",
        help="Max character line length",
        default="80",
        has_range=True,
        range_min=1,
        range_max=200,
        value_name="INTEGER",
        group="Format options",
    ]
    var quiet: Flag[
        long="quiet",
        short="q",
        help="Disables non-error messages",
        group="Diagnostic options",
    ]
    var source: Positional[
        String,
        help="Mojo source file to format",
        required=True,
        value_name="SOURCE",
    ]

    @staticmethod
    def name() -> String:
        return "format"

    @staticmethod
    def description() -> String:
        return "Formats Mojo source files."

    def run(self) raises:
        print("Formatting:", self.source.value)
        print("  line-length:", self.line_length.value)
        if self.quiet.value:
            print("  (quiet mode)")


struct JomoDoc(Parsable):
    """Compile docstrings from a Mojo file."""

    var path: Positional[
        String,
        help="Path to the Mojo source file",
        required=True,
        value_name="PATH",
    ]
    var output: Option[
        String,
        long="output",
        short="o",
        help="Output path for generated docs",
        value_name="PATH",
        group="Output options",
    ]

    @staticmethod
    def name() -> String:
        return "doc"

    @staticmethod
    def description() -> String:
        return "Compiles docstrings from a Mojo file."

    def run(self) raises:
        print("Generating docs for:", self.path.value)
        if self.output.value:
            print("  output:", self.output.value)


struct JomoPackage(Parsable):
    """Compile a Mojo package."""

    var path: Positional[
        String,
        help="Path to the package directory",
        required=True,
        value_name="PATH",
    ]
    var output: Option[
        String,
        long="output",
        short="o",
        help="Output path (.mojopkg)",
        value_name="PATH",
        group="Output options",
    ]
    var include_path: Option[
        List[String],
        long="include-path",
        short="I",
        help="Append to the module search path",
        append=True,
        value_name="PATH",
    ]

    @staticmethod
    def name() -> String:
        return "package"

    @staticmethod
    def description() -> String:
        return "Compiles a Mojo package."

    def run(self) raises:
        print("Packaging:", self.path.value)
        if self.output.value:
            print("  output:", self.output.value)
        for i in range(len(self.include_path.value)):
            print("  include:", self.include_path.value[i])


# =====================================================================
# Builder subcommands: run, build (share compilation/target options)
# =====================================================================


def shared_compilation_options(mut cmd: Command) raises:
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


def shared_target_options(mut cmd: Command) raises:
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


def build_run() raises -> Command:
    var cmd = Command("run", "Builds and executes a Mojo file.")
    shared_compilation_options(cmd)
    shared_target_options(cmd)
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


def build_build() raises -> Command:
    var cmd = Command("build", "Builds an executable from a Mojo file.")
    shared_compilation_options(cmd)
    shared_target_options(cmd)
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


# =====================================================================
# Entry point
# =====================================================================


def main() raises:
    # Build the command tree: declarative root + mixed subcommands.
    var cmd = to_command[Jomo]()

    # Parse argv.
    var result = cmd.parse()

    # Populate the declarative root struct.
    var jomo = from_result[Jomo](result)

    # Show verbosity if set.
    if jomo.verbose.value > 0:
        print("Verbosity level:", jomo.verbose.value)

    # Dispatch subcommands.
    if result.has_subcommand_result():
        var sub = result.get_subcommand_result()

        # Declarative subcommands — typed dispatch via from_result + run().
        if result.subcommand == "format":
            from_result[JomoFormat](sub).run()
        elif result.subcommand == "doc":
            from_result[JomoDoc](sub).run()
        elif result.subcommand == "package":
            from_result[JomoPackage](sub).run()
        else:
            # Builder subcommands (run, build) — use raw ParseResult.
            sub.print_summary()
    else:
        jomo.run()
