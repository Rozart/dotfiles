import argparse
import os
from pathlib import Path
import shlex
import stat
import subprocess


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
    args = parser.parse_args()
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
    os.execv(base[0], [
        *base, "-N", "-T", "-L", f"{args.local}:{args.remote}",
        "-R", f"{args.forwarded_agent}:{args.agent}", *forwards, args.host,
    ])


if __name__ == "__main__":
    main()
