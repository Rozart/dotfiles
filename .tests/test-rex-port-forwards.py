import importlib.util
import json
from pathlib import Path
import plistlib
import signal
import subprocess
import sys
import tomllib
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
DATA = tomllib.loads((ROOT / ".chezmoidata.toml").read_text())["rex"]
SPEC = importlib.util.spec_from_file_location("tunnel", ROOT / "dot_config/rex/ssh-tunnel.py")
tunnel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tunnel)


def render(path, hostname):
    return subprocess.check_output([
        "chezmoi", "--source", str(ROOT), "--override-data",
        json.dumps({"chezmoi": {"os": "darwin", "hostname": hostname, "homeDir": "/Users/test"}}),
        "execute-template", "--file", str(ROOT / path),
    ], text=True)


class PortForwardTests(unittest.TestCase):
    def test_both_macs_receive_only_dev_station_forwards(self):
        expected = [
            "127.0.0.1:4200:localhost:4200", "127.0.0.1:4201:localhost:4201",
            "127.0.0.1:4300:localhost:4300", "127.0.0.1:4321:localhost:4321",
            "127.0.0.1:3100:localhost:3100", "127.0.0.1:3000:localhost:3000",
            "127.0.0.1:3389:localhost:3389", "127.0.0.1:8385:localhost:8384",
            "127.0.0.1:5173:localhost:5173", "127.0.0.1:8100:100.85.168.15:8000",
            "127.0.0.1:3001:100.85.168.15:3000",
        ]
        for hostname in ("roz-laptop", "roz-mini-laptop"):
            for host in DATA["hosts"]:
                path = f'Library/LaunchAgents/dev.rozart.rex-{host["label"]}.plist.tmpl'
                args = plistlib.loads(render(path, hostname).encode())["ProgramArguments"]
                forwards = [args[index + 1] for index, value in enumerate(args) if value == "--local-forward"]
                self.assertEqual(forwards, expected if host["label"] == "dev-station" else [])

    def test_conflict_retries_without_readding_successful_forwards(self):
        process = mock.Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("ssh", 5), 0]
        first = "127.0.0.1:3000:localhost:3000"
        second = "127.0.0.1:5173:localhost:5173"
        results = [subprocess.CompletedProcess([], 1, "", "Address already in use"),
                   subprocess.CompletedProcess([], 0, "", ""),
                   subprocess.CompletedProcess([], 0, "", "")]
        with mock.patch.object(tunnel.subprocess, "run", side_effect=results) as run:
            with mock.patch.object(tunnel.sys, "stderr"):
                result = tunnel.attach_forwards(process, ["ssh", "-F", "config"], "control", "host", [first, second])
        self.assertEqual(result, 0)
        self.assertEqual([call.args[0][-2] for call in run.call_args_list], [first, second, first])
        self.assertTrue(all(call.args[0][3:7] == ["-S", "control", "-O", "forward"]
                            for call in run.call_args_list))
        process.terminate.assert_not_called()

    def test_control_timeout_and_missing_socket_are_retried(self):
        process = mock.Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("ssh", 5), subprocess.TimeoutExpired("ssh", 5), 255]
        results = [subprocess.TimeoutExpired("ssh", 10), FileNotFoundError("socket unavailable"),
                   subprocess.CompletedProcess([], 0, "", "")]
        with mock.patch.object(tunnel.subprocess, "run", side_effect=results) as run:
            with mock.patch.object(tunnel.sys, "stderr"):
                result = tunnel.attach_forwards(process, ["ssh"], "control", "host", ["127.0.0.1:3000:localhost:3000"])
        self.assertEqual(result, 255)
        self.assertEqual(run.call_count, 3)

    def test_unchanged_errors_are_logged_once(self):
        process = mock.Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("ssh", 5), 1]
        with mock.patch.object(tunnel.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "busy")):
            with mock.patch("builtins.print") as output:
                tunnel.attach_forwards(process, ["ssh"], "control", "host", ["127.0.0.1:3000:localhost:3000"])
        self.assertEqual(output.call_count, 1)

    def test_supervisor_terminates_child_on_shutdown_and_restores_handler(self):
        process = mock.Mock()
        process.poll.return_value = None
        process.__enter__ = mock.Mock(return_value=process)
        process.__exit__ = mock.Mock(return_value=False)
        with mock.patch.object(tunnel.subprocess, "Popen", return_value=process):
            with mock.patch.object(tunnel, "attach_forwards", side_effect=SystemExit(143)):
                with mock.patch.object(tunnel.signal, "signal", return_value="previous") as handler:
                    with self.assertRaises(SystemExit):
                        tunnel.supervise(["ssh"], ["ssh"], "control", "host", [])
        process.terminate.assert_called_once()
        handler.assert_has_calls([mock.call(signal.SIGTERM, tunnel.stop), mock.call(signal.SIGTERM, "previous")])

    def test_launcher_preserves_core_forwards_and_enables_master_only_when_needed(self):
        args = ["tunnel", "--config", "config", "--host", "host", "--local", "rex.sock",
                "--remote", "/run/rex.sock", "--agent", "agent.sock", "--forwarded-agent", "/run/mac.sock"]
        for forward in (None, "127.0.0.1:8385:localhost:8384"):
            argv = args + (["--local-forward", forward] if forward else [])
            with mock.patch.object(sys, "argv", argv), mock.patch.object(Path, "is_socket", return_value=True):
                with mock.patch.object(tunnel.subprocess, "run"), mock.patch.object(tunnel.os, "execv") as execute:
                    with mock.patch.object(tunnel, "supervise", return_value=0) as supervise:
                        if forward:
                            with self.assertRaises(SystemExit):
                                tunnel.main()
                            command = supervise.call_args.args[0]
                            self.assertEqual(command[3:6], ["-M", "-S", "rex.sock.control"])
                            self.assertEqual(supervise.call_args.args[-1], [forward])
                            execute.assert_not_called()
                        else:
                            tunnel.main()
                            command = execute.call_args.args[1]
                            supervise.assert_not_called()
                        self.assertIn("rex.sock:/run/rex.sock", command)
                        self.assertIn("/run/mac.sock:agent.sock", command)
                        self.assertNotIn("-O", command)
                        self.assertEqual(command[-1], "host")

    def test_non_loopback_and_invalid_ports_rejected_before_ssh(self):
        args = ["tunnel", "--config", "config", "--host", "host", "--local", "rex.sock",
                "--remote", "remote", "--agent", "agent", "--forwarded-agent", "forwarded"]
        for forward in ("0.0.0.0:3000:localhost:3000", "3000:localhost:3000", "127.0.0.1:0:localhost:3000",
                        "127.0.0.1:3000:localhost:65536", "127.0.0.1:3000::3000"):
            with mock.patch.object(sys, "argv", args + ["--local-forward", forward]):
                with mock.patch.object(tunnel.subprocess, "run") as run, mock.patch.object(tunnel.sys, "stderr"):
                    with self.assertRaises(SystemExit):
                        tunnel.main()
                    run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
