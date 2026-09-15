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
        repo = Path(__file__).resolve().parents[1]
        shutil.copy2(repo / "ssh2", self.root)
        shutil.copytree(repo / "lib", self.root / "lib")
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
        self.command("uname", 'echo "${MOCK_OS:-Linux}"\n')
        self.command("avahi-browse", 'printf "%s" "${MOCK_MDNS:-}"\nexit "${MDNS_STATUS:-0}"\n')

    def command(self, name, body):
        path = self.root / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def run_cli(self, *args):
        return subprocess.run([str(self.root / "ssh2"), *args], env=self.env,
                              capture_output=True, text=True, timeout=8)

    def interactive(self, args, steps):
        master, slave = pty.openpty()
        proc = subprocess.Popen([str(self.root / "ssh2"), *args], env=self.env,
                                stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b""
        pending = list(steps)
        deadline = time.monotonic() + 8
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
        (self.root / "lib").rename(source / "lib")
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

    def mdns_record(self, host="new-pc.local", address="192.168.7.20", port=22,
                    name=r"Ignored\032service\059name"):
        return f"=;eth0;IPv4;{name};_ssh._tcp;local;{host};{address};{port};\"user=evil\"\n"

    def test_avahi_supported_arguments(self):
        self.command("avahi-browse", '''for arg; do
  case "$arg" in
    --resolve|--terminate|--parsable|--no-db-lookup|_ssh._tcp) ;;
    *) echo "unsupported avahi-browse argument: $arg" >&2; exit 1 ;;
  esac
done
printf "%s" "$MOCK_MDNS"
''')
        self.env["MOCK_MDNS"] = self.mdns_record()
        code, output = self.interactive([], [("192.168.7.20", b"q")])
        self.assertEqual(code, 0, output)

    def test_mdns_merge_manual_priority_and_port(self):
        before = self.config.read_bytes()
        self.env["MOCK_MDNS"] = (
            self.mdns_record("known.local", "192.168.7.10") +
            self.mdns_record() + self.mdns_record() +
            self.mdns_record(port=2222))
        code, output = self.interactive([], [
            ("192.168.7.20:2222", b"\x1b[B\x1b[B\n"),
            ("SSH username [", b"other-user\n"),
        ])
        self.assertEqual(code, 0, output)
        self.assertIn("known (192.168.7.10)", output)
        self.assertNotIn("known.local (", output)
        self.assertIn("SSH_ARG:-p\r\nSSH_ARG:2222", output)
        self.assertIn("SSH_ARG:other-user", output)
        self.assertNotIn("evil", output)
        self.assertEqual(before, self.config.read_bytes())
        self.assertFalse((self.root / "nmap.args").exists())

    def test_mdns_only_without_config(self):
        self.config.unlink()
        self.env["MOCK_MDNS"] = self.mdns_record()
        code, output = self.interactive([], [
            ("new-pc (192.168.7.20)", b"\n"), ("SSH username [", b"\n")])
        self.assertEqual(code, 0, output)
        self.assertIn("SSH_ARG:-p\r\nSSH_ARG:22", output)
        self.assertFalse(self.config.exists())

    def test_mdns_config_hostname_match(self):
        self.config.write_text("friendly NEW-PC.local.\n")
        self.env["MOCK_MDNS"] = self.mdns_record()
        code, output = self.interactive([], [("friendly (NEW-PC.local.)", b"\n")])
        self.assertEqual(code, 0, output)
        self.assertNotIn("new-pc (", output)
        self.assertNotIn("SSH_ARG:-l", output)

    def test_mdns_untrusted_records_ignored(self):
        self.env["MOCK_MDNS"] = "".join([
            self.mdns_record(host="-oProxyCommand=evil"),
            self.mdns_record(host="bad\x1b[2J.local"),
            self.mdns_record(address="999.1.2.3"),
            self.mdns_record(address="-oOption"),
            self.mdns_record(port="65536"),
            self.mdns_record(port="0"),
            self.mdns_record(port="$(touch nope)"),
            self.mdns_record().replace("=;", "+;", 1),
        ])
        code, output = self.interactive([], [("known (192.168.7.10)", b"\n")])
        self.assertEqual(code, 0, output)
        self.assertNotIn("new-pc", output)
        self.assertNotIn("evil", output)

    def test_mdns_failure_retains_config(self):
        self.env["MDNS_STATUS"] = "1"
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertIn("Avahi discovery failed", output)

    def test_mdns_missing_backend(self):
        # An isolated PATH cannot accidentally use a live Bonjour installation.
        self.env["MOCK_OS"] = "Darwin"
        for name in ("dirname", "mktemp", "cat", "rm", "sleep", "tr", "awk", "tput", "stty"):
            (self.root / name).symlink_to(shutil.which(name))
        self.env["PATH"] = str(self.root)
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertIn("dns-sd missing", output)

    def test_no_mdns_and_scan_skip_discovery(self):
        self.command("avahi-browse", 'touch "$MOCK_LOG.mdns"\nexit 1\n')
        code, output = self.interactive(["--no-mdns"], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.run_cli("--scan")
        self.assertFalse((self.root / "nmap.args.mdns").exists())

    def test_avahi_timeout_keeps_partial_results_and_reaps_tool(self):
        self.env["MOCK_MDNS"] = self.mdns_record()
        self.command("avahi-browse", 'echo $$ > "$MOCK_LOG.pid"\nprintf "%s" "$MOCK_MDNS"\nexec sleep 30\n')
        start = time.monotonic()
        code, output = self.interactive([], [("new-pc (192.168.7.20)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertLess(time.monotonic() - start, 7)
        self.assertIn("timed out", output)
        pid = int((self.root / "nmap.args.pid").read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def test_bonjour_zone_snapshot_and_dedup(self):
        self.env["MOCK_OS"] = "Darwin"
        # Format from Apple's dns-sd.c zonedata_resolve, including escaped name.
        self.env["MOCK_MDNS"] = (
            "; comments\n_ssh._tcp. PTR My\\032Mac._ssh._tcp.\n"
            "My\\032Mac._ssh._tcp. SRV 0 0 22 mac.local. ; Replace with unicast FQDN of target host\n"
            "My\\032Mac._ssh._tcp. TXT \"user=evil\"\n"
            "Other._ssh._tcp. SRV 0 0 2200 other.local. ; Replace with unicast FQDN of target host\n"
            "Invalid._ssh._tcp. SRV 0 0 22 -bad.local.\n")
        self.command("dns-sd", 'printf "%s" "$MOCK_MDNS"\nexec sleep 30\n')
        self.command("dscacheutil", 'if [[ $5 == mac.local ]]; then echo "ip_address: 192.168.7.10"; else echo "ip_address: 192.168.7.30"; fi\n')
        code, output = self.interactive([], [
            ("other (192.168.7.30:2200)", b"\x1b[B\n"),
            ("SSH username [", b"remote\n")])
        self.assertEqual(code, 0, output)
        self.assertNotIn("mac (", output)
        self.assertIn("SSH_ARG:-p\r\nSSH_ARG:2200", output)

    def test_bonjour_lookup_total_budget(self):
        self.env["MOCK_OS"] = "Darwin"
        self.command("dns-sd", 'printf "One._ssh._tcp. SRV 0 0 22 one.local.\\nTwo._ssh._tcp. SRV 0 0 22 two.local.\\n"\n')
        self.command("dscacheutil", 'echo $$ > "$MOCK_LOG.pid"\nexec sleep 30\n')
        start = time.monotonic()
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertLess(time.monotonic() - start, 7)
        self.assertIn("budget exhausted", output)
        with self.assertRaises(ProcessLookupError):
            os.kill(int((self.root / "nmap.args.pid").read_text()), 0)

    def test_avahi_high_volume_is_bounded_and_keeps_manual_priority(self):
        before = self.config.read_bytes()
        fixture = self.root / "mdns.fixture"
        self.env["MDNS_FIXTURE"] = str(fixture)
        self.command("avahi-browse", 'exec cat "$MDNS_FIXTURE"\n')
        for count in (100, 200, 2000):
            with self.subTest(records=count):
                fixture.write_text(self.mdns_record("known.local", "192.168.7.10") + "".join(
                    self.mdns_record(f"node-{i}.local", f"10.20.{i // 250}.{i % 250 + 1}")
                    for i in range(count)))
                start = time.monotonic()
                code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
                elapsed = time.monotonic() - start
                self.assertEqual(code, 0, output)
                self.assertLess(elapsed, 2, f"{count} records took {elapsed:.3f}s")
                # 64 candidates: the manual duplicate plus 63 new endpoints.
                self.assertEqual(output.count("node-"), 63, output)
                self.assertNotIn("known.local (", output)
                self.assertEqual(before, self.config.read_bytes())

    def test_bonjour_high_volume_limits_lookups_and_results(self):
        before = self.config.read_bytes()
        self.env["MOCK_OS"] = "Darwin"
        self.env["MOCK_MDNS"] = (
            "Known._ssh._tcp. SRV 0 0 22 known.local.\n" + "".join(
                f"Node{i}._ssh._tcp. SRV 0 0 22 node-{i}.local.\n" for i in range(200)))
        self.command("dns-sd", 'printf "%s" "$MOCK_MDNS"\n')
        self.command("dscacheutil", '''echo "$5" >> "$MOCK_LOG.lookups"
if [[ $5 == known.local ]]; then
  echo 'ip_address: 192.168.7.10'
else
  number=${5#node-}; number=${number%.local}
  echo "ip_address: 10.20.0.$((number + 1))"
fi
''')
        start = time.monotonic()
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertLess(time.monotonic() - start, 7)
        lookups = (self.root / "nmap.args.lookups").read_text().splitlines()
        self.assertLessEqual(len(lookups), 64)
        self.assertGreater(len(lookups), 1)
        self.assertLessEqual(output.count("node-"), 63)
        self.assertNotIn("known.local (", output)
        self.assertEqual(before, self.config.read_bytes())

    def test_capture_byte_limit_drops_incomplete_record(self):
        fixture = self.root / "mdns.fixture"
        complete = self.mdns_record()
        # Oversized output and stderr cannot grow capture files without bound;
        # retain the first complete record, not a truncated final record.
        fixture.write_text(complete + "x" * 131072 + "\n" + self.mdns_record())
        self.env["MDNS_FIXTURE"] = str(fixture)
        self.command("avahi-browse", 'cat "$MDNS_FIXTURE" >&2\nexec cat "$MDNS_FIXTURE"\n')
        start = time.monotonic()
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; ssh2_bounded 2 avahi-browse', "_",
             str(self.root / "lib/ssh2-mdns.sh")],
            env=self.env, text=True, capture_output=True, timeout=4)
        self.assertLess(time.monotonic() - start, 3)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, complete)
        self.assertLess(len(result.stderr), 1024)

    def test_capture_line_limit(self):
        self.env["MOCK_MDNS"] = "ignored\n" * 256 + self.mdns_record()
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertNotIn("new-pc (", output)

    def test_bonjour_failure(self):
        self.env["MOCK_OS"] = "Darwin"
        self.command("dns-sd", 'exit 1\n')
        code, output = self.interactive([], [("known (192.168.7.10)", b"q")])
        self.assertEqual(code, 0, output)
        self.assertIn("Bonjour discovery failed", output)

    def test_help(self):
        self.config.unlink()
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Usage:", result.stdout)

    def test_bad_or_missing_config(self):
        self.config.write_text("invalid\n")
        self.assertIn("Invalid config line", self.run_cli().stderr)
        self.config.unlink()
        self.assertIn("No SSH targets", self.run_cli().stderr)
        self.assertIn("Missing config file", self.run_cli("--no-mdns").stderr)


if __name__ == "__main__":
    unittest.main()
