import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("rex_core_fixture", Path(__file__).with_name("rex-core-app.py"))
FIXTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIXTURE)


class CoreFixtureTests(unittest.TestCase):
    def test_failed_kill_does_not_skip_other_owned_sessions(self):
        calls = []

        def invoke(*args):
            calls.append(args)
            if args == ("kill", "first"):
                raise RuntimeError("network error")
            if args == ("ls", "--json"):
                return {"sessions": [{"session_id": "first"}, {"session_id": "unrelated"}]}

        with patch.object(FIXTURE, "call", invoke):
            remaining, errors = FIXTURE.cleanup_sessions(["first", "second"])
        self.assertIn(("kill", "second"), calls)
        self.assertNotIn(("kill", "unrelated"), calls)
        self.assertEqual(remaining, ["first"])
        self.assertIn("first", errors)

    def test_list_failure_does_not_undo_acknowledged_cleanup(self):
        def invoke(*args):
            if args == ("ls", "--json"):
                raise RuntimeError("network error")

        with patch.object(FIXTURE, "call", invoke):
            remaining, errors = FIXTURE.cleanup_sessions(["first", "second"])
        self.assertEqual(remaining, [])
        self.assertIn("verification", errors)

    def test_session_removed_concurrently_is_not_reported_remaining(self):
        def invoke(*args):
            if args == ("kill", "first"):
                raise RuntimeError("session not found")
            return {"sessions": []}

        with patch.object(FIXTURE, "call", invoke):
            remaining, errors = FIXTURE.cleanup_sessions(["first"])
        self.assertEqual(remaining, [])
        self.assertIn("first", errors)


if __name__ == "__main__":
    unittest.main()
