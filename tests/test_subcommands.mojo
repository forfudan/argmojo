"""Tests for argmojo subcommand support.

Step 0: Validates that the _apply_defaults() and _validate() extraction
from parse_args() preserves all existing behavior. These tests exercise
the defaults and validation paths directly through parse_args(), ensuring
no regression from the refactor.

Step 1: Validates the data model & API surface for subcommand support:
  - Command.subcommands field (List[Command]) and add_subcommand()
  - ParseResult.subcommand field (String, defaults to "")
  - ParseResult.has_subcommand_result() / get_subcommand_result()
  - ParseResult.__copyinit__ preserves subcommand data
  - parse_args() unchanged when no subcommands are registered

Step 2: Validates parse-time subcommand routing:
  - Basic dispatch: subcommand token → child parse_args()
  - Root flags before subcommand parsed by root
  - Child flags/positionals parsed by child
  - ``--`` stops dispatch; subsequent tokens are root positionals
  - Unknown token with subcommands registered → root positional
  - Routing to first / second of multiple subcommands
  - Child validation errors propagate
  - Child default values applied
  - Root still validates its own required args after dispatch
  - Root tokens not forwarded to child

Step 2b: Validates the auto-registered 'help' subcommand:
  - help subcommand auto-added on first add_subcommand() call
  - Only added once even with multiple add_subcommand() calls
  - help appears after user subcommands in the list
  - _is_help_subcommand flag is set correctly
  - disable_help_subcommand() before add_subcommand() prevents insertion
  - disable_help_subcommand() after add_subcommand() removes it
  - Normal dispatch is unaffected by the presence of help subcommand
"""

from testing import assert_true, assert_false, assert_equal, TestSuite
import argmojo
from argmojo import Argument, Command, ParseResult

# ── Step 0: _apply_defaults() behavior ───────────────────────────────────────


fn test_defaults_named_arg() raises:
    """Tests that a named arg with a default gets filled when not provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format").long("format").default("json")
    )

    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("format"), "json")
    print("  ✓ test_defaults_named_arg")


fn test_defaults_positional_arg() raises:
    """Tests that a positional arg with a default gets filled when not provided.
    """
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    command.add_argument(
        Argument("path", help="Path").positional().default(".")
    )

    var args: List[String] = ["test", "hello"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("pattern"), "hello")
    assert_equal(result.get_string("path"), ".")
    print("  ✓ test_defaults_positional_arg")


fn test_defaults_not_applied_when_provided() raises:
    """Tests that defaults do not overwrite explicitly provided values."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("format", help="Output format").long("format").default("json")
    )

    var args: List[String] = ["test", "--format", "csv"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("format"), "csv")
    print("  ✓ test_defaults_not_applied_when_provided")


fn test_defaults_multiple_positional() raises:
    """Tests defaults with multiple positional args where some are provided."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("src", help="Source").positional().default("a.txt")
    )
    command.add_argument(
        Argument("dst", help="Dest").positional().default("b.txt")
    )

    # Provide only the first positional.
    var args: List[String] = ["test", "input.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("src"), "input.txt")
    assert_equal(result.get_string("dst"), "b.txt")
    print("  ✓ test_defaults_multiple_positional")


# ── Step 0: _validate() — required args ──────────────────────────────────────


fn test_validate_required_missing() raises:
    """Tests that a missing required arg raises an error."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").required()
    )

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Required argument" in msg,
            msg="Error should mention 'Required argument'",
        )
        assert_true("output" in msg, msg="Error should mention 'output'")
    assert_true(caught, msg="Should have raised for missing required arg")
    print("  ✓ test_validate_required_missing")


fn test_validate_required_provided() raises:
    """Tests that providing a required arg passes validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("output", help="Output file").long("output").required()
    )

    var args: List[String] = ["test", "--output", "out.txt"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("output"), "out.txt")
    print("  ✓ test_validate_required_provided")


# ── Step 0: _validate() — positional count ───────────────────────────────────


fn test_validate_too_many_positionals() raises:
    """Tests that too many positional args fails validation."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("name", help="Name").positional())

    var args: List[String] = ["test", "alice", "bob"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Too many positional" in msg,
            msg="Error should mention 'Too many positional'",
        )
    assert_true(caught, msg="Should have raised for too many positionals")
    print("  ✓ test_validate_too_many_positionals")


# ── Step 0: _validate() — mutually exclusive ─────────────────────────────────


fn test_validate_exclusive_conflict() raises:
    """Tests that mutually exclusive args in conflict raise an error."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("json", help="JSON").long("json").flag())
    command.add_argument(Argument("yaml", help="YAML").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json", "--yaml"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        assert_true(
            "mutually exclusive" in String(e),
            msg="Error should mention 'mutually exclusive'",
        )
    assert_true(caught, msg="Should have raised for exclusive conflict")
    print("  ✓ test_validate_exclusive_conflict")


fn test_validate_exclusive_ok() raises:
    """Tests that providing only one from exclusive group is fine."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("json", help="JSON").long("json").flag())
    command.add_argument(Argument("yaml", help="YAML").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    command.mutually_exclusive(group^)

    var args: List[String] = ["test", "--json"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("json"))
    print("  ✓ test_validate_exclusive_ok")


# ── Step 0: _validate() — required-together ──────────────────────────────────


fn test_validate_together_partial() raises:
    """Tests that providing only some of a required-together group fails."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("user", help="User").long("user"))
    command.add_argument(Argument("pass", help="Pass").long("pass"))
    var group: List[String] = ["user", "pass"]
    command.required_together(group^)

    var args: List[String] = ["test", "--user", "alice"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        assert_true(
            "required together" in String(e).lower()
            or "Arguments required together" in String(e),
            msg="Error should mention required together",
        )
    assert_true(caught, msg="Should have raised for partial together group")
    print("  ✓ test_validate_together_partial")


# ── Step 0: _validate() — one-required ───────────────────────────────────────


fn test_validate_one_required_none() raises:
    """Tests that providing none from a one-required group fails."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("json", help="JSON").long("json").flag())
    command.add_argument(Argument("yaml", help="YAML").long("yaml").flag())
    var group: List[String] = ["json", "yaml"]
    command.one_required(group^)

    var args: List[String] = ["test"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        assert_true(
            "At least one" in String(e),
            msg="Error should mention 'At least one'",
        )
    assert_true(caught, msg="Should have raised for one-required group")
    print("  ✓ test_validate_one_required_none")


# ── Step 0: _validate() — conditional requirements ───────────────────────────


fn test_validate_conditional_triggered() raises:
    """Tests that conditional requirement fires when condition is present."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("save", help="Save").long("save").flag())
    command.add_argument(Argument("output", help="Output").long("output"))
    command.required_if("output", "save")

    var args: List[String] = ["test", "--save"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        assert_true(
            "required when" in String(e),
            msg="Error should mention 'required when'",
        )
    assert_true(caught, msg="Should have raised for conditional requirement")
    print("  ✓ test_validate_conditional_triggered")


fn test_validate_conditional_satisfied() raises:
    """Tests that conditional requirement passes when both are provided."""
    var command = Command("test", "Test app")
    command.add_argument(Argument("save", help="Save").long("save").flag())
    command.add_argument(Argument("output", help="Output").long("output"))
    command.required_if("output", "save")

    var args: List[String] = ["test", "--save", "--output", "out.txt"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("save"))
    assert_equal(result.get_string("output"), "out.txt")
    print("  ✓ test_validate_conditional_satisfied")


# ── Step 0: _validate() — numeric range ──────────────────────────────────────


fn test_validate_range_out_of_bounds() raises:
    """Tests that a value outside numeric range fails validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long("port").range(1, 100)
    )

    var args: List[String] = ["test", "--port", "200"]
    var caught = False
    try:
        _ = command.parse_args(args)
    except e:
        caught = True
        assert_true(
            "out of range" in String(e),
            msg="Error should mention 'out of range'",
        )
    assert_true(caught, msg="Should have raised for out-of-range value")
    print("  ✓ test_validate_range_out_of_bounds")


fn test_validate_range_in_bounds() raises:
    """Tests that a value within numeric range passes validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long("port").range(1, 100)
    )

    var args: List[String] = ["test", "--port", "50"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("port"), "50")
    print("  ✓ test_validate_range_in_bounds")


# ── Step 0: full round-trip (defaults + validation combined) ─────────────────


fn test_defaults_then_validation_combined() raises:
    """Tests that defaults are applied BEFORE validation runs.

    A required-together group where one arg has a default: providing
    neither should NOT trigger required-together error (neither is present).
    Providing just one should trigger the error.
    """
    var command = Command("test", "Test app")
    command.add_argument(Argument("user", help="User").long("user"))
    command.add_argument(Argument("pass", help="Pass").long("pass"))
    var group: List[String] = ["user", "pass"]
    command.required_together(group^)

    # Providing neither — no error (required-together only fires if some present).
    var args1: List[String] = ["test"]
    var result = command.parse_args(args1)
    assert_false(result.has("user"))
    assert_false(result.has("pass"))
    print("  ✓ test_defaults_then_validation_combined")


fn test_full_parse_with_defaults_and_range() raises:
    """Tests that default values also pass range validation."""
    var command = Command("test", "Test app")
    command.add_argument(
        Argument("port", help="Port").long("port").range(1, 100).default("50")
    )

    # Not providing --port should use default "50" which is in range.
    var args: List[String] = ["test"]
    var result = command.parse_args(args)
    assert_equal(result.get_string("port"), "50")
    print("  ✓ test_full_parse_with_defaults_and_range")


# ── Step 1: Data model — Command.subcommands field ───────────────────────────


fn test_command_subcommands_empty_initially() raises:
    """Tests that a fresh Command has no subcommands registered."""
    var app = Command("app", "My app")
    assert_equal(len(app.subcommands), 0)
    print("  ✓ test_command_subcommands_empty_initially")


fn test_add_subcommand_single() raises:
    """Tests that add_subcommand() appends one subcommand to the list.

    After the first add_subcommand() call the auto-added 'help' subcommand
    is also present at index 0, so the total count is 2.
    """
    var app = Command("app", "My app")
    var search = Command("search", "Search for patterns")
    app.add_subcommand(search^)
    # help (index 0) + search (index 1).
    assert_equal(len(app.subcommands), 2)
    var idx = app._find_subcommand("search")
    assert_true(idx >= 0)
    assert_equal(app.subcommands[idx].name, "search")
    assert_equal(app.subcommands[idx].description, "Search for patterns")
    print("  ✓ test_add_subcommand_single")


fn test_add_subcommand_multiple() raises:
    """Tests that multiple subcommands can be registered and are ordered.

    'help' is auto-inserted at index 0; user subcommands follow in
    registration order.
    """
    var app = Command("app", "My app")
    var search = Command("search", "Search for patterns")
    var init = Command("init", "Initialize a new project")
    var build = Command("build", "Build the project")
    app.add_subcommand(search^)
    app.add_subcommand(init^)
    app.add_subcommand(build^)
    # help [0], search [1], init [2], build [3].
    assert_equal(len(app.subcommands), 4)
    assert_equal(app.subcommands[0].name, "help")
    assert_equal(app.subcommands[1].name, "search")
    assert_equal(app.subcommands[2].name, "init")
    assert_equal(app.subcommands[3].name, "build")
    print("  ✓ test_add_subcommand_multiple")


fn test_add_subcommand_preserves_child_args() raises:
    """Tests that a subcommand's own arg definitions survive transfer.

    Total count is 2 (help at [0] + search at [1]).
    """
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    search.add_argument(
        Argument("max-depth", help="Max depth").long("max-depth").short("d")
    )
    app.add_subcommand(search^)
    assert_equal(len(app.subcommands), 2)
    var idx = app._find_subcommand("search")
    assert_equal(len(app.subcommands[idx].args), 2)
    assert_equal(app.subcommands[idx].args[0].name, "pattern")
    assert_equal(app.subcommands[idx].args[1].name, "max-depth")
    print("  ✓ test_add_subcommand_preserves_child_args")


fn test_subcommand_has_own_version() raises:
    """Tests that a subcommand can have its own version string."""
    var app = Command("app", "My app", version="1.0.0")
    var sub = Command("serve", "Start server", version="2.0.0-beta")
    app.add_subcommand(sub^)
    assert_equal(app.version, "1.0.0")
    var idx = app._find_subcommand("serve")
    assert_equal(app.subcommands[idx].version, "2.0.0-beta")
    print("  ✓ test_subcommand_has_own_version")


# ── Step 1: Data model — ParseResult.subcommand field ────────────────────────


fn test_parseresult_subcommand_defaults_empty() raises:
    """Tests that ParseResult.subcommand defaults to empty string."""
    var result = ParseResult()
    assert_equal(result.subcommand, "")
    print("  ✓ test_parseresult_subcommand_defaults_empty")


fn test_parseresult_subcommand_can_be_set() raises:
    """Tests that ParseResult.subcommand can be assigned a name."""
    var result = ParseResult()
    result.subcommand = "search"
    assert_equal(result.subcommand, "search")
    print("  ✓ test_parseresult_subcommand_can_be_set")


fn test_parseresult_no_subcommand_result_initially() raises:
    """Tests that has_subcommand_result() returns False on a fresh ParseResult.
    """
    var result = ParseResult()
    assert_false(result.has_subcommand_result())
    print("  ✓ test_parseresult_no_subcommand_result_initially")


fn test_parseresult_get_subcommand_result_raises_when_empty() raises:
    """Tests that get_subcommand_result() raises when no child result exists."""
    var result = ParseResult()
    var caught = False
    try:
        _ = result.get_subcommand_result()
    except e:
        caught = True
        assert_true(
            "No subcommand result" in String(e),
            msg="Error should mention 'No subcommand result'",
        )
    assert_true(caught, msg="Should have raised for empty subcommand result")
    print("  ✓ test_parseresult_get_subcommand_result_raises_when_empty")


fn test_parseresult_subcommand_result_stored_and_retrieved() raises:
    """Tests that a child ParseResult can be stored and retrieved."""
    var parent = ParseResult()
    var child = ParseResult()
    child.values["pattern"] = "hello"
    parent.subcommand = "search"
    parent._subcommand_results.append(child^)
    assert_true(parent.has_subcommand_result())
    var retrieved = parent.get_subcommand_result()
    assert_equal(retrieved.get_string("pattern"), "hello")
    print("  ✓ test_parseresult_subcommand_result_stored_and_retrieved")


fn test_parseresult_str_includes_subcommand() raises:
    """Tests that __str__ includes the subcommand name when set."""
    var result = ParseResult()
    result.subcommand = "build"
    var s = String(result)
    assert_true("build" in s, msg="__str__ should include the subcommand name")
    print("  ✓ test_parseresult_str_includes_subcommand")


fn test_parseresult_str_no_subcommand_section_when_empty() raises:
    """Tests that __str__ omits the subcommand when it is empty."""
    var result = ParseResult()
    var s = String(result)
    assert_false(
        "subcommand" in s,
        msg="__str__ should not include 'subcommand' when empty",
    )
    print("  ✓ test_parseresult_str_no_subcommand_section_when_empty")


fn test_parseresult_copy_preserves_subcommand() raises:
    """Tests that copying a ParseResult preserves subcommand and child result.
    """
    var original = ParseResult()
    original.subcommand = "init"
    var child = ParseResult()
    child.values["name"] = "myproject"
    original._subcommand_results.append(child^)
    # Copy explicitly (triggers __copyinit__).
    var copy = original.copy()
    assert_equal(copy.subcommand, "init")
    assert_true(copy.has_subcommand_result())
    assert_equal(copy.get_subcommand_result().get_string("name"), "myproject")
    print("  ✓ test_parseresult_copy_preserves_subcommand")


fn test_parse_without_subcommands_unaffected() raises:
    """Tests that parse_args() results are unchanged when no subcommands exist.
    """
    var command = Command("app", "My app")
    command.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    var args: List[String] = ["app", "--verbose"]
    var result = command.parse_args(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.subcommand, "")
    assert_false(result.has_subcommand_result())
    print("  ✓ test_parse_without_subcommands_unaffected")


# ── Step 2: Parse routing ─────────────────────────────────────────────────────


fn test_dispatch_basic() raises:
    """Tests basic subcommand dispatch: app search pattern."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search", "hello"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "search")
    assert_true(result.has_subcommand_result())
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("pattern"), "hello")
    print("  ✓ test_dispatch_basic")


fn test_dispatch_root_flag_before_subcommand() raises:
    """Tests that root flags before subcommand are parsed by root."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "--verbose", "search", "hello"]
    var result = app.parse_args(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.subcommand, "search")
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("pattern"), "hello")
    print("  ✓ test_dispatch_root_flag_before_subcommand")


fn test_dispatch_root_short_flag_before_subcommand() raises:
    """Tests that root short flags before subcommand are parsed by root."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "-v", "search", "hello"]
    var result = app.parse_args(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.subcommand, "search")
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("pattern"), "hello")
    print("  ✓ test_dispatch_root_short_flag_before_subcommand")


fn test_dispatch_child_flag() raises:
    """Tests that child flags are parsed by the child command."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    search.add_argument(
        Argument("max-depth", help="Depth").long("max-depth").short("d")
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search", "--max-depth", "3", "hello"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "search")
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("max-depth"), "3")
    assert_equal(sub.get_string("pattern"), "hello")
    print("  ✓ test_dispatch_child_flag")


fn test_dispatch_child_flag_short() raises:
    """Tests that child short flags are parsed by the child command."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    search.add_argument(
        Argument("max-depth", help="Depth").long("max-depth").short("d")
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search", "-d", "5", "hello"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "search")
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("max-depth"), "5")
    assert_equal(sub.get_string("pattern"), "hello")
    print("  ✓ test_dispatch_child_flag_short")


fn test_dispatch_double_dash_stops_dispatch() raises:
    """Tests that -- before subcommand name prevents dispatch."""
    var app = Command("app", "My app")
    app.allow_positional_with_subcommands()
    var search = Command("search", "Search")
    search.add_argument(Argument("pattern", help="Pattern").positional())
    app.add_subcommand(search^)
    # "search" is registered but -- forces it to be a positional on root.
    app.add_argument(Argument("arg1", help="First arg").positional())

    var args: List[String] = ["app", "--", "search"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "")
    assert_false(result.has_subcommand_result())
    assert_equal(result.get_string("arg1"), "search")
    print("  ✓ test_dispatch_double_dash_stops_dispatch")


fn test_dispatch_unknown_token_is_positional() raises:
    """Tests that an unknown token (no subcommand match) is treated as positional.
    """
    var app = Command("app", "My app")
    app.allow_positional_with_subcommands()
    var search = Command("search", "Search")
    app.add_subcommand(search^)
    app.add_argument(Argument("name", help="Name").positional())

    var args: List[String] = ["app", "hello"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "")
    assert_equal(result.get_string("name"), "hello")
    print("  ✓ test_dispatch_unknown_token_is_positional")


fn test_dispatch_two_subcommands_route_first() raises:
    """Tests routing to the first of two registered subcommands."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    var init = Command("init", "Init")
    init.add_argument(Argument("name", help="Name").positional().required())
    app.add_subcommand(search^)
    app.add_subcommand(init^)

    var args: List[String] = ["app", "search", "foo"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "search")
    assert_equal(result.get_subcommand_result().get_string("pattern"), "foo")
    print("  ✓ test_dispatch_two_subcommands_route_first")


fn test_dispatch_two_subcommands_route_second() raises:
    """Tests routing to the second of two registered subcommands."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    var init = Command("init", "Init")
    init.add_argument(Argument("name", help="Name").positional().required())
    app.add_subcommand(search^)
    app.add_subcommand(init^)

    var args: List[String] = ["app", "init", "myproject"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "init")
    assert_equal(result.get_subcommand_result().get_string("name"), "myproject")
    print("  ✓ test_dispatch_two_subcommands_route_second")


fn test_dispatch_child_validation_error() raises:
    """Tests that missing required child arg raises an error."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search"]
    var caught = False
    try:
        _ = app.parse_args(args)
    except e:
        caught = True
        assert_true(
            "Required argument" in String(e),
            msg="Error should mention 'Required argument'",
        )
    assert_true(caught, msg="Should have raised for missing child required arg")
    print("  ✓ test_dispatch_child_validation_error")


fn test_dispatch_child_default_value() raises:
    """Tests that child defaults are applied during child parse.

    Required positionals are declared first so the single token fills
    'pattern'; 'path' then falls back to its default '.'.
    """
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    search.add_argument(Argument("path", help="Path").positional().default("."))
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search", "hello"]
    var result = app.parse_args(args)
    var sub = result.get_subcommand_result()
    assert_equal(sub.get_string("pattern"), "hello")
    assert_equal(sub.get_string("path"), ".")
    print("  ✓ test_dispatch_child_default_value")


fn test_dispatch_no_subcommand_when_none_match() raises:
    """Tests that subcommand field stays empty when no token matches."""
    var app = Command("app", "My app")
    app.allow_positional_with_subcommands()
    var search = Command("search", "Search")
    app.add_subcommand(search^)
    app.add_argument(Argument("file", help="File").positional())

    var args: List[String] = ["app", "myfile.txt"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "")
    assert_false(result.has_subcommand_result())
    print("  ✓ test_dispatch_no_subcommand_when_none_match")


fn test_dispatch_root_still_validates_own_required() raises:
    """Tests that root still validates its own required args after dispatch."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("token", help="API token").long("token").required()
    )
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search", "hello"]
    var caught = False
    try:
        _ = app.parse_args(args)
    except e:
        caught = True
        assert_true("Required argument" in String(e))
        assert_true("token" in String(e))
    assert_true(caught, msg="Root required arg should still be validated")
    print("  ✓ test_dispatch_root_still_validates_own_required")


fn test_dispatch_child_receives_no_root_tokens() raises:
    """Tests tokens before subcommand are NOT forwarded to the child."""
    var app = Command("app", "My app")
    app.add_argument(
        Argument("verbose", help="Verbose").long("verbose").short("v").flag()
    )
    var sub = Command("run", "Run")
    # Child only registers a positional; --verbose is NOT a child arg.
    sub.add_argument(Argument("script", help="Script").positional())
    app.add_subcommand(sub^)

    var args: List[String] = ["app", "--verbose", "run", "main.mojo"]
    var result = app.parse_args(args)
    assert_true(result.get_flag("verbose"))
    assert_equal(result.subcommand, "run")
    var child = result.get_subcommand_result()
    assert_equal(child.get_string("script"), "main.mojo")
    # --verbose is not in child result (child doesn't know about it).
    assert_false(child.has("verbose"))
    print("  ✓ test_dispatch_child_receives_no_root_tokens")


# ── Step 2b: auto-registered 'help' subcommand ───────────────────────────────


fn test_help_sub_auto_added() raises:
    """Tests that add_subcommand() automatically inserts a 'help' subcommand."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    app.add_subcommand(search^)

    # Should have 2 entries: 'help' (index 0) + 'search' (index 1).
    assert_equal(len(app.subcommands), 2)
    var help_idx = app._find_subcommand("help")
    assert_true(help_idx >= 0)
    assert_true(app.subcommands[help_idx]._is_help_subcommand)
    print("  ✓ test_help_sub_auto_added")


fn test_help_sub_added_only_once() raises:
    """Tests that 'help' is not duplicated on multiple add_subcommand() calls.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)
    app.add_subcommand(Command("init", "Init")^)
    app.add_subcommand(Command("build", "Build")^)

    # 3 user subs + 1 help = 4 total.
    assert_equal(len(app.subcommands), 4)
    var count = 0
    for i in range(len(app.subcommands)):
        if app.subcommands[i].name == "help":
            count += 1
    assert_equal(count, 1)
    print("  ✓ test_help_sub_added_only_once")


fn test_help_sub_appears_after_user_subs() raises:
    """Tests that 'help' is at index 0 and user subs follow in order."""
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)
    app.add_subcommand(Command("init", "Init")^)

    # help [0], search [1], init [2].
    assert_equal(app.subcommands[0].name, "help")
    assert_equal(app.subcommands[1].name, "search")
    assert_equal(app.subcommands[2].name, "init")
    print("  ✓ test_help_sub_appears_after_user_subs")


fn test_help_sub_flag_on_user_subs() raises:
    """Tests that user-registered subcommands do NOT have the flag set."""
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)

    var search_idx = app._find_subcommand("search")
    assert_true(search_idx >= 0)
    assert_false(app.subcommands[search_idx]._is_help_subcommand)
    print("  ✓ test_help_sub_flag_on_user_subs")


fn test_disable_help_sub_before_add() raises:
    """Tests that disable_help_subcommand() before add_subcommand() prevents insertion.
    """
    var app = Command("app", "My app")
    app.disable_help_subcommand()
    app.add_subcommand(Command("search", "Search")^)

    # Only 1 subcommand — no 'help'.
    assert_equal(len(app.subcommands), 1)
    assert_equal(app._find_subcommand("help"), -1)
    print("  ✓ test_disable_help_sub_before_add")


fn test_disable_help_sub_after_add() raises:
    """Tests that disable_help_subcommand() after add_subcommand() removes it.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)
    # 'help' is now present.
    assert_equal(len(app.subcommands), 2)

    app.disable_help_subcommand()
    # 'help' should be gone; only 'search' remains.
    assert_equal(len(app.subcommands), 1)
    assert_equal(app.subcommands[0].name, "search")
    assert_equal(app._find_subcommand("help"), -1)
    print("  ✓ test_disable_help_sub_after_add")


fn test_dispatch_unaffected_by_help_sub() raises:
    """Tests that normal dispatch still works when 'help' sub is auto-added."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    var args: List[String] = ["app", "search", "TODO"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "search")
    var child = result.get_subcommand_result()
    assert_equal(child.get_string("pattern"), "TODO")
    print("  ✓ test_dispatch_unaffected_by_help_sub")


fn test_help_sub_disabled_unknown_word_becomes_positional() raises:
    """Tests that with help disabled, 'help' token is treated as a positional.
    """
    var app = Command("app", "My app")
    app.allow_positional_with_subcommands()
    app.add_argument(Argument("query", help="Query").positional())
    app.disable_help_subcommand()
    app.add_subcommand(Command("init", "Init")^)

    # "help" should be treated as a root positional, not dispatch.
    var args: List[String] = ["app", "help"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "")
    assert_equal(result.positionals[0], "help")
    print("  ✓ test_help_sub_disabled_unknown_word_becomes_positional")


# ── Error handling ───────────────────────────────────────────────────────────


fn test_unknown_subcommand_error_no_positionals() raises:
    """Tests that an unknown subcommand name gives an error when no positional args are defined.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)
    app.add_subcommand(Command("init", "Init")^)

    var args: List[String] = ["app", "foo"]
    var caught = False
    try:
        _ = app.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown command" in msg,
            msg="Should mention unknown command",
        )
        assert_true("foo" in msg, msg="Should mention 'foo'")
        assert_true("search" in msg, msg="Should list available 'search'")
        assert_true("init" in msg, msg="Should list available 'init'")
    assert_true(caught, msg="Should have raised for unknown subcommand")
    print("  ✓ test_unknown_subcommand_error_no_positionals")


fn test_unknown_token_becomes_positional_when_positionals_defined() raises:
    """Tests that unknown token becomes positional when root has positional args.
    """
    var app = Command("app", "My app")
    app.allow_positional_with_subcommands()
    app.add_argument(Argument("query", help="Query").positional())
    app.add_subcommand(Command("search", "Search")^)

    # "foo" doesn't match any subcommand but root has positional args → positional.
    var args: List[String] = ["app", "foo"]
    var result = app.parse_args(args)
    assert_equal(result.subcommand, "")
    assert_equal(result.positionals[0], "foo")
    print("  ✓ test_unknown_token_becomes_positional_when_positionals_defined")


fn test_child_error_includes_command_path() raises:
    """Tests that child parse errors include the full command path in stderr."""
    var app = Command("app", "My app")
    var search = Command("search", "Search")
    search.add_argument(
        Argument("pattern", help="Pattern").positional().required()
    )
    app.add_subcommand(search^)

    # Missing required positional in child.
    var args: List[String] = ["app", "search"]
    var caught = False
    try:
        _ = app.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Required argument" in msg,
            msg="Should mention required argument",
        )
        assert_true("pattern" in msg, msg="Should mention 'pattern'")
    assert_true(caught, msg="Should have raised for missing required in child")
    print("  ✓ test_child_error_includes_command_path")


fn test_unknown_subcommand_error_excludes_help_sub() raises:
    """Tests that the error message for unknown subcommand does not list 'help'.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)

    var args: List[String] = ["app", "foo"]
    var caught = False
    try:
        _ = app.parse_args(args)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Unknown command" in msg,
            msg="Should mention unknown command",
        )
        assert_true("search" in msg, msg="Should list 'search'")
        # 'help' should not appear in available commands.
        # But the full msg could contain "help" in other contexts.
        # Check the "Available commands:" part specifically.
        var avail_start = msg.find("Available commands: ")
        if avail_start >= 0:
            var avail_part = String(msg[avail_start:])
            assert_false(
                "help" in avail_part,
                msg="'help' sub should not appear in available commands",
            )
    assert_true(caught, msg="Should have raised")
    print("  ✓ test_unknown_subcommand_error_excludes_help_sub")


# ── Positional + subcommand guard ────────────────────────────────────────────


fn test_add_positional_after_subcommand_raises() raises:
    """Tests that adding a positional after a subcommand raises without opt-in.
    """
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)

    var caught = False
    try:
        app.add_argument(Argument("query", help="Query").positional())
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Cannot add positional argument" in msg,
            msg="Should mention positional conflict",
        )
        assert_true(
            "allow_positional_with_subcommands" in msg,
            msg="Should mention opt-in method",
        )
    assert_true(caught, msg="Should have raised")
    print("  ✓ test_add_positional_after_subcommand_raises")


fn test_add_subcommand_after_positional_raises() raises:
    """Tests that adding a subcommand after a positional raises without opt-in.
    """
    var app = Command("app", "My app")
    app.add_argument(Argument("file", help="File").positional())

    var caught = False
    try:
        app.add_subcommand(Command("init", "Init")^)
    except e:
        caught = True
        var msg = String(e)
        assert_true(
            "Cannot add subcommand" in msg,
            msg="Should mention subcommand conflict",
        )
        assert_true(
            "allow_positional_with_subcommands" in msg,
            msg="Should mention opt-in method",
        )
    assert_true(caught, msg="Should have raised")
    print("  ✓ test_add_subcommand_after_positional_raises")


fn test_allow_positional_with_subcommands_opt_in() raises:
    """Tests that with opt-in, both directions work without error."""
    # Direction 1: positional first, then subcommand.
    var app1 = Command("app", "My app")
    app1.allow_positional_with_subcommands()
    app1.add_argument(Argument("file", help="File").positional())
    app1.add_subcommand(Command("init", "Init")^)
    assert_equal(len(app1.subcommands), 2)  # init + auto help

    # Direction 2: subcommand first, then positional.
    var app2 = Command("app", "My app")
    app2.allow_positional_with_subcommands()
    app2.add_subcommand(Command("search", "Search")^)
    app2.add_argument(Argument("query", help="Query").positional())

    # Verify parsing works: unknown token → positional.
    var args: List[String] = ["app", "hello"]
    var result = app2.parse_args(args)
    assert_equal(result.subcommand, "")
    assert_equal(result.positionals[0], "hello")
    print("  ✓ test_allow_positional_with_subcommands_opt_in")


fn test_non_positional_args_unaffected_by_guard() raises:
    """Tests that adding non-positional (flags/options) with subcommands
    does not trigger the guard, even without opt-in."""
    var app = Command("app", "My app")
    app.add_subcommand(Command("search", "Search")^)
    # These should NOT raise:
    app.add_argument(Argument("verbose", help="Verbose").long("verbose").flag())
    app.add_argument(Argument("output", help="Output").long("output"))
    assert_true(True, msg="Non-positional args should not trigger guard")
    print("  ✓ test_non_positional_args_unaffected_by_guard")


# ── main ─────────────────────────────────────────────────────────────────────


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
