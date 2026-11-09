import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen


SPEC = importlib.util.spec_from_file_location("rex_agent_status", Path(__file__).with_name("rex-agent-status.py"))
FIXTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIXTURE)


class AgentStatusTests(unittest.TestCase):
    def test_control_commands_strip_inherited_rex_targets(self):
        with patch.object(FIXTURE.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="{}", stderr="")) as run:
            FIXTURE.rex("ls", "--json")
        environment = run.call_args.kwargs["env"]
        self.assertFalse(any(key.startswith("REX_") for key in environment))
        self.assertEqual(run.call_args.args[0][-2:], ["ls", "--json"])

    def test_local_server_rejects_network_and_remote_authority_endpoints(self):
        for endpoint in ("tcp://127.0.0.1:9999", "ssh://remote", "unix://remote/tmp/rex.sock", "relative.sock"):
            with self.subTest(endpoint=endpoint), patch.object(FIXTURE, "rex", return_value={"endpoint": endpoint}), patch.object(FIXTURE, "COMMAND", ["rex"]):
                with self.assertRaises(SystemExit):
                    FIXTURE.configure_local_server()
                self.assertEqual(FIXTURE.COMMAND, ["rex"])

    def test_local_server_pins_the_verified_unix_endpoint(self):
        endpoint = "unix:///tmp/owned%20rex.sock"
        with patch.object(FIXTURE, "rex", return_value={"endpoint": endpoint}), patch.object(FIXTURE, "COMMAND", ["rex"]):
            self.assertEqual(FIXTURE.configure_local_server(), endpoint)
            self.assertEqual(FIXTURE.COMMAND, ["rex", "-S", endpoint])

    def test_status_requires_the_expected_application(self):
        records = [{"records": [{"state": "working", "app": "other"}]},
                   {"records": [{"state": "working", "app": "claude-code"}]}]
        with patch.object(FIXTURE, "rex", side_effect=records) as call, patch.object(FIXTURE.time, "sleep"):
            FIXTURE.wait_status("fixture-session", "fixture-block", "working", app="claude-code")
        self.assertEqual(call.call_count, 2)

    def test_blocked_requires_the_expected_reason(self):
        records = [{"records": [{"state": "blocked", "app": "pi", "kind": "question"}]},
                   {"records": [{"state": "blocked", "app": "pi", "kind": "permission"}]}]
        with patch.object(FIXTURE, "rex", side_effect=records) as call, patch.object(FIXTURE.time, "sleep"):
            FIXTURE.wait_status("fixture-session", "fixture-block", "blocked", "permission", app="pi")
        self.assertEqual(call.call_count, 2)

    def test_permission_fixture_quotes_its_owned_output_path(self):
        events = FIXTURE.anthropic_events("permission", "fixture", Path("/tmp/owned fixture"))
        delta = events[2][1]["delta"]
        command = json.loads(delta["partial_json"])["command"]
        self.assertEqual(command, "printf status-fixture > '/tmp/owned fixture/approval-proof'")
        self.assertEqual(events[-2][1]["delta"]["stop_reason"], "tool_use")

    def test_codex_permission_explicitly_requests_approval(self):
        events = FIXTURE.openai_events("permission")
        item = events[-1][1]["response"]["output"][0]
        self.assertEqual(item["name"], "exec_command")
        self.assertEqual(json.loads(item["arguments"])["sandbox_permissions"], "require_escalated")

    def test_loopback_provider_streams_success_and_returns_a_fatal_error(self):
        with tempfile.TemporaryDirectory() as directory:
            for agent in ("claude", "codex"):
                with self.subTest(agent=agent):
                    with FIXTURE.provider(agent, "done", Path(directory)) as (endpoint, release):
                        self.assertTrue(endpoint.startswith("http://127.0.0.1:"))
                        release.set()
                        request = Request(endpoint + "/v1/messages", data=b'{"model":"fixture"}', headers={"Content-Type": "application/json"})
                        with urlopen(request, timeout=3) as response:
                            payload = response.read().decode()
                        self.assertIn("Status fixture complete.", payload)
                    with FIXTURE.provider(agent, "error", Path(directory)) as (endpoint, release):
                        release.set()
                        with self.assertRaises(HTTPError) as raised:
                            urlopen(Request(endpoint, data=b"{}"), timeout=3)
                        self.assertEqual(raised.exception.code, 400)
                        self.assertEqual(json.loads(raised.exception.read())["error"]["type"], "invalid_request_error")


if __name__ == "__main__":
    unittest.main()
