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


fn _is_wide_codepoint(codepoint: Int) -> Bool:
    """Returns True if the Unicode codepoint occupies two terminal columns.

    Covers CJK Unified Ideographs, CJK Compatibility Ideographs,
    CJK Extension blocks (A-J), Fullwidth Forms, and a selection of
    other commonly wide ranges (Hangul Syllables, CJK Symbols, etc.).
    """

    # Unicode East Asian Width W/F 範圍表（Unicode 16.0）
    # 相鄰區塊已合併以減少分支數（38 → 15）。
    #
    # ── 合併區 [0x2E80, 0x9FFF] ──────────────────────────────────────
    # [0x2E80,  0x2EFF]  # 中日韓漢字部首補充
    # [0x2F00,  0x2FDF]  # 康熙部首
    # [0x2FF0,  0x2FFF]  # 表意文字描述字符
    # [0x3000,  0x303F]  # 中日韓符號和標點
    # [0x3040,  0x309F]  # 平假名
    # [0x30A0,  0x30FF]  # 片假名
    # [0x3100,  0x312F]  # 注音符號
    # [0x3130,  0x318F]  # 諺文兼容字母
    # [0x3190,  0x319F]  # 漢文訓讀
    # [0x31A0,  0x31BF]  # 注音符號擴展
    # [0x31C0,  0x31EF]  # 中日韓筆畫
    # [0x31F0,  0x31FF]  # 片假名音標擴展
    # [0x3200,  0x32FF]  # 中日韓帶圈字符及月份
    # [0x3300,  0x33FF]  # 中日韓兼容字符
    # [0x3400,  0x4DBF]  # 中日韓統一表意文字擴展區A
    # [0x4DC0,  0x4DFF]  # 易經六十四卦
    # [0x4E00,  0x9FFF]  # 中日韓統一表意文字
    #
    # ── 合併區 [0xE000, 0xFAFF] ──────────────────────────────────────
    # [0xE000,  0xF8FF]  # 私用區（宇浩字根在此區，EAW=A）
    # [0xF900,  0xFAFF]  # 中日韓兼容表意文字
    #
    # ── 合併區 [0x16FE0, 0x18D7F] ────────────────────────────────────
    # [0x16FE0, 0x16FFF] # 表意文字符號和標點
    # [0x17000, 0x187FF] # 西夏文
    # [0x18800, 0x18AFF] # 西夏文部件
    # [0x18B00, 0x18CFF] # 契丹小字
    # [0x18D00, 0x18D7F] # 西夏文補充
    #
    # ── 合併區 [0x1B000, 0x1B16F] ────────────────────────────────────
    # [0x1B000, 0x1B0FF] # 補充假名
    # [0x1B100, 0x1B12F] # 假名擴展
    # [0x1B130, 0x1B16F] # 小型假名擴展
    #
    # ── 獨立區 ────────────────────────────────────────────────────────
    # [0x1100,  0x115F]  # 諺文字母初聲
    # [0xA960,  0xA97C]  # 諺文字母擴展A
    # [0xAC00,  0xD7AF]  # 韓文音節
    # [0xFE30,  0xFE4F]  # 中日韓兼容形式
    # [0xFF01,  0xFF60]  # 全形ASCII和標點
    # [0xFFE0,  0xFFE6]  # 全形特殊符號
    # [0x1D300, 0x1D35F] # 太玄經卦爻
    # [0x1F200, 0x1F2FF] # 帶圈表意文字補充
    # [0x20000, 0x2EE5F] # 中日韓統一表意文字擴展區BCDEFI
    # [0x2F800, 0x2FA1F] # 中日韓兼容表意文字補充
    # [0x30000, 0x3347F] # 中日韓統一表意文字擴展區GHJ
    #
    # ── 已排除（EAW ≠ W/F）───────────────────────────────────────────
    # [0x1160,  0x11FF]  # 諺文字母中聲/終聲 — EAW=N
    # [0x2600,  0x26FF]  # 雜項符號 — 多數 EAW=N
    # [0xD7B0,  0xD7FF]  # 諺文字母擴展B — EAW=N
    # [0x1F000, 0x1F02F] # 麻將牌 — 僅 U+1F004 為 W
    # [0x1FA00, 0x1FA6F] # 棋類符號 — EAW=N

    # Fast path: ASCII and Latin/Greek/Cyrillic/Arabic etc.
    if codepoint < 0x1100:
        return False
    # Fast path: above all known wide ranges.
    if codepoint > 0x3347F:
        return False

    # ── BMP: U+0000 – U+FFFF ────────────────────────────────────────
    if codepoint <= 0xFFFF:
        # CJK 大區（17 個相鄰區塊合併）
        if codepoint >= 0x2E80 and codepoint <= 0x9FFF:
            return True
        # 韓文音節
        if codepoint >= 0xAC00 and codepoint <= 0xD7AF:
            return True
        # 私用區 + 中日韓兼容表意文字
        if codepoint >= 0xE000 and codepoint <= 0xFAFF:
            return True
        # 全形 ASCII 和標點
        if codepoint >= 0xFF01 and codepoint <= 0xFF60:
            return True
        # 諺文字母擴展A
        if codepoint >= 0xA960 and codepoint <= 0xA97C:
            return True
        # 全形特殊符號
        if codepoint >= 0xFFE0 and codepoint <= 0xFFE6:
            return True
        # 中日韓兼容形式
        if codepoint >= 0xFE30 and codepoint <= 0xFE4F:
            return True
        # 諺文字母初聲（0x1100 ≤ cp guaranteed by early exit）
        return codepoint <= 0x115F

    # ── SMP/SIP/TIP: U+10000+ ───────────────────────────────────────
    # CJK 統一漢字擴展 BCDEFI
    if codepoint >= 0x20000 and codepoint <= 0x2EE5F:
        return True
    # CJK 統一漢字擴展 GHJ（≤ 0x3347F guaranteed by early exit）
    if codepoint >= 0x30000:
        return True
    # 表意符號 + 西夏文 + 西夏部件 + 契丹小字 + 西夏補充
    if codepoint >= 0x16FE0 and codepoint <= 0x18D7F:
        return True
    # 假名補充 + 假名擴展 + 小型假名擴展
    if codepoint >= 0x1B000 and codepoint <= 0x1B16F:
        return True
    # CJK 兼容表意文字補充
    if codepoint >= 0x2F800 and codepoint <= 0x2FA1F:
        return True
    # 帶圈表意文字補充
    if codepoint >= 0x1F200 and codepoint <= 0x1F2FF:
        return True
    # 太玄經卦爻
    if codepoint >= 0x1D300 and codepoint <= 0x1D35F:
        return True
    return False


fn _display_width(s: String) -> Int:
    """Returns the terminal display width of a string.

    CJK characters and fullwidth forms count as 2 columns each.  ANSI
    escape sequences (e.g. colour codes) are skipped and contribute 0.
    All other visible characters count as 1.  This function is used by
    the help formatter to align columns correctly with mixed CJK/ASCII
    text.

    Args:
        s: The string to measure.

    Returns:
        The number of terminal columns the string would occupy.
    """
    var width = 0
    var i = 0
    var n = len(s)
    while i < n:
        var b0 = Int(s.as_bytes()[i])
        # Skip ANSI escape sequences: ESC [ ... final_byte.
        if b0 == 0x1B and i + 1 < n and Int(s.as_bytes()[i + 1]) == 0x5B:
            i += 2  # skip ESC [
            while i < n:
                var c = Int(s.as_bytes()[i])
                i += 1
                # Final byte of CSI sequence is in 0x40–0x7E range.
                if c >= 0x40 and c <= 0x7E:
                    break
            continue
        # Decode UTF-8 codepoint.
        var codepoint: Int
        var seq_len: Int
        if b0 < 0x80:
            codepoint = b0
            seq_len = 1
        elif b0 < 0xC0:
            # Continuation byte (shouldn't start a sequence); skip.
            i += 1
            continue
        elif b0 < 0xE0:
            seq_len = 2
            codepoint = b0 & 0x1F
        elif b0 < 0xF0:
            seq_len = 3
            codepoint = b0 & 0x0F
        else:
            seq_len = 4
            codepoint = b0 & 0x07
        for j in range(1, seq_len):
            if i + j < n:
                codepoint = (codepoint << 6) | (Int(s.as_bytes()[i + j]) & 0x3F)
        i += seq_len
        # Determine display width of this codepoint.
        if _is_wide_codepoint(codepoint):
            width += 2
        else:
            width += 1
    return width


fn _looks_like_number(token: String) -> Bool:
    """Returns True if *token* is a negative-number literal.

    Recognises the forms ``-N``, ``-N.N``, ``-.N``, ``-NeX``, ``-N.NeX``,
    ``-N.NEX``, ``-.NE+X``, and the corresponding ``-Ne+X``, ``-Ne-X``,
    ``-NE+X``, ``-NE-X`` variants.
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

    Uses Levenshtein distance with a threshold of ``max(len(input)/2, 2)``.
    If no candidate is close enough, returns an empty string.

    Args:
        input: The unrecognised token the user typed.
        candidates: Valid option / subcommand names to compare against.

    Returns:
        A non-empty hint string such as ``". Did you mean '--verbose'?"``
        or ``""`` when there is no good match.
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
