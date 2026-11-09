import argparse
import os
from pathlib import Path
import shlex
import subprocess


CLEANUP = """
import os
from pathlib import Path
import stat
import sys

path = Path(sys.argv[1])
parent = path.parent.lstat()
if not stat.S_ISDIR(parent.st_mode) or parent.st_uid != os.getuid() or stat.S_IMODE(parent.st_mode) != 0o700:
    raise ValueError('Untrusted remote agent directory')
try:
    metadata = path.lstat()
except FileNotFoundError:
    pass
else:
    if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise ValueError('Refusing to unlink an untrusted remote socket')
    path.unlink()
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--local", required=True)
    parser.add_argument("--remote", required=True)
    parser.add_argument("--agent", required=True)
    parser.add_argument("--forwarded-agent", required=True)
    args = parser.parse_args()
    if not Path(args.agent).is_socket():
        raise ValueError("The local 1Password SSH agent socket is unavailable")
    base = ["/usr/bin/ssh", "-F", args.config]
    command = shlex.join(["python3", "-c", CLEANUP, args.forwarded_agent])
    subprocess.run([*base, args.host, command], check=True, timeout=30)
    os.execv(base[0], [
        *base, "-N", "-T", "-L", f"{args.local}:{args.remote}",
        "-R", f"{args.forwarded_agent}:{args.agent}", args.host,
    ])


if __name__ == "__main__":
    main()
