#!/usr/bin/env python3
"""Native Bash history regression test; isolated HOME, inputrc, and PTY."""
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import struct
import subprocess
import tempfile
import termios
import time

PROFILE = Path(__file__).resolve().parents[1] / "bash"
with tempfile.TemporaryDirectory(prefix="dotfiles-history-test-") as home:
    root = Path(home)
    (root / ".inputrc").write_text("")
    (root / ".bash_history").write_text("echo unrelated\necho recall-marker\necho final\n")
    (root / ".bashrc").write_text(
        # Simulate the binding installed by Omarchy's fzf integration.
        "bind -x '\"\\C-r\":touch \"$HOME/fzf-called\"'\n"
        f"source {shlex.quote(str(PROFILE / 'after.sh'))}\n"
        "PS1='HISTORY_TEST> '\n"
        "snapshot() { printf '%s' \"$READLINE_LINE\" > \"$HOME/state\"; }\n"
        "bind -x '\"\\C-x\\C-t\":snapshot'\n"
    )
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=home + "/.config",
               INPUTRC=str(root / ".inputrc"), HISTFILE=str(root / ".bash_history"),
               TERM="xterm-256color")
    env.pop("PROMPT_COMMAND", None)
    shell = subprocess.Popen(
        ["bash", "--noprofile", "--rcfile", str(root / ".bashrc"), "-i"],
        stdin=slave, stdout=slave, stderr=slave, start_new_session=True, env=env,
    )
    os.close(slave)

    def drain(seconds=0.5):
        output = b""
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                output += os.read(master, 65536)
        return output

    def snapshot(expected):
        os.write(master, b"\x18\x14")
        drain()
        assert (root / "state").read_text() == expected

    try:
        drain(1)
        os.write(master, b"\x12recall-marker")
        assert b"reverse-i-search" in drain(), "Ctrl+R did not start native search"
        os.write(master, b"\x05")  # Ctrl+E accepts for editing, without executing.
        drain()
        snapshot("echo recall-marker")
        assert not (root / "fzf-called").exists(), "fzf binding survived"
        os.write(master, b"\x15\x1b>\x10")  # End of history; Ctrl+P recalls latest.
        drain()
        snapshot("echo final")
        os.write(master, b"\x15echo rerun-marker >> \"$HOME/ran\"\n")
        drain()
        os.write(master, b"!!\n")
        drain()
        assert (root / "ran").read_text() == "rerun-marker\nrerun-marker\n"
        print("Interactive Bash history test passed: Ctrl+R, recall, and !! rerun.")
    finally:
        shell.kill()
        shell.wait(timeout=5)
        os.close(master)
