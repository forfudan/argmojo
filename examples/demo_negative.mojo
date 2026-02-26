"""Demo: negative number passthrough (argparse-style auto-detect + explicit opt-in).

Shows all three approaches to passing negative numbers as positional arguments:

  1. Auto-detect:  when no registered short option begins with a digit,
                   tokens like ``-9``, ``-3.14``, ``-1.5e10`` transparently
                   become positionals.

  2. ``--`` separator:  always works, regardless of whether digit short options
                        are registered or allow_negative_numbers() was called.

  3. allow_negative_numbers():  explicit opt-in that overrides even when a
                                digit short option would normally claim the token.

Usage:
    pixi run demo_negative
"""

from argmojo import Argument, Command, ParseResult


fn sep(title: String):
    print("\n── " + title + " " + ("─" * max(0, 56 - len(title))))


fn check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


fn main() raises:
    # ── Case 1: Auto-detect — negative integer ───────────────────────────────
    sep("Case 1: auto-detect — negative integer (-9876543)")
    var command1 = Command("calc", "Simple calculator")
    command1.add_argument(
        Argument("operand", help="A numeric operand").positional().required()
    )

    var args1: List[String] = ["calc", "-9876543"]
    var r1 = command1.parse_args(args1)
    print("positionals[0] =", r1.positionals[0])
    check(r1.positionals[0] == "-9876543", "FAIL case 1")
    print("PASS ✓")

    # ── Case 2: Auto-detect — negative float ─────────────────────────────────
    sep("Case 2: auto-detect — negative float (-3.14)")
    var command2 = Command("calc", "Simple calculator")
    command2.add_argument(
        Argument("operand", help="A numeric operand").positional().required()
    )

    var args2: List[String] = ["calc", "-3.14"]
    var r2 = command2.parse_args(args2)
    print("positionals[0] =", r2.positionals[0])
    check(r2.positionals[0] == "-3.14", "FAIL case 2")
    print("PASS ✓")

    # ── Case 3: Auto-detect — scientific notation ─────────────────────────────
    sep("Case 3: auto-detect — scientific notation (-1.5e10)")
    var command3 = Command("calc", "Simple calculator")
    command3.add_argument(
        Argument("operand", help="A numeric operand").positional().required()
    )

    var args3: List[String] = ["calc", "-1.5e10"]
    var r3 = command3.parse_args(args3)
    print("positionals[0] =", r3.positionals[0])
    check(r3.positionals[0] == "-1.5e10", "FAIL case 3")
    print("PASS ✓")

    # ── Case 4: '--' separator always works ───────────────────────────────────
    sep("Case 4: '--' separator always works for negative values")
    var command4 = Command("calc", "Simple calculator")
    command4.add_argument(
        Argument("operand", help="A numeric operand").positional().required()
    )

    var args4: List[String] = ["calc", "--", "-9.5"]
    var r4 = command4.parse_args(args4)
    print("positionals[0] =", r4.positionals[0])
    check(r4.positionals[0] == "-9.5", "FAIL case 4")
    print("PASS ✓")

    # ── Case 5: digit short opt suppresses auto-detect ────────────────────────
    sep("Case 5: digit short option (-3) is consumed as a flag")
    var command5 = Command("triple", "Triple a file")
    command5.add_argument(
        Argument("three", help="Repeat three times")
        .long("three")
        .short("3")
        .flag()
    )
    # No allow_negative_numbers() — auto-detect is suppressed for digit shorts.
    var args5: List[String] = ["triple", "-3"]
    var r5 = command5.parse_args(args5)
    print("flag 'three' =", r5.get_flag("three"))
    check(r5.get_flag("three") == True, "FAIL case 5")
    print("PASS ✓")

    # ── Case 6: allow_negative_numbers() overrides even with digit short opt ──
    sep("Case 6: allow_negative_numbers() overrides digit short conflict")
    var command6 = Command("triple", "Triple a file")
    command6.allow_negative_numbers()  # ← explicit opt-in
    command6.add_argument(
        Argument("three", help="Repeat three times")
        .long("three")
        .short("3")
        .flag()
    )
    command6.add_argument(
        Argument("operand", help="A numeric operand").positional().required()
    )
    # Now "-3.14" is a positional, but use "--three" to set the flag.
    var args6: List[String] = ["triple", "--three", "-3.14"]
    var r6 = command6.parse_args(args6)
    print("flag 'three' =", r6.get_flag("three"))
    print("positionals[0] =", r6.positionals[0])
    check(r6.get_flag("three") == True, "FAIL case 6 flag")
    check(r6.positionals[0] == "-3.14", "FAIL case 6 positional")
    print("PASS ✓")

    # ── Case 7: non-numeric '-x' still errors ─────────────────────────────────
    sep("Case 7: non-numeric '-x' still raises Unknown option")
    var command7 = Command("tool", "A tool")
    var raised = False
    var unknown_args: List[String] = ["tool", "-x"]
    try:
        _ = command7.parse_args(unknown_args)
    except e:
        raised = True
        print("Caught expected error:", String(e))
    check(raised, "FAIL case 7 — should have raised")
    print("PASS ✓")

    # ── Case 8: help output includes '--' tip when positionals exist ───────────
    sep("Case 8: '--' tip appears in help when positionals are registered")
    var command8 = Command("myapp", "My application")
    command8.add_argument(
        Argument("input", help="Input file").positional().required()
    )
    var help8 = command8._generate_help(color=False)
    print(help8)
    check("Tip:" in help8, "FAIL case 8 — tip missing")
    check("'--'" in help8, "FAIL case 8 — '--' missing from tip")
    print("PASS ✓")

    print("\n\nAll negative-number demo cases passed.")
