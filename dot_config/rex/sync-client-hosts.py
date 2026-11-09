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


class PeerUnavailable(ValueError):
    pass


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


def https_endpoint(value):
    if not isinstance(value, str) or any(character.isspace() for character in value):
        raise ValueError("Mac peers require a tailnet HTTPS URL")
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.hostname or not parsed.hostname.endswith(".ts.net")
            or parsed.username or parsed.password or parsed.port not in {None, 443}
            or parsed.path not in {"", "/"} or parsed.query or parsed.fragment):
        raise ValueError("Mac peers require a tailnet HTTPS URL without credentials, paths, or custom ports")
    return "https://" + parsed.hostname.lower()


def endpoint_key(locator):
    path = socket_path(locator)
    if path is not None:
        return path
    try:
        return https_endpoint(locator)
    except ValueError:
        return None


def validate_requests(hosts, peers):
    if not isinstance(peers, list):
        raise ValueError("Invalid managed Mac peers")
    labels = set()
    endpoints = set()
    for host in hosts + peers:
        if not isinstance(host, dict) or not isinstance(host.get("label"), str) or not host["label"]:
            raise ValueError("Managed Rex hosts require labels")
        endpoint = host.get("endpoint")
        if not isinstance(endpoint, str):
            raise ValueError("Managed Rex hosts require endpoints")
        key = endpoint_key(endpoint)
        if key is None or host["label"].casefold() in labels or key in endpoints:
            raise ValueError("Invalid or duplicate managed Rex host")
        labels.add(host["label"].casefold())
        endpoints.add(key)
    for host in hosts:
        if not host["endpoint"].startswith("/"):
            raise ValueError("Linux hosts require absolute socket paths")
    for peer in peers:
        https_endpoint(peer["endpoint"])
        if not isinstance(peer.get("host_id"), str):
            raise ValueError("Mac peers require a verified host identity")
        uuid.UUID(peer["host_id"])


def request(rex, endpoint, arguments):
    try:
        raw = run([rex, "--autostart=false", "--timeout", "5s", "-S", endpoint, *arguments])
    except (ValueError, subprocess.TimeoutExpired) as error:
        raise PeerUnavailable(str(error)) from error
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise ValueError("Invalid Rex identity/status response")
    return value


def checked_tailnet(status, expected):
    tailnet = status.get("tailscale", {})
    if not isinstance(tailnet, dict) or not isinstance(tailnet.get("https", {}), dict):
        raise ValueError("Invalid Rex Tailscale status")
    if tailnet.get("tags") or tailnet.get("allow_tailnet_members") is not False:
        raise ValueError("Mac Rex access requires an untagged node restricted to its enrolling Tailscale user")
    if tailnet.get("state") != "running" or tailnet.get("https", {}).get("state") != "available":
        raise PeerUnavailable("Rex Tailscale HTTPS is not ready")
    if https_endpoint(tailnet["https"]["url"]) != https_endpoint(expected):
        raise ValueError("Rex Tailscale DNS does not match the managed Mac endpoint; existing node was not renamed")
    return tailnet


def local_tailnet(config, rex):
    local = config.get("local")
    if local is None:
        return None
    if not isinstance(local, dict) or not isinstance(local.get("endpoint"), str) or not local["endpoint"].startswith("/"):
        raise ValueError("Local Rex setup requires its explicit absolute Unix socket")
    expected = https_endpoint(local["https"])
    expected_host = str(uuid.UUID(local["host_id"]))
    try:
        status = request(rex, local["endpoint"], ["server", "status", "--json"])
    except PeerUnavailable:
        return {"state": "pending", "reason": "Local Rex is not reachable; open Rex, then reapply. No server was started"}
    if str(uuid.UUID(status["host_id"])) != expected_host:
        raise ValueError("Local Rex host identity does not match this Mac; refusing to change its access policy")
    tailnet = status.get("tailscale", {})
    if not isinstance(tailnet, dict):
        raise ValueError("Invalid local Rex Tailscale status")
    if tailnet.get("tags"):
        raise ValueError("Tagged Rex nodes have no personal owner; re-enrollment requires a separate decision")
    state = tailnet.get("state", "unsupported")
    if state != "running":
        return {"state": state, "reason": "Enable built-in Tailscale in Rex Server settings and finish sign-in/approval with the same identity; CLI on is runtime-only"}
    if tailnet.get("allow_tailnet_members") is True:
        request(rex, local["endpoint"], ["api", "call", "server.tailscale.enable", '{"allow_tailnet_members":false}'])
        narrowed = request(rex, local["endpoint"], ["server", "status", "--json"])
        if (narrowed.get("host_id"), narrowed.get("instance_id")) != (status.get("host_id"), status.get("instance_id")):
            raise ValueError("Local Rex identity changed during access-policy synchronization")
        status = narrowed
    try:
        checked_tailnet(status, expected)
    except PeerUnavailable as error:
        return {"state": "pending", "reason": str(error)}
    return {"state": "ready", "https": expected, "allow_tailnet_members": False}


def merge_hosts(directory, hosts, identify):
    merged = copy.deepcopy(directory)
    endpoints = {endpoint_key(locator) for record in merged["records"] for locator in record["locators"]}
    names = {record["name"].casefold() for record in merged["records"]}
    added = []
    requested = set()
    requested_labels = set()
    for host in hosts:
        label = host["label"]
        endpoint = host["endpoint"]
        if not isinstance(label, str) or not label or not isinstance(endpoint, str):
            raise ValueError("Managed Rex hosts require labels and endpoints")
        endpoint = endpoint_key(endpoint)
        if endpoint is None:
            raise ValueError("Managed Rex hosts require absolute sockets or tailnet HTTPS URLs")
        if endpoint in requested or label.casefold() in requested_labels:
            raise ValueError("Duplicate managed Rex host")
        requested.add(endpoint)
        requested_labels.add(label.casefold())
        if endpoint in endpoints:
            if host.get("host_id"):
                expected = str(uuid.UUID(host["host_id"]))
                for record in merged["records"]:
                    if endpoint in {endpoint_key(locator) for locator in record["locators"]}:
                        if record.get("lastHostID") and str(uuid.UUID(record["lastHostID"])) != expected:
                            raise ValueError("Existing Mac peer has a conflicting host identity")
            continue
        if label.casefold() in names:
            raise ValueError(f"Existing Rex host named {label} has a different address; refusing to replace it")
        identity = identify(endpoint)
        host_id = str(uuid.UUID(identity["host_id"]))
        instance_id = str(uuid.UUID(identity["instance_id"]))
        if host.get("host_id") and host_id != str(uuid.UUID(host["host_id"])):
            raise ValueError("Mac peer host identity does not match the verified machine")
        merged["records"].append({
            "icon": "globe",
            "id": str(uuid.uuid4()).upper(),
            "lastHostID": host_id,
            "lastInstanceID": instance_id,
            "locators": ["unix://" + quote(endpoint, safe="/") if endpoint.startswith("/") else endpoint],
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
    peers = config.get("peers", [])
    validate_requests(hosts, peers)
    original = preferences().get(KEY)
    directory = directory_from(original)
    local = local_tailnet(config, rex)

    def identify(endpoint):
        try:
            identity = request(rex, endpoint, ["whoami", "--json"])
            if endpoint.startswith("https://"):
                status = request(rex, endpoint, ["server", "status", "--json"])
                checked_tailnet(status, endpoint)
                if (status.get("host_id"), status.get("instance_id")) != (identity.get("host_id"), identity.get("instance_id")):
                    raise ValueError("Mac peer identity changed during discovery")
            return identity
        except PeerUnavailable as error:
            if endpoint.startswith("/"):
                raise ValueError(f"Cannot reach {endpoint}; unlock SSH access, wait for the tunnel, and reapply: {error}") from error
            raise

    merged, added = merge_hosts(directory, hosts, identify)
    pending = []
    for peer in peers:
        try:
            merged, peer_added = merge_hosts(merged, [peer], identify)
            added.extend(peer_added)
        except PeerUnavailable as error:
            pending.append({"label": peer["label"], "reason": str(error),
                            "action": "Keep the peer awake and enrolled; connect standalone Tailscale on this Mac for HTTPS DNS/routes, then reapply"})
    result = {"added": added, "managed_hosts": len(hosts) + len(peers), "changed": bool(added), "pending_peers": pending}
    if local is not None:
        result["local_tailnet"] = local
    if not added:
        return result
    if preferences().get(KEY) != original:
        raise ValueError("Rex host directory changed during discovery; reapply without editing hosts concurrently")
    saved = backup(original, state)
    encoded = json.dumps(merged, separators=(",", ":")).encode()
    run(["defaults", "write", DOMAIN, KEY, "-data", encoded.hex()])
    if preferences().get(KEY) != encoded:
        raise ValueError(f"Rex host directory did not retain the write; original backup: {saved}")
    return dict(result, backup=str(saved))


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
    if result["pending_peers"]:
        print("Mac peer registration is pending; leave servers running and reapply when the peer is awake and signed in.")


if __name__ == "__main__":
    main()
