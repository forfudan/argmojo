"""Example: a git-like CLI to demonstrate argmojo with subcommands.

Simulates the interface of git.  Only argument parsing is performed;
no actual version-control operations are implemented.

Showcases: subcommands, persistent (global) flags, per-command positional
args, boolean flags, count flags, negatable flags, choices, default values,
required arguments, metavar, hidden arguments, append/collect, value
delimiter, mutually exclusive groups, required-together groups, conditional
requirements, numeric range validation, aliases, deprecated arguments,
Commands section in help, Global Options heading, full command path in
child help/errors, unknown subcommand error, and custom tips.

Try these:
  git --help                        # root help (Commands + Global Options)
  git --version
  git clone --help                  # child help with full path
  git clone https://example.com/repo.git my-project --depth 1
  git commit -am "initial commit"
  git log --oneline -n 20 --author "Alice"
  git remote add origin https://example.com/repo.git
  git -v push origin main --force --tags
"""

from argmojo import Argument, Command


fn main() raises:
    var app = Command(
        "git",
        "A git-like CLI to demonstrate argmojo with subcommands.",
        version="2.47.0",
    )

    # ── Persistent (global) flags ────────────────────────────────────────
    app.add_argument(
        Argument("verbose", help="Be more verbose")
        .long("verbose")
        .short("v")
        .count()
        .persistent()
    )
    app.add_argument(
        Argument("no-pager", help="Do not pipe output into a pager")
        .long("no-pager")
        .flag()
        .persistent()
    )
    app.add_argument(
        Argument("git-dir", help="Set the path to the repository (.git)")
        .long("git-dir")
        .metavar("PATH")
        .persistent()
    )
    app.add_argument(
        Argument("work-tree", help="Set the path to the working tree")
        .long("work-tree")
        .metavar("PATH")
        .persistent()
    )

    # ── Custom tips ──────────────────────────────────────────────────────
    app.add_tip("Run 'git <command> --help' for detailed help on a command.")

    # ── clone ────────────────────────────────────────────────────────────
    var clone = Command("clone", "Clone a repository into a new directory")
    clone.add_argument(
        Argument("repository", help="Repository URL or path")
        .positional()
        .required()
    )
    clone.add_argument(
        Argument("directory", help="Target directory name").positional()
    )
    clone.add_argument(
        Argument("depth", help="Create a shallow clone with N commits")
        .long("depth")
        .metavar("N")
        .range(1, 999999)
    )
    clone.add_argument(
        Argument("branch", help="Check out this branch instead of HEAD")
        .long("branch")
        .short("b")
    )
    clone.add_argument(
        Argument("bare", help="Make a bare repository").long("bare").flag()
    )
    clone.add_argument(
        Argument("recurse-submodules", help="Initialize submodules")
        .long("recurse-submodules")
        .flag()
    )
    clone.help_on_no_args()
    app.add_subcommand(clone^)

    # ── init ─────────────────────────────────────────────────────────────
    var init = Command("init", "Create an empty Git repository")
    init.add_argument(
        Argument("directory", help="Directory to initialize")
        .positional()
        .default(".")
    )
    init.add_argument(
        Argument("bare", help="Create a bare repository").long("bare").flag()
    )
    var templates: List[String] = ["default", "minimal"]
    init.add_argument(
        Argument("template", help="Template directory")
        .long("template")
        .choices(templates^)
        .default("default")
    )
    init.add_argument(
        Argument("initial-branch", help="Name for the initial branch")
        .long("initial-branch")
        .short("b")
        .default("main")
    )
    app.add_subcommand(init^)

    # ── add ──────────────────────────────────────────────────────────────
    var add = Command("add", "Add file contents to the index")
    add.add_argument(Argument("pathspec", help="Files to add").positional())
    add.add_argument(
        Argument("all", help="Add all changed files")
        .long("all")
        .short("A")
        .flag()
    )
    add.add_argument(
        Argument("force", help="Allow adding otherwise ignored files")
        .long("force")
        .short("f")
        .flag()
    )
    add.add_argument(
        Argument("dry-run", help="Show what would be added without adding")
        .long("dry-run")
        .short("n")
        .flag()
    )
    add.add_argument(
        Argument("patch", help="Interactively select hunks to add")
        .long("patch")
        .short("p")
        .flag()
    )
    app.add_subcommand(add^)

    # ── commit ───────────────────────────────────────────────────────────
    var commit = Command("commit", "Record changes to the repository")
    commit.add_argument(
        Argument("message", help="Commit message")
        .long("message")
        .short("m")
        .required()
    )
    commit.add_argument(
        Argument("all", help="Automatically stage modified/deleted files")
        .long("all")
        .short("a")
        .flag()
    )
    commit.add_argument(
        Argument("amend", help="Amend the previous commit").long("amend").flag()
    )
    commit.add_argument(
        Argument("no-verify", help="Skip pre-commit and commit-msg hooks")
        .long("no-verify")
        .short("n")
        .flag()
    )
    commit.add_argument(
        Argument("author", help="Override the commit author")
        .long("author")
        .metavar("NAME")
    )
    # Deprecated flag
    commit.add_argument(
        Argument("cleanup-mode", help="Set cleanup mode (legacy)")
        .long("cleanup-mode")
        .deprecated("Use --cleanup instead")
    )
    app.add_subcommand(commit^)

    # ── push ─────────────────────────────────────────────────────────────
    var push = Command("push", "Update remote refs along with objects")
    push.add_argument(
        Argument("remote", help="Remote name").positional().default("origin")
    )
    push.add_argument(
        Argument("refspec", help="Branch or refspec to push").positional()
    )
    push.add_argument(
        Argument("force", help="Force push (use with caution!)")
        .long("force")
        .short("f")
        .flag()
    )
    push.add_argument(
        Argument("set-upstream", help="Set upstream for the branch")
        .long("set-upstream")
        .short("u")
        .flag()
    )
    push.add_argument(
        Argument("tags", help="Push all tags").long("tags").flag()
    )
    push.add_argument(
        Argument("dry-run", help="Simulate the push without sending")
        .long("dry-run")
        .short("n")
        .flag()
    )
    # Mutually exclusive: force strategies
    push.add_argument(
        Argument("force-with-lease", help="Safe force push")
        .long("force-with-lease")
        .flag()
    )
    var force_group: List[String] = ["force", "force-with-lease"]
    push.mutually_exclusive(force_group^)
    app.add_subcommand(push^)

    # ── pull ─────────────────────────────────────────────────────────────
    var pull = Command("pull", "Fetch from and integrate with a remote")
    pull.add_argument(
        Argument("remote", help="Remote name").positional().default("origin")
    )
    pull.add_argument(Argument("branch", help="Branch to pull").positional())
    # Mutually exclusive: merge strategy
    pull.add_argument(
        Argument("rebase", help="Rebase instead of merge").long("rebase").flag()
    )
    pull.add_argument(
        Argument("no-rebase", help="Merge instead of rebase")
        .long("no-rebase")
        .flag()
    )
    var merge_strat: List[String] = ["rebase", "no-rebase"]
    pull.mutually_exclusive(merge_strat^)
    pull.add_argument(
        Argument("autostash", help="Stash changes before pull, reapply after")
        .long("autostash")
        .flag()
    )
    app.add_subcommand(pull^)

    # ── log ──────────────────────────────────────────────────────────────
    var log = Command("log", "Show commit logs")
    log.add_argument(
        Argument("oneline", help="Compact one-line format")
        .long("oneline")
        .flag()
    )
    log.add_argument(
        Argument("graph", help="Draw ASCII commit graph").long("graph").flag()
    )
    log.add_argument(
        Argument("number", help="Limit number of commits shown")
        .long("number")
        .short("n")
        .metavar("N")
        .range(1, 999999)
    )
    log.add_argument(
        Argument("author", help="Filter by author")
        .long("author")
        .metavar("PATTERN")
    )
    log.add_argument(
        Argument("since", help="Show commits after date")
        .long("since")
        .metavar("DATE")
    )
    log.add_argument(
        Argument("until", help="Show commits before date")
        .long("until")
        .metavar("DATE")
    )
    # Append: multiple --grep patterns
    log.add_argument(
        Argument("grep", help="Filter by commit message (repeatable)")
        .long("grep")
        .append()
    )
    # Aliases
    var format_aliases: List[String] = ["pretty"]
    var format_choices: List[String] = [
        "oneline",
        "short",
        "medium",
        "full",
        "fuller",
    ]
    log.add_argument(
        Argument("format", help="Pretty-print format")
        .long("format")
        .aliases(format_aliases^)
        .choices(format_choices^)
    )
    app.add_subcommand(log^)

    # ── remote ───────────────────────────────────────────────────────────
    var remote = Command("remote", "Manage set of tracked repositories")
    # remote itself has subcommands: add, remove, rename, show
    var remote_add = Command("add", "Add a new remote")
    remote_add.add_argument(
        Argument("name", help="Remote name").positional().required()
    )
    remote_add.add_argument(
        Argument("url", help="Remote URL").positional().required()
    )
    remote_add.add_argument(
        Argument("fetch", help="Fetch the remote after adding")
        .long("fetch")
        .short("f")
        .flag()
    )
    remote_add.help_on_no_args()
    remote.add_subcommand(remote_add^)

    var remote_remove = Command("remove", "Remove a remote")
    remote_remove.add_argument(
        Argument("name", help="Remote name to remove").positional().required()
    )
    remote_remove.help_on_no_args()
    remote.add_subcommand(remote_remove^)

    var remote_rename = Command("rename", "Rename a remote")
    remote_rename.add_argument(
        Argument("old", help="Current remote name").positional().required()
    )
    remote_rename.add_argument(
        Argument("new", help="New remote name").positional().required()
    )
    remote_rename.help_on_no_args()
    remote.add_subcommand(remote_rename^)

    var remote_show = Command("show", "Show information about a remote")
    remote_show.add_argument(
        Argument("name", help="Remote name").positional().required()
    )
    remote_show.help_on_no_args()
    remote.add_subcommand(remote_show^)

    remote.help_on_no_args()
    app.add_subcommand(remote^)

    # ── branch ───────────────────────────────────────────────────────────
    var branch = Command("branch", "List, create, or delete branches")
    branch.add_argument(Argument("name", help="Branch name").positional())
    branch.add_argument(
        Argument("delete", help="Delete a branch")
        .long("delete")
        .short("d")
        .flag()
    )
    branch.add_argument(
        Argument("force-delete", help="Force delete a branch")
        .long("force-delete")
        .short("D")
        .flag()
    )
    branch.add_argument(
        Argument("list", help="List branches (default)").long("list").flag()
    )
    branch.add_argument(
        Argument("all-branches", help="List both local and remote branches")
        .long("all")
        .short("a")
        .flag()
    )
    branch.add_argument(
        Argument("move", help="Rename branch").long("move").short("m").flag()
    )
    app.add_subcommand(branch^)

    # ── diff ─────────────────────────────────────────────────────────────
    var diff = Command("diff", "Show changes between commits, trees, etc.")
    diff.add_argument(Argument("path", help="Path to diff").positional())
    diff.add_argument(
        Argument("staged", help="Show staged changes").long("staged").flag()
    )
    # Alias for --staged
    var cached_aliases: List[String] = ["staged"]
    diff.add_argument(
        Argument("cached", help="Synonym for --staged")
        .long("cached")
        .aliases(cached_aliases^)
        .flag()
        .hidden()
    )
    diff.add_argument(
        Argument("stat", help="Show diffstat instead of patch")
        .long("stat")
        .flag()
    )
    diff.add_argument(
        Argument("name-only", help="Show only names of changed files")
        .long("name-only")
        .flag()
    )
    # Nargs: unified context lines
    diff.add_argument(
        Argument("unified", help="Generate diffs with N lines of context")
        .long("unified")
        .short("U")
        .metavar("N")
    )
    app.add_subcommand(diff^)

    # ── tag ──────────────────────────────────────────────────────────────
    var tag = Command("tag", "Create, list, or delete tags")
    tag.add_argument(Argument("tagname", help="Tag name").positional())
    tag.add_argument(
        Argument("annotate", help="Create an annotated tag")
        .long("annotate")
        .short("a")
        .flag()
    )
    tag.add_argument(
        Argument("tag-message", help="Tag message (for annotated tags)")
        .long("message")
        .short("m")
    )
    tag.add_argument(
        Argument("tag-delete", help="Delete a tag")
        .long("delete")
        .short("d")
        .flag()
    )
    tag.add_argument(
        Argument("tag-list", help="List tags matching a pattern")
        .long("list")
        .short("l")
        .flag()
    )
    tag.add_argument(
        Argument("force-tag", help="Replace an existing tag")
        .long("force")
        .short("f")
        .flag()
    )
    app.add_subcommand(tag^)

    # ── stash ────────────────────────────────────────────────────────────
    var stash = Command("stash", "Stash changes in working directory")
    stash.add_argument(
        Argument("stash-message", help="Stash message")
        .long("message")
        .short("m")
    )
    stash.add_argument(
        Argument("keep-index", help="Keep staged changes in the index")
        .long("keep-index")
        .short("k")
        .flag()
    )
    stash.add_argument(
        Argument("include-untracked", help="Also stash untracked files")
        .long("include-untracked")
        .short("u")
        .flag()
    )
    app.add_subcommand(stash^)

    # ── Show help when invoked with no arguments ─────────────────────────
    app.help_on_no_args()

    # ── Parse & display ──────────────────────────────────────────────────
    var result = app.parse()
    app.print_summary(result)
