#!/usr/bin/env python3
"""Exercise the real Zsh plugins with synthetic history and an isolated HOME."""
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

PROFILE = Path(__file__).resolve().parents[1] / "zsh" / "zshrc"
with tempfile.TemporaryDirectory(prefix="dotfiles-zsh-test-") as home:
    root = Path(home)
    (root / ".cache").mkdir()
    (root / ".zsh_history").write_text(
        "echo unrelated\ndocker container list\necho other\nnmcli connection list\n"
    )
    (root / ".bash_history").write_text("bash history must stay untouched\n")
    (root / ".zshrc").write_text(
        f"source {shlex.quote(str(PROFILE))}\n"
        "autoload -Uz add-zle-hook-widget\n"
        "_test_snapshot() { print -r -- \"$BUFFER\" > \"$HOME/state\"; "
        "print -r -- \"$KEYMAP\" >> \"$HOME/state\"; }\n"
        "add-zle-hook-widget line-pre-redraw _test_snapshot\n"
    )
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
    env = dict(os.environ, HOME=home, ZDOTDIR=home, XDG_CONFIG_HOME=home + "/.config",
               XDG_CACHE_HOME=home + "/.cache", TERM="xterm-256color")
    # Do not inherit Ghostty's injected ZDOTDIR or terminal integration in tests.
    for key in list(env):
        if key.startswith("GHOSTTY_"):
            del env[key]
    shell = subprocess.Popen(["zsh", "-d", "-i"], stdin=slave, stdout=slave,
                             stderr=slave, env=env, start_new_session=True)
    os.close(slave)

    def drain(seconds):
        output = b""
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if select.select([master], [], [], .1)[0]:
                output += os.read(master, 65536)
        return output.decode(errors="replace")

    def press(keys, buffer, keymap=None):
        os.write(master, keys)
        drain(1)
        state = (root / "state").read_text().splitlines()
        assert state[0] == buffer, (keys, state)
        if keymap:
            expected_maps = {"viins", "main"} if keymap == "viins" else {keymap}
            assert state[1] in expected_maps, (keys, state)

    try:
        startup = drain(5)
        assert "command not found" not in startup and "missing zsh-" not in startup, startup
        press(b"list", "list")
        press(b"\x1b[A", "nmcli connection list")
        press(b"\x1b[A", "docker container list")
        press(b"\x1b[B", "nmcli connection list")
        press(b"\x1b", "", "viins")
        press(b"hello", "hello")
        press(b"\x1b", "hello", "vicmd")
        # Return to insert mode, clear the line, and test a separate search.
        press(b"0Didocker", "docker")
        press(b"\x1bOA", "docker container list")
        press(b"\x1b", "", "viins")
        assert (root / ".bash_history").read_text() == "bash history must stay untouched\n"
        print("Zsh interactive test passed: substring arrows, Esc, Vi mode, separate history.")
    finally:
        shell.kill()
        shell.wait(timeout=5)
        os.close(master)
