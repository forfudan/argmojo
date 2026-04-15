"""Example: a git-like CLI to demonstrate argmojo with subcommands.

Simulates the interface of git.  Only argument parsing is performed;
no actual version-control operations are implemented.

Showcases: auto-dispatch (set_run_function / execute), subcommands,
sub-subcommands (remote, stash, config), persistent (global) flags,
per-command positional args, boolean flags, count flags, negatable flags,
choices, default values, required arguments, value_name, hidden arguments,
append/collect, value delimiter, mutually exclusive groups,
required-together groups, conditional requirements, numeric range
validation, aliases, deprecated arguments, Commands section in help,
Global Options heading, full command path in child help/errors, unknown
subcommand error, custom tips, and shell completion script generation.

Try these:
  mgit --help                          # root help (Commands + Global Options)
  mgit --version
  mgit clone --help                    # child help with full path
  mgit clone https://example.com/repo.git my-project --depth 1
  mgit commit -am "initial commit"
  mgit log --oneline -n 20 --author "Alice"
  mgit remote add origin https://example.com/repo.git
  mgit -v push origin main --force --tags
  mgit stash push -m "wip"            # stash sub-subcommand
  mgit stash pop                       # stash pop
  mgit config set user.name "Alice"    # config sub-subcommand
  mgit config get user.name
  mgit --completions bash              # shell completion script (built-in)
"""

from argmojo import Argument, Command, ParseResult


# ═══════════════════════════════════════════════════════════════════════════
# Handler functions — called automatically by execute() via auto-dispatch
# ═══════════════════════════════════════════════════════════════════════════


def handle_clone(result: ParseResult) raises:
    """Handler for 'mgit clone'."""
    var repo = result.get_string("repository")
    var msg = String("Cloning into '")
    try:
        msg += result.get_string("directory")
    except:
        # Use the last segment of the URL as directory name.
        var parts = repo.split("/")
        var last = parts[len(parts) - 1]
        if last.endswith(".git"):
            msg += last[byte = : len(last) - 4]
        else:
            msg += last
    msg += "'..."
    print(msg)
    print("  remote: " + repo)
    try:
        var depth = result.get_int("depth")
        print("  shallow clone: depth " + String(depth))
    except:
        pass
    if result.get_flag("bare"):
        print("  creating bare repository")
    try:
        print("  branch: " + result.get_string("branch"))
    except:
        pass
    if result.get_flag("recurse-submodules"):
        print("  recursing into submodules")
    print("done.")


def handle_init(result: ParseResult) raises:
    """Handler for 'mgit init'."""
    var dir = result.get_string("directory")
    if result.get_flag("bare"):
        print("Initialized empty bare Git repository in " + dir + "/")
    else:
        print("Initialized empty Git repository in " + dir + "/.git/")
    try:
        print("  template: " + result.get_string("template"))
    except:
        pass
    try:
        print("  initial branch: " + result.get_string("initial-branch"))
    except:
        pass


def handle_add(result: ParseResult) raises:
    """Handler for 'mgit add'."""
    if result.get_flag("dry-run"):
        print("dry run — nothing will be staged")
    if result.get_flag("all"):
        print("Adding all changed files to the index")
    else:
        try:
            print("Adding '" + result.get_string("pathspec") + "' to the index")
        except:
            print("Adding files to the index")
    if result.get_flag("force"):
        print("  (including ignored files)")
    if result.get_flag("patch"):
        print("  entering interactive patch mode...")


def handle_commit(result: ParseResult) raises:
    """Handler for 'mgit commit'."""
    var msg = result.get_string("message")
    if result.get_flag("amend"):
        print("[main abc1234] (amended) " + msg)
    else:
        print("[main def5678] " + msg)
    if result.get_flag("all"):
        print("  auto-staged modified and deleted files")
    try:
        print("  author: " + result.get_string("author"))
    except:
        pass
    if result.get_flag("no-verify"):
        print("  (hooks skipped)")
    print(" 3 files changed, 42 insertions(+), 7 deletions(-)")


def handle_push(result: ParseResult) raises:
    """Handler for 'mgit push'."""
    var remote = result.get_string("remote")
    var refspec = String("HEAD")
    try:
        refspec = result.get_string("refspec")
    except:
        pass
    if result.get_flag("dry-run"):
        print("(dry run) ", end="")
    if result.get_flag("force"):
        print("Force pushing to " + remote + "/" + refspec + "...")
    elif result.get_flag("force-with-lease"):
        print("Force-with-lease pushing to " + remote + "/" + refspec + "...")
    else:
        print("Pushing to " + remote + "/" + refspec + "...")
    if result.get_flag("set-upstream"):
        print(
            "  branch '"
            + refspec
            + "' set up to track '"
            + remote
            + "/"
            + refspec
            + "'"
        )
    if result.get_flag("tags"):
        print("  including all tags")
    print("  Everything up-to-date")


def handle_pull(result: ParseResult) raises:
    """Handler for 'mgit pull'."""
    var remote = result.get_string("remote")
    var branch = String("main")
    try:
        branch = result.get_string("branch")
    except:
        pass
    print("Pulling from " + remote + "/" + branch + "...")
    if result.get_flag("autostash"):
        print("  auto-stashing local changes")
    if result.get_flag("rebase"):
        print("  rebasing on top of upstream")
    elif result.get_flag("no-rebase"):
        print("  merging upstream changes")
    print("  Already up to date.")


def handle_log(result: ParseResult) raises:
    """Handler for 'mgit log'."""
    var n = 5
    try:
        n = result.get_int("number")
    except:
        pass
    var oneline = result.get_flag("oneline")
    var graph = result.get_flag("graph")
    try:
        print("Filtering by author: " + result.get_string("author"))
    except:
        pass
    try:
        print("Since: " + result.get_string("since"))
    except:
        pass
    try:
        print("Until: " + result.get_string("until"))
    except:
        pass
    var patterns = result.get_list("grep")
    if len(patterns) > 0:
        for i in range(len(patterns)):
            print("Grep: " + patterns[i])
    # Simulated log output.
    var commits: List[String] = [
        "abc1234 Initial commit",
        "def5678 Add README.md",
        "789abcd Implement feature X",
        "012efgh Fix bug in parser",
        "345ijkl Refactor module Y",
        "678mnop Add unit tests",
        "901qrst Update documentation",
    ]
    var limit = n if n < len(commits) else len(commits)
    for i in range(limit):
        if graph:
            print("* ", end="")
        if oneline:
            print(commits[i])
        else:
            var parts = commits[i].split(" ", 1)
            print("commit " + parts[0])
            print("    " + parts[1])
            print()


def handle_branch(result: ParseResult) raises:
    """Handler for 'mgit branch'."""
    var name = String("")
    try:
        name = result.get_string("name")
    except:
        pass
    if name != "" and result.get_flag("delete"):
        print("Deleted branch " + name + " (was abc1234).")
    elif name != "" and result.get_flag("force-delete"):
        print("Force-deleted branch " + name + " (was abc1234).")
    elif name != "" and result.get_flag("move"):
        print("Renamed branch to '" + name + "'")
    elif name != "":
        print("Created branch '" + name + "' at abc1234")
    else:
        # List branches.
        var show_all = result.get_flag("all-branches")
        print("* main")
        print("  develop")
        print("  feature/auto-dispatch")
        if show_all:
            print("  remotes/origin/main")
            print("  remotes/origin/develop")


def handle_diff(result: ParseResult) raises:
    """Handler for 'mgit diff'."""
    var path = String("")
    try:
        path = result.get_string("path")
    except:
        pass
    if result.get_flag("staged"):
        print("Changes staged for commit", end="")
    else:
        print("Changes not staged for commit", end="")
    if path != "":
        print(" (" + path + ")")
    else:
        print("")
    if result.get_flag("stat"):
        print(" src/main.mojo | 12 ++++++------")
        print(" 1 file changed, 6 insertions(+), 6 deletions(-)")
    elif result.get_flag("name-only"):
        print(" src/main.mojo")
    else:
        print("diff --git a/src/main.mojo b/src/main.mojo")
        print("--- a/src/main.mojo")
        print("+++ b/src/main.mojo")
        print("@@ -10,3 +10,3 @@")
        print("-    old_line()")
        print("+    new_line()")


def handle_tag(result: ParseResult) raises:
    """Handler for 'mgit tag'."""
    var name = String("")
    try:
        name = result.get_string("tagname")
    except:
        pass
    if result.get_flag("tag-list") or name == "":
        print("v0.1.0")
        print("v0.2.0")
        print("v0.5.0")
        return
    if result.get_flag("tag-delete"):
        print("Deleted tag '" + name + "' (was abc1234)")
        return
    if result.get_flag("annotate"):
        var msg = String("Release " + name)
        try:
            msg = result.get_string("tag-message")
        except:
            pass
        print("Created annotated tag '" + name + "': " + msg)
    else:
        print("Created lightweight tag '" + name + "' at abc1234")


# ── remote sub-subcommand handlers ──────────────────────────────────────


def handle_remote_add(result: ParseResult) raises:
    """Handler for 'mgit remote add'."""
    var name = result.get_string("name")
    var url = result.get_string("url")
    print("Added remote '" + name + "' -> " + url)
    if result.get_flag("fetch"):
        print("Fetching from " + name + "...")
        print("  * [new branch]  main -> " + name + "/main")


def handle_remote_remove(result: ParseResult) raises:
    """Handler for 'mgit remote remove'."""
    print("Removed remote '" + result.get_string("name") + "'")


def handle_remote_rename(result: ParseResult) raises:
    """Handler for 'mgit remote rename'."""
    print(
        "Renamed remote '"
        + result.get_string("old")
        + "' to '"
        + result.get_string("new")
        + "'"
    )


def handle_remote_show(result: ParseResult) raises:
    """Handler for 'mgit remote show'."""
    var name = result.get_string("name")
    print("* remote " + name)
    print("  Fetch URL: https://example.com/repo.git")
    print("  Push  URL: https://example.com/repo.git")
    print("  HEAD branch: main")
    print("  Remote branches:")
    print("    main    tracked")
    print("    develop tracked")


# ── stash sub-subcommand handlers ───────────────────────────────────────


def handle_stash_push(result: ParseResult) raises:
    """Handler for 'mgit stash push'."""
    var msg = String("WIP on main")
    try:
        msg = result.get_string("stash-message")
    except:
        pass
    print("Saved working directory and index state: " + msg)
    if result.get_flag("keep-index"):
        print("  (staged changes kept in index)")
    if result.get_flag("include-untracked"):
        print("  (including untracked files)")


def handle_stash_pop(result: ParseResult) raises:
    """Handler for 'mgit stash pop'."""
    var index = String("0")
    try:
        index = result.get_string("stash-index")
    except:
        pass
    print("Popping stash@{" + index + "}...")
    print("On branch main")
    print("Changes restored from stash.")
    print("Dropped stash@{" + index + "}")


def handle_stash_list(result: ParseResult) raises:
    """Handler for 'mgit stash list'."""
    _ = result
    print("stash@{0}: WIP on main: abc1234 Fix parser bug")
    print("stash@{1}: On develop: def5678 Half-done feature")


def handle_stash_drop(result: ParseResult) raises:
    """Handler for 'mgit stash drop'."""
    var index = String("0")
    try:
        index = result.get_string("stash-index")
    except:
        pass
    print("Dropped stash@{" + index + "} (abc1234)")


def handle_stash_apply(result: ParseResult) raises:
    """Handler for 'mgit stash apply'."""
    var index = String("0")
    try:
        index = result.get_string("stash-index")
    except:
        pass
    print("Applying stash@{" + index + "}...")
    print("On branch main")
    print("Changes restored from stash.")


# ── config sub-subcommand handlers ──────────────────────────────────────


def handle_config_get(result: ParseResult) raises:
    """Handler for 'mgit config get'."""
    var key = result.get_string("key")
    # Simulated config values.
    if key == "user.name":
        print("Alice")
    elif key == "user.email":
        print("alice@example.com")
    elif key == "core.editor":
        print("vim")
    else:
        print("(not set)")


def handle_config_set(result: ParseResult) raises:
    """Handler for 'mgit config set'."""
    var key = result.get_string("key")
    var value = result.get_string("value")
    if result.get_flag("global"):
        print("Set global config: " + key + " = " + value)
    else:
        print("Set local config: " + key + " = " + value)


def handle_config_list(result: ParseResult) raises:
    """Handler for 'mgit config list'."""
    _ = result
    print("user.name=Alice")
    print("user.email=alice@example.com")
    print("core.editor=vim")
    print("core.autocrlf=input")
    print("remote.origin.url=https://example.com/repo.git")
    print("remote.origin.fetch=+refs/heads/*:refs/remotes/origin/*")


def handle_config_unset(result: ParseResult) raises:
    """Handler for 'mgit config unset'."""
    var key = result.get_string("key")
    if result.get_flag("global"):
        print("Unset global config: " + key)
    else:
        print("Unset local config: " + key)


# ═══════════════════════════════════════════════════════════════════════════
# Subcommand generators
#
# Each subcommand is built in its own function to keep individual function
# bodies small.  The Mojo compiler's CheckLifetimes pass scales
# super-linearly with the number of live variables in a single function, so
# splitting a monolithic main() into many small generators dramatically
# reduces total compile time (benchmarked: ~320 s → ~30 s for this file).
# ═══════════════════════════════════════════════════════════════════════════


def generate_clone_subcommand() raises -> Command:
    """Builds the 'clone' subcommand."""
    var cmd = Command("clone", "Clone a repository into a new directory")
    cmd.add_argument(
        Argument("repository", help="Repository URL or path")
        .positional()
        .required()
    )
    cmd.add_argument(
        Argument("directory", help="Target directory name").positional()
    )
    cmd.add_argument(
        Argument("depth", help="Create a shallow clone with N commits")
        .long["depth"]()
        .value_name["N"]()
        .range[1, 999999]()
    )
    cmd.add_argument(
        Argument("branch", help="Check out this branch instead of HEAD")
        .long["branch"]()
        .short["b"]()
    )
    cmd.add_argument(
        Argument("bare", help="Make a bare repository").long["bare"]().flag()
    )
    cmd.add_argument(
        Argument("recurse-submodules", help="Initialize submodules")
        .long["recurse-submodules"]()
        .flag()
    )
    cmd.help_on_no_arguments()
    var aliases: List[String] = ["cl"]
    cmd.command_aliases(aliases^)
    cmd.set_run_function(handle_clone)
    return cmd^


def generate_init_subcommand() raises -> Command:
    """Builds the 'init' subcommand."""
    var cmd = Command("init", "Create an empty Git repository")
    cmd.add_argument(
        Argument("directory", help="Directory to initialize")
        .positional()
        .default["."]()
    )
    cmd.add_argument(
        Argument("bare", help="Create a bare repository").long["bare"]().flag()
    )
    cmd.add_argument(
        Argument("template", help="Template directory")
        .long["template"]()
        .choice["default"]()
        .choice["minimal"]()
        .default["default"]()
    )
    cmd.add_argument(
        Argument("initial-branch", help="Name for the initial branch")
        .long["initial-branch"]()
        .short["b"]()
        .default["main"]()
    )
    cmd.set_run_function(handle_init)
    return cmd^


def generate_add_subcommand() raises -> Command:
    """Builds the 'add' subcommand."""
    var cmd = Command("add", "Add file contents to the index")
    cmd.add_argument(Argument("pathspec", help="Files to add").positional())
    cmd.add_argument(
        Argument("all", help="Add all changed files")
        .long["all"]()
        .short["A"]()
        .flag()
    )
    cmd.add_argument(
        Argument("force", help="Allow adding otherwise ignored files")
        .long["force"]()
        .short["f"]()
        .flag()
    )
    cmd.add_argument(
        Argument("dry-run", help="Show what would be added without adding")
        .long["dry-run"]()
        .short["n"]()
        .flag()
    )
    cmd.add_argument(
        Argument("patch", help="Interactively select hunks to add")
        .long["patch"]()
        .short["p"]()
        .flag()
    )
    cmd.set_run_function(handle_add)
    return cmd^


def generate_commit_subcommand() raises -> Command:
    """Builds the 'commit' subcommand."""
    var cmd = Command("commit", "Record changes to the repository")
    cmd.add_argument(
        Argument("message", help="Commit message")
        .long["message"]()
        .short["m"]()
        .required()
    )
    cmd.add_argument(
        Argument("all", help="Automatically stage modified/deleted files")
        .long["all"]()
        .short["a"]()
        .flag()
    )
    cmd.add_argument(
        Argument("amend", help="Amend the previous commit")
        .long["amend"]()
        .flag()
    )
    cmd.add_argument(
        Argument("no-verify", help="Skip pre-commit and commit-msg hooks")
        .long["no-verify"]()
        .short["n"]()
        .flag()
    )
    cmd.add_argument(
        Argument("author", help="Override the commit author")
        .long["author"]()
        .value_name["NAME"]()
    )
    # Deprecated flag
    cmd.add_argument(
        Argument("cleanup-mode", help="Set cleanup mode (legacy)")
        .long["cleanup-mode"]()
        .deprecated["Use --cleanup instead"]()
    )
    var aliases: List[String] = ["ci"]
    cmd.command_aliases(aliases^)
    cmd.set_run_function(handle_commit)
    return cmd^


def generate_push_subcommand() raises -> Command:
    """Builds the 'push' subcommand."""
    var cmd = Command("push", "Update remote refs along with objects")
    cmd.add_argument(
        Argument("remote", help="Remote name").positional().default["origin"]()
    )
    cmd.add_argument(
        Argument("refspec", help="Branch or refspec to push").positional()
    )
    cmd.add_argument(
        Argument("force", help="Force push (use with caution!)")
        .long["force"]()
        .short["f"]()
        .flag()
    )
    cmd.add_argument(
        Argument("set-upstream", help="Set upstream for the branch")
        .long["set-upstream"]()
        .short["u"]()
        .flag()
    )
    cmd.add_argument(
        Argument("tags", help="Push all tags").long["tags"]().flag()
    )
    cmd.add_argument(
        Argument("dry-run", help="Simulate the push without sending")
        .long["dry-run"]()
        .short["n"]()
        .flag()
    )
    # Mutually exclusive: force strategies
    cmd.add_argument(
        Argument("force-with-lease", help="Safe force push")
        .long["force-with-lease"]()
        .flag()
    )
    var force_group: List[String] = ["force", "force-with-lease"]
    cmd.mutually_exclusive(force_group^)
    cmd.set_run_function(handle_push)
    return cmd^


def generate_pull_subcommand() raises -> Command:
    """Builds the 'pull' subcommand."""
    var cmd = Command("pull", "Fetch from and integrate with a remote")
    cmd.add_argument(
        Argument("remote", help="Remote name").positional().default["origin"]()
    )
    cmd.add_argument(Argument("branch", help="Branch to pull").positional())
    # Mutually exclusive: merge strategy
    cmd.add_argument(
        Argument("rebase", help="Rebase instead of merge")
        .long["rebase"]()
        .flag()
    )
    cmd.add_argument(
        Argument("no-rebase", help="Merge instead of rebase")
        .long["no-rebase"]()
        .flag()
    )
    var merge_strat: List[String] = ["rebase", "no-rebase"]
    cmd.mutually_exclusive(merge_strat^)
    cmd.add_argument(
        Argument("autostash", help="Stash changes before pull, reapply after")
        .long["autostash"]()
        .flag()
    )
    cmd.set_run_function(handle_pull)
    return cmd^


def generate_log_subcommand() raises -> Command:
    """Builds the 'log' subcommand."""
    var cmd = Command("log", "Show commit logs")
    cmd.add_argument(
        Argument("oneline", help="Compact one-line format")
        .long["oneline"]()
        .flag()
    )
    cmd.add_argument(
        Argument("graph", help="Draw ASCII commit graph").long["graph"]().flag()
    )
    cmd.add_argument(
        Argument("number", help="Limit number of commits shown")
        .long["number"]()
        .short["n"]()
        .value_name["N"]()
        .range[1, 999999]()
    )
    cmd.add_argument(
        Argument("author", help="Filter by author")
        .long["author"]()
        .value_name["PATTERN"]()
    )
    cmd.add_argument(
        Argument("since", help="Show commits after date")
        .long["since"]()
        .value_name["DATE"]()
    )
    cmd.add_argument(
        Argument("until", help="Show commits before date")
        .long["until"]()
        .value_name["DATE"]()
    )
    # Append: multiple --grep patterns
    cmd.add_argument(
        Argument("grep", help="Filter by commit message (repeatable)")
        .long["grep"]()
        .append()
    )
    # Aliases
    cmd.add_argument(
        Argument("format", help="Pretty-print format")
        .long["format"]()
        .alias_name["pretty"]()
        .choice["oneline"]()
        .choice["short"]()
        .choice["medium"]()
        .choice["full"]()
        .choice["fuller"]()
    )
    cmd.set_run_function(handle_log)
    return cmd^


def generate_remote_subcommand() raises -> Command:
    """Builds the 'remote' subcommand with its sub-subcommands."""
    var cmd = Command("remote", "Manage set of tracked repositories")

    var remote_add = Command("add", "Add a new remote")
    remote_add.add_argument(
        Argument("name", help="Remote name").positional().required()
    )
    remote_add.add_argument(
        Argument("url", help="Remote URL").positional().required()
    )
    remote_add.add_argument(
        Argument("fetch", help="Fetch the remote after adding")
        .long["fetch"]()
        .short["f"]()
        .flag()
    )
    remote_add.help_on_no_arguments()
    remote_add.set_run_function(handle_remote_add)
    cmd.add_subcommand(remote_add^)

    var remote_remove = Command("remove", "Remove a remote")
    remote_remove.add_argument(
        Argument("name", help="Remote name to remove").positional().required()
    )
    remote_remove.help_on_no_arguments()
    remote_remove.set_run_function(handle_remote_remove)
    cmd.add_subcommand(remote_remove^)

    var remote_rename = Command("rename", "Rename a remote")
    remote_rename.add_argument(
        Argument("old", help="Current remote name").positional().required()
    )
    remote_rename.add_argument(
        Argument("new", help="New remote name").positional().required()
    )
    remote_rename.help_on_no_arguments()
    remote_rename.set_run_function(handle_remote_rename)
    cmd.add_subcommand(remote_rename^)

    var remote_show = Command("show", "Show information about a remote")
    remote_show.add_argument(
        Argument("name", help="Remote name").positional().required()
    )
    remote_show.help_on_no_arguments()
    remote_show.set_run_function(handle_remote_show)
    cmd.add_subcommand(remote_show^)

    cmd.help_on_no_arguments()
    return cmd^


def generate_branch_subcommand() raises -> Command:
    """Builds the 'branch' subcommand."""
    var cmd = Command("branch", "List, create, or delete branches")
    var aliases: List[String] = ["br"]
    cmd.command_aliases(aliases^)
    cmd.add_argument(Argument("name", help="Branch name").positional())
    cmd.add_argument(
        Argument("delete", help="Delete a branch")
        .long["delete"]()
        .short["d"]()
        .flag()
    )
    cmd.add_argument(
        Argument("force-delete", help="Force delete a branch")
        .long["force-delete"]()
        .short["D"]()
        .flag()
    )
    cmd.add_argument(
        Argument("list", help="List branches (default)").long["list"]().flag()
    )
    cmd.add_argument(
        Argument("all-branches", help="List both local and remote branches")
        .long["all"]()
        .short["a"]()
        .flag()
    )
    cmd.add_argument(
        Argument("move", help="Rename branch")
        .long["move"]()
        .short["m"]()
        .flag()
    )
    cmd.set_run_function(handle_branch)
    return cmd^


def generate_diff_subcommand() raises -> Command:
    """Builds the 'diff' subcommand."""
    var cmd = Command("diff", "Show changes between commits, trees, etc.")
    var aliases: List[String] = ["di"]
    cmd.command_aliases(aliases^)
    cmd.add_argument(Argument("path", help="Path to diff").positional())
    cmd.add_argument(
        Argument("staged", help="Show staged changes")
        .long["staged"]()
        .alias_name["cached"]()
        .flag()
    )
    cmd.add_argument(
        Argument("stat", help="Show diffstat instead of patch")
        .long["stat"]()
        .flag()
    )
    cmd.add_argument(
        Argument("name-only", help="Show only names of changed files")
        .long["name-only"]()
        .flag()
    )
    # Nargs: unified context lines
    cmd.add_argument(
        Argument("unified", help="Generate diffs with N lines of context")
        .long["unified"]()
        .short["U"]()
        .value_name["N"]()
    )
    cmd.set_run_function(handle_diff)
    return cmd^


def generate_tag_subcommand() raises -> Command:
    """Builds the 'tag' subcommand."""
    var cmd = Command("tag", "Create, list, or delete tags")
    cmd.add_argument(Argument("tagname", help="Tag name").positional())
    cmd.add_argument(
        Argument("annotate", help="Create an annotated tag")
        .long["annotate"]()
        .short["a"]()
        .flag()
    )
    cmd.add_argument(
        Argument("tag-message", help="Tag message (for annotated tags)")
        .long["message"]()
        .short["m"]()
    )
    cmd.add_argument(
        Argument("tag-delete", help="Delete a tag")
        .long["delete"]()
        .short["d"]()
        .flag()
    )
    cmd.add_argument(
        Argument("tag-list", help="List tags matching a pattern")
        .long["list"]()
        .short["l"]()
        .flag()
    )
    cmd.add_argument(
        Argument("force-tag", help="Replace an existing tag")
        .long["force"]()
        .short["f"]()
        .flag()
    )
    cmd.set_run_function(handle_tag)
    return cmd^


def generate_stash_subcommand() raises -> Command:
    """Builds the 'stash' subcommand with its sub-subcommands."""
    var cmd = Command("stash", "Stash changes in working directory")
    var aliases: List[String] = ["st"]
    cmd.command_aliases(aliases^)

    var stash_push = Command("push", "Save local modifications to a new stash")
    stash_push.add_argument(
        Argument("stash-message", help="Stash message")
        .long["message"]()
        .short["m"]()
    )
    stash_push.add_argument(
        Argument("keep-index", help="Keep staged changes in the index")
        .long["keep-index"]()
        .short["k"]()
        .flag()
    )
    stash_push.add_argument(
        Argument("include-untracked", help="Also stash untracked files")
        .long["include-untracked"]()
        .short["u"]()
        .flag()
    )
    stash_push.set_run_function(handle_stash_push)
    cmd.add_subcommand(stash_push^)

    var stash_pop = Command("pop", "Apply and remove the top stash entry")
    stash_pop.add_argument(
        Argument("stash-index", help="Stash index to pop")
        .positional()
        .default["0"]()
    )
    stash_pop.set_run_function(handle_stash_pop)
    cmd.add_subcommand(stash_pop^)

    var stash_list = Command("list", "List all stash entries")
    stash_list.set_run_function(handle_stash_list)
    cmd.add_subcommand(stash_list^)

    var stash_drop = Command("drop", "Remove a single stash entry")
    stash_drop.add_argument(
        Argument("stash-index", help="Stash index to drop")
        .positional()
        .default["0"]()
    )
    stash_drop.set_run_function(handle_stash_drop)
    cmd.add_subcommand(stash_drop^)

    var stash_apply = Command("apply", "Apply a stash without removing it")
    stash_apply.add_argument(
        Argument("stash-index", help="Stash index to apply")
        .positional()
        .default["0"]()
    )
    stash_apply.set_run_function(handle_stash_apply)
    cmd.add_subcommand(stash_apply^)

    cmd.help_on_no_arguments()
    return cmd^


def generate_config_subcommand() raises -> Command:
    """Builds the 'config' subcommand with its sub-subcommands."""
    var cmd = Command("config", "Get and set repository or global options")

    var config_get = Command("get", "Get a configuration value")
    config_get.add_argument(
        Argument("key", help="Configuration key (e.g. user.name)")
        .positional()
        .required()
    )
    config_get.help_on_no_arguments()
    config_get.set_run_function(handle_config_get)
    cmd.add_subcommand(config_get^)

    var config_set = Command("set", "Set a configuration value")
    config_set.add_argument(
        Argument("key", help="Configuration key (e.g. user.name)")
        .positional()
        .required()
    )
    config_set.add_argument(
        Argument("value", help="Value to set").positional().required()
    )
    config_set.add_argument(
        Argument("global", help="Write to global config instead of local")
        .long["global"]()
        .flag()
    )
    config_set.help_on_no_arguments()
    config_set.set_run_function(handle_config_set)
    cmd.add_subcommand(config_set^)

    var config_list = Command("list", "List all configuration entries")
    config_list.set_run_function(handle_config_list)
    cmd.add_subcommand(config_list^)

    var config_unset = Command("unset", "Remove a configuration entry")
    config_unset.add_argument(
        Argument("key", help="Configuration key to remove")
        .positional()
        .required()
    )
    config_unset.add_argument(
        Argument("global", help="Remove from global config instead of local")
        .long["global"]()
        .flag()
    )
    config_unset.help_on_no_arguments()
    config_unset.set_run_function(handle_config_unset)
    cmd.add_subcommand(config_unset^)

    cmd.help_on_no_arguments()
    return cmd^


# ═══════════════════════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════════════════════


def main() raises:
    var app = Command(
        "mgit",
        "A git-like CLI to demonstrate argmojo with subcommands.",
        version="2.47.0",
    )

    # ── Persistent (global) flags ────────────────────────────────────────
    app.add_argument(
        Argument("verbose", help="Be more verbose")
        .long["verbose"]()
        .short["v"]()
        .count()
        .persistent()
    )
    app.add_argument(
        Argument("no-pager", help="Do not pipe output into a pager")
        .long["no-pager"]()
        .flag()
        .persistent()
    )
    app.add_argument(
        Argument("git-dir", help="Set the path to the repository (.git)")
        .long["git-dir"]()
        .value_name["PATH"]()
        .persistent()
    )
    app.add_argument(
        Argument("work-tree", help="Set the path to the working tree")
        .long["work-tree"]()
        .value_name["PATH"]()
        .persistent()
    )

    # ── Custom tips ──────────────────────────────────────────────────────
    app.add_tip("Run 'mgit <command> --help' for detailed help on a command.")

    # ── Subcommands ──────────────────────────────────────────────────────
    app.add_subcommand(generate_clone_subcommand())
    app.add_subcommand(generate_init_subcommand())
    app.add_subcommand(generate_add_subcommand())
    app.add_subcommand(generate_commit_subcommand())
    app.add_subcommand(generate_push_subcommand())
    app.add_subcommand(generate_pull_subcommand())
    app.add_subcommand(generate_log_subcommand())
    app.add_subcommand(generate_remote_subcommand())
    app.add_subcommand(generate_branch_subcommand())
    app.add_subcommand(generate_diff_subcommand())
    app.add_subcommand(generate_tag_subcommand())
    app.add_subcommand(generate_stash_subcommand())
    app.add_subcommand(generate_config_subcommand())

    # ── Show help when invoked with no arguments ─────────────────────────
    app.help_on_no_arguments()

    # ── Auto-dispatch ────────────────────────────────────────────────────
    app.execute()
