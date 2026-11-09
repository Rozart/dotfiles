import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[1]
COMMAND = ["rex", "--autostart=false"]


def call(*args):
    result = subprocess.run(
        [*COMMAND, *args], capture_output=True, text=True, timeout=90,
    )
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return json.loads(result.stdout) if result.stdout.strip() else None


def cleanup_sessions(sessions):
    failures = {}
    for session in sessions:
        try:
            call("kill", session)
        except Exception as error:
            failures[session] = str(error)
    try:
        present = {item["session_id"] for item in call("ls", "--json")["sessions"]}
        remaining = [session for session in sessions if session in present]
    except Exception as error:
        failures["verification"] = str(error)
        remaining = [session for session in sessions if session in failures]
    return remaining, failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", required=True)
    parser.add_argument("--server")
    parser.add_argument("--observer-pid", type=int)
    parser.add_argument("--restore-session", required=True)
    parser.add_argument("--restore-window", required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    if args.server:
        if not args.observer_pid:
            raise SystemExit("Remote fixtures require the local app's --observer-pid")
        COMMAND.extend(["-S", args.server])
    if args.manifest.exists():
        raise SystemExit("Manifest already exists; inspect its resources before another run")
    clients = call("client", "ls", "--json")["clients"]
    matches = [item for item in clients if item.get("info", {}).get("kind") == "app"
               and (item["client_id"] == args.client or item["info"].get("label") == args.client)]
    if len(matches) != 1:
        raise SystemExit("Expected exactly one connected app matching --client")
    client = matches[0]
    args.client = client["client_id"]
    state = {"sessions": [], "cleaned": False}
    fixture = None
    if args.server:
        directories = dict(zip("ABCDE", map(Path, ("/tmp", "/var", "/usr", "/", "/tmp"))))
    else:
        fixture = tempfile.TemporaryDirectory(prefix="rp-", dir="/tmp")
        directories = {letter: Path(fixture.name) / ("parity-pane-" + letter) for letter in "ABCDE"}
        for directory in directories.values():
            directory.mkdir()

    def save():
        args.manifest.write_text(json.dumps(state, indent=2) + "\n")

    def create(letter):
        label = "rp-" + letter + "-" + uuid.uuid4().hex[:8]
        result = call("new", label, "-c", str(directories[letter]), "--shell", "none", "--json", "--", "/bin/sleep", "600")
        state["sessions"].append(result["session_id"])
        save()
        return label, result["session_id"], result["initial_windows"][0]

    save()
    try:
        source_label, source, window = create("A")
        anchor = window["block_ids"][0]
        blocks = [anchor]
        for letter in "BCD":
            result = call("split", "-s", source, "-b", anchor, "--split", "right", "-c", str(directories[letter]), "--shell", "none", "--json", "--", "/bin/sleep", "600")
            anchor = result["block_ids"][0]
            blocks.append(anchor)
        destination_label, destination, _ = create("E")
        for attempt in range(50):
            processes = {block: call("block", "call", "-s", source, "-b", block, "process").get("child") for block in blocks}
            if all(process and process.get("pid") for process in processes.values()):
                break
            time.sleep(0.1)
        assert all(process and process.get("pid") for process in processes.values())
        call("api", "call", "session.focus_block", json.dumps({"session_id": source, "block_id": blocks[0]}))
        call("-C", args.client, "do", "session.select", "session_id=" + source, "window_id=" + window["window_id"])
        result = call(
            "-C", args.client, "do", "-s", source, "-b", blocks[0], str(ROOT / ".tests/rex-core-app.lua"),
            "source_session=" + source, "source_block=" + blocks[0], "source_window=" + window["window_id"],
            "last_block=" + blocks[-1],
            "source_label=" + source_label, "destination_session=" + destination, "destination_label=" + destination_label,
            "observer=" + str(ROOT / ".tests/rex-window-title.swift"), "pid=" + str(args.observer_pid or client["principal"]["pid"]),
            *(["module=" + str(ROOT / "dot_config/rex/panes.lua"),
               *("title_" + letter.lower() + "=sleep " + str(directory) + " - " for letter, directory in directories.items())]
              if args.server else []), "--json",
        )
        result["server"] = args.server or "local"
        result["adapter_source"] = "local-script" if args.server else "server-config"
        for block, process in processes.items():
            assert call("block", "call", "-s", source, "-b", block, "process")["child"]["pid"] == process["pid"]
        result["processes_preserved"] = True
    finally:
        state["selection_restored"] = False
        try:
            call("-C", args.client, "do", "session.select", "session_id=" + args.restore_session, "window_id=" + args.restore_window)
            state["selection_restored"] = True
        except Exception as error:
            state["restore_error"] = str(error)
            print("Could not restore app selection: " + str(error), file=sys.stderr)
        remaining, errors = cleanup_sessions(state["sessions"])
        state["remaining_sessions"] = remaining
        state["cleanup_errors"] = errors
        state["cleaned"] = not remaining
        save()
        if fixture:
            fixture.cleanup()
    if not state["cleaned"] or not state["selection_restored"]:
        raise RuntimeError("Fixture cleanup or selection restoration failed; inspect " + str(args.manifest))
    result["fixtures_cleaned"] = True
    result["selection_restored"] = True
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
