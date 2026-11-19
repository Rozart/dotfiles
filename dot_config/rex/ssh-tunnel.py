import argparse
import os
from pathlib import Path
import shlex
import signal
import stat
import subprocess
import sys


def attach_forwards(process, base, control, host, forwards):
    pending = dict.fromkeys(forwards)
    errors = {}
    while process.poll() is None:
        for forward in list(pending):
            try:
                result = subprocess.run(
                    [*base, "-S", control, "-O", "forward", "-L", forward, host],
                    stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10,
                )
                error = result.stderr.strip() if result.returncode else None
                if result.returncode and not error:
                    error = f"SSH exited with status {result.returncode}"
            except (OSError, subprocess.TimeoutExpired) as exception:
                error = str(exception)
            if error is None:
                print(f"Forward active: {forward}", file=sys.stderr, flush=True)
                del pending[forward]
                errors.pop(forward, None)
            elif errors.get(forward) != error:
                print(f"Forward pending: {forward}: {error}", file=sys.stderr, flush=True)
                errors[forward] = error
        try:
            return process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
    return process.wait()


def stop(signum, frame):
    raise SystemExit(128 + signum)


def supervise(command, base, control, host, forwards):
    previous = signal.signal(signal.SIGTERM, stop)
    try:
        with subprocess.Popen(command, stdin=subprocess.DEVNULL) as process:
            try:
                return attach_forwards(process, base, control, host, forwards)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
    finally:
        signal.signal(signal.SIGTERM, previous)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--local", required=True)
    parser.add_argument("--remote", required=True)
    parser.add_argument("--agent", required=True)
    parser.add_argument("--forwarded-agent", required=True)
    parser.add_argument("--bridge-local")
    parser.add_argument("--bridge-remote")
    parser.add_argument("--local-forward", action="append", default=[])
    args = parser.parse_args()
    for forward in args.local_forward:
        parts = forward.split(":")
        if (len(parts) != 4 or parts[0] != "127.0.0.1" or not parts[2]
                or any(not port.isascii() or not port.isdecimal() or not 1 <= int(port) <= 65535
                       for port in (parts[1], parts[3]))):
            parser.error("Local forwards must use 127.0.0.1:port:host:port")
    if not Path(args.agent).is_socket():
        raise ValueError("The local 1Password SSH agent socket is unavailable")
    base = ["/usr/bin/ssh", "-F", args.config]
    client = Path(args.forwarded_agent).stem
    command = shlex.join(["python3", ".config/rex/ssh-tunnel-command.py", "--client", client])
    subprocess.run([*base, args.host, command], check=True, timeout=30)
    forwards = []
    if bool(args.bridge_local) != bool(args.bridge_remote):
        raise ValueError("Both bridge socket paths are required")
    if args.bridge_local:
        parent = Path(args.bridge_local).parent
        parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        metadata = parent.lstat()
        if metadata.st_uid != os.getuid() or metadata.st_mode & 0o777 != 0o700 or parent.is_symlink():
            raise ValueError("Untrusted bridge socket directory")
        listener = Path(args.bridge_local)
        if listener.exists() or listener.is_symlink():
            metadata = listener.lstat()
            if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid():
                raise ValueError("Refusing to replace an untrusted bridge listener")
        forwards = ["-L", f"{args.bridge_local}:{args.bridge_remote}"]
    command = [
        *base, "-N", "-T", "-L", f"{args.local}:{args.remote}",
        "-R", f"{args.forwarded_agent}:{args.agent}", *forwards, args.host,
    ]
    if args.local_forward:
        control = args.local + ".control"
        command[len(base):len(base)] = ["-M", "-S", control]
        raise SystemExit(supervise(command, base, control, args.host, args.local_forward))
    os.execv(base[0], command)


if __name__ == "__main__":
    main()
