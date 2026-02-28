"""ANSI colour constants and small utility functions used by ArgMojo."""

# ── ANSI colour codes ────────────────────────────────────────────────────────
comptime _RESET = "\x1b[0m"
comptime _BOLD_UL = "\x1b[1;4m"  # bold + underline (no colour)

# Bright foreground colours.
comptime _RED = "\x1b[91m"
comptime _GREEN = "\x1b[92m"
comptime _YELLOW = "\x1b[93m"
comptime _BLUE = "\x1b[94m"
comptime _MAGENTA = "\x1b[95m"
comptime _CYAN = "\x1b[96m"
comptime _WHITE = "\x1b[97m"
comptime _ORANGE = "\x1b[33m"  # dark yellow — renders as orange on most terminals

# Default colours.
comptime _DEFAULT_HEADER_COLOR = _YELLOW
comptime _DEFAULT_ARG_COLOR = _MAGENTA
comptime _DEFAULT_WARN_COLOR = _ORANGE
comptime _DEFAULT_ERROR_COLOR = _RED


# ── Utility functions ────────────────────────────────────────────────────────


fn _looks_like_number(token: String) -> Bool:
    """Returns True if *token* is a negative-number literal.

    Recognises the forms `-N`, `-N.N`, `-.N`, `-NeX`, `-N.NeX`, `-N.NEX`,
    `-.NE+X`, and the corresponding `-Ne+X`, `-Ne-X`, `-NE+X`, `-NE-X` variants.
    """
    if len(token) < 2 or token[0:1] != "-":
        return False
    var j = 1
    # Optional leading '.' after minus (e.g. -.5).
    if token[j : j + 1] == ".":
        j += 1
        if j >= len(token) or not (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            return False
    elif not (token[j : j + 1] >= "0" and token[j : j + 1] <= "9"):
        return False
    # Integer digits.
    while j < len(token) and (
        token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
    ):
        j += 1
    # Optional fractional part.
    if j < len(token) and token[j : j + 1] == ".":
        j += 1
        while j < len(token) and (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            j += 1
    # Optional exponent.
    if j < len(token) and (token[j : j + 1] == "e" or token[j : j + 1] == "E"):
        j += 1
        if j < len(token) and (
            token[j : j + 1] == "+" or token[j : j + 1] == "-"
        ):
            j += 1
        if j >= len(token) or not (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            return False
        while j < len(token) and (
            token[j : j + 1] >= "0" and token[j : j + 1] <= "9"
        ):
            j += 1
    return j == len(token)


fn _is_ascii_digit(ch: String) -> Bool:
    """Returns True if *ch* is a single ASCII digit character ('0'-'9')."""
    return ch >= "0" and ch <= "9"


fn _resolve_color(name: String) raises -> String:
    """Maps a user-facing colour name to its ANSI code.

    Accepted names (case-insensitive): RED, GREEN, YELLOW, BLUE,
    MAGENTA, PINK (alias for MAGENTA), CYAN, WHITE, ORANGE.

    Returns:
        The ANSI escape code for the colour.

    Raises:
        Error if the name is not recognised.
    """
    var upper = name.upper()
    if upper == "RED":
        return _RED
    if upper == "GREEN":
        return _GREEN
    if upper == "YELLOW":
        return _YELLOW
    if upper == "BLUE":
        return _BLUE
    if upper == "MAGENTA" or upper == "PINK":
        return _MAGENTA
    if upper == "CYAN":
        return _CYAN
    if upper == "WHITE":
        return _WHITE
    if upper == "ORANGE":
        return _ORANGE
    raise Error(
        "Unknown colour '"
        + name
        + "'. Choose from: RED, GREEN, YELLOW, BLUE, MAGENTA, PINK, CYAN,"
        " WHITE, ORANGE"
    )


fn _levenshtein(a: String, b: String) -> Int:
    """Returns the Levenshtein edit distance between two strings.

    The classic dynamic-programming algorithm, O(m*n) time and O(min(m,n))
    space (only the previous row is kept).
    """
    var m = len(a)
    var n = len(b)
    if m == 0:
        return n
    if n == 0:
        return m
    # Ensure the shorter string is used for the column dimension.
    if m < n:
        return _levenshtein(b, a)
    # prev holds the previous row of the DP matrix.
    var prev = List[Int]()
    for j in range(n + 1):
        prev.append(j)
    var curr = List[Int]()
    for _ in range(n + 1):
        curr.append(0)
    for i in range(1, m + 1):
        curr[0] = i
        for j in range(1, n + 1):
            var cost = 0 if a[i - 1 : i] == b[j - 1 : j] else 1
            var ins = prev[j] + 1
            var dele = curr[j - 1] + 1
            var sub = prev[j - 1] + cost
            # min of three
            var best = ins
            if dele < best:
                best = dele
            if sub < best:
                best = sub
            curr[j] = best
        # Swap rows.
        for j in range(n + 1):
            var tmp = prev[j]
            prev[j] = curr[j]
            curr[j] = tmp
    return prev[n]


fn _suggest_similar(input: String, candidates: List[String]) -> String:
    """Returns a 'Did you mean ...?' hint for the closest candidate.

    Uses Levenshtein distance with a threshold of `max(len(input)/2, 2)`.
    If no candidate is close enough, returns an empty string.

    Args:
        input: The unrecognised token the user typed.
        candidates: Valid option / subcommand names to compare against.

    Returns:
        A non-empty hint string such as `". Did you mean '--verbose'?"`
        or `""` when there is no good match.
    """
    if len(candidates) == 0:
        return ""
    var best_dist = len(input) + 1
    var best_name = String("")
    var threshold = len(input) // 2
    if threshold < 2:
        threshold = 2
    for i in range(len(candidates)):
        var d = _levenshtein(input, candidates[i])
        if d < best_dist:
            best_dist = d
            best_name = candidates[i]
    if best_dist <= threshold:
        return best_name
    return ""
