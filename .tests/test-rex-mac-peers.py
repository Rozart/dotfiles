import copy
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch
import uuid


ROOT = Path(__file__).resolve().parents[1]
DATA = tomllib.loads((ROOT / ".chezmoidata.toml").read_text())["rex"]
SPEC = importlib.util.spec_from_file_location("rex_mac_peers", ROOT / "dot_config/rex/sync-client-hosts.py")
assert SPEC is not None and SPEC.loader is not None
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


def render(path, hostname, platform="darwin"):
    return subprocess.check_output(["chezmoi", "--source", str(ROOT), "--override-data",
                                   json.dumps({"chezmoi": {"os": platform, "hostname": hostname,
                                                          "homeDir": "/Users/fixture", "username": "rozart"}}),
                                   "execute-template", "--file", str(ROOT / path)], text=True)


class MacPeerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.app = self.home / "Rex Beta.app"
        (self.app / "Contents").mkdir(parents=True)
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": SYNC.BUILD}))
        self.state = self.home / "backups"
        self.own, self.peer = copy.deepcopy(DATA["macs"])
        self.local_socket = "/Users/fixture/Library/Application Support/rex/server.sock"
        self.instance = str(uuid.uuid4())
        self.peer_instance = str(uuid.uuid4())
        self.current = self.status(self.own, self.instance)
        self.remote = self.status(self.peer, self.peer_instance)
        self.linux_id = str(uuid.uuid4())
        self.record = {"id": str(uuid.uuid4()), "name": "My existing Linux host", "futureField": "keep",
                       "locators": ["unix:///Users/fixture/dev.sock", "https://custom.example.test"]}
        self.directory = {"formatVersion": 1, "records": [self.record], "unknownRoot": "keep"}
        self.original = json.dumps(self.directory, indent=3).encode()
        self.preferences = {SYNC.KEY: self.original, "Workspace.customThemes": b"exact colors", "remoteControl": False}
        self.config = {"build": SYNC.BUILD, "hosts": [{"label": "dev", "endpoint": "/Users/fixture/dev.sock"}],
                       "peers": [{key: self.peer[key] for key in ("label", "endpoint", "host_id")}],
                       "local": {"endpoint": self.local_socket, "https": self.own["endpoint"], "host_id": self.own["host_id"]}}
        self.commands = []
        self.writes = []
        self.failure = None
        prefs = patch.object(SYNC, "preferences", side_effect=lambda: copy.deepcopy(self.preferences))
        run = patch.object(SYNC, "run", side_effect=self.command)
        prefs.start()
        run.start()
        self.addCleanup(prefs.stop)
        self.addCleanup(run.stop)

    def status(self, mac, instance):
        return {"host_id": mac["host_id"], "instance_id": instance,
                "tailscale": {"state": "running", "allow_tailnet_members": False,
                              "https": {"state": "available", "url": mac["endpoint"]}}}

    def command(self, arguments):
        self.commands.append(arguments)
        if arguments[0] == "defaults":
            self.assertEqual(arguments[:5], ["defaults", "write", SYNC.DOMAIN, SYNC.KEY, "-data"])
            self.writes.append(arguments)
            self.preferences[SYNC.KEY] = bytes.fromhex(arguments[5])
            return b""
        self.assertEqual(arguments[:5], ["rex-fixture", "--autostart=false", "--timeout", "5s", "-S"])
        endpoint, command = arguments[5], arguments[6:]
        if endpoint == self.local_socket:
            if self.failure == "local offline":
                raise ValueError("local socket missing")
            if command[:3] == ["api", "call", "server.tailscale.enable"]:
                self.assertEqual(json.loads(command[3]), {"allow_tailnet_members": False})
                self.current["tailscale"]["allow_tailnet_members"] = False
                return json.dumps({"tailscale": self.current["tailscale"]}).encode()
            self.assertEqual(command, ["server", "status", "--json"])
            return json.dumps(self.current).encode()
        if endpoint == self.peer["endpoint"]:
            if self.failure == "peer offline":
                raise ValueError("peer offline")
            if self.failure == "malformed":
                return b"not JSON"
            if command == ["whoami", "--json"]:
                return json.dumps({"host_id": self.remote["host_id"], "instance_id": self.peer_instance}).encode()
            self.assertEqual(command, ["server", "status", "--json"])
            return json.dumps(self.remote).encode()
        self.assertEqual(endpoint, "/Users/fixture/dev.sock")
        self.assertEqual(command, ["whoami", "--json"])
        return json.dumps({"host_id": self.linux_id, "instance_id": str(uuid.uuid4())}).encode()

    def synchronize(self):
        return SYNC.synchronize(self.config, self.app, "rex-fixture", self.state)

    def test_metadata_aliases_and_opposite_mac_rendering(self):
        self.assertEqual(sorted(DATA["mac_hostnames"]), sorted(alias for mac in DATA["macs"] for alias in mac["hostnames"]))
        for own in DATA["macs"]:
            peer = next(mac for mac in DATA["macs"] if mac != own)
            for alias in own["hostnames"]:
                for hostname in (alias, alias.upper()):
                    with self.subTest(hostname=hostname):
                        config = json.loads(render("dot_config/rex/client-hosts.json.tmpl", hostname))
                        self.assertEqual(len(config["hosts"]), 6)
                        self.assertEqual(config["peers"], [{key: peer[key] for key in ("label", "endpoint", "host_id")}])
                        self.assertEqual(config["local"]["host_id"], own["host_id"])
                        self.assertEqual(config["local"]["endpoint"], self.local_socket)
                        lua = render("dot_config/rex/init.lua.tmpl", hostname)
                        self.assertEqual(lua.count("rex.host{"), 7)
                        self.assertIn(peer["endpoint"], lua)
                        self.assertNotIn(own["endpoint"], lua)
                        self.assertIn(peer["endpoint"], render("dot_config/rex/client-hosts.txt.tmpl", hostname))
        for platform, hostname in (("linux", "roz-dev-station"), ("darwin", "unlisted"), ("windows", "laptop")):
            self.assertNotIn("https://", render("dot_config/rex/init.lua.tmpl", hostname, platform))

    def test_add_peer_preserves_linux_custom_names_colors_and_real_identity(self):
        result = self.synchronize()
        self.assertEqual(result["added"], [self.peer["label"]])
        self.assertEqual(result["local_tailnet"]["state"], "ready")
        merged = json.loads(self.preferences[SYNC.KEY])
        self.assertEqual(merged["records"][0], self.record)
        self.assertEqual(merged["unknownRoot"], "keep")
        added = merged["records"][-1]
        self.assertEqual(added["locators"], [self.peer["endpoint"]])
        self.assertEqual(added["lastHostID"], self.peer["host_id"])
        self.assertEqual(added["lastInstanceID"], self.peer_instance)
        self.assertEqual(self.preferences["Workspace.customThemes"], b"exact colors")
        self.assertFalse(self.preferences["remoteControl"])
        self.assertEqual(plistlib.loads(Path(result["backup"]).read_bytes())["value"], self.original)

    def test_reapply_preserves_native_bytes_ids_and_backup_count(self):
        self.synchronize()
        before = self.preferences[SYNC.KEY]
        result = self.synchronize()
        self.assertFalse(result["changed"])
        self.assertEqual(result["pending_peers"], [])
        self.assertEqual(self.preferences[SYNC.KEY], before)
        self.assertEqual(len(self.writes), 1)
        self.assertEqual(len(list(self.state.iterdir())), 1)

    def test_offline_peer_is_pending_without_writes(self):
        self.failure = "peer offline"
        result = self.synchronize()
        self.assertFalse(result["changed"])
        self.assertEqual(result["pending_peers"][0]["label"], self.peer["label"])
        self.assertEqual(self.preferences[SYNC.KEY], self.original)
        self.assertFalse(self.state.exists())

    def test_offline_peer_does_not_block_new_linux_registration(self):
        self.preferences[SYNC.KEY] = json.dumps(dict(self.directory, records=[])).encode()
        self.failure = "peer offline"
        result = self.synchronize()
        self.assertEqual(result["added"], ["dev"])
        self.assertEqual(len(result["pending_peers"]), 1)
        self.assertEqual(json.loads(self.preferences[SYNC.KEY])["records"][0]["lastHostID"], self.linux_id)

    def test_invalid_https_addresses_fail_before_commands(self):
        cases = ["http://peer.ts.net", "https://example.test", "https://user@peer.ts.net",
                 "https://peer.ts.net:444", "https://peer.ts.net/api", "https://peer.ts.net?x=1",
                 "https://peer.ts.net#fragment", "https://peer.ts.net/../", "https://peer.ts.net with-space"]
        for address in cases:
            self.config["peers"][0]["endpoint"] = address
            with self.subTest(address=address), self.assertRaises(ValueError):
                self.synchronize()
        self.assertFalse(self.commands)
        self.assertFalse(self.writes)

    def test_duplicate_requests_fail_before_commands(self):
        self.config["peers"].append(copy.deepcopy(self.config["peers"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.synchronize()
        self.assertFalse(self.commands)

    def test_conflicting_native_name_is_not_ignored_as_pending(self):
        self.record["name"] = self.peer["label"]
        self.preferences[SYNC.KEY] = json.dumps(self.directory).encode()
        with self.assertRaisesRegex(ValueError, "different address"):
            self.synchronize()
        self.assertFalse(self.writes)

    def test_wrong_peer_host_id_fails_without_write(self):
        self.remote["host_id"] = str(uuid.uuid4())
        with self.assertRaisesRegex(ValueError, "verified machine"):
            self.synchronize()
        self.assertFalse(self.writes)

    def test_peer_restarting_during_discovery_fails_without_write(self):
        self.remote["instance_id"] = str(uuid.uuid4())
        with self.assertRaisesRegex(ValueError, "changed during discovery"):
            self.synchronize()
        self.assertFalse(self.writes)

    def test_non_owner_policy_or_tagged_peer_is_rejected(self):
        for field, value in (("allow_tailnet_members", True), ("allow_tailnet_members", None), ("tags", ["tag:rex"])):
            with self.subTest(field=field):
                before = copy.deepcopy(self.remote)
                self.remote["tailscale"][field] = value
                with self.assertRaisesRegex(ValueError, "enrolling Tailscale user"):
                    self.synchronize()
                self.remote = before
        self.assertFalse(self.writes)

    def test_local_broader_policy_is_only_narrowed_over_its_unix_socket(self):
        self.current["tailscale"]["allow_tailnet_members"] = True
        result = self.synchronize()
        changes = [command for command in self.commands if "server.tailscale.enable" in command]
        self.assertEqual(len(changes), 1)
        self.assertEqual(changes[0][5], self.local_socket)
        self.assertFalse(self.current["tailscale"]["allow_tailnet_members"])
        self.assertEqual(self.current["instance_id"], self.instance)
        self.assertEqual(result["local_tailnet"]["state"], "ready")

    def test_local_wrong_identity_is_never_mutated(self):
        self.current["host_id"] = str(uuid.uuid4())
        self.current["tailscale"]["allow_tailnet_members"] = True
        with self.assertRaisesRegex(ValueError, "refusing to change"):
            self.synchronize()
        self.assertFalse(any("server.tailscale.enable" in command for command in self.commands))
        self.assertFalse(self.writes)

    def test_local_tagged_node_is_not_reenrolled(self):
        self.current["tailscale"]["tags"] = ["tag:rex"]
        with self.assertRaisesRegex(ValueError, "re-enrollment requires"):
            self.synchronize()
        self.assertFalse(any("server.tailscale.enable" in command for command in self.commands))
        self.assertFalse(self.writes)

    def test_disabled_login_and_approval_states_do_not_enable_or_restart(self):
        self.synchronize()
        for state in ("disabled", "starting", "needs_login", "needs_machine_approval", "future-state"):
            with self.subTest(state=state):
                self.current["tailscale"]["state"] = state
                result = self.synchronize()
                self.assertEqual(result["local_tailnet"]["state"], state)
                self.assertFalse(result["changed"])
                self.assertIn("runtime-only", result["local_tailnet"]["reason"])
        self.assertFalse(any("server.tailscale.enable" in command for command in self.commands))

    def test_missing_local_server_is_not_started(self):
        self.failure = "local offline"
        result = self.synchronize()
        self.assertEqual(result["local_tailnet"]["state"], "pending")
        self.assertFalse(any("server.tailscale.enable" in command for command in self.commands))

    def test_https_pending_and_dns_mismatch_are_explicit(self):
        self.current["tailscale"]["https"]["state"] = "pending"
        self.assertEqual(self.synchronize()["local_tailnet"]["state"], "pending")
        self.current["tailscale"]["https"] = {"state": "available", "url": "https://other.ts.net"}
        with self.assertRaisesRegex(ValueError, "DNS does not match"):
            self.synchronize()
        self.assertFalse(any("server.tailscale.rename" in command for command in self.commands))

    def test_existing_peer_conflicting_identity_is_rejected(self):
        self.directory["records"].append({"id": str(uuid.uuid4()), "name": "My Mac",
                                          "locators": [self.peer["endpoint"]], "lastHostID": str(uuid.uuid4())})
        self.preferences[SYNC.KEY] = json.dumps(self.directory).encode()
        with self.assertRaisesRegex(ValueError, "conflicting host identity"):
            self.synchronize()
        self.assertFalse(self.writes)

    def test_existing_peer_url_normalization_keeps_custom_name(self):
        self.directory["records"].append({"id": str(uuid.uuid4()), "name": "My Mac",
                                          "locators": [self.peer["endpoint"].upper() + "/"], "lastHostID": self.peer["host_id"]})
        self.preferences[SYNC.KEY] = json.dumps(self.directory).encode()
        result = self.synchronize()
        self.assertFalse(result["changed"])
        self.assertFalse(self.writes)

    def test_malformed_peer_json_fails_instead_of_becoming_offline(self):
        self.failure = "malformed"
        with self.assertRaises(ValueError):
            self.synchronize()
        self.assertFalse(self.writes)


if __name__ == "__main__":
    unittest.main()
