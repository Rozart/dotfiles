import argparse
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import threading
import time
import uuid
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
COMMAND = ["rex", "--autostart=false"]
CONTROL_ENV = {key: value for key, value in os.environ.items() if not key.startswith("REX_")}


def rex_output(*args):
    result = subprocess.run([*COMMAND, *args], env=CONTROL_ENV, capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout


def rex(*args):
    output = rex_output(*args)
    return json.loads(output) if output.strip() else None


def configure_local_server():
    identity = rex("whoami", "--json")
    endpoint = identity["endpoint"]
    address = urlsplit(endpoint)
    if address.scheme != "unix" or address.netloc or not Path(unquote(address.path)).is_absolute():
        raise SystemExit("Local-only fixtures require a local Unix-socket Rex endpoint")
    COMMAND.extend(["-S", endpoint])
    return endpoint


def anthropic_events(mode, model, home):
    permission = mode == "permission"
    block = {"type": "tool_use", "id": "toolu_fixture", "name": "Bash", "input": {}} if permission else {"type": "text", "text": ""}
    delta = {"type": "input_json_delta", "partial_json": json.dumps({"command": "printf status-fixture > " + shlex.quote(str(home / "approval-proof")), "description": "Status fixture permission"})} if permission else {"type": "text_delta", "text": "Status fixture complete."}
    return [
        ("message_start", {"type": "message_start", "message": {"id": "msg_fixture", "type": "message", "role": "assistant", "model": model, "content": [], "stop_reason": None, "stop_sequence": None, "usage": {"input_tokens": 1, "output_tokens": 0}}}),
        ("content_block_start", {"type": "content_block_start", "index": 0, "content_block": block}),
        ("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": delta}),
        ("content_block_stop", {"type": "content_block_stop", "index": 0}),
        ("message_delta", {"type": "message_delta", "delta": {"stop_reason": "tool_use" if permission else "end_turn", "stop_sequence": None}, "usage": {"output_tokens": 1}}),
        ("message_stop", {"type": "message_stop"}),
    ]


def openai_events(mode):
    if mode == "permission":
        item = {"type": "function_call", "id": "fc_fixture", "call_id": "call_fixture", "name": "exec_command", "arguments": json.dumps({"cmd": "printf status-fixture", "sandbox_permissions": "require_escalated", "justification": "Status fixture permission"}), "status": "completed"}
    else:
        item = {"type": "message", "id": "msg_fixture", "role": "assistant", "content": [{"type": "output_text", "text": "Status fixture complete.", "annotations": []}], "status": "completed"}
    response = {"id": "resp_fixture", "object": "response", "created_at": 0, "model": "gpt-5.4", "status": "completed", "output": [item], "usage": {"input_tokens": 1, "output_tokens": 1, "total_tokens": 2}}
    return [
        ("response.created", {"type": "response.created", "response": {**response, "status": "in_progress", "output": []}}),
        ("response.output_item.added", {"type": "response.output_item.added", "output_index": 0, "item": item}),
        ("response.output_item.done", {"type": "response.output_item.done", "output_index": 0, "item": item}),
        ("response.completed", {"type": "response.completed", "response": response}),
    ]


@contextmanager
def provider(agent, mode, home):
    release = threading.Event()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
            if "count_tokens" in self.path:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"input_tokens":1}')
                return
            release.wait(25)
            self.send_response(400 if mode == "error" else 200)
            self.send_header("Content-Type", "application/json" if mode == "error" else "text/event-stream")
            self.end_headers()
            if mode == "error":
                self.wfile.write(b'{"type":"error","error":{"type":"invalid_request_error","message":"Fixture request error"}}')
            else:
                events = anthropic_events(mode, body.get("model", "fixture"), home) if agent == "claude" else openai_events(mode)
                for name, data in events:
                    self.wfile.write(("event: " + name + "\ndata: " + json.dumps(data) + "\n\n").encode())
                    self.wfile.flush()

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        yield "http://127.0.0.1:" + str(server.server_port), release
    finally:
        release.set()
        server.shutdown()
        server.server_close()
        worker.join(timeout=3)


def wait_status(session, block, state, kind=None, app=None):
    last = []
    for attempt in range(120):
        last = rex("block", "call", "-s", session, "-b", block, "program_status")["records"]
        if any(record["state"] == state and (kind is None or record.get("kind") == kind)
               and (app is None or record.get("app") == app) for record in last):
            return
        time.sleep(0.15)
    screen = rex_output("capture", "-s", session, "-b", block, "--trim")
    raise AssertionError(json.dumps({"expected": state, "kind": kind, "records": last, "fixture_screen": screen[-1800:]}))


def agent_command(agent, home, endpoint):
    if agent == "claude":
        (home / ".claude.json").write_text(json.dumps({"hasCompletedOnboarding": True, "theme": "dark", "projects": {str(home): {"hasTrustDialogAccepted": True}}}))
        return ["ANTHROPIC_AUTH_TOKEN=fixture-not-a-real-token", "ANTHROPIC_BASE_URL=" + endpoint, "DISABLE_AUTOUPDATER=1", shutil.which(agent), "--setting-sources", "", "--tools", "Bash", "--permission-mode", "default", "--", "Status reporting fixture."]
    config = home / ".codex"
    config.mkdir()
    (config / "config.toml").write_text(
        'model = "gpt-5.4"\nmodel_provider = "fixture"\ncheck_for_update_on_startup = false\n'
        '[analytics]\nenabled = false\n'
        '[model_providers.fixture]\nname = "Fixture"\nbase_url = ' + json.dumps(endpoint + "/v1") + '\nwire_api = "responses"\nrequires_openai_auth = false\n'
        f'[projects.{json.dumps(str(home))}]\ntrust_level = "trusted"\n'
    )
    return [shutil.which(agent), "--no-daemon", "--no-alt-screen", "-a", "on-request", "-s", "read-only", "Status reporting fixture."]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--agents", nargs="+", choices=["claude", "codex", "pi"], default=["claude", "codex", "pi"])
    args = parser.parse_args()
    if args.manifest.exists():
        raise SystemExit("Manifest already exists; inspect it before another run")
    required = {"rex", *args.agents} | ({"node"} if "pi" in args.agents else set())
    missing = sorted(command for command in required if not shutil.which(command))
    if missing:
        raise SystemExit("Missing required executables: " + ", ".join(missing))
    versions = {agent: subprocess.check_output([agent, "--version"], text=True).strip() for agent in args.agents}
    versions["rex"] = subprocess.check_output(["rex", "version"], text=True).splitlines()[0]
    endpoint = configure_local_server()
    state = {"versions": versions, "local_server": endpoint, "created_sessions": [], "remaining_sessions": [], "pending_labels": [], "results": [], "cleaned": False}

    def save():
        args.manifest.write_text(json.dumps(state, indent=2) + "\n")

    def create(home, command):
        label = "status-fixture-" + uuid.uuid4().hex
        state["pending_labels"].append(label)
        save()
        created = rex("new", label, "-c", str(home), "--shell", "none", "--json", "--", "/usr/bin/env", "-i", "HOME=" + str(home), "PATH=" + os.environ["PATH"], "TERM=xterm-256color", "TERM_PROGRAM=rex", "LANG=en_US.UTF-8", *command)
        session = created["session_id"]
        state["created_sessions"].append(session)
        state["remaining_sessions"].append(session)
        state["pending_labels"].remove(label)
        save()
        return session, created["initial_windows"][0]["block_ids"][0]

    def destroy(session):
        rex("kill", session)
        state["remaining_sessions"].remove(session)
        save()

    save()
    with tempfile.TemporaryDirectory(prefix="rex-status-") as directory:
        root = Path(directory).resolve()
        try:
            for agent in args.agents:
                if agent == "pi":
                    version = subprocess.check_output(["pi", "--version"], text=True).strip()
                    modules = Path(os.environ.get("PI_MANAGED_INSTALL_ROOT", str(Path.home() / ".pi/agent/install"))) / "releases" / version / "node_modules"
                    session, block = create(root, [shutil.which("node"), str(ROOT / ".tests/rex-pi-status.mjs"), str(modules)])
                    try:
                        wait_status(session, block, "idle", app="pi")
                        commands = [
                            ({"action": "event", "event": {"type": "agent_start"}}, "working", None),
                            ({"action": "blocked", "source": "permission", "status": {"kind": "permission", "message": "Fixture permission"}}, "blocked", "permission"),
                            ({"action": "blocked", "source": "question", "status": {"kind": "question", "message": "Fixture question"}}, "blocked", "question"),
                            ({"action": "blocked", "source": "question"}, "blocked", "permission"),
                            ({"action": "blocked", "source": "permission"}, "working", None),
                            ({"action": "event", "event": {"type": "agent_settled", "aborted": False}}, "done", None),
                            ({"action": "event", "event": {"type": "agent_start"}}, "working", None),
                            ({"action": "event", "event": {"type": "message_end", "message": {"role": "assistant", "stopReason": "error", "errorMessage": "Fixture failure"}}}, "working", None),
                            ({"action": "event", "event": {"type": "agent_settled", "aborted": False}}, "error", None),
                            ({"action": "event", "event": {"type": "agent_start"}}, "working", None),
                            ({"action": "event", "event": {"type": "agent_settled", "aborted": True}}, "idle", None),
                        ]
                        for command, expected, kind in commands:
                            rex("block", "call", "-s", session, "-b", block, "write", json.dumps({"data": json.dumps(command) + "\n"}))
                            wait_status(session, block, expected, kind, app="pi")
                        state["results"].append({"agent": "pi", "verification": "installed reporter and formatter; injected lifecycle events", "states": ["idle", "working", "blocked:permission", "blocked:question", "done", "error", "abort:idle"]})
                    finally:
                        destroy(session)
                    continue
                for mode in ("done", "error", "permission"):
                    home = root / (agent + "-" + mode)
                    home.mkdir()
                    with provider(agent, mode, home) as (endpoint, release):
                        session, block = create(home, agent_command(agent, home, endpoint))
                        try:
                            wait_status(session, block, "working", app="claude-code" if agent == "claude" else "codex")
                            release.set()
                            wait_status(session, block, "blocked" if mode == "permission" else mode,
                                        "permission" if mode == "permission" else None,
                                        app="claude-code" if agent == "claude" else "codex")
                            assert not (home / "approval-proof").exists(), "Permission fixture unexpectedly executed"
                            state["results"].append({"agent": agent, "verification": "installed interactive CLI with loopback-only model fixture", "states": ["working", "blocked:permission" if mode == "permission" else mode]})
                            save()
                        finally:
                            destroy(session)
        finally:
            failures = {}
            for session in list(state["remaining_sessions"]):
                try:
                    destroy(session)
                except Exception as error:
                    failures[session] = str(error)
            state["cleaned"] = not state["remaining_sessions"] and not state["pending_labels"]
            state["cleanup_errors"] = failures
            save()
    if not state["cleaned"]:
        raise RuntimeError("Inspect remaining owned sessions in " + str(args.manifest))
    print(json.dumps({"versions": versions, "results": state["results"], "fixtures_cleaned": True}, indent=2))


if __name__ == "__main__":
    main()
