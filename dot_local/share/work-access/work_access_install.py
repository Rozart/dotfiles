from contextlib import contextmanager
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import tempfile
from urllib.parse import urlsplit
import uuid

from work_access_health import LABEL, RESOLVER_CONTENT, checked, idle_blockers, native_status, personal_preflight, run, tun_collisions


STATE_MOVED = b"Node state moved into dev.rozart.work-access. Use work-access restore-pilot before restarting the old pilot.\n"


class Layout:
    def __init__(self, root=Path("/"), uid=0, gid=0):
        self.root = Path(root).resolve()
        self.uid = uid
        self.gid = gid
        self.runtime = self.path("/Library/Application Support/" + LABEL)
        self.state = self.path("/var/db/" + LABEL)
        self.logs = self.path("/var/log/" + LABEL)
        self.plist = self.path("/Library/LaunchDaemons/" + LABEL + ".plist")
        self.resolvers = self.path("/etc/resolver")
        self.record = self.runtime / "installation.json"

    def path(self, path):
        return self.root / str(path).lstrip("/")

    def secure(self, path, directory=False):
        metadata = path.lstat()
        kind = stat.S_ISDIR if directory else stat.S_ISREG
        if not kind(metadata.st_mode) or metadata.st_uid != self.uid or metadata.st_mode & 0o022 or (not directory and metadata.st_nlink != 1):
            raise RuntimeError("Unsafe installed path; refusing to change it: " + str(path))
        return metadata

    def directory(self, path, mode=0o755):
        parent = path.parent.resolve()
        for ancestor in (parent, *parent.parents):
            if ancestor == self.root:
                break
            if ancestor.exists():
                self.secure(ancestor, directory=True)
        if path.is_symlink():
            raise RuntimeError("Refusing a symlink directory: " + str(path))
        if not path.exists():
            if not path.parent.exists():
                self.directory(path.parent)
            path.mkdir(mode=mode)
            os.chown(path, self.uid, self.gid)
            path.chmod(mode)
        self.secure(path, directory=True)
        if stat.S_IMODE(path.stat().st_mode) != mode:
            raise RuntimeError("Unexpected directory permissions: " + str(path))

    def write(self, path, content, mode=0o600):
        if path.exists() or path.is_symlink():
            self.secure(path)
        descriptor, name = tempfile.mkstemp(prefix=".work-access-", dir=path.parent)
        temporary = Path(name)
        try:
            with os.fdopen(descriptor, "wb") as target:
                os.fchown(target.fileno(), self.uid, self.gid)
                os.fchmod(target.fileno(), mode)
                target.write(content)
                target.flush()
                os.fsync(target.fileno())
            os.replace(temporary, path)
        finally:
            if temporary.exists():
                temporary.unlink()

    def read_record(self):
        if not self.record.exists() and not self.record.is_symlink():
            return None
        self.secure(self.record)
        record = json.loads(self.record.read_text())
        if record.get("format") != 1 or record.get("phase") not in ("prepared", "installed", "restored"):
            raise RuntimeError("Unrecognized installation record")
        for name in ("release", "previous_release"):
            if record.get(name) and not re.fullmatch(r"[a-f0-9]{64}", record[name]):
                raise RuntimeError("Invalid recorded release")
        return record

    def save_record(self, record):
        self.write(self.record, (json.dumps(record, indent=2) + "\n").encode())

    def select(self, release):
        current = self.runtime / "current"
        if current.exists() or current.is_symlink():
            if not current.is_symlink() or current.lstat().st_uid != self.uid or not re.fullmatch(r"releases/[a-f0-9]{64}", os.readlink(current)):
                raise RuntimeError("Unrecognized installed current-release link")
        temporary = self.runtime / (".current-" + uuid.uuid4().hex)
        try:
            os.symlink("releases/" + release, temporary)
            os.lchown(temporary, self.uid, self.gid)
            os.replace(temporary, current)
        finally:
            if temporary.is_symlink():
                temporary.unlink()


class Bundle:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.files = {name: (self.directory / name).read_bytes() for name in ("settings.json", "config.json", "launchdaemon.plist")}
        self.settings = json.loads(self.files["settings.json"])
        self.config = json.loads(self.files["config.json"])
        self.plist = plistlib.loads(self.files["launchdaemon.plist"])
        self.validate()

    def validate(self):
        settings, config = self.settings, self.config
        pilot = Path(settings["pilot_state"])
        if not pilot.is_absolute() or pilot.parts[-5:] != (".local", "state", "private-access-migration", "work-pilot", "tailscale") or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", settings["node_hostname"]):
            raise RuntimeError("Expected the dedicated local pilot state and an explicit node hostname")
        if not re.fullmatch(r"[a-f0-9]{64}", settings["binary"]["sha256"]):
            raise RuntimeError("A tested binary hash is required")
        if not settings["domains"] or len(set(settings["domains"])) != len(settings["domains"]):
            raise RuntimeError("DNS domains must be nonempty and unique")
        for domain in settings["domains"]:
            if len(domain) > 253 or "." not in domain or any(not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", part) for part in domain.split(".")):
                raise RuntimeError("Invalid private DNS suffix")
        if not settings["routes"] or len(set(settings["routes"])) != len(settings["routes"]):
            raise RuntimeError("Work routes must be nonempty and unique")
        for value in settings["routes"]:
            network = ipaddress.ip_network(value)
            tailnet = ipaddress.ip_network("100.64.0.0/10" if network.version == 4 else "fd7a:115c:a1e0::/48")
            if network.prefixlen != network.max_prefixlen or not network.subnet_of(tailnet):
                raise RuntimeError("Only individual Tailscale host routes are allowed")
        addresses = [ipaddress.ip_interface(value) for value in settings["tun_addresses"]]
        if sorted(address.version for address in addresses) != [4, 6] or any(not address.is_private or address.network.prefixlen != (30 if address.version == 4 else 126) for address in addresses):
            raise RuntimeError("Expected one private IPv4 /30 and one IPv6 /126 TUN address")
        url = urlsplit(settings["health_url"])
        if url.scheme != "https" or url.username or url.password or not any(url.hostname == suffix or (url.hostname or "").endswith("." + suffix) for suffix in settings["domains"]):
            raise RuntimeError("Health URL must be HTTPS inside a configured work namespace")
        expected_rules = [
            {"inbound": ["work-dns-listener"], "action": "hijack-dns"},
            {"inbound": ["ts-work"], "action": "reject"},
            {"inbound": ["work-tun"], "ip_cidr": settings["routes"], "action": "route", "outbound": "ts-work"},
            {"action": "reject"},
        ]
        inbounds = config["inbounds"]
        if len(inbounds) != 2 or inbounds[0] != {"type": "tun", "tag": "work-tun", "address": settings["tun_addresses"], "mtu": 1280, "auto_route": True, "route_address": settings["routes"], "dns_mode": "disabled", "stack": "gvisor"} or inbounds[1] != {"type": "direct", "tag": "work-dns-listener", "listen": "127.0.0.1", "listen_port": 1053}:
            raise RuntimeError("Unexpected listener, TUN route or system DNS scope")
        endpoint = {"type": "tailscale", "tag": "ts-work", "state_directory": "/var/db/" + LABEL + "/tailscale", "hostname": settings["node_hostname"], "ephemeral": False, "accept_routes": False, "advertise_routes": [], "advertise_exit_node": False, "system_interface": False, "ssh_server": False, "taildrop_directory": "/var/db/" + LABEL + "/taildrop"}
        if config["endpoints"] != [endpoint] or config["route"] != {"rules": expected_rules, "final": "direct", "default_domain_resolver": "underlay-dns", "auto_detect_interface": False}:
            raise RuntimeError("Unexpected endpoint credentials, ingress or routing scope")
        expected_dns = {"servers": [{"type": "local", "tag": "underlay-dns"}, {"type": "tailscale", "tag": "work-dns", "endpoint": "ts-work", "accept_default_resolvers": False, "accept_search_domain": False}], "rules": [{"inbound": ["ts-work"], "action": "reject"}, {"domain_suffix": settings["domains"], "server": "work-dns"}, {"action": "reject"}], "final": "underlay-dns"}
        if config.get("log") != {"level": "info", "timestamp": True} or config["dns"] != expected_dns or config.get("outbounds") != [{"type": "direct", "tag": "direct"}] or set(config) != {"log", "inbounds", "endpoints", "dns", "outbounds", "route"}:
            raise RuntimeError("Unexpected DNS bootstrap or outbound settings")
        runtime = "/Library/Application Support/" + LABEL + "/current/"
        expected_arguments = [runtime + "sing-box", "run", "--disable-color", "-c", runtime + "config.json", "-D", "/var/db/" + LABEL]
        expected_plist = {"Label": LABEL, "ProgramArguments": expected_arguments, "UserName": "root", "GroupName": "wheel", "KeepAlive": True, "ThrottleInterval": 15, "ExitTimeOut": 20, "Umask": 63, "WorkingDirectory": "/var/db/" + LABEL, "EnvironmentVariables": {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin"}, "StandardOutPath": "/var/log/" + LABEL + "/sing-box.log", "StandardErrorPath": "/var/log/" + LABEL + "/sing-box.log"}
        if self.plist != expected_plist:
            raise RuntimeError("Unexpected daemon identity, executable, environment or log paths")

    def binary(self):
        path = Path(self.settings["binary"]["path"]).resolve(strict=True)
        if not path.is_file() or digest(path) != self.settings["binary"]["sha256"]:
            raise RuntimeError("Installed Homebrew binary differs from the tested hash; do not upgrade or install it into the service automatically")
        return path

    def check(self):
        source = self.binary()
        with tempfile.TemporaryDirectory(prefix=LABEL + "-check-") as temporary:
            directory = Path(temporary)
            binary = directory / "sing-box"
            shutil.copyfile(source, binary)
            binary.chmod(0o755)
            if digest(binary) != self.settings["binary"]["sha256"]:
                raise RuntimeError("Binary changed while taking a private validation snapshot")
            configuration = directory / "config.json"
            configuration.write_bytes(self.files["config.json"])
            libraries = checked(["/usr/bin/otool", "-L", str(binary)]).splitlines()[1:]
            if not libraries or any(not line.strip().startswith(("/System/Library/", "/usr/lib/")) for line in libraries):
                raise RuntimeError("The root binary must not depend on user-writable libraries")
            version = checked([str(binary), "version"])
            if version.splitlines()[0] != "sing-box version " + self.settings["version"] or any(tag not in version for tag in ("with_tailscale", "with_gvisor")):
                raise RuntimeError("Unexpected sing-box version or build features")
            checked([str(binary), "check", "--disable-color", "-c", str(configuration), "-D", str(directory)])
        return {"binary_version": self.settings["version"], "binary_sha256": self.settings["binary"]["sha256"], "configuration": "valid", "service_activation": "not performed"}

    def release(self):
        return payload_digest(self.files, self.settings["binary"]["sha256"])


def payload_digest(files, binary_sha256):
    value = hashlib.sha256(binary_sha256.encode())
    for name in ("settings.json", "config.json", "launchdaemon.plist"):
        value.update(name.encode() + b"\0" + files[name])
    return value.hexdigest()


def release_digest(directory, binary_sha256):
    files = {name: (directory / name).read_bytes() for name in ("settings.json", "config.json", "launchdaemon.plist")}
    return payload_digest(files, binary_sha256)


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


@contextmanager
def locked(layout):
    layout.directory(layout.runtime)
    lock = layout.runtime / "install.lock"
    if lock.exists() or lock.is_symlink():
        layout.secure(lock)
    descriptor = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        os.fchown(descriptor, layout.uid, layout.gid)
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    finally:
        os.close(descriptor)


def require_idle():
    blockers = idle_blockers()
    if blockers:
        raise RuntimeError("; ".join(blockers))


def resolver_preflight(layout, domains):
    for domain in domains:
        path = layout.resolvers / domain
        if path.exists() or path.is_symlink():
            layout.secure(path)
            if path.read_text() != RESOLVER_CONTENT:
                raise RuntimeError("Existing DNS resolver will not be overwritten: " + str(path))


def state_tree(path, owners):
    paths = [path]
    for directory, directories, files in os.walk(path, followlinks=False):
        paths.extend(Path(directory) / name for name in directories + files)
    if not (path / "tailscaled.state").is_file() or (path / "tailscaled.state").stat().st_size == 0:
        raise RuntimeError("Expected nonempty existing sing-box state; enrollment must be verified separately")
    for entry in paths:
        metadata = entry.lstat()
        if metadata.st_uid not in owners or metadata.st_mode & 0o077 or not (stat.S_ISDIR(metadata.st_mode) or stat.S_ISREG(metadata.st_mode)) or (stat.S_ISREG(metadata.st_mode) and metadata.st_nlink != 1):
            raise RuntimeError("State must contain only private owned directories and single-link files; contents were not read")
    return paths


def protect_state(path, uid, gid):
    for entry in state_tree(path, {path.stat().st_uid, uid}):
        metadata = entry.lstat()
        os.chown(entry, uid, gid, follow_symlinks=False)
        entry.chmod(0o700 if stat.S_ISDIR(metadata.st_mode) else 0o600)


def stage_release(layout, bundle):
    releases = layout.runtime / "releases"
    layout.directory(releases)
    release = releases / bundle.release()
    layout.directory(release)
    binary = release / "sing-box"
    if binary.exists() or binary.is_symlink():
        layout.secure(binary)
        if digest(binary) != bundle.settings["binary"]["sha256"]:
            raise RuntimeError("Previously staged root binary was modified")
    else:
        with bundle.binary().open("rb") as source, binary.open("xb") as target:
            shutil.copyfileobj(source, target, length=1024 * 1024)
        os.chown(binary, layout.uid, layout.gid)
        binary.chmod(0o755)
        if digest(binary) != bundle.settings["binary"]["sha256"]:
            raise RuntimeError("Binary changed while copying; release will not be activated")
    for name in ("settings.json", "config.json", "launchdaemon.plist"):
        path = release / name
        expected = bundle.files[name]
        if path.exists() or path.is_symlink():
            layout.secure(path)
            if path.read_bytes() != expected:
                raise RuntimeError("An immutable installed release was modified")
        else:
            layout.write(path, expected, 0o644 if name != "config.json" else 0o600)
    return release


def install(bundle, layout, adopt=None, caller_uid=None):
    bundle.check()
    personal_preflight(bundle.settings, native_status())
    require_idle()
    collisions = tun_collisions(bundle.settings)
    if collisions:
        raise RuntimeError("Private TUN addresses overlap existing routes: " + ", ".join(collisions))
    with locked(layout):
        previous = layout.read_record()
        if previous and previous["phase"] == "prepared":
            raise RuntimeError("Incomplete installation recorded; inspect and restore before retrying")
        installed = previous and previous["phase"] == "installed"
        if installed and adopt:
            raise RuntimeError("Existing identity must not be replaced")
        if installed and (previous["domains"] != bundle.settings["domains"] or previous["node_hostname"] != bundle.settings["node_hostname"]):
            raise RuntimeError("DNS suffix or node-name migration requires separate review")
        resolver_preflight(layout, bundle.settings["domains"])
        if layout.plist.exists() or layout.plist.is_symlink():
            layout.secure(layout.plist)
            if not installed or layout.plist.read_bytes() != (layout.runtime / "current/launchdaemon.plist").read_bytes():
                raise RuntimeError("Existing LaunchDaemon will not be overwritten")
        source = None
        if not installed:
            if adopt is None or caller_uid is None or caller_uid == 0:
                raise RuntimeError("First install requires --adopt-state and a non-root sudo caller")
            supplied = Path(adopt).expanduser().absolute()
            if supplied != Path(bundle.settings["pilot_state"]):
                raise RuntimeError("Only the dedicated local work pilot may be adopted; never use official or Rex node state")
            if supplied.is_symlink():
                raise RuntimeError("Refusing a symlink state directory")
            source = supplied.resolve(strict=True)
            if source != supplied:
                raise RuntimeError("Pilot state aliases and symlink parents are not accepted")
            if not source.is_dir() or source.stat().st_uid != caller_uid or source.stat().st_mode & 0o077:
                raise RuntimeError("Adopt only this caller's private local pilot state")
            for ancestor in (source.parent, *source.parent.parents):
                metadata = ancestor.stat()
                if metadata.st_uid not in {0, caller_uid} or metadata.st_mode & 0o022:
                    raise RuntimeError("State source has an unsafe parent directory")
            state_tree(source, {caller_uid})
            if (layout.state / "tailscale").exists() or (layout.state / "tailscale").is_symlink():
                raise RuntimeError("Existing protected state will not be replaced")
        else:
            state_tree(layout.state / "tailscale", {layout.uid})
        release = stage_release(layout, bundle)
        for path, mode in ((layout.state, 0o700), (layout.logs, 0o700), (layout.resolvers, 0o755), (layout.plist.parent, 0o755)):
            layout.directory(path, mode)
        log = layout.logs / "sing-box.log"
        if log.exists() or log.is_symlink():
            layout.secure(log)
        else:
            layout.write(log, b"")
        record = {"format": 1, "phase": "prepared", "release": bundle.release(), "previous_release": previous["release"] if installed and previous["release"] != bundle.release() else (previous or {}).get("previous_release"), "domains": bundle.settings["domains"], "node_hostname": bundle.settings["node_hostname"], "source": previous["source"] if installed else str(source), "source_uid": previous["source_uid"] if installed else caller_uid, "source_gid": previous["source_gid"] if installed else source.stat().st_gid}
        checked(["/bin/launchctl", "disable", "system/" + LABEL])
        layout.save_record(record)
        if source:
            source.rename(layout.state / "tailscale")
            layout.write(source, STATE_MOVED)
            protect_state(layout.state / "tailscale", layout.uid, layout.gid)
        layout.select(record["release"])
        layout.write(layout.plist, (release / "launchdaemon.plist").read_bytes(), 0o644)
        for domain in record["domains"]:
            layout.write(layout.resolvers / domain, RESOLVER_CONTENT.encode(), 0o644)
        checked(["/usr/bin/dscacheutil", "-flushcache"])
        record["phase"] = "installed"
        layout.save_record(record)
        return {"release": record["release"], "service": "installed but disabled; run start explicitly", "credentials": "moved locally, never copied", "dns": "owned scoped resolvers installed"}


def assert_installed(layout):
    record = layout.read_record()
    if not record or record["phase"] != "installed":
        raise RuntimeError("No complete installation exists")
    current = layout.runtime / "current"
    if not current.is_symlink() or current.lstat().st_uid != layout.uid or os.readlink(current) != "releases/" + record["release"]:
        raise RuntimeError("Installed release selection differs from the record")
    layout.directory(layout.runtime / "releases")
    layout.directory(layout.state, 0o700)
    layout.directory(layout.logs, 0o700)
    layout.secure(layout.logs / "sing-box.log")
    directory = layout.runtime / "releases" / record["release"]
    layout.secure(directory, directory=True)
    for name in ("sing-box", "config.json", "settings.json", "launchdaemon.plist"):
        layout.secure(directory / name)
    settings = json.loads((directory / "settings.json").read_text())
    if release_digest(directory, settings["binary"]["sha256"]) != record["release"] or digest(directory / "sing-box") != settings["binary"]["sha256"]:
        raise RuntimeError("Installed release integrity check failed")
    bundle = Bundle(directory)
    layout.secure(layout.plist)
    if layout.plist.read_bytes() != (directory / "launchdaemon.plist").read_bytes():
        raise RuntimeError("Installed LaunchDaemon differs from the selected release")
    resolver_preflight(layout, record["domains"])
    if any(not (layout.resolvers / domain).exists() for domain in record["domains"]):
        raise RuntimeError("An owned DNS resolver is missing")
    state_tree(layout.state / "tailscale", {layout.uid})
    return record, bundle


def start(layout):
    with locked(layout):
        record, bundle = assert_installed(layout)
        personal_preflight(bundle.settings, native_status())
        require_idle()
        if tun_collisions(bundle.settings):
            raise RuntimeError("Private TUN addresses overlap existing routes")
        checked(["/bin/launchctl", "enable", "system/" + LABEL])
        try:
            checked(["/bin/launchctl", "bootstrap", "system", str(layout.plist)])
        except Exception:
            checked(["/bin/launchctl", "disable", "system/" + LABEL])
            raise
    return {"service": "submitted to launchd; run verify before accepting it", "release": record["release"]}


def stop(layout):
    with locked(layout):
        record = layout.read_record()
        if not record or record["phase"] == "restored":
            raise RuntimeError("No owned installation to stop")
        checked(["/bin/launchctl", "disable", "system/" + LABEL])
        if run(["/bin/launchctl", "print", "system/" + LABEL]).returncode == 0:
            checked(["/bin/launchctl", "bootout", "system/" + LABEL])
        checked(["/usr/bin/dscacheutil", "-flushcache"])
    return {"service": "disabled across reboot and bootout requested", "dns": "private scoped resolvers retained; fail-closed behavior must be tested"}


def rollback(layout):
    require_idle()
    with locked(layout):
        record = layout.read_record()
        if not record or record["phase"] == "restored" or not record.get("previous_release"):
            raise RuntimeError("No previous managed release to restore; use restore-pilot for the first cutover")
        release = layout.runtime / "releases" / record["previous_release"]
        layout.secure(release, directory=True)
        for name in ("sing-box", "settings.json", "config.json", "launchdaemon.plist"):
            layout.secure(release / name)
        bundle = Bundle(release)
        current_settings = json.loads((layout.runtime / "releases" / record["release"] / "settings.json").read_text())
        if bundle.settings["binary"]["sha256"] != current_settings["binary"]["sha256"]:
            raise RuntimeError("Binary changed; validate node-state compatibility before rollback")
        if bundle.release() != record["previous_release"] or digest(release / "sing-box") != bundle.settings["binary"]["sha256"] or bundle.settings["domains"] != record["domains"]:
            raise RuntimeError("Previous release integrity or DNS scope differs")
        personal_preflight(bundle.settings, native_status())
        if tun_collisions(bundle.settings):
            raise RuntimeError("Previous TUN addresses collide with current routes")
        resolver_preflight(layout, record["domains"])
        if layout.plist.exists() or layout.plist.is_symlink():
            layout.secure(layout.plist)
            possible = [(release / "launchdaemon.plist").read_bytes(), (layout.runtime / "releases" / record["release"] / "launchdaemon.plist").read_bytes()]
            if layout.plist.read_bytes() not in possible:
                raise RuntimeError("Changed LaunchDaemon will not be overwritten")
        state_tree(layout.state / "tailscale", {layout.uid})
        checked(["/bin/launchctl", "disable", "system/" + LABEL])
        record["release"], record["previous_release"] = record["previous_release"], record["release"]
        record["phase"] = "prepared"
        layout.save_record(record)
        layout.select(record["release"])
        layout.write(layout.plist, (release / "launchdaemon.plist").read_bytes(), 0o644)
        for domain in record["domains"]:
            layout.write(layout.resolvers / domain, RESOLVER_CONTENT.encode(), 0o644)
        checked(["/usr/bin/dscacheutil", "-flushcache"])
        record["phase"] = "installed"
        layout.save_record(record)
        return {"service": "previous configuration restored, still disabled; start explicitly", "release": record["release"], "credentials": "unchanged"}


def restore_pilot(layout):
    require_idle()
    with locked(layout):
        record = layout.read_record()
        if not record or record["phase"] not in ("prepared", "installed"):
            raise RuntimeError("No active installation or interrupted transaction to restore")
        resolver_preflight(layout, record["domains"])
        release = layout.runtime / "releases" / record["release"]
        if layout.plist.exists() or layout.plist.is_symlink():
            layout.secure(layout.plist)
            if layout.plist.read_bytes() != (release / "launchdaemon.plist").read_bytes():
                raise RuntimeError("Changed LaunchDaemon will not be removed")
        source = Path(record["source"])
        state = layout.state / "tailscale"
        if not source.is_absolute() or source.parent.resolve() != source.parent:
            raise RuntimeError("Original state path now has an alias or symlink parent")
        metadata = source.lstat() if source.exists() or source.is_symlink() else None
        guarded = metadata is not None and stat.S_ISREG(metadata.st_mode) and metadata.st_uid in {layout.uid, record["source_uid"]} and metadata.st_nlink == 1 and not metadata.st_mode & 0o077 and metadata.st_size == len(STATE_MOVED) and source.read_bytes() == STATE_MOVED
        if not source.parent.is_dir() or source.parent.stat().st_uid != record["source_uid"] or source.parent.stat().st_mode & 0o077:
            raise RuntimeError("Original private state parent changed")
        if metadata is not None and not guarded:
            if state.exists() or state.is_symlink():
                raise RuntimeError("Both state locations exist; inspect manually without merging them")
            state_tree(source, {record["source_uid"]})
        else:
            state_tree(state, {layout.uid, record["source_uid"]})
        checked(["/bin/launchctl", "disable", "system/" + LABEL])
        if guarded or not source.exists():
            protect_state(state, record["source_uid"], record["source_gid"])
            if guarded:
                source.unlink()
            try:
                state.rename(source)
            except Exception:
                protect_state(state, layout.uid, layout.gid)
                if guarded and not source.exists():
                    layout.write(source, STATE_MOVED)
                raise
        resolver_preflight(layout, record["domains"])
        for domain in record["domains"]:
            path = layout.resolvers / domain
            if path.exists():
                path.unlink()
        if layout.plist.exists():
            layout.plist.unlink()
        checked(["/usr/bin/dscacheutil", "-flushcache"])
        record["phase"] = "restored"
        layout.save_record(record)
        return {"service": "disabled", "state": "returned to original private pilot directory", "dns": "only unchanged managed resolvers removed", "retained": "root releases and logs; no nodes deleted"}
