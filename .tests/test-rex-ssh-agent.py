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
import time
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
        self.assertIn("ssh-agent-start.sh", unit)
        sources = json.loads(render("dot_config/rex/ssh-agent-sources.json.tmpl"))["sources"]
        self.assertEqual([source["label"] for source in sources], ["roz-mini-laptop", "roz-laptop"])
        self.assertIn("--bridge-local", args)
        self.assertIn("/Users/rozart/.local/state/rex/ssh-agent/upstream-roz-laptop.sock", args)
        self.assertIn("UMask=0177", unit)
        fish = render("dot_config/fish/conf.d/rex-ssh-agent.fish.tmpl")
        self.assertIn("refresh_ssh_agent", fish)
        helper = (ROOT / "dot_config/fish/functions/executable_refresh_ssh_agent.fish").read_text()
        self.assertIn("rex/ssh-agent/b-$block_id.sock", helper)
        self.assertLess(helper.index("REX_SESSION"), helper.index("TMUX"))
        for hostname in ("proxmox", "raspbox1", "raspbox2", "roz-dev-station", "roz-media-host"):
            self.assertIn("refresh_ssh_agent", render("dot_config/fish/conf.d/rex-ssh-agent.fish.tmpl", hostname=hostname))


class RouterTests(unittest.TestCase):
    block = "block:11111111-1111-1111-1111-111111111111"

    def test_strict_owner_routing_detach_revocation_and_health(self):
        with tempfile.TemporaryDirectory(prefix="rex-route-", dir="/tmp") as directory:
            root = Path(directory)
            root.chmod(0o700)
            agents = [FakeAgent(root / "a.sock", 1), FakeAgent(root / "b.sock", 2)]
            sources = [{"label": name, "aliases": [name], "path": str(root / f"{name}.sock")} for name in ("a", "b")]
            clients = [{"client_id": name, "info": {"kind": "app", "label": name}, "principal": {"kind": "peer", "uid": os.getuid()}} for name in ("a", "b")]
            router = relay.AgentRouter(root, sources)

            def query():
                with socket.socket(socket.AF_UNIX) as connection:
                    connection.settimeout(5)
                    connection.connect(str(relay.pane_socket(root, self.block)))
                    return relay.agent_identities(connection)

            def owner(value):
                router.receive({"type": "owner", "block_id": self.block, "owner": value, "clients": clients})

            try:
                router.receive({"type": "snapshot", "blocks": [{"block_id": self.block, "owner": "a"}], "clients": clients})
                self.assertEqual(query(), 1)
                persistent = socket.socket(socket.AF_UNIX)
                persistent.settimeout(5)
                persistent.connect(str(relay.pane_socket(root, self.block)))
                self.assertEqual(relay.agent_identities(persistent), 1)
                owner("b")
                self.assertEqual(query(), 2)
                with self.assertRaises((OSError, ConnectionError)):
                    relay.agent_identities(persistent)
                persistent.close()
                owner(None)
                self.assertEqual(query(), 2)
                agents[1].identities = 0
                with self.assertRaises((OSError, ConnectionError)):
                    query()
                agents[1].identities = 2
                owner("unknown")
                with self.assertRaises((OSError, ConnectionError)):
                    query()
                owner(None)
                with self.assertRaises((OSError, ConnectionError)):
                    query()
                owner("a")
                self.assertEqual(query(), 1)
                router.last_seen = 0
                with self.assertRaises((OSError, ConnectionError)):
                    query()
                router.expire()
                with self.assertRaises((OSError, ConnectionError)):
                    query()
                router.receive({"type": "snapshot", "blocks": [{"block_id": self.block}], "clients": clients})
                with self.assertRaises((OSError, ConnectionError)):
                    query()
                owner("b")
                self.assertEqual(query(), 2)
                router.receive({"type": "snapshot", "blocks": [], "clients": clients})
                self.assertFalse(relay.pane_socket(root, self.block).exists())
            finally:
                router.close()
                for agent in agents:
                    agent.stop()

    def test_cleanup_does_not_block_health_revocation(self):
        with tempfile.TemporaryDirectory(prefix="rex-clean-", dir="/tmp") as directory:
            root = Path(directory)
            root.chmod(0o700)
            router = relay.AgentRouter(root, [])
            other = "block:22222222-2222-2222-2222-222222222222"
            router.receive({"type": "snapshot", "blocks": [{"block_id": self.block}, {"block_id": other}], "clients": []})
            release = threading.Event()
            waiting = threading.Event()
            server = router.servers[self.block]
            shutdown = server.shutdown

            def delayed_shutdown():
                waiting.set()
                release.wait(2)
                shutdown()

            server.shutdown = delayed_shutdown
            try:
                start = time.monotonic()
                router.receive({"type": "snapshot", "blocks": [{"block_id": other}], "clients": []})
                self.assertLess(time.monotonic() - start, 0.5)
                self.assertTrue(waiting.wait(1))
                router.last_seen = 0
                router.expire()
                self.assertFalse(router.ready)
            finally:
                release.set()
                router.close()

    def test_identity_mapping_rejects_cli_and_spoofed_remote_label(self):
        sources = [{"label": "a", "aliases": ["a"]}]
        self.assertIsNone(relay.client_source({"info": {"kind": "cli", "label": "a"}, "principal": {"kind": "peer", "uid": os.getuid()}}, sources))
        self.assertIsNone(relay.client_source({"info": {"kind": "app", "label": "a"}, "principal": {"kind": "tailscale", "node": "unknown"}}, sources))
        self.assertEqual(relay.client_source({"info": {"kind": "app"}, "principal": {"kind": "tailscale", "node": "a"}}, sources), "a")

    def test_shell_scope_and_ssh_override(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {**os.environ, "HOME": str(root), "REX_SESSION": "test", "REX_BLOCK": self.block, "SSH_AUTH_SOCK": "/wrong.sock"}
            script = ROOT / "dot_config/rex/ssh-agent.sh"
            result = subprocess.check_output(["/bin/sh", "-c", f'. "{script}"; printf "%s" "$SSH_AUTH_SOCK"'], env=env, text=True)
            self.assertEqual(result, str(root / ".local/state/rex/ssh-agent/b-11111111-1111-1111-1111-111111111111.sock"))
            env["REX_BLOCK"] = "../../bad"
            result = subprocess.check_output(["/bin/sh", "-c", f'. "{script}"; printf "%s" "$SSH_AUTH_SOCK"'], env=env, text=True)
            self.assertEqual(result, str(root / ".local/state/rex/ssh-agent/unrouted.sock"))
            config = root / "ssh_config"
            config.write_text(render("private_dot_ssh/config.tmpl", "darwin", "roz-mini-laptop", str(root)))
            result = subprocess.check_output(["ssh", "-G", "-F", str(config), "personalgit"], env=env, text=True, stderr=subprocess.DEVNULL)
            self.assertIn("identityagent SSH_AUTH_SOCK", result)
            env.pop("REX_SESSION")
            result = subprocess.check_output(["ssh", "-G", "-F", str(config), "personalgit"], env=env, text=True, stderr=subprocess.DEVNULL)
            self.assertNotIn("identityagent SSH_AUTH_SOCK", result)

    def test_profile_modifier_preserves_content_and_is_idempotent(self):
        content = "export EXISTING=value\n"
        modifier = render("modify_dot_profile.tmpl")
        first = subprocess.check_output([sys.executable, "-c", modifier], input=content, text=True)
        second = subprocess.check_output([sys.executable, "-c", modifier], input=first, text=True)
        self.assertEqual(first, second)
        self.assertTrue(first.endswith(content))

    def test_signing_refuses_private_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            key = Path(directory) / "private"
            key.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\n")
            result = subprocess.run([sys.executable, str(ROOT / "dot_local/bin/executable_rex-ssh-sign"), "-Y", "sign", "-f", str(key)], env={**os.environ, "REX_SESSION": "test", "REX_BLOCK": self.block}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("refuses local private keys", result.stderr)
            result = subprocess.run([sys.executable, str(ROOT / "dot_local/bin/executable_rex-ssh-sign"), "-Ysign", "-f", str(key)], env={**os.environ, "REX_SESSION": "test", "REX_BLOCK": self.block}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("refuses local private keys", result.stderr)
            result = subprocess.run([sys.executable, str(ROOT / "dot_local/bin/executable_rex-ssh-sign"), "-Y", "sign", "-f", str(key), "-f", str(key)], env={**os.environ, "REX_SESSION": "test", "REX_BLOCK": self.block}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Ambiguous", result.stderr)


if __name__ == "__main__":
    unittest.main()
