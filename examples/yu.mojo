"""Example: Yuhao Input Method character code lookup.

例：宇浩輸入法單字編碼查詢

A CJK-heavy demo that showcases ArgMojo's CJK-aware help alignment
and full-width → half-width auto-correction.

The purpose of the app is to lookup the encoding of Chinese characters in the
Yuhao Input Method (宇浩輸入法).

In Yuhao Input Method, each Chinese character is represented by a 4-letter code
based on its components and radicals. For example, the character "字" is encoded
as "khvi" in the Lingming variant.

Yuhao Input Method has several variants: The app supports looking up any variant
individually or all three side by side.

For full character tables, see https://shurufa.app

This demo app supports three Yuhao IME variants:
  - 宇浩靈明 — default (used when no variant flag is given)
  - 宇浩卿雲 (--joy)
  - 宇浩星陳 (--star)

Try these (build first with: `pixi run build`):

  ./yu --help
  ./yu 字
  ./yu 宇浩靈明
  ./yu --joy 字根
  ./yu --star 你好
  ./yu --all 宇浩
  ./yu --version

Full-width auto-correction examples (CJK users may type these accidentally):

  ./yu －－ａｌｌ 宇浩      # auto-corrected to: ./yu --all 宇浩
  ./yu －ｊ 字根           # auto-corrected to: ./yu -j 字根
"""

from argmojo import Argument, Command


def _build_ling_table() -> Dict[String, String]:
    """Build 宇浩靈明 lookup table (20 high-frequency characters)."""
    var d: Dict[String, String] = {
        "的": "d",
        "一": "fi",
        "是": "i",
        "不": "u",
        "了": "a",
        "人": "ne",
        "我": "o",
        "在": "mvu",
        "有": "me",
        "他": "jse",
        "這": "rwo",
        "個": "ju",
        "上": "ka",
        "來": "rla",
        "到": "kva",
        "大": "yda",
        "中": "di",
        "字": "khvi",
        "宇": "kfjo",
        "浩": "vmdo",
        "你": "ja",
        "好": "fhi",
    }
    return d^


def _build_joy_table() -> Dict[String, String]:
    """Build 宇浩卿雲 lookup table (20 high-frequency characters)."""
    var d: Dict[String, String] = {
        "的": "d",
        "一": "f",
        "是": "j",
        "不": "n",
        "了": "l",
        "人": "ur",
        "我": "w",
        "在": "xl",
        "有": "x",
        "他": "e",
        "這": "ruc",
        "個": "ebog",
        "上": "o",
        "來": "cl",
        "到": "uo",
        "大": "md",
        "中": "k",
        "字": "il",
        "宇": "ife",
        "浩": "npk",
        "你": "eo",
        "好": "wlz",
    }
    return d^


def _build_star_table() -> Dict[String, String]:
    """Build 宇浩星陳 lookup table (20 high-frequency characters)."""
    var d: Dict[String, String] = {
        "的": "d",
        "一": "f",
        "是": "j",
        "不": "v",
        "了": "k",
        "人": "r",
        "我": "g",
        "在": "eu",
        "有": "ew",
        "他": "eo",
        "這": "bocy",
        "個": "ewj",
        "上": "jv",
        "來": "all",
        "到": "dm",
        "大": "o",
        "中": "l",
        "字": "ikz",
        "宇": "ifk",
        "浩": "npl",
        "你": "e",
        "好": "c",
    }
    return d^


def _lookup(table: Dict[String, String], ch: String) raises -> String:
    if ch in table:
        return table[ch]
    return "（未收錄）"


def main() raises:
    var app = Command(
        "yu",
        "宇浩輸入法單字編碼查詢。完整碼表請見 https://shurufa.app",
        version="0.1.0",
    )

    app.add_argument(
        Argument("漢字", help="要查詢的漢字\n（可以輸入多個漢字）").positional().required()
    )
    app.add_argument(
        Argument("joy", help="使用卿雲編碼\n（預設為靈明）")
        .long["joy"]()
        .short["j"]()
        .flag()
    )
    app.add_argument(
        Argument("star", help="使用星陳編碼\n（預設為靈明）")
        .long["star"]()
        .short["s"]()
        .flag()
    )
    app.add_argument(
        Argument("all", help="同時顯示靈明、卿雲、星陳編碼").long["all"]().short["a"]().flag()
    )

    app.add_tip("完整碼表與教程請訪問 https://shurufa.app")

    var args = app.parse()
    var input = args.get_string("漢字")
    var use_joy = args.get_flag("joy")
    var use_star = args.get_flag("star")
    var show_all = args.get_flag("all")

    var ling = _build_ling_table()
    var joy = _build_joy_table()
    var star = _build_star_table()

    # Extract individual codepoints from the UTF-8 input string.
    var chars = List[String]()
    var bytes = input.as_bytes()
    var i = 0
    var n = len(bytes)
    while i < n:
        var b0 = Int(bytes[i])
        var seq_len: Int
        if b0 < 0x80:
            seq_len = 1
        elif b0 < 0xE0:
            seq_len = 2
        elif b0 < 0xF0:
            seq_len = 3
        else:
            seq_len = 4
        chars.append(String(input[byte = i : i + seq_len]))
        i += seq_len

    if show_all:
        print("漢字\t靈明\t卿雲\t星陳")
        print("────\t────\t────\t────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(
                ch
                + "\t"
                + _lookup(ling, ch)
                + "\t"
                + _lookup(joy, ch)
                + "\t"
                + _lookup(star, ch)
            )
    elif use_star:
        print("漢字\t星陳編碼")
        print("────\t────────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(ch + "\t" + _lookup(star, ch))
    elif use_joy:
        print("漢字\t卿雲編碼")
        print("────\t────────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(ch + "\t" + _lookup(joy, ch))
    else:
        print("漢字\t靈明編碼")
        print("────\t────────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(ch + "\t" + _lookup(ling, ch))
