"""Example: 宇浩輸入法單字編碼查詢 — Yuhao input method character code lookup.

A CJK-heavy demo that showcases ArgMojo's CJK-aware help alignment.
For full character tables, see https://shurufa.app

Supports two Yuhao variants:
  - 宇浩靈明 (--ling) — default
  - 宇浩卿雲 (--joy)

Try these (build first with: pixi run package && mojo build -I src -o yu examples/yu.mojo):

  ./yu --help
  ./yu 字
  ./yu 宇浩靈明
  ./yu --joy 字根
  ./yu --all 宇浩
  ./yu --version
"""

from argmojo import Argument, Command


fn _lookup_ling(ch: String) -> String:
    """Lookup 宇浩靈明 encoding for a single character."""
    # A small built-in sample table for demonstration.
    # Full tables available at https://shurufa.app
    if ch == "宇":
        return "Jcf"
    if ch == "浩":
        return "Dcng"
    if ch == "輸":
        return "Lcrq"
    if ch == "入":
        return "Kf"
    if ch == "法":
        return "Dcbr"
    if ch == "字":
        return "Jcsd"
    if ch == "根":
        return "Awvg"
    if ch == "靈":
        return "Mwks"
    if ch == "明":
        return "Hejc"
    if ch == "卿":
        return "Erye"
    if ch == "雲":
        return "Mmfm"
    if ch == "查":
        return "Awjy"
    if ch == "詢":
        return "Yixq"
    if ch == "編":
        return "Xijq"
    if ch == "碼":
        return "Gahf"
    if ch == "單":
        return "Rkfj"
    if ch == "你":
        return "Wiey"
    if ch == "好":
        return "Vjsd"
    if ch == "的":
        return "Hjkf"
    if ch == "中":
        return "Ol"
    if ch == "國":
        return "Lgjy"
    if ch == "人":
        return "Wi"
    if ch == "大":
        return "Ke"
    if ch == "學":
        return "Rpei"
    return "（未收錄）"


fn _lookup_joy(ch: String) -> String:
    """Lookup 宇浩卿雲 encoding for a single character."""
    if ch == "宇":
        return "Jdf"
    if ch == "浩":
        return "Dcwg"
    if ch == "輸":
        return "Ldpq"
    if ch == "入":
        return "Kf"
    if ch == "法":
        return "Dcam"
    if ch == "字":
        return "Jdsd"
    if ch == "根":
        return "Awng"
    if ch == "靈":
        return "Mwns"
    if ch == "明":
        return "Hejd"
    if ch == "卿":
        return "Emya"
    if ch == "雲":
        return "Mlfm"
    if ch == "查":
        return "Awjy"
    if ch == "詢":
        return "Yixq"
    if ch == "編":
        return "Xijq"
    if ch == "碼":
        return "Gahf"
    if ch == "單":
        return "Rnfj"
    if ch == "你":
        return "Wiey"
    if ch == "好":
        return "Vjsd"
    if ch == "的":
        return "Hjnf"
    if ch == "中":
        return "Ol"
    if ch == "國":
        return "Lgjy"
    if ch == "人":
        return "Wi"
    if ch == "大":
        return "Ke"
    if ch == "學":
        return "Mpei"
    return "（未收錄）"


fn main() raises:
    var app = Command(
        "yu",
        "宇浩輸入法單字編碼查詢。完整碼表請見 https://shurufa.app",
        version="0.1.0",
    )
    app.header_color("CYAN")
    app.arg_color("YELLOW")

    app.add_argument(
        Argument("漢字", help="要查詢的漢字（如「宇浩靈明」）").positional().required()
    )
    app.add_argument(
        Argument("joy", help="使用卿雲編碼（預設為靈明）").long("joy").short("j").flag()
    )
    app.add_argument(
        Argument("all", help="同時顯示靈明與卿雲編碼").long("all").short("a").flag()
    )

    app.add_tip("完整碼表與教程請訪問 https://shurufa.app")

    var args = app.parse()
    var input = args.get_string("漢字")
    var use_joy = args.get_flag("joy")
    var show_all = args.get_flag("all")

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
        chars.append(String(input[i : i + seq_len]))
        i += seq_len

    if show_all:
        print("漢字\t靈明\t卿雲")
        print("────\t────\t────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(ch + "\t" + _lookup_ling(ch) + "\t" + _lookup_joy(ch))
    elif use_joy:
        print("漢字\t卿雲編碼")
        print("────\t────────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(ch + "\t" + _lookup_joy(ch))
    else:
        print("漢字\t靈明編碼")
        print("────\t────────")
        for k in range(len(chars)):
            var ch = chars[k]
            print(ch + "\t" + _lookup_ling(ch))
