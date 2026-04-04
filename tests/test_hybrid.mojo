"""Hybrid declarative + builder tests.

Tests the bridge between declarative Parsable structs and
builder-level customisations using to_command(), parse_arguments(),
parse_args(), ParseResult, and from_parse_result().

Covers:
  - to_command() + builder modifications + parse_arguments() + from_parse_result()
  - Trait static methods: T.to_command(), T.parse_args(), T.from_parse_result()
  - mutually_exclusive() via to_command()
  - required_together() via to_command()
  - implies() via to_command()
  - Extra builder args accessible via ParseResult
  - configure() free function pattern

Note: parse_from_command(), parse_full(), and parse_full_from_command() call
cmd.parse() which reads sys.argv(), so they cannot be exercised in
unit tests with synthetic argument lists.  Their logic is identical
to to_command() + parse_arguments() + from_parse_result() which IS tested.
"""

from std.testing import assert_true, assert_false, assert_equal, TestSuite

from argmojo import (
    Argument,
    Command,
    Parsable,
    Option,
    Flag,
    Positional,
)


# =======================================================================
# Test structs
# =======================================================================


struct Deploy(Parsable):
    var target: Positional[String, help="Deploy target", required=True]
    var force: Flag[short="f", help="Force deploy"]
    var dry_run: Flag[long="dry-run", help="Simulate without changes"]
    var tag: Option[String, long="tag", short="t", help="Release tag"]
    var replicas: Option[
        Int,
        long="replicas",
        short="r",
        help="Number of replicas",
        default="3",
    ]

    @staticmethod
    def description() -> String:
        return String("Deploy application to target environment.")


struct Convert(Parsable):
    var input: Positional[String, help="Input file", required=True]
    var output: Option[String, long="output", short="o", help="Output file"]

    @staticmethod
    def description() -> String:
        return String("File format converter.")


struct AuthArgs(Parsable):
    var username: Option[String, long="username", short="u", help="Username"]
    var password: Option[String, long="password", short="p", help="Password"]
    var token: Option[String, long="token", help="Auth token"]

    @staticmethod
    def description() -> String:
        return String("Authentication options.")


struct DebugArgs(Parsable):
    var debug: Flag[long="debug", short="d", help="Enable debug mode"]
    var verbose: Flag[short="v", help="Verbose output"]
    var trace: Flag[long="trace", help="Enable tracing"]

    @staticmethod
    def description() -> String:
        return String("Debug options.")


# =======================================================================
# 1. to_command + builder modifications + parse
# =======================================================================


def test_to_command_with_tip() raises:
    """To_command() + add_tip() + parse still returns correct typed values."""
    var cmd = Deploy.to_command()
    cmd.add_tip("Use --dry-run to preview changes first")

    var args: List[String] = ["command", "--tag", "v1.0", "-f", "staging"]
    var result = cmd.parse_arguments(args)
    var deploy = Deploy.from_parse_result(result)

    assert_equal(deploy.target.value, "staging")
    assert_equal(deploy.tag.value, "v1.0")
    assert_true(deploy.force.value, msg="force should be True")
    assert_false(deploy.dry_run.value, msg="dry_run should be False")
    assert_equal(deploy.replicas.value, 3)


def test_to_command_with_colors() raises:
    """Builder color customisation on to_command() works."""
    var cmd = Deploy.to_command()
    cmd.header_color["CYAN"]()
    cmd.arg_color["GREEN"]()

    var args: List[String] = ["command", "--replicas", "5", "prod"]
    var result = cmd.parse_arguments(args)
    var deploy = Deploy.from_parse_result(result)

    assert_equal(deploy.target.value, "prod")
    assert_equal(deploy.replicas.value, 5)


def test_to_command_with_usage() raises:
    """Custom usage line on to_command() works."""
    var cmd = Deploy.to_command()
    cmd.usage("deploy [flags] <target>")

    var args: List[String] = ["command", "staging"]
    var result = cmd.parse_arguments(args)
    var deploy = Deploy.from_parse_result(result)

    assert_equal(deploy.target.value, "staging")


# =======================================================================
# 2. mutually_exclusive via to_command
# =======================================================================


def test_exclusive_one_allowed() raises:
    """Mutually exclusive on declarative flags: one flag is fine."""
    var cmd = Deploy.to_command()
    var group: List[String] = ["force", "dry_run"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["command", "-f", "staging"]
    var result = cmd.parse_arguments(args)
    var deploy = Deploy.from_parse_result(result)

    assert_true(deploy.force.value, msg="force should be True")
    assert_false(deploy.dry_run.value, msg="dry_run should be False")


def test_exclusive_conflict_raises() raises:
    """Mutually exclusive on declarative flags: both flags raises error."""
    var cmd = Deploy.to_command()
    var group: List[String] = ["force", "dry_run"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["command", "-f", "--dry-run", "staging"]
    var caught = False
    try:
        _ = cmd.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="Should have raised for exclusive conflict")


def test_exclusive_none_allowed() raises:
    """Mutually exclusive: providing neither is fine."""
    var cmd = Deploy.to_command()
    var group: List[String] = ["force", "dry_run"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = ["command", "staging"]
    var result = cmd.parse_arguments(args)
    var deploy = Deploy.from_parse_result(result)

    assert_false(deploy.force.value, msg="force should be False")
    assert_false(deploy.dry_run.value, msg="dry_run should be False")


# =======================================================================
# 3. required_together via to_command
# =======================================================================


def test_required_together_both_provided() raises:
    """Required together: providing both is fine."""
    var cmd = AuthArgs.to_command()
    var group: List[String] = ["username", "password"]
    cmd.required_together(group^)

    var args: List[String] = ["command", "-u", "admin", "-p", "secret"]
    var result = cmd.parse_arguments(args)
    var auth = AuthArgs.from_parse_result(result)

    assert_equal(auth.username.value, "admin")
    assert_equal(auth.password.value, "secret")


def test_required_together_none_provided() raises:
    """Required together: providing neither is fine."""
    var cmd = AuthArgs.to_command()
    var group: List[String] = ["username", "password"]
    cmd.required_together(group^)

    var args: List[String] = ["command"]
    var result = cmd.parse_arguments(args)
    var auth = AuthArgs.from_parse_result(result)

    assert_equal(auth.username.value, "")
    assert_equal(auth.password.value, "")


def test_required_together_partial_raises() raises:
    """Required together: providing only one raises error."""
    var cmd = AuthArgs.to_command()
    var group: List[String] = ["username", "password"]
    cmd.required_together(group^)

    var args: List[String] = ["command", "-u", "admin"]
    var caught = False
    try:
        _ = cmd.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "required together" in msg or "must be provided together" in msg,
            msg="Error should mention required together: " + msg,
        )
    assert_true(caught, msg="Should have raised for partial required_together")


# =======================================================================
# 4. implies via to_command
# =======================================================================


def test_implies_sets_flag() raises:
    """Implies: --debug implies --verbose."""
    var cmd = DebugArgs.to_command()
    cmd.implies("debug", "verbose")

    var args: List[String] = ["command", "-d"]
    var result = cmd.parse_arguments(args)
    var dbg = DebugArgs.from_parse_result(result)

    assert_true(dbg.debug.value, msg="debug should be True")
    assert_true(dbg.verbose.value, msg="verbose should be implied by debug")


def test_implies_not_triggered() raises:
    """Implies: without trigger, implied flag stays False."""
    var cmd = DebugArgs.to_command()
    cmd.implies("debug", "verbose")

    var args: List[String] = ["command"]
    var result = cmd.parse_arguments(args)
    var dbg = DebugArgs.from_parse_result(result)

    assert_false(dbg.debug.value, msg="debug should be False")
    assert_false(dbg.verbose.value, msg="verbose should be False")


def test_implies_chain() raises:
    """Implies: debug → verbose → trace (chain)."""
    var cmd = DebugArgs.to_command()
    cmd.implies("debug", "verbose")
    cmd.implies("verbose", "trace")

    var args: List[String] = ["command", "--debug"]
    var result = cmd.parse_arguments(args)
    var dbg = DebugArgs.from_parse_result(result)

    assert_true(dbg.debug.value, msg="debug should be True")
    assert_true(dbg.verbose.value, msg="verbose should be implied")
    assert_true(dbg.trace.value, msg="trace should be implied by chain")


# =======================================================================
# 5. Extra builder args + parse_full / dual return
# =======================================================================


def test_extra_builder_args() raises:
    """Extra builder args are accessible via ParseResult."""
    var cmd = Convert.to_command()
    cmd.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .short["f"]()
        .default["json"]()
    )
    cmd.add_argument(
        Argument("indent", help="Indent level").long["indent"]().default["2"]()
    )

    var args: List[String] = [
        "command",
        "--format",
        "yaml",
        "--indent",
        "4",
        "-o",
        "out.yaml",
        "input.json",
    ]
    var result = cmd.parse_arguments(args)

    # Typed access for declarative fields
    var conv = Convert.from_parse_result(result)
    assert_equal(conv.input.value, "input.json")
    assert_equal(conv.output.value, "out.yaml")

    # Raw access for builder-added fields
    assert_equal(result.get_string("format"), "yaml")
    assert_equal(result.get_string("indent"), "4")


def test_extra_builder_args_defaults() raises:
    """Extra builder args fall back to defaults when not provided."""
    var cmd = Convert.to_command()
    cmd.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .default["json"]()
    )

    var args: List[String] = ["command", "input.txt"]
    var result = cmd.parse_arguments(args)

    var conv = Convert.from_parse_result(result)
    assert_equal(conv.input.value, "input.txt")
    assert_equal(conv.output.value, "")
    assert_equal(result.get_string("format"), "json")


# =======================================================================
# 6. parse_full_from_command trait static method pattern
# =======================================================================


def test_parse_full_from_command_manual() raises:
    """Simulate parse_full_from_command: to_command → customise → parse → both.
    """
    var cmd = Deploy.to_command()
    cmd.add_tip("Verify before deploying")

    var args: List[String] = [
        "command",
        "-f",
        "--tag",
        "v2.0",
        "--replicas",
        "10",
        "prod",
    ]
    var result = cmd.parse_arguments(args)

    # Typed write-back
    var deploy = Deploy.from_parse_result(result)
    assert_equal(deploy.target.value, "prod")
    assert_true(deploy.force.value, msg="force")
    assert_equal(deploy.tag.value, "v2.0")
    assert_equal(deploy.replicas.value, 10)

    # Raw ParseResult also has everything
    assert_true(result.get_flag("force"), msg="raw force")
    assert_equal(result.get_string("tag"), "v2.0")
    assert_equal(result.get_string("replicas"), "10")
    assert_equal(result.get_string("target"), "prod")


# =======================================================================
# 7. configure() free function pattern
# =======================================================================


def configure_deploy(mut cmd: Command) raises:
    """Reusable configuration function for Deploy commands."""
    var group: List[String] = ["force", "dry_run"]
    cmd.mutually_exclusive(group^)
    cmd.add_tip("Use --dry-run to preview changes first")


def test_configure_function_pattern() raises:
    """Configure free function pattern: reusable Command customisation."""
    var cmd = Deploy.to_command()
    configure_deploy(cmd)

    # configure_deploy sets a mutually exclusive group for --force/--dry-run.
    # This test covers the non-conflicting case where only --dry-run is used.
    var args: List[String] = ["command", "--dry-run", "staging"]
    var result = cmd.parse_arguments(args)
    var deploy = Deploy.from_parse_result(result)

    assert_false(deploy.force.value, msg="force should be False")
    assert_true(deploy.dry_run.value, msg="dry_run should be True")
    assert_equal(deploy.target.value, "staging")


def test_configure_exclusive_enforced() raises:
    """Configure with mutually_exclusive: conflict caught."""
    var cmd = Deploy.to_command()
    configure_deploy(cmd)

    var args: List[String] = ["command", "-f", "--dry-run", "staging"]
    var caught = False
    try:
        _ = cmd.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="Should have raised for exclusive conflict")


# =======================================================================
# 8. Trait static methods: T.to_command(), T.parse_args(), T.from_parse_result()
# =======================================================================


def test_to_command() raises:
    """Trait static method T.to_command() builds Command with all arguments."""
    var cmd = Deploy.to_command()

    # Same result as Deploy.to_command() — 5 args registered.
    assert_true(
        len(cmd.args) == 5, "expected 5 args, got " + String(len(cmd.args))
    )


def test_parse_args() raises:
    """Trait static method T.parse_args() parses an argument list into a typed struct.
    """
    var args: List[String] = [
        "command",
        "--tag",
        "v3.0",
        "-f",
        "--replicas",
        "7",
        "staging",
    ]
    var deploy = Deploy.parse_args(args)

    assert_equal(deploy.target.value, "staging")
    assert_equal(deploy.tag.value, "v3.0")
    assert_true(deploy.force.value, msg="force should be True")
    assert_equal(deploy.replicas.value, 7)


def test_from_result() raises:
    """Trait static method T.from_parse_result() populates struct from ParseResult.
    """
    var cmd = AuthArgs.to_command()
    var args: List[String] = ["command", "-u", "alice", "--token", "tok123"]
    var result = cmd.parse_arguments(args)

    # Use the trait static method.
    var auth = AuthArgs.from_parse_result(result)
    assert_equal(auth.username.value, "alice")
    assert_equal(auth.token.value, "tok123")
    assert_equal(auth.password.value, "")


def test_methods_with_builder_mods() raises:
    """Trait methods + builder mods: to_command → customise → parse → from_parse_result.
    """
    var cmd = Deploy.to_command()
    var group: List[String] = ["force", "dry_run"]
    cmd.mutually_exclusive(group^)
    cmd.add_tip("Use --dry-run to preview")

    var args: List[String] = ["command", "--dry-run", "--replicas", "2", "prod"]
    var result = cmd.parse_arguments(args)

    var deploy = Deploy.from_parse_result(result)
    assert_equal(deploy.target.value, "prod")
    assert_true(deploy.dry_run.value, msg="dry_run should be True")
    assert_false(deploy.force.value, msg="force should be False")
    assert_equal(deploy.replicas.value, 2)


def test_dual_return_typed_and_raw() raises:
    """Dual return pattern: both typed struct AND raw ParseResult from same parse.
    """
    var cmd = Convert.to_command()
    cmd.add_argument(
        Argument("format", help="Output format")
        .long["format"]()
        .default["json"]()
    )

    var args: List[String] = [
        "command",
        "--format",
        "yaml",
        "-o",
        "out.yaml",
        "input.json",
    ]
    var result = cmd.parse_arguments(args)

    # Typed access via trait static method.
    var conv = Convert.from_parse_result(result)
    assert_equal(conv.input.value, "input.json")
    assert_equal(conv.output.value, "out.yaml")

    # Raw access for both declarative and builder-added fields.
    assert_equal(result.get_string("format"), "yaml")
    assert_equal(result.get_string("output"), "out.yaml")
    assert_equal(result.get_string("input"), "input.json")


# =======================================================================
# 9. Combined: declarative struct + builder constraints + mixed access
# =======================================================================


def test_combined_workflow() raises:
    """Full hybrid workflow: declarative struct + builder constraints + extra args.
    """
    var cmd = AuthArgs.to_command()

    # Builder: add cross-field constraints
    var group: List[String] = ["username", "token"]
    cmd.mutually_exclusive(group^)

    # Builder: add extra argument not in struct
    cmd.add_argument(Argument("mfa-code", help="MFA code").long["mfa-code"]())

    # Parse with username + password (no token, no mfa)
    var args: List[String] = [
        "command",
        "-u",
        "admin",
        "-p",
        "secret123",
    ]
    var result = cmd.parse_arguments(args)

    # Typed access
    var auth = AuthArgs.from_parse_result(result)
    assert_equal(auth.username.value, "admin")
    assert_equal(auth.password.value, "secret123")
    assert_equal(auth.token.value, "")

    # Raw access for builder-added field
    assert_false(result.has("mfa-code"), msg="mfa-code not provided")


def test_combined_exclusive_conflict() raises:
    """Hybrid: username and token are mutually exclusive via builder."""
    var cmd = AuthArgs.to_command()
    var group: List[String] = ["username", "token"]
    cmd.mutually_exclusive(group^)

    var args: List[String] = [
        "command",
        "-u",
        "admin",
        "--token",
        "abc123",
    ]
    var caught = False
    try:
        _ = cmd.parse_arguments(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "mutually exclusive" in msg,
            msg="Error should mention mutually exclusive",
        )
    assert_true(caught, msg="username + token should conflict")


def test_combined_extra_arg_with_mfa() raises:
    """Hybrid: builder-added mfa-code accessible via ParseResult."""
    var cmd = AuthArgs.to_command()
    cmd.add_argument(Argument("mfa-code", help="MFA code").long["mfa-code"]())

    var args: List[String] = [
        "command",
        "--token",
        "abc123",
        "--mfa-code",
        "987654",
    ]
    var result = cmd.parse_arguments(args)

    # Typed struct
    var auth = AuthArgs.from_parse_result(result)
    assert_equal(auth.token.value, "abc123")
    assert_equal(auth.username.value, "")

    # Builder-added field via raw result
    assert_true(result.has("mfa-code"), msg="mfa-code should be present")
    assert_equal(result.get_string("mfa-code"), "987654")


# =======================================================================
# Main
# =======================================================================


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
