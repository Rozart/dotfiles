import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("rex_parity_inventory", ROOT / ".tests/update-rex-parity.py")
INVENTORY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INVENTORY)


class ParityInventoryTests(unittest.TestCase):
    def test_tmux_keys_normalize_to_rex_physical_keys(self):
        expected = {
            "\\{": "shift+[", "\\}": "shift+]", "\\\"": "shift+'", "\\'": "'",
            "(": "shift+9", ")": "shift+0", "C-o": "ctrl+o", "M-Up": "alt+up",
            "BTab": "shift+tab", "Space": "space", "T": "shift+t",
        }
        for key, normalized in expected.items():
            with self.subTest(key=key):
                self.assertEqual(INVENTORY.rex_key(key), normalized)

    def test_accepted_differences_do_not_imply_unverified_parity(self):
        self.assertEqual(INVENTORY.binding_status("copy-mode-vi", "v", None), "Accepted difference")
        self.assertEqual(INVENTORY.binding_status("copy-mode", "C-Space", None), "Accepted difference")
        self.assertEqual(INVENTORY.binding_status("prefix", "C-Up", {"action": "pane.resize"}), "Accepted difference")
        self.assertEqual(INVENTORY.binding_status("prefix", "C-Up", None), "Missing")
        self.assertEqual(INVENTORY.binding_status("prefix", "M-1", None), "Missing")
        self.assertEqual(INVENTORY.binding_status("prefix", "h", {"action": "pane.focus"}), "Investigating")

    def test_every_inventory_binding_has_an_explicit_status(self):
        data = json.loads((ROOT / ".tests/rex-parity-inventory.json").read_text())
        self.assertTrue({"prefix", "root", "copy-mode", "copy-mode-vi", "move"}.issubset(
            {binding["table"] for binding in data["bindings"]}))
        statuses = {"Matched", "Accepted difference", "Missing", "Investigating", "Not applicable"}
        for binding in data["bindings"]:
            self.assertIn(binding["status"], statuses)
            self.assertTrue(binding["evidence"])

    def test_snapshot_bindings_target_advertised_actions(self):
        data = json.loads((ROOT / ".tests/rex-parity-inventory.json").read_text())
        actions = {action["name"]: action for action in [*data["rex_keymap"]["actions"], *data["rex_actions"]]}
        for binding in data["rex_keymap"]["bindings"]:
            with self.subTest(keys=binding["keys"]):
                self.assertTrue(binding["action"] in actions, "Missing advertised action: " + binding["action"])
                schema = actions[binding["action"]].get("args", {})
                for argument in schema.get("required", []):
                    self.assertIn(argument, binding.get("args", {}))
        self.assertGreaterEqual(len(data["rex_keymap"]["bindings"]), 59)
        self.assertEqual(data["rex_keymap"]["diagnostics"], [])


if __name__ == "__main__":
    unittest.main()
