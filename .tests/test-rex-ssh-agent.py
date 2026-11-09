import importlib.util
import json
import os
from pathlib import Path
import plistlib
import socket
import socketserver
import struct
import subprocess
import sys
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("relay", ROOT / "dot_config/rex/ssh-agent-relay.py")
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)


def render(path, platform="linux", hostname="roz-docker-host", home="/home/rozart"):
    return subprocess.check_output([
        "chezmoi", "--source", str(ROOT), "--override-data",
        json.dumps({"chezmoi": {"os": platform, "hostname": hostname, "homeDir": home}}),
        "execute-template", "--file", str(ROOT / path),
    ], text=True)


class IdentityHandler(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            while True:
                size = struct.unpack(">I", relay.receive_exact(self.request, 4))[0]
                request = relay.receive_exact(self.request, size)
                if request == b"\x0b":
                    self.request.sendall(struct.pack(">IBI", 5, 12, self.server.identities))
                else:
                    self.request.sendall(struct.pack(">IB", 1, 5))
        except (OSError, ConnectionError):
            return


class FakeAgent(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True

    def __init__(self, path, identities):
        self.identities = identities
        super().__init__(str(path), IdentityHandler)
        self.thread = threading.Thread(target=self.serve_forever, daemon=True)
        self.thread.start()

    def stop(self):
        self.shutdown()
        self.server_close()
        self.thread.join()


class RelayTests(unittest.TestCase):
    def test_failover_reconnect_and_protocol(self):
        with tempfile.TemporaryDirectory(prefix="rex-agent-", dir="/tmp") as directory:
            root = Path(directory)
            sources = [root / "first.sock", root / "second.sock"]
            first = FakeAgent(sources[0], 0)
            second = FakeAgent(sources[1], 2)
            server = relay.AgentServer(root / "agent.sock", sources)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                def query():
                    with socket.socket(socket.AF_UNIX) as connection:
                        connection.settimeout(5)
                        connection.connect(str(root / "agent.sock"))
                        return relay.agent_identities(connection)

                self.assertEqual(query(), 2)
                first.identities = 1
                self.assertEqual(query(), 1)
                first.stop()
                self.assertEqual(query(), 2)
                sources[0].unlink()
                first = FakeAgent(sources[0], 3)
                self.assertEqual(query(), 3)
                first.identities = 0
                second.identities = 0
                with self.assertRaises((ConnectionError, OSError)):
                    query()
            finally:
                server.shutdown()
                server.server_close()
                thread.join()
                first.stop()
                second.stop()

    def test_reject_symlink_source(self):
        with tempfile.TemporaryDirectory(prefix="rex-agent-", dir="/tmp") as directory:
            root = Path(directory)
            agent = FakeAgent(root / "real.sock", 1)
            (root / "alias.sock").symlink_to(root / "real.sock")
            try:
                with self.assertRaises(ConnectionError):
                    relay.connect_agent([root / "alias.sock"])
            finally:
                agent.stop()

    def test_tunnel_cleanup_rejects_non_socket_and_symlink(self):
        spec = importlib.util.spec_from_file_location("tunnel", ROOT / "dot_config/rex/ssh-tunnel.py")
        tunnel = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tunnel)
        with tempfile.TemporaryDirectory(prefix="rex-agent-", dir="/tmp") as directory:
            root = Path(directory)
            root.chmod(0o700)
            path = root / "mac.sock"
            path.write_text("preserve")
            result = subprocess.run([sys.executable, "-c", tunnel.CLEANUP, str(path)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(path.read_text(), "preserve")
            path.unlink()
            agent = FakeAgent(root / "real.sock", 1)
            try:
                path.symlink_to(root / "real.sock")
                result = subprocess.run([sys.executable, "-c", tunnel.CLEANUP, str(path)], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(path.is_symlink())
                path.unlink()
                agent.stop()
                result = subprocess.run([sys.executable, "-c", tunnel.CLEANUP, str(root / "real.sock")], capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse((root / "real.sock").exists())
            finally:
                if agent.socket.fileno() != -1:
                    agent.stop()

    def test_bootstrap_retry_is_bounded(self):
        script = render("run_onchange_after_setup-rex.sh.tmpl", "darwin", "roz-mini-laptop", "/Users/rozart")
        start = script.index("    attempt=0")
        end = script.index("    printf", start)
        retry = script[start:end]
        success = 'domain=test; plist=test; n=0; launchctl() { n=$((n + 1)); [ "$n" -ge 3 ]; }; sleep() { :; };\n'
        result = subprocess.run(["/bin/sh"], input=success + retry + '\ntest "$n" -eq 3\n', text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        failure = 'domain=test; plist=test; launchctl() { return 1; }; sleep() { :; };\n'
        result = subprocess.run(["/bin/sh"], input=failure + retry, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)

    def test_templates(self):
        plist = plistlib.loads(render(
            "Library/LaunchAgents/dev.rozart.rex-docker-host.plist.tmpl",
            "darwin", "roz-mini-laptop", "/Users/rozart",
        ).encode())
        args = plist["ProgramArguments"]
        self.assertIn("--forwarded-agent", args)
        self.assertIn(
            "/run/user/1000/rex-ssh-agent/roz-mini-laptop.sock",
            args,
        )
        unit = render("dot_config/systemd/user/rex-ssh-agent.service.tmpl")
        self.assertIn("RuntimeDirectoryMode=0700", unit)
        self.assertIn("--sources roz-mini-laptop roz-laptop", unit)
        self.assertIn("UMask=0177", unit)
        fish = render("dot_config/fish/conf.d/rex-ssh-agent.fish.tmpl")
        self.assertIn("refresh_ssh_agent", fish)
        helper = (ROOT / "dot_config/fish/functions/executable_refresh_ssh_agent.fish").read_text()
        self.assertIn("rex-ssh-agent/agent.sock", helper)
        self.assertLess(helper.index("REX_SESSION"), helper.index("TMUX"))
        for hostname in ("proxmox", "raspbox1", "raspbox2", "roz-dev-station", "roz-media-host"):
            self.assertIn("refresh_ssh_agent", render("dot_config/fish/conf.d/rex-ssh-agent.fish.tmpl", hostname=hostname))


if __name__ == "__main__":
    unittest.main()
