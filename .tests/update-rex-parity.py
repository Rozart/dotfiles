import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SHIFTED = dict(zip('!@#$%^&*()_+{}|:"<>?~', "1234567890-=[]\\;',./`"))
SPECIAL = {"Space": "space", "Tab": "tab", "BTab": "shift+tab", "Enter": "enter", "Escape": "esc",
           "BSpace": "backspace", "DC": "delete", "PPage": "pageup", "NPage": "pagedown"}


def call(*args):
    return subprocess.check_output(args, text=True, timeout=20)


def rex_key(key):
    key = shlex.split(key)[0]
    modifiers = []
    while len(key) > 2 and key[1] == "-" and key[0] in "CMS":
        modifiers.append({"C": "ctrl", "M": "alt", "S": "shift"}[key[0]])
        key = key[2:]
    if key in SPECIAL:
        key = SPECIAL[key]
    elif key in SHIFTED:
        modifiers.append("shift")
        key = SHIFTED[key]
    elif len(key) == 1 and key.isupper():
        modifiers.append("shift")
        key = key.lower()
    else:
        key = key.lower()
    return "+".join([*dict.fromkeys(modifiers), key])


def binding_status(table, key, binding):
    if table in {"copy-mode", "copy-mode-vi"}:
        return "Accepted difference"
    if table == "prefix" and binding:
        accepted = set("123456789") | {"'", "C", "g", "[", "PPage", "]", "/",
                   "C-Up", "C-Down", "C-Left", "C-Right", "M-Up", "M-Down", "M-Left", "M-Right"}
        if key in accepted:
            return "Accepted difference"
    return "Investigating" if binding or table == "root" else "Missing"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", required=True)
    args = parser.parse_args()
    keymap = json.loads(call("rex", "--autostart=false", "keymap", "--json"))
    actions = json.loads(call("rex", "--autostart=false", "-C", args.client, "actions", "--json"))["actions"]
    bindings = {tuple(binding["keys"]): binding for binding in keymap["bindings"]}
    inventory = []
    for line in call("tmux", "list-keys").splitlines():
        match = re.fullmatch(r"bind-key\s+(-r\s+)?-T\s+(\S+)\s+(\S+)\s+(.+)", line)
        if not match:
            raise ValueError("Unrecognized tmux binding: " + line)
        repeat, table, key, command = match.groups()
        sequence = ("ctrl+a", rex_key(key)) if table == "prefix" else (rex_key(key),)
        binding = bindings.get(sequence) if table in ("prefix", "root") else None
        normalized = shlex.split(key)[0]
        status = binding_status(table, normalized, binding)
        inventory.append({
            "table": table, "key": normalized, "repeat": bool(repeat),
            "command": command.replace(os.environ["HOME"], "$HOME"),
            "rex_config_binding": binding, "status": status,
            "evidence": "See rex-parity.md for workflow scope and behavioral verification; registration alone does not establish parity.",
        })
    report = {
        "scope": "Key-table/configuration inventory, not proof of runtime parity or plugin activation. Rex native/default bindings are not included in rex keymap.",
        "tmux_version": call("tmux", "-V").strip(),
        "rex_version": call("rex", "version").strip(),
        "bindings": inventory,
        "rex_keymap": keymap,
        "rex_actions": actions,
    }
    path = ROOT / ".tests/rex-parity-inventory.json"
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    tables = sorted({item["table"] for item in inventory})
    print(json.dumps({"path": str(path), "tmux_bindings": len(inventory), "tables": tables,
                      "rex_bindings": len(keymap["bindings"]), "diagnostics": keymap["diagnostics"]}, indent=2))


if __name__ == "__main__":
    main()
