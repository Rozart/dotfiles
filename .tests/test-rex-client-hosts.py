import copy
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import uuid


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("rex_client_hosts", ROOT / "dot_config/rex/sync-client-hosts.py")
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


class NativeHostTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.app = self.home / "Rex Beta.app"
        (self.app / "Contents").mkdir(parents=True)
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": SYNC.BUILD}))
        self.state = self.home / "backups"
        self.existing = {
            "icon": "custom-icon",
            "id": str(uuid.uuid4()).upper(),
            "lastHostID": str(uuid.uuid4()),
            "lastInstanceID": str(uuid.uuid4()),
            "locators": ["unix:///Users/example/dev.sock", "https://dev.example.test"],
            "name": "My custom dev name",
            "futureField": {"keep": True},
        }
        self.directory = {"formatVersion": 1, "records": [self.existing], "futureRoot": "keep"}
        self.original = json.dumps(self.directory).encode()
        self.preferences = {SYNC.KEY: self.original, "unrelated": {"keep": [1, 2]}}
        self.config = {"build": SYNC.BUILD, "hosts": [
            {"label": "dev", "endpoint": "/Users/example/dev.sock"},
            {"label": "media", "endpoint": "/Users/example/media.sock"},
        ]}
        self.calls = []
        self.failure = None
        self.prefs_patch = patch.object(SYNC, "preferences", side_effect=lambda: copy.deepcopy(self.preferences))
        self.run_patch = patch.object(SYNC, "run", side_effect=self.run_command)
        self.prefs_patch.start()
        self.run_patch.start()
        self.addCleanup(self.prefs_patch.stop)
        self.addCleanup(self.run_patch.stop)

    def run_command(self, arguments):
        self.calls.append(arguments)
        if arguments[0] == "rex-fixture":
            self.assertEqual(arguments[1:4], ["--autostart=false", "--timeout", "5s"])
            self.assertEqual(arguments[-2:], ["whoami", "--json"])
            if self.failure == "identify":
                raise ValueError("socket unavailable")
            return json.dumps({"host_id": str(uuid.uuid4()), "instance_id": str(uuid.uuid4())}).encode()
        self.assertEqual(arguments[:5], ["defaults", "write", SYNC.DOMAIN, SYNC.KEY, "-data"])
        if self.failure == "write":
            raise ValueError("preference write failed")
        self.preferences[SYNC.KEY] = bytes.fromhex(arguments[5])
        return b""

    def synchronize(self):
        return SYNC.synchronize(self.config, self.app, "rex-fixture", self.state)

    def test_add_missing_hosts_and_preserve_existing_data(self):
        result = self.synchronize()
        self.assertEqual(result["added"], ["media"])
        directory = json.loads(self.preferences[SYNC.KEY])
        self.assertEqual(directory["records"][0], self.existing)
        self.assertEqual(directory["futureRoot"], "keep")
        self.assertEqual(self.preferences["unrelated"], {"keep": [1, 2]})
        added = directory["records"][1]
        self.assertEqual(added["name"], "media")
        self.assertEqual(added["locators"], ["unix:///Users/example/media.sock"])
        for field in ["id", "lastHostID", "lastInstanceID"]:
            uuid.UUID(added[field])
        backup = Path(result["backup"])
        self.assertEqual(plistlib.loads(backup.read_bytes())["value"], self.original)
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o700)
        self.assertEqual(len(self.calls), 2)

    def test_reapply_keeps_identities_and_avoids_writes(self):
        self.synchronize()
        previous = self.preferences[SYNC.KEY]
        calls = len(self.calls)
        result = self.synchronize()
        self.assertFalse(result["changed"])
        self.assertEqual(self.preferences[SYNC.KEY], previous)
        self.assertEqual(len(self.calls), calls)
        self.assertEqual(len(list(self.state.iterdir())), 1)

    def test_fresh_app_without_host_preference(self):
        del self.preferences[SYNC.KEY]
        result = self.synchronize()
        self.assertEqual(result["added"], ["dev", "media"])
        saved = plistlib.loads(Path(result["backup"]).read_bytes())
        self.assertFalse(saved["present"])
        self.assertNotIn("value", saved)
        self.assertEqual(self.preferences["unrelated"], {"keep": [1, 2]})

    def test_unknown_or_invalid_directory_is_not_overwritten(self):
        cases = [
            b"not json",
            {"formatVersion": 1, "records": []},
            json.dumps({"formatVersion": 2, "records": []}).encode(),
            json.dumps({"formatVersion": True, "records": []}).encode(),
            json.dumps({"formatVersion": 1, "records": "wrong"}).encode(),
            json.dumps({"formatVersion": 1, "records": [dict(self.existing, id="invalid")]}).encode(),
            json.dumps({"formatVersion": 1, "records": [self.existing, self.existing]}).encode(),
        ]
        for value in cases:
            with self.subTest(value=value):
                self.preferences[SYNC.KEY] = value
                with self.assertRaises(ValueError):
                    self.synchronize()
                self.assertEqual(self.preferences[SYNC.KEY], value)
                self.assertFalse(self.state.exists())
                self.assertFalse(self.calls)

    def test_unreviewed_app_build_is_preserved(self):
        info = self.app / "Contents/Info.plist"
        info.write_bytes(plistlib.dumps({"CFBundleVersion": "9999"}))
        before = info.read_bytes()
        with self.assertRaisesRegex(ValueError, "existing app is preserved"):
            self.synchronize()
        self.assertEqual(info.read_bytes(), before)
        self.assertEqual(self.preferences[SYNC.KEY], self.original)
        self.assertFalse(self.calls)

    def test_unreviewed_config_build_is_refused(self):
        self.config["build"] = "9999"
        with self.assertRaisesRegex(ValueError, "reviewed build"):
            self.synchronize()
        self.assertFalse(self.calls)

    def test_unreachable_host_leaves_directory_unchanged(self):
        self.failure = "identify"
        with self.assertRaisesRegex(ValueError, "unlock SSH access"):
            self.synchronize()
        self.assertEqual(self.preferences[SYNC.KEY], self.original)
        self.assertFalse(self.state.exists())
        self.assertEqual(len(self.calls), 1)

    def test_name_conflict_does_not_replace_user_host(self):
        self.config["hosts"][1]["label"] = self.existing["name"]
        with self.assertRaisesRegex(ValueError, "different address"):
            self.synchronize()
        self.assertEqual(self.preferences[SYNC.KEY], self.original)
        self.assertFalse(self.calls)

    def test_concurrent_native_edit_is_preserved(self):
        concurrent = json.dumps(dict(self.directory, futureRoot="user change")).encode()
        with patch.object(SYNC, "preferences", side_effect=[{SYNC.KEY: self.original}, {SYNC.KEY: concurrent}]):
            with self.assertRaisesRegex(ValueError, "changed during discovery"):
                self.synchronize()
        self.assertFalse(self.state.exists())
        self.assertEqual(len(self.calls), 1)

    def test_failed_write_retains_recovery_backup(self):
        self.failure = "write"
        with self.assertRaisesRegex(ValueError, "preference write failed"):
            self.synchronize()
        self.assertEqual(self.preferences[SYNC.KEY], self.original)
        saved = next(self.state.iterdir())
        self.assertEqual(plistlib.loads(saved.read_bytes())["value"], self.original)

    def test_spaces_in_socket_paths_are_encoded_and_matched(self):
        self.config["hosts"][1]["endpoint"] = "/Users/Example User/media.sock"
        self.synchronize()
        directory = json.loads(self.preferences[SYNC.KEY])
        self.assertEqual(directory["records"][1]["locators"], ["unix:///Users/Example%20User/media.sock"])
        calls = len(self.calls)
        self.assertFalse(self.synchronize()["changed"])
        self.assertEqual(len(self.calls), calls)


if __name__ == "__main__":
    unittest.main()
