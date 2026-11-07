import argparse
import copy
import datetime
import json
import os
from pathlib import Path
import plistlib
import subprocess
from urllib.parse import quote, unquote, urlsplit
import uuid


DOMAIN = "com.superlogical.rex"
KEY = "RexSync.servers"
BUILD = "1853"


def run(arguments):
    result = subprocess.run(arguments, capture_output=True, timeout=20)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors="replace").strip() or f"Command failed: {arguments[0]}")
    return result.stdout


def preferences():
    return plistlib.loads(run(["defaults", "export", DOMAIN, "-"]))


def directory_from(value):
    if value is None:
        return {"formatVersion": 1, "records": []}
    if not isinstance(value, bytes):
        raise ValueError("Rex host directory is not native Data; refusing to replace it")
    directory = json.loads(value)
    if not isinstance(directory, dict) or type(directory.get("formatVersion")) is not int or directory["formatVersion"] != 1:
        raise ValueError("Unknown Rex host-directory format; refusing to replace it")
    records = directory.get("records")
    if not isinstance(records, list):
        raise ValueError("Invalid Rex host-directory records")
    identities = set()
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("name"), str):
            raise ValueError("Invalid Rex host record")
        if not isinstance(record.get("id"), str):
            raise ValueError("Invalid Rex host record identity")
        identity = str(uuid.UUID(record["id"]))
        if identity in identities:
            raise ValueError("Duplicate Rex host record identity")
        identities.add(identity)
        locators = record.get("locators")
        if not isinstance(locators, list) or not locators or any(not isinstance(item, str) for item in locators):
            raise ValueError("Invalid Rex host record locators")
    return directory


def socket_path(locator):
    if locator.startswith("/"):
        return locator
    parsed = urlsplit(locator)
    if parsed.scheme == "unix" and not parsed.netloc:
        return unquote(parsed.path)
    return None


def merge_hosts(directory, hosts, identify):
    merged = copy.deepcopy(directory)
    endpoints = {socket_path(locator) for record in merged["records"] for locator in record["locators"]}
    names = {record["name"].casefold() for record in merged["records"]}
    added = []
    requested = set()
    requested_labels = set()
    for host in hosts:
        label = host["label"]
        endpoint = host["endpoint"]
        if not isinstance(label, str) or not label or not isinstance(endpoint, str) or not endpoint.startswith("/"):
            raise ValueError("Managed Rex hosts require labels and absolute socket paths")
        if endpoint in requested or label.casefold() in requested_labels:
            raise ValueError("Duplicate managed Rex host")
        requested.add(endpoint)
        requested_labels.add(label.casefold())
        if endpoint in endpoints:
            continue
        if label.casefold() in names:
            raise ValueError(f"Existing Rex host named {label} has a different address; refusing to replace it")
        identity = identify(endpoint)
        host_id = str(uuid.UUID(identity["host_id"]))
        instance_id = str(uuid.UUID(identity["instance_id"]))
        merged["records"].append({
            "icon": "globe",
            "id": str(uuid.uuid4()).upper(),
            "lastHostID": host_id,
            "lastInstanceID": instance_id,
            "locators": ["unix://" + quote(endpoint, safe="/")],
            "name": label,
        })
        endpoints.add(endpoint)
        names.add(label.casefold())
        added.append(label)
    return merged, added


def backup(value, state):
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    state.chmod(0o700)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = state / f"{stamp}-{uuid.uuid4().hex[:8]}.plist"
    contents = {"domain": DOMAIN, "key": KEY, "present": value is not None}
    if value is not None:
        contents["value"] = value
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        plistlib.dump(contents, stream)
    return path


def synchronize(config, app, rex, state):
    if config.get("build") != BUILD:
        raise ValueError(f"Native Rex host sync supports only reviewed build {BUILD}")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if str(info.get("CFBundleVersion")) != BUILD:
        raise ValueError(f"Native Rex host sync supports only build {BUILD}; existing app is preserved")
    hosts = config.get("hosts")
    if not isinstance(hosts, list):
        raise ValueError("Invalid managed Rex host configuration")
    original = preferences().get(KEY)
    directory = directory_from(original)

    def identify(endpoint):
        try:
            return json.loads(run([rex, "--autostart=false", "--timeout", "5s", "-S", endpoint, "whoami", "--json"]))
        except (ValueError, subprocess.TimeoutExpired) as error:
            raise ValueError(f"Cannot reach {endpoint}; unlock SSH access, wait for the tunnel, and reapply: {error}") from error

    merged, added = merge_hosts(directory, hosts, identify)
    if not added:
        return {"added": [], "managed_hosts": len(hosts), "changed": False}
    if preferences().get(KEY) != original:
        raise ValueError("Rex host directory changed during discovery; reapply without editing hosts concurrently")
    saved = backup(original, state)
    encoded = json.dumps(merged, separators=(",", ":")).encode()
    run(["defaults", "write", DOMAIN, KEY, "-data", encoded.hex()])
    if preferences().get(KEY) != encoded:
        raise ValueError(f"Rex host directory did not retain the write; original backup: {saved}")
    return {"added": added, "managed_hosts": len(hosts), "changed": True, "backup": str(saved)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("client-hosts.json"))
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--rex", required=True)
    parser.add_argument("--state", type=Path, default=Path.home() / ".local/state/rex/client-host-backups")
    arguments = parser.parse_args()
    try:
        result = synchronize(json.loads(arguments.config.read_text()), arguments.app, arguments.rex, arguments.state)
    except (ValueError, KeyError, TypeError, OSError, subprocess.TimeoutExpired, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Rex native host sync: {error}\n")
    print(json.dumps(result))
    if result["changed"]:
        print("Native hosts saved without restarting Rex. Verify Ctrl-a g; the running app may require a user-approved relaunch.")


if __name__ == "__main__":
    main()
