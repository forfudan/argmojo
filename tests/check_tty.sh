#!/bin/bash
# check_tty.sh — exercise the terminal code paths the regular tests cannot
# reach, because they run with stdin from /dev/null: terminal-width
# detection, hidden password input, and prompts with a closed stdin.
#
# A small probe program is built once and driven through a pseudo-terminal
# with Python's `pty` module (python3 from the system is enough).
#
# Usage:  bash tests/check_tty.sh

set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/tty_probe.mojo" <<'MOJO'
from std.os import getenv

from argmojo import Argument, Command
from argmojo.utils import _help_line_width


def main() raises:
    var mode = getenv("TTY_MODE", "")
    if mode == "width":
        print("width=" + String(_help_line_width()))
        return
    var app = Command("probe", "TTY probe")
    if mode == "password":
        app.add_argument(
            Argument("token", help="Token").long["token"]().prompt().password()
        )
    elif mode == "asterisk":
        app.add_argument(
            Argument("token", help="Token")
            .long["token"]()
            .prompt()
            .password[True]()
        )
    elif mode == "confirm":
        app.confirmation_option()
    else:
        app.add_argument(Argument("token", help="Token").long["token"]().prompt())
    var result = app.parse()
    var token = result.get_string("token") if result.has("token") else ""
    print("got=[" + token + "]")
MOJO

cat > "$TMPDIR/drive.py" <<'PY'
"""Run the probe under a pty; print exit status, echo state and output."""
import fcntl, os, pty, select, struct, sys, termios, time

prog, mode, cols, keys = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
keys = keys.encode().decode("unicode_escape").encode("latin1")
os.environ["TTY_MODE"] = mode
pid, fd = pty.fork()
if pid == 0:
    fcntl.ioctl(1, termios.TIOCSWINSZ, struct.pack("HHHH", 24, cols, 0, 0))
    os.execv(prog, [prog])

out = b""

def drain(until, timeout):
    global out
    end = time.time() + timeout
    while time.time() < end and (until is None or until not in out):
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                data = os.read(fd, 4096)
            except OSError:
                return
            if not data:
                return
            out += data

drain(b":" if keys else None, 30)
if keys:
    os.write(fd, keys)
    drain(None, 30)
try:
    echo = "on" if termios.tcgetattr(fd)[3] & termios.ECHO else "off"
except OSError:
    echo = "unknown"
_, status = os.waitpid(pid, 0)
code = 128 + os.WTERMSIG(status) if os.WIFSIGNALED(status) else os.WEXITSTATUS(status)
text = out.decode(errors="replace").replace("\r", "").replace("\n", " | ")
print(f"exit={code} echo={echo} out={text}")
PY

pixi run mojo build -I src "$TMPDIR/tty_probe.mojo" -o "$TMPDIR/tty_probe"

# check NAME EXPECTED_PATTERN... -- reads the drive result from $RESULT.
check() {
    local name="$1"
    shift
    for pattern in "$@"; do
        if ! grep -qF -- "$pattern" <<<"$RESULT"; then
            echo "FAIL  $name — expected '$pattern'"
            echo "      got: $RESULT"
            FAIL=$((FAIL + 1))
            return
        fi
    done
    echo "PASS  $name"
    PASS=$((PASS + 1))
}

drive() {
    python3 -I "$TMPDIR/drive.py" "$TMPDIR/tty_probe" "$@"
}

echo "=== Terminal (pty) checks ==="
echo

RESULT=$(drive width 100 "")
check "width_from_terminal" "exit=0" "width=98"

RESULT=$(COLUMNS=60 drive width 100 "")
check "width_from_COLUMNS" "exit=0" "width=58"

# Backspace removes a whole character, including the two-byte "é".
RESULT=$(drive password 80 's3cr\x7f\x7f\xc3\xa9\x7fok\r')
check "password_backspace" "exit=0" "got=[s3ok]"

RESULT=$(drive password 80 'ab\x03')
check "password_ctrl_c_aborts" "exit=2" "echo=on" "Aborted"

RESULT=$(drive asterisk 80 'ab\r')
check "asterisk_echo" "exit=0" "**" "got=[ab]"

RESULT=$(drive asterisk 80 '\x03')
check "asterisk_ctrl_c_aborts" "exit=2" "echo=on" "Aborted"

echo
echo "=== Closed stdin ==="
echo

for mode in prompt password asterisk; do
    set +e
    RESULT="exit=$(TTY_MODE=$mode "$TMPDIR/tty_probe" <&- >/dev/null 2>&1; echo $?)"
    set -e
    check "closed_stdin_$mode" "exit=0"
done

set +e
RESULT="$(TTY_MODE=confirm "$TMPDIR/tty_probe" <&- 2>&1; echo "exit=$?")"
set -e
check "closed_stdin_confirm" "exit=2" "no interactive input"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
