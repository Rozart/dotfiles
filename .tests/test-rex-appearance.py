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
SPEC = importlib.util.spec_from_file_location("rex_appearance", ROOT / "dot_config/rex/sync-appearance.py")
assert SPEC is not None and SPEC.loader is not None
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)
REAL_PREFERENCES = SYNC.preferences


class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.app = self.home / "Rex Beta.app"
        (self.app / "Contents").mkdir(parents=True)
        self.info = {"CFBundleVersion": SYNC.BUILD, "CFBundleIdentifier": SYNC.DOMAIN, "CFBundleExecutable": "Rex"}
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps(self.info))
        self.state = self.home / "backups"
        self.config = json.loads((ROOT / "dot_config/rex/appearance.json").read_text())
        self.other = copy.deepcopy(self.config["themes"][0])
        self.other.update(id="custom-" + str(uuid.uuid4()).upper(), name="My unrelated theme", futureField={"keep": True})
        self.themes = copy.deepcopy(self.config["themes"]) + [self.other]
        self.themes[0]["futureField"] = "keep"
        self.themes[0]["palette"]["futurePaletteField"] = "keep"
        self.preferences = copy.deepcopy(self.config["preferences"])
        self.preferences.update({
            SYNC.THEMES_KEY: json.dumps(self.themes, indent=3).encode(),
            "Workspace.terminalFontPointSize": 9.0,
            "RexSync.servers": b"exact original host data",
            "Workspace.sidebarWidth": 500.0,
            "Workspace.sidebarCollapsed": True,
            "Workspace.lastFocusedSession": b"session state",
            "Workspace.terminalCopyOnSelect": False,
            "remoteControl": False,
            "SUAutomaticallyUpdate": True,
            "unrelated": {"keep": [1, 2]},
        })
        self.calls = []
        self.failure = None
        patches = [
            patch.object(SYNC, "preferences", side_effect=lambda: copy.deepcopy(self.preferences)),
            patch.object(SYNC, "gui_running", return_value=False),
            patch.object(SYNC, "installed_font", return_value=True),
            patch.object(SYNC, "run", side_effect=self.run_command),
        ]
        self.mocks = [item.start() for item in patches]
        for item in patches:
            self.addCleanup(item.stop)

    def run_command(self, arguments):
        self.calls.append(arguments)
        self.assertEqual(arguments[:3], ["defaults", "write", SYNC.DOMAIN])
        key, kind, value = arguments[3:]
        self.assertIn(key, set(SYNC.PREFERENCE_TYPES) | {SYNC.THEMES_KEY})
        if self.failure == "write":
            raise ValueError("fixture write failed")
        converters = {"-data": bytes.fromhex, "-bool": lambda value: value == "true", "-float": float, "-int": int, "-string": str}
        self.preferences[key] = converters[kind](value)
        if self.failure == "readback":
            self.preferences[key] = "incorrect readback"
        if self.failure == "typed readback":
            self.preferences[key] = int(self.preferences[key])
        if self.failure == "concurrent":
            self.preferences["Workspace.appearance"] = "concurrent change"
        return b""

    def synchronize(self, check=False):
        return SYNC.synchronize(self.config, self.app, self.state, check)

    def test_profile_capture_has_only_approved_appearance(self):
        SYNC.validate_profile(self.config)
        self.assertEqual(len(self.config["preferences"]), 36)
        self.assertEqual({theme["name"] for theme in self.config["themes"]}, {"Sonokai Hikari", "Sonokai Shusia"})
        self.assertEqual(self.config["preferences"]["Workspace.terminalFontName"], "Pragmasevka Nerd Font")
        self.assertEqual(self.config["preferences"]["Workspace.terminalFontPointSize"], 11.0)
        self.assertEqual(self.config["preferences"]["Workspace.activePaneBorderColor"], "accent")
        self.assertNotIn("/Users/", json.dumps(self.config))

    def test_changes_preserve_unmanaged_preferences_and_exact_backup(self):
        before = copy.deepcopy(self.preferences)
        result = self.synchronize()
        self.assertTrue(result["changed"])
        self.assertFalse(result["pending"])
        self.assertEqual(result["keys"], ["Workspace.terminalFontPointSize"])
        for key in set(before) - {"Workspace.terminalFontPointSize"}:
            self.assertEqual(self.preferences[key], before[key])
        saved = Path(result["backup"])
        contents = plistlib.loads(saved.read_bytes())
        self.assertEqual(contents["domain"], SYNC.DOMAIN)
        self.assertEqual(contents["preferences"][SYNC.THEMES_KEY]["value"], before[SYNC.THEMES_KEY])
        self.assertEqual(contents["preferences"]["Workspace.terminalFontPointSize"]["value"], 9.0)
        self.assertNotIn("RexSync.servers", contents["preferences"])
        self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.calls[0][-2:], ["-float", "11.0"])

    def test_reapply_has_no_write_or_additional_backup_with_running_gui(self):
        self.synchronize()
        before = copy.deepcopy(self.preferences)
        calls = len(self.calls)
        self.mocks[1].return_value = True
        result = self.synchronize()
        self.assertFalse(result["changed"])
        self.assertFalse(result["pending"])
        self.assertEqual(self.preferences, before)
        self.assertEqual(len(self.calls), calls)
        self.assertEqual(len(list(self.state.iterdir())), 1)

    def test_running_gui_defers_all_changes_without_backup(self):
        before = copy.deepcopy(self.preferences)
        self.mocks[1].return_value = True
        result = self.synchronize()
        self.assertTrue(result["pending"])
        self.assertFalse(result["changed"])
        self.assertIn("quit only the GUI", result["reason"])
        self.assertEqual(self.preferences, before)
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_check_only_never_writes_or_backs_up(self):
        result = self.synchronize(check=True)
        self.assertTrue(result["pending"])
        self.assertIn("Check only", result["reason"])
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_fresh_preferences_and_typed_writes(self):
        self.preferences = {}
        result = self.synchronize()
        self.assertTrue(result["changed"])
        self.assertEqual(len(self.calls), 37)
        self.assertEqual(self.calls[0][3], SYNC.THEMES_KEY)
        self.assertEqual({call[4] for call in self.calls}, {"-data", "-bool", "-float", "-int", "-string"})
        saved = plistlib.loads(Path(result["backup"]).read_bytes())
        self.assertTrue(all(record == {"present": False} for record in saved["preferences"].values()))
        self.assertFalse(self.synchronize()["changed"])

    def test_merge_preserves_unmanaged_and_unknown_theme_fields(self):
        self.themes[0]["palette"]["foreground"]["red"] = 0.0
        self.preferences[SYNC.THEMES_KEY] = json.dumps(self.themes).encode()
        result = self.synchronize()
        merged = json.loads(self.preferences[SYNC.THEMES_KEY])
        self.assertEqual(merged[-1], self.other)
        self.assertEqual(merged[0]["futureField"], "keep")
        self.assertEqual(merged[0]["palette"]["futurePaletteField"], "keep")
        self.assertEqual(merged[0]["palette"]["foreground"], self.config["themes"][0]["palette"]["foreground"])
        self.assertTrue(result["changed"])

    def test_new_managed_themes_are_additive(self):
        self.preferences[SYNC.THEMES_KEY] = json.dumps([self.other]).encode()
        self.synchronize()
        merged = json.loads(self.preferences[SYNC.THEMES_KEY])
        self.assertEqual(merged[0], self.other)
        self.assertEqual(len(merged), 3)

    def test_invalid_profile_and_builds_never_write(self):
        cases = []
        for key, value in [("formatVersion", 2), ("formatVersion", True), ("build", "9999"), ("preferences", {})]:
            cases.append(dict(self.config, **{key: value}))
        invalid = copy.deepcopy(self.config)
        invalid["preferences"]["RexSync.servers"] = "not allowed"
        cases.append(invalid)
        invalid = copy.deepcopy(self.config)
        invalid["preferences"]["Workspace.cursorShadersEnabled"] = 1
        cases.append(invalid)
        invalid = copy.deepcopy(self.config)
        invalid["preferences"]["Workspace.terminalFontPointSize"] = float("nan")
        cases.append(invalid)
        invalid = copy.deepcopy(self.config)
        invalid["preferences"]["Workspace.lightThemeID"] = "missing"
        cases.append(invalid)
        for config in cases:
            with self.subTest(config_version=config.get("formatVersion")):
                self.config = config
                with self.assertRaises(ValueError):
                    self.synchronize()
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_wrong_app_identity_or_build_never_writes(self):
        for key, value in [("CFBundleVersion", "9999"), ("CFBundleIdentifier", "other.app"), ("CFBundleExecutable", "Other")]:
            (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps(dict(self.info, **{key: value})))
            with self.assertRaisesRegex(ValueError, "existing app is preserved"):
                self.synchronize()
        self.assertFalse(self.calls)

    def test_missing_font_fails_without_fallback_or_changes(self):
        self.mocks[2].return_value = False
        with self.assertRaisesRegex(ValueError, "Required font is not installed"):
            self.synchronize()
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_invalid_native_theme_formats_never_write(self):
        original = json.dumps(self.themes).encode()
        cases = ["not Data", b"not JSON", b"{}", json.dumps([self.other, self.other]).encode()]
        for field, value in [("id", "invalid"), ("palette", {}), ("appearance", "invalid")]:
            cases.append(json.dumps([dict(self.other, **{field: value})]).encode())
        invalid = copy.deepcopy(self.other)
        invalid["palette"]["foreground"]["red"] = True
        cases.append(json.dumps([invalid]).encode())
        for value in cases:
            with self.subTest(value_type=type(value).__name__):
                self.preferences[SYNC.THEMES_KEY] = value
                with self.assertRaises(ValueError):
                    self.synchronize()
                self.assertEqual(self.preferences[SYNC.THEMES_KEY], value)
        self.preferences[SYNC.THEMES_KEY] = original
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_concurrent_target_edit_aborts_before_backup(self):
        concurrent = dict(self.preferences, **{"Workspace.appearance": "concurrent change"})
        self.mocks[0].side_effect = [copy.deepcopy(self.preferences), concurrent]
        with self.assertRaisesRegex(ValueError, "changed during discovery"):
            self.synchronize()
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_gui_starting_before_write_aborts(self):
        self.mocks[1].side_effect = [False, True]
        with self.assertRaisesRegex(ValueError, "Rex started"):
            self.synchronize()
        self.assertFalse(self.calls)
        self.assertFalse(self.state.exists())

    def test_failure_or_concurrent_edit_retains_recovery_backup(self):
        for failure in ("write", "readback", "typed readback", "concurrent"):
            with self.subTest(failure=failure):
                self.failure = failure
                before = copy.deepcopy(self.preferences)
                self.preferences["Workspace.terminalFontPointSize"] = 9.0
                with self.assertRaisesRegex(ValueError, "original appearance backup"):
                    self.synchronize()
                self.preferences = before
        self.assertEqual(len(list(self.state.iterdir())), 4)

    def test_snapshots_distinguish_boolean_integer_and_real(self):
        self.assertFalse(SYNC.same_snapshot({"a": True}, {"a": 1}))
        self.assertFalse(SYNC.same_snapshot({"a": 1.0}, {"a": 1}))

    def test_native_domain_absence_is_supported_without_masking_other_errors(self):
        with patch.object(SYNC, "run", return_value=plistlib.dumps({})):
            self.assertEqual(REAL_PREFERENCES(), {})
        with patch.object(SYNC, "run", side_effect=ValueError("preference export failed")):
            with self.assertRaisesRegex(ValueError, "preference export failed"):
                REAL_PREFERENCES()


if __name__ == "__main__":
    unittest.main()
