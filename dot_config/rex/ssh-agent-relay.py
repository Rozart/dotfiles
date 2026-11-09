import argparse
import os
from pathlib import Path
import select
import socket
import socketserver
import stat
import struct


MAX_MESSAGE = 1024 * 1024


def receive_exact(connection, size):
    result = bytearray()
    while len(result) < size:
        chunk = connection.recv(size - len(result))
        if not chunk:
            raise ConnectionError("Agent closed the connection")
        result.extend(chunk)
    return bytes(result)


def agent_identities(connection):
    connection.sendall(struct.pack(">IB", 1, 11))
    size = struct.unpack(">I", receive_exact(connection, 4))[0]
    if not 5 <= size <= MAX_MESSAGE:
        raise ValueError("Invalid agent identities response length")
    response = receive_exact(connection, size)
    if response[0] != 12:
        raise ValueError("Invalid agent identities response type")
    return struct.unpack(">I", response[1:5])[0]


def connect_agent(paths):
    for path in paths:
        connection = socket.socket(socket.AF_UNIX)
        try:
            metadata = path.lstat()
            if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid():
                raise ValueError("Untrusted agent socket")
            connection.settimeout(2)
            connection.connect(str(path))
            if not agent_identities(connection):
                raise ValueError("Agent has no identities")
            connection.settimeout(None)
            return connection
        except (OSError, ValueError, ConnectionError):
            connection.close()
    raise ConnectionError("No available SSH agent")


def relay(client, upstream):
    connections = (client, upstream)
    while True:
        readable, _, _ = select.select(connections, [], [])
        for source in readable:
            data = source.recv(65536)
            if not data:
                return
            destination = upstream if source is client else client
            destination.sendall(data)


class AgentHandler(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            with connect_agent(self.server.upstreams) as upstream:
                relay(self.request, upstream)
        except (OSError, ValueError, ConnectionError):
            return


class AgentServer(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True

    def __init__(self, path, upstreams):
        self.upstreams = upstreams
        super().__init__(str(path), AgentHandler)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--sources", nargs="+", required=True)
    args = parser.parse_args()
    directory = args.directory
    metadata = directory.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise ValueError("Agent directory must be owned by this user with mode 0700")
    if any(Path(name).name != name or name in (".", "..", "agent") for name in args.sources):
        raise ValueError("Invalid agent source name")
    listener = directory / "agent.sock"
    if listener.exists() or listener.is_symlink():
        metadata = listener.lstat()
        if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid():
            raise ValueError("Refusing to replace an untrusted listener")
        listener.unlink()
    os.umask(0o177)
    upstreams = [directory / f"{name}.sock" for name in args.sources]
    with AgentServer(listener, upstreams) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
