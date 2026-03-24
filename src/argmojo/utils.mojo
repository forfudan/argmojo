"""ANSI colour constants and small utility functions used by ArgMojo."""

from std.ffi import external_call

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


def _is_wide_codepoint(codepoint: Int) -> Bool:
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


def _display_width(s: String) -> Int:
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
    var in_ansi = False
    var saw_esc = False
    for cp in s.codepoints():
        var val = Int(cp)
        if saw_esc:
            saw_esc = False
            if val == 0x5B:  # '[' — start of CSI sequence
                in_ansi = True
                continue
            # Not a CSI introducer: treat this codepoint normally.
        if in_ansi:
            if val >= 0x40 and val <= 0x7E:  # CSI final byte
                in_ansi = False
            continue
        if val == 0x1B:  # ESC
            saw_esc = True
            continue
        if _is_wide_codepoint(val):
            width += 2
        else:
            width += 1
    return width


def _looks_like_number(token: String) -> Bool:
    """Returns True if *token* is a negative-number literal.

    Recognises the forms ``-N``, ``-N.N``, ``-.N``, ``-NeX``, ``-N.NeX``,
    ``-N.NEX``, ``-.NE+X``, and the corresponding ``-Ne+X``, ``-Ne-X``,
    ``-NE+X``, ``-NE-X`` variants.
    """
    if len(token) < 2 or not token.startswith("-"):
        return False
    var j = 1
    # Optional leading '.' after minus (e.g. -.5).
    if token[byte = j : j + 1] == ".":
        j += 1
        if j >= len(token) or not (
            token[byte = j : j + 1] >= "0" and token[byte = j : j + 1] <= "9"
        ):
            return False
    elif not (
        token[byte = j : j + 1] >= "0" and token[byte = j : j + 1] <= "9"
    ):
        return False
    # Integer digits.
    while j < len(token) and (
        token[byte = j : j + 1] >= "0" and token[byte = j : j + 1] <= "9"
    ):
        j += 1
    # Optional fractional part.
    if j < len(token) and token[byte = j : j + 1] == ".":
        j += 1
        while j < len(token) and (
            token[byte = j : j + 1] >= "0" and token[byte = j : j + 1] <= "9"
        ):
            j += 1
    # Optional exponent.
    if j < len(token) and (
        token[byte = j : j + 1] == "e" or token[byte = j : j + 1] == "E"
    ):
        j += 1
        if j < len(token) and (
            token[byte = j : j + 1] == "+" or token[byte = j : j + 1] == "-"
        ):
            j += 1
        if j >= len(token) or not (
            token[byte = j : j + 1] >= "0" and token[byte = j : j + 1] <= "9"
        ):
            return False
        while j < len(token) and (
            token[byte = j : j + 1] >= "0" and token[byte = j : j + 1] <= "9"
        ):
            j += 1
    return j == len(token)


def _is_ascii_digit(ch: String) -> Bool:
    """Returns True if *ch* is a single ASCII digit character ('0'-'9')."""
    return ch >= "0" and ch <= "9"


def _resolve_color[name: StringLiteral]() -> String:
    """Maps a user-facing colour name to its ANSI code at compile time.

    Accepted names (uppercase only): RED, GREEN, YELLOW, BLUE,
    MAGENTA, PINK (alias for MAGENTA), CYAN, WHITE, ORANGE.

    Parameters:
        name: The colour name (must be one of the accepted names).

    Returns:
        The ANSI escape code for the colour.
    """
    comptime assert (
        name == "RED"
        or name == "GREEN"
        or name == "YELLOW"
        or name == "BLUE"
        or name == "MAGENTA"
        or name == "PINK"
        or name == "CYAN"
        or name == "WHITE"
        or name == "ORANGE"
    ), (
        "Unknown colour '"
        + name
        + "'. Choose from: RED, GREEN, YELLOW, BLUE, MAGENTA, PINK,"
        " CYAN, WHITE, ORANGE"
    )

    comptime if name == "RED":
        return _RED
    elif name == "GREEN":
        return _GREEN
    elif name == "YELLOW":
        return _YELLOW
    elif name == "BLUE":
        return _BLUE
    elif name == "MAGENTA" or name == "PINK":
        return _MAGENTA
    elif name == "CYAN":
        return _CYAN
    elif name == "WHITE":
        return _WHITE
    else:  # ORANGE
        return _ORANGE


def _levenshtein(a: String, b: String) -> Int:
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
            var cost = 0 if a[byte = i - 1 : i] == b[byte = j - 1 : j] else 1
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


def _suggest_similar(input: String, candidates: List[String]) -> String:
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


def _has_fullwidth_chars(token: String) -> Bool:
    """Returns True if *token* contains any fullwidth ASCII character.

    Checks for fullwidth ASCII ``U+FF01``–``U+FF5E`` and fullwidth space
    ``U+3000``.  Used to decide whether to attempt auto-correction.
    """
    for cp in token.codepoints():
        var val = Int(cp)
        if (val >= 0xFF01 and val <= 0xFF5E) or val == 0x3000:
            return True
    return False


def _fullwidth_to_halfwidth(token: String) -> String:
    """Converts fullwidth ASCII characters to their halfwidth equivalents.

    Fullwidth ASCII range ``U+FF01``–``U+FF5E`` is mapped to
    ``U+0021``–``U+007E`` by subtracting ``0xFEE0``.

    Fullwidth spaces (``U+3000``) are converted to regular spaces
    (``U+0020``).

    Characters outside these ranges are left unchanged.
    """
    var result = String("")
    for cp in token.codepoints():
        var val = Int(cp)
        if val >= 0xFF01 and val <= 0xFF5E:
            result += chr(val - 0xFEE0)
        elif val == 0x3000:
            result += " "
        else:
            result += chr(val)
    return result


def _split_on_fullwidth_spaces(token: String) -> List[String]:
    """Splits a token on fullwidth spaces (``U+3000``) after fullwidth correction.

    After converting fullwidth ASCII to halfwidth, embedded fullwidth
    spaces become regular spaces.  This function splits the corrected
    token on space boundaries and returns the non-empty parts.

    Args:
        token: The token to split.

    Returns:
        A list of non-empty, fullwidth-corrected substrings. If no
        fullwidth spaces are present, the list contains the corrected
        token as a single element.
    """
    var converted = _fullwidth_to_halfwidth(token)
    var parts = converted.split(" ")
    var result = List[String]()
    for k in range(len(parts)):
        var part = String(String(parts[k]).strip())
        if len(part) > 0:
            result.append(part)
    return result^


def _correct_cjk_punctuation(token: String) -> String:
    """Replaces common CJK punctuation with ASCII equivalents.

    This handles characters outside the fullwidth ASCII range
    (``U+FF01``–``U+FF5E``) that CJK users may accidentally type:

    - ``U+2014`` EM DASH (——) → ``U+002D`` HYPHEN-MINUS (-)

    Used as a pre-Levenshtein error recovery step: when an unknown
    option is encountered, try this substitution before computing
    edit distance.

    Args:
        token: The token to correct.

    Returns:
        The token with CJK punctuation replaced by ASCII equivalents.
    """
    var result = String("")
    for cp in token.codepoints():
        var val = Int(cp)
        if val == 0x2014:  # EM DASH → hyphen-minus
            result += "-"
        else:
            result += chr(val)
    return result


# ── Terminal echo control (POSIX) ────────────────────────────────────────────
# Used by .password() to suppress typed characters during interactive
# prompting.  These wrap tcgetattr(3) / tcsetattr(3) via external_call.
#
# The termios struct is represented as a flat List[UInt32] buffer large
# enough to hold the platform's struct (see _TERMIOS_BUF_LEN below).  The
# c_lflag field (type tcflag_t) does not have the same layout everywhere:
#   - macOS arm64: tcflag_t = unsigned long (8 bytes) → c_lflag at byte 24
#                  → UInt32 index 6
#   - Linux x86-64: tcflag_t = unsigned int (4 bytes) → c_lflag at byte 12
#                   → UInt32 index 3
# The helper _lflag_offset() inspects the buffer and picks the correct
# index by finding which word has the ECHO bit set.
#
# ECHO is 0x8, TCSANOW is 0.  If tcgetattr(3) fails (e.g. stdin is not a
# terminal), _disable_echo() returns an empty List[UInt32] and no echo
# changes are applied.  _restore_echo() returns False if it cannot restore
# the saved settings.  Callers should treat these cases as "echo control
# unavailable" and fall back to normal (visible) input.

comptime _TERMIOS_BUF_LEN = 24  # 24 × UInt32 = 96 bytes ≥ sizeof(struct termios)
# c_lflag UInt32 offset varies by platform (see _lflag_offset below).
comptime _ECHO: UInt32 = 0x00000008
comptime _TCSANOW = 0


@always_inline
def _lflag_offset(buf: List[UInt32]) -> Int:
    """Returns the UInt32 index of c_lflag in a tcgetattr buffer.

    On macOS (tcflag_t = 8 bytes), c_lflag is at UInt32 offset 6.
    On Linux (tcflag_t = 4 bytes), c_lflag is at UInt32 offset 3.
    Detects the layout by checking which word has the ECHO bit set.
    Returns -1 if the layout cannot be determined safely (e.g. ECHO
    is already disabled in both candidate positions).
    """
    var has_echo_6 = (buf[6] & _ECHO) != 0
    var has_echo_3 = (buf[3] & _ECHO) != 0
    if has_echo_6 and not has_echo_3:
        return 6
    if has_echo_3 and not has_echo_6:
        return 3
    # Both or neither have ECHO set — cannot reliably determine layout.
    return -1


def _disable_echo() -> List[UInt32]:
    """Disables terminal echo on stdin.

    Uses POSIX ``tcgetattr`` / ``tcsetattr`` to clear the ``ECHO``
    bit in ``c_lflag``.  Returns the original termios settings (so
    ``_restore_echo`` can restore them exactly), or an empty list if
    stdin is not a terminal or the termios layout cannot be determined
    safely.
    """
    var buf = List[UInt32](length=_TERMIOS_BUF_LEN, fill=0)
    var ptr = buf.unsafe_ptr()
    var rc = external_call["tcgetattr", Int, Int, Int](0, Int(ptr))
    if rc != 0:
        return List[UInt32]()
    # Save the original termios settings before modifying.
    var saved = buf.copy()
    var offset = _lflag_offset(buf)
    if offset < 0:
        # Cannot safely locate c_lflag — do not modify termios.
        return List[UInt32]()
    buf[offset] = buf[offset] & ~_ECHO
    ptr = buf.unsafe_ptr()
    rc = external_call["tcsetattr", Int, Int, Int, Int](0, _TCSANOW, Int(ptr))
    # Keep buf alive until tcsetattr has finished reading from it.
    # Without this, the compiler may destroy buf (freeing the heap
    # memory) before tcsetattr copies the data into kernel space.
    _ = buf^
    if rc != 0:
        return List[UInt32]()
    return saved^


def _restore_echo(var saved: List[UInt32]) -> Bool:
    """Restores terminal echo on stdin.

    Restores the original termios settings saved by ``_disable_echo``.
    Returns ``True`` on success.
    """
    if len(saved) == 0:
        return True
    var ptr = saved.unsafe_ptr()
    var rc = external_call["tcsetattr", Int, Int, Int, Int](
        0, _TCSANOW, Int(ptr)
    )
    # Keep saved alive — see _disable_echo comment.
    _ = saved^
    return rc == 0


# ── ICANON bitmask (platform-dependent) ─────────────────────────────────────
# macOS: ICANON = 0x100 (bit 8 of c_lflag)
# Linux: ICANON = 0x002 (bit 1 of c_lflag)
# We pick the right constant at runtime based on the c_lflag offset
# detected by _lflag_offset().
comptime _ICANON_MACOS: UInt32 = 0x00000100
comptime _ICANON_LINUX: UInt32 = 0x00000002

# ── ISIG bitmask (platform-dependent) ───────────────────────────────────────
# macOS: ISIG = 0x080 (bit 7 of c_lflag)
# Linux: ISIG = 0x001 (bit 0 of c_lflag)
comptime _ISIG_MACOS: UInt32 = 0x00000080
comptime _ISIG_LINUX: UInt32 = 0x00000001


def _read_password_asterisk(msg: String) raises -> String:
    """Reads a password interactively, echoing ``*`` for each keystroke.

    Disables ECHO, ICANON, and ISIG in terminal settings so that each
    byte is delivered immediately and without echo, and interrupt
    signals (such as Ctrl-C) are read as raw bytes rather than
    generating signals.  For every printable byte, a ``*`` is written
    to stderr.  Backspace erases the last ``*``.  Enter (LF/CR)
    finishes input.

    Prompt and feedback are written to stderr (unbuffered), following
    the convention used by ``sudo``, ``ssh``, and similar tools.

    Falls back to plain ``input()`` (visible) when stdin is not a
    terminal or the termios layout cannot be determined.

    Raises on Ctrl-C, Ctrl-D (EOF), or read error after restoring
    the terminal to its original settings.  The exception message
    distinguishes the cause:
    - ``"password input cancelled"`` for Ctrl-C
    - ``"password input EOF"`` for Ctrl-D / EOF
    - ``"password input read error"`` for a read(2) failure

    Note: passwords are assumed to be ASCII (the overwhelmingly common
    case).  Non-ASCII / UTF-8 multi-byte input will produce one ``*``
    per byte rather than per character, and backspace operates on bytes.
    The plain ``.password()`` mode (using ``input()``) handles UTF-8
    correctly and should be preferred when Unicode passphrases are
    expected.
    """
    from std.sys import stderr

    # ── Print prompt ─────────────────────────────────────────────
    print(msg, end="", file=stderr)

    # ── tcgetattr — save original terminal settings ──────────────
    var buf = List[UInt32](length=_TERMIOS_BUF_LEN, fill=0)
    var ptr = buf.unsafe_ptr()
    var rc = external_call["tcgetattr", Int, Int, Int](0, Int(ptr))
    if rc != 0:
        # Not a terminal — fall back to regular input.
        # Let input() raise on EOF so the caller can stop prompting.
        return input()

    var saved = buf.copy()
    var offset = _lflag_offset(buf)
    if offset < 0:
        return input()

    # ── Disable ECHO + ICANON + ISIG ─────────────────────────────
    var icanon: UInt32
    var isig: UInt32
    if offset == 6:  # macOS
        icanon = _ICANON_MACOS
        isig = _ISIG_MACOS
    else:  # Linux
        icanon = _ICANON_LINUX
        isig = _ISIG_LINUX
    buf[offset] = buf[offset] & ~_ECHO & ~icanon & ~isig
    ptr = buf.unsafe_ptr()
    rc = external_call["tcsetattr", Int, Int, Int, Int](0, _TCSANOW, Int(ptr))
    _ = buf^
    if rc != 0:
        _ = _restore_echo(saved^)
        return input()

    # ── Read one byte at a time ──────────────────────────────────
    var password = List[UInt8]()
    var one = List[UInt8](length=1, fill=0)
    var cancelled = False
    var cancel_reason = String()

    while True:
        var one_ptr = one.unsafe_ptr()
        var n = external_call["read", Int, Int, Int, Int](0, Int(one_ptr), 1)
        if n <= 0:
            cancelled = True
            cancel_reason = "password input read error"
            break  # EOF or error
        var ch = one[0]
        if ch == 10 or ch == 13:  # Enter (LF / CR)
            break
        elif ch == 127 or ch == 8:  # Backspace / Delete
            if len(password) > 0:
                _ = password.pop()
                # Erase one asterisk: cursor back, overwrite space, cursor back.
                print("\x08 \x08", end="", file=stderr)
        elif ch == 3:  # Ctrl-C — cancel
            cancelled = True
            cancel_reason = "password input cancelled"
            break
        elif ch == 4:  # Ctrl-D — EOF
            cancelled = True
            cancel_reason = "password input EOF"
            break
        elif ch == 27:  # ESC — start of escape sequence (e.g. arrow keys)
            # Consume remaining bytes of the sequence so they don't
            # pollute the password buffer.  Typical sequences are
            # 2-3 bytes (e.g. ESC [ A), but we read up to 8 to be safe.
            var discard_count = 0
            while discard_count < 8:
                var esc_ptr = one.unsafe_ptr()
                var n2 = external_call["read", Int, Int, Int, Int](
                    0, Int(esc_ptr), 1
                )
                if n2 <= 0:
                    break
                # Stop after the terminating letter of a CSI sequence.
                var esc_ch = one[0]
                discard_count += 1
                if esc_ch >= 64 and esc_ch <= 126:  # '@' .. '~'
                    break
            continue
        elif ch >= 32:  # Printable byte
            password.append(ch)
            print("*", end="", file=stderr)

    # ── Always restore terminal before returning or raising ──────
    print(file=stderr)
    _ = _restore_echo(saved^)

    if cancelled:
        raise cancel_reason

    var result = String()
    for i in range(len(password)):
        result += chr(Int(password[i]))
    return result^
