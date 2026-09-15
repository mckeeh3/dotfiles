"""Offline Omarchy mDNS setup tests; every privileged command is mocked."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class MDNSSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.services = self.root / "services"
        self.services.mkdir()
        self.repo = Path(__file__).resolve().parents[1]
        self.script = self.root / "setup.sh"
        self.script.write_text((self.repo / "omarchy/mdns/setup.sh").read_text().replace(
            "service_dir=/etc/avahi/services", f"service_dir={self.services}"))
        shutil.copy2(self.repo / "omarchy/mdns/ssh.service.in", self.root)
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        STATE=str(self.root),
                        EFFECTIVE="port 2222\nlistenaddress 0.0.0.0:2222\nlistenaddress [::]:2222\n")
        self.log = self.root / "log"
        self.command("sudo", 'printf "sudo %s\\n" "$*" >> "$STATE/log"\nexec "$@"\n')
        self.command("pacman", '[[ -f "$STATE/pkg.$2" ]]\n')
        self.command("omarchy", 'printf "omarchy %s\\n" "$*" >> "$STATE/log"\nshift 2\nfor pkg; do touch "$STATE/pkg.$pkg"; done\n')
        self.command("sshd", 'printf "%s" "$EFFECTIVE"\nexit "${SSHD_STATUS:-0}"\n')
        self.command("systemctl", '''case $1 in
  show) echo "${EXEC_START:-{ path=/usr/bin/sshd ; argv[]=/usr/bin/sshd -D ; ignore_errors=no ; }}" ;;
  is-enabled) [[ -e "$STATE/enabled.$3" ]] ;;
  is-active) [[ -e "$STATE/active.$3" ]] ;;
  enable) touch "$STATE/enabled.$2" ;;
  start) touch "$STATE/active.$2" ;;
  *) exit 1 ;;
esac
''')

    def command(self, name, body):
        file = self.bin / name
        file.write_text("#!/bin/bash\n" + body)
        file.chmod(0o755)

    def run_setup(self, *args):
        return subprocess.run(["bash", str(self.script), *args], env=self.env,
                              text=True, capture_output=True, timeout=5)

    def test_preview_does_not_mutate(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("incoming SSH", result.stdout)
        self.assertFalse(self.log.exists())

    def test_install_configured_port_and_idempotence(self):
        (self.root / "pkg.avahi").touch()
        unrelated = self.services / "printer.service"
        unrelated.write_text("<service><type>_ipp._tcp</type></service>\n")
        result = self.run_setup("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.services / "ssh2.service"
        self.assertIn("<port>2222</port>", target.read_text())
        log = self.log.read_text()
        self.assertIn("omarchy pkg add openssh", log)
        self.assertNotIn("omarchy pkg add avahi", log)
        self.assertIn("sudo systemctl start sshd.service", log)
        self.assertIn("sudo systemctl enable avahi-daemon.service", log)
        mtime = target.stat().st_mtime_ns
        self.log.write_text("")
        result = self.run_setup("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "sudo sshd -T\n")
        self.assertEqual(mtime, target.stat().st_mtime_ns)
        self.assertEqual(unrelated.read_text(), "<service><type>_ipp._tcp</type></service>\n")

    def test_capitalized_sshd_output(self):
        self.env["EFFECTIVE"] = (
            "Port 22\nAddressFamily any\nListenAddress [::]:22\n"
            "ListenAddress 0.0.0.0:22\nUsePAM yes\n")
        result = self.run_setup("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("<port>22</port>", (self.services / "ssh2.service").read_text())

    def test_conflicts_preserved_before_services_enabled(self):
        for filename, contents in [("ssh2.service", "personal config\n"),
                                   ("existing.service", "<type>_ssh._tcp</type>\n")]:
            with self.subTest(filename=filename):
                file = self.services / filename
                file.write_text(contents)
                self.log.write_text("")
                result = self.run_setup("--apply")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("existing", result.stderr)
                self.assertEqual(file.read_text(), contents)
                self.assertNotIn("systemctl start", self.log.read_text())
                self.assertNotIn("sudo install", self.log.read_text())
                file.unlink()

    def test_nonstandard_sshd_stops(self):
        cases = [
            {"EFFECTIVE": "port 22\nport 2222\nlistenaddress 0.0.0.0:22\n"},
            {"EFFECTIVE": "Port 22\nPort 2222\nListenAddress 0.0.0.0:22\n"},
            {"EFFECTIVE": "Port 22\nListenAddress 127.0.0.1:22\n"},
            {"EFFECTIVE": "port 22\nlistenaddress 127.0.0.1:22\n"},
            {"EFFECTIVE": "port 22\nlistenaddress 0.0.0.0:2222\n"},
            {"SSHD_STATUS": "1"},
            {"EXEC_START": "{ argv[]=/usr/bin/sshd -D -p 2222 ; }"},
        ]
        for values in cases:
            with self.subTest(values=values):
                original = self.env.copy()
                self.env.update(values)
                self.log.write_text("")
                result = self.run_setup("--apply")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Cannot automatically advertise SSH", result.stderr)
                self.assertNotIn("systemctl start", self.log.read_text())
                self.assertFalse((self.services / "ssh2.service").exists())
                self.env = original

    def test_socket_activation_stops(self):
        (self.root / "enabled.sshd.socket").touch()
        result = self.run_setup("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sshd.socket", result.stderr)
        self.assertNotIn("systemctl start", self.log.read_text())

    def test_owned_path_symlink_is_not_followed(self):
        other = self.root / "other"
        other.write_text("keep me")
        (self.services / "ssh2.service").symlink_to(other)
        result = self.run_setup("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(other.read_text(), "keep me")

    def test_entrypoints_forward_explicit_option_only(self):
        copy = self.root / "repo"
        shutil.copytree(self.repo / "omarchy", copy / "omarchy")
        for filename in ("omarchy-setup.sh", "omarchy-zsh-setup.sh", "ssh2"):
            shutil.copy2(self.repo / filename, copy)
        (copy / "omarchy/mdns/setup.sh").write_text('echo "mdns $*" >> "$STATE/entrypoint"\n')
        home = self.root / "home"
        home.mkdir()
        defaults = self.root / "omarchy/default/bash"
        defaults.mkdir(parents=True)
        (defaults / "rc").write_text("# mock\n")
        self.env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                        OMARCHY_PATH=str(self.root / "omarchy"))
        self.env.pop("ZDOTDIR", None)
        self.command("zsh", "exit 0\n")
        self.command("starship", "exit 0\n")
        for entry in ("omarchy-setup.sh", "omarchy-zsh-setup.sh"):
            link = home / ".local/bin/ssh2"
            link.unlink(missing_ok=True)
            for args in ([], ["--setup-mdns"]):
                marker = self.root / "entrypoint"
                marker.unlink(missing_ok=True)
                result = subprocess.run(["bash", str(copy / entry), *args], env=self.env,
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(marker.exists(), bool(args))
                if args:
                    self.assertEqual(marker.read_text(), "mdns --apply\n")
                    self.assertTrue(link.is_symlink())
                    self.assertEqual(link.resolve(), copy / "ssh2")
        link.unlink()
        for kind in ("file", "link", "directory"):
            with self.subTest(kind=kind):
                if kind == "file":
                    link.write_text("personal command\n")
                elif kind == "link":
                    link.symlink_to(self.root / "missing-command")
                else:
                    link.mkdir()
                marker.unlink(missing_ok=True)
                result = subprocess.run(["bash", str(copy / "omarchy-zsh-setup.sh"),
                                         "--setup-mdns"], env=self.env, capture_output=True,
                                        text=True, timeout=5)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("differs", result.stderr)
                self.assertFalse(marker.exists())
                if kind == "directory":
                    link.rmdir()
                else:
                    if kind == "file":
                        self.assertEqual(link.read_text(), "personal command\n")
                    else:
                        self.assertTrue(link.is_symlink())
                    link.unlink()


if __name__ == "__main__":
    unittest.main()
