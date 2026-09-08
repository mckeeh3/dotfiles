#!/usr/bin/env python3
"""Optional ble.sh regression test. Uses only synthetic history in a temporary HOME."""
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shlex
import struct
import subprocess
import tempfile
import termios
import time

PROFILE = Path(__file__).resolve().parents[1] / "bash"
if not Path("/usr/share/blesh/ble.sh").is_file():
    raise SystemExit("SKIP: ble.sh is not installed")

with tempfile.TemporaryDirectory(prefix="dotfiles-history-test-") as home:
    root = Path(home)
    (root / ".cache").mkdir()
    commands = ["echo unrelated", "docker container list", "echo other",
                "nmcli connection list", "echo final"]
    (root / ".bash_history").write_text("\n".join(commands) + "\n")
    (root / ".bashrc").write_text(
        f"source {shlex.quote(str(PROFILE / 'before.sh'))}\n"
        f"source {shlex.quote(str(PROFILE / 'after.sh'))}\n"
        "PS1='HISTORY_TEST> '\n"
        "ble/widget/test-snapshot() { printf '%s\\n' \"$_ble_edit_str\" "
        "\"$_ble_decode_keymap\" > \"$HOME/state\"; }\n"
        "ble-bind -m vi_imap -f 'C-x C-q' test-snapshot\n"
        "ble-bind -m vi_nmap -f 'C-x C-q' test-snapshot\n"
        "ble-attach\n"
    )
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
    shell = subprocess.Popen(
        ["bash", "--noprofile", "--rcfile", str(root / ".bashrc"), "-i"],
        stdin=slave, stdout=slave, stderr=slave, start_new_session=True,
        env=dict(os.environ, HOME=home, XDG_CONFIG_HOME=home + "/.config",
                 XDG_CACHE_HOME=home + "/.cache", TERM="xterm-256color"),
    )
    os.close(slave)

    def drain(seconds):
        output = b""
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                output += os.read(master, 65536)
        text = output.decode(errors="replace")
        return re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)

    try:
        drain(5)
        # An actual prompt cycle matters: history -s alone missed the corruption.
        os.write(master, b'HISTTIMEFORMAT=__ENTRY__ builtin history > "$HOME/dump"\n')
        drain(2)
        entries = re.split(r"^ *\d+[ *]+__ENTRY__", (root / "dump").read_text(),
                           flags=re.MULTILINE)[1:]
        assert len(entries) == len(commands) + 1, "unexpected history entry count"
        assert all(len(entry.splitlines()) == 1 for entry in entries), \
            "separate commands were imported as a giant multiline entry"

        os.write(master, b"list")
        drain(1)
        for key, expected in [(b"\x1b[A", commands[3]),
                              (b"\x1b[A", commands[1]),
                              (b"\x1b[B", commands[3])]:
            os.write(master, key)
            output = drain(1)
            assert expected in output, f"arrow search did not recall {expected!r}"
            assert "echo unrelated" not in output, "arrow recalled an entire history block"
        os.write(master, b"\x1b")
        drain(1)
        os.write(master, b"\x18\x11")  # Snapshot without executing the command line.
        drain(1)
        assert (root / "state").read_text() == "\nvi_imap\n", \
            f"Esc did not cancel search to an empty insert-mode prompt: {(root / 'state').read_text()!r}"

        os.write(master, b"hello")
        drain(1)
        os.write(master, b"\x1b")
        drain(1)
        os.write(master, b"\x18\x11")
        drain(1)
        assert (root / "state").read_text() == "hello\nvi_nmap\n", \
            "Esc outside search must retain normal Vi behavior"
        print("Interactive history test passed: entries, Up/Down, Esc cancellation, and Vi mode.")
    finally:
        shell.kill()
        shell.wait(timeout=5)
        os.close(master)
