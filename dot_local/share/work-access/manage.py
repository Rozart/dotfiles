import argparse
import json
import os
from pathlib import Path
import sys

import work_access_health as health
from work_access_install import Bundle, Layout, install, restore_pilot, rollback, start, stop


DIRECTORY = Path(__file__).resolve().parent


def parser():
    result = argparse.ArgumentParser(description="Stage and inspect work access; privileged changes require explicit user-run commands")
    commands = result.add_subparsers(dest="command", required=True)
    for name in ("check", "plan", "status", "snapshot"):
        commands.add_parser(name)
    verify = commands.add_parser("verify")
    verify.add_argument("--baseline", type=Path)
    for name in ("install", "start", "stop", "rollback", "restore-pilot"):
        command = commands.add_parser(name)
        command.add_argument("--confirm", action="store_true")
        if name == "install":
            command.add_argument("--adopt-state", type=Path)
    return result


def service_loaded():
    return health.run(["/bin/launchctl", "print", "system/" + health.LABEL]).returncode == 0


def plan(bundle, layout):
    report = bundle.check()
    blockers = health.idle_blockers()
    try:
        health.personal_preflight(bundle.settings, health.native_status())
        collisions = health.tun_collisions(bundle.settings)
        if collisions:
            blockers.append("TUN address collisions: " + ", ".join(collisions))
    except (RuntimeError, OSError, ValueError) as error:
        blockers.append(str(error))
    for domain in bundle.settings["domains"]:
        path = layout.resolvers / domain
        if path.is_symlink() or (path.exists() and path.read_text() != health.RESOLVER_CONTENT):
            blockers.append("Existing resolver must be preserved: " + str(path))
    return dict(report, work_routes=bundle.settings["routes"], scoped_dns=bundle.settings["domains"], expected_work_login=bundle.settings["work_login"], allowed_state_source=bundle.settings["pilot_state"], blockers=blockers, ready_for_install=not blockers, requires="Local maintenance window, active-session check, explicit root install and enrolled state adoption", native_preferences="Never changed by this tool")


def resolver_status(path):
    if path.is_symlink():
        return "symlink; inspect"
    if not path.exists():
        return "absent"
    return "managed" if path.read_text() == health.RESOLVER_CONTENT else "existing; not owned by this service"


def status(bundle, layout):
    current = layout.runtime / "current"
    selected = os.readlink(current) if current.is_symlink() else None
    return {
        "service_loaded": service_loaded(),
        "installed_release": selected,
        "staged_release": "releases/" + bundle.release(),
        "staged_matches_installed": selected == "releases/" + bundle.release(),
        "native": health.identity(health.native_status()),
        "scoped_resolvers": {domain: resolver_status(layout.resolvers / domain) for domain in bundle.settings["domains"]},
        "credentials": "Not inspected; protected state is intentionally private",
    }


def main(arguments=None):
    args = parser().parse_args(arguments)
    privileged = args.command in {"install", "start", "stop", "rollback", "restore-pilot"}
    if privileged and (os.geteuid() != 0 or not args.confirm):
        raise RuntimeError("Run this command directly with sudo and --confirm after reviewing active sessions and local rollback access")
    if privileged:
        os.umask(0o077)
    if sys.platform != "darwin":
        raise RuntimeError("This service is qualified for macOS only")
    layout = Layout()
    if args.command == "stop":
        return stop(layout)
    if args.command == "restore-pilot":
        return restore_pilot(layout)
    if args.command == "rollback":
        return rollback(layout)
    if args.command == "start":
        return start(layout)
    if args.command == "verify":
        if not service_loaded():
            raise RuntimeError("Managed service is not loaded; pilot success is not managed-service acceptance")
        settings = json.loads((layout.runtime / "current/settings.json").read_text())
        baseline = json.loads(args.baseline.read_text()) if args.baseline else None
        return health.verify(settings, baseline)
    bundle = Bundle(DIRECTORY)
    if args.command == "check":
        return bundle.check()
    if args.command == "plan":
        return plan(bundle, layout)
    if args.command == "status":
        return status(bundle, layout)
    if args.command == "snapshot":
        return health.snapshot(bundle.settings)
    caller = os.environ.get("SUDO_UID", "")
    return install(bundle, layout, args.adopt_state, int(caller) if caller.isdigit() else None)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), indent=2))
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as error:
        print("work-access: " + str(error), file=sys.stderr)
        sys.exit(1)
