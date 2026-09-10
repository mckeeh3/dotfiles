"""Offline SSH picker tests using mock commands and a pseudo-terminal."""

import errno
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import time
import unittest


class SSH2Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copy2(Path(__file__).resolve().parents[1] / "ssh2", self.root)
        self.config = self.root / "ssh2.config"
        self.config.write_text("known 192.168.7.10\n")
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}", TERM="xterm")
        self.env["MOCK_LOG"] = str(self.root / "nmap.args")
        self.env["MOCK_RESULTS"] = (
            "Host: 192.168.7.10 (dns-name)\tPorts: 22/open/tcp//ssh///\n"
            "Host: 192.168.7.11 (other-pc)\tPorts: 22/open/tcp//ssh///\n"
            "Host: 192.168.7.12 ()\tPorts: 22/open/tcp//ssh///\n"
            "Host: 192.168.7.13 ()\tPorts: 22/closed/tcp//ssh///\n"
        )
        self.command("nmap", 'printf "%s\\n" "$@" > "$MOCK_LOG"\n'
                     'printf "%s" "$MOCK_RESULTS"\nexit "${MOCK_STATUS:-0}"\n')
        self.command("ssh", 'printf "SSH_ARG:%s\\n" "$@"\n')

    def command(self, name, body):
        path = self.root / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def run_cli(self, *args):
        return subprocess.run([str(self.root / "ssh2"), *args], env=self.env,
                              capture_output=True, text=True, timeout=5)

    def interactive(self, args, steps):
        master, slave = pty.openpty()
        proc = subprocess.Popen([str(self.root / "ssh2"), *args], env=self.env,
                                stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b""
        pending = list(steps)
        deadline = time.monotonic() + 5
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        break
                    if not chunk:
                        break
                    output += chunk
                if pending and pending[0][0].encode() in output:
                    _, keys = pending.pop(0)
                    os.write(master, keys)
            proc.wait(timeout=1)
            self.assertFalse(pending, output.decode())
            return proc.returncode, output.decode()
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            os.close(master)

    def test_configured_mode_does_not_scan(self):
        code, output = self.interactive([], [("known (192.168.7.10)", b"\n")])
        self.assertEqual(code, 0, output)
        self.assertIn("SSH_ARG:192.168.7.10", output)
        self.assertNotIn("SSH_ARG:-l", output)
        self.assertFalse((self.root / "nmap.args").exists())

    def test_configured_mode_through_symlinks(self):
        source = self.root / "repo with spaces"
        source.mkdir()
        (self.root / "ssh2").rename(source / "ssh2")
        self.config.rename(source / "ssh2.config")
        (self.root / "relative-link").symlink_to("repo with spaces/ssh2")
        (self.root / "ssh2").symlink_to(self.root / "relative-link")
        self.test_configured_mode_does_not_scan()

    def test_scan_labels_navigation_and_username(self):
        before = self.config.read_bytes()
        code, output = self.interactive(["--scan"], [
            ("192.168.7.12 (192.168.7.12)", b"\x1b[B\n"),
            ("SSH username [", b"remote-user\n"),
        ])
        self.assertEqual(code, 0, output)
        self.assertIn("known (192.168.7.10)", output)
        self.assertIn("other-pc (192.168.7.11)", output)
        self.assertNotIn("192.168.7.13", output)
        self.assertIn("SSH_ARG:-l\r\nSSH_ARG:remote-user", output)
        self.assertIn("SSH_ARG:192.168.7.11", output)
        self.assertEqual(self.config.read_bytes(), before)
        self.assertEqual((self.root / "nmap.args").read_text().splitlines(),
                         ["-sT", "-Pn", "-p", "22", "--open", "-oG", "-", "192.168.7.0/24"])

    def test_scan_without_config_and_default_username(self):
        self.config.unlink()
        code, output = self.interactive(["--scan", "192.168.8.0/24"], [
            ("dns-name (192.168.7.10)", b"\n"),
            ("SSH username [", b"\n"),
        ])
        self.assertEqual(code, 0, output)
        user = subprocess.check_output(["id", "-un"], text=True).strip()
        self.assertIn(f"SSH_ARG:{user}", output)
        self.assertTrue((self.root / "nmap.args").read_text().endswith("192.168.8.0/24\n"))
        self.assertFalse(self.config.exists())

    def test_cancel(self):
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertNotIn("SSH_ARG:", output)

    def test_empty_scan(self):
        self.env["MOCK_RESULTS"] = ""
        result = self.run_cli("--scan")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No hosts", result.stderr)

    def test_scan_failure(self):
        self.env["MOCK_STATUS"] = "1"
        result = self.run_cli("--scan")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Network scan failed", result.stderr)

    def test_invalid_arguments(self):
        for args in [("--bad",), ("--scan", "--help"),
                     ("--scan", "192.168.999.0/24"), ("--scan", "192.168.7.0/33"),
                     ("--scan", "192.168.7.0/24", "extra")]:
            with self.subTest(args=args):
                self.assertNotEqual(self.run_cli(*args).returncode, 0)
        self.assertFalse((self.root / "nmap.args").exists())

    def test_missing_nmap(self):
        (self.root / "nmap").unlink()
        (self.root / "dirname").symlink_to(shutil.which("dirname"))
        self.env["PATH"] = str(self.root)
        result = self.run_cli("--scan")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Scanning requires nmap", result.stderr)

    def test_noninteractive_menu(self):
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires an interactive terminal", result.stderr)

    def test_empty_config(self):
        self.config.write_text("# No targets yet\n\n")
        result = self.run_cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No SSH targets", result.stderr)

    def test_help(self):
        self.config.unlink()
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Usage:", result.stdout)

    def test_bad_or_missing_config(self):
        self.config.write_text("invalid\n")
        self.assertIn("Invalid config line", self.run_cli().stderr)
        self.config.unlink()
        self.assertIn("Missing config file", self.run_cli().stderr)


if __name__ == "__main__":
    unittest.main()
