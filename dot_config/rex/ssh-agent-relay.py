import argparse
import json
import os
from pathlib import Path
import re
import select
import signal
import socket
import socketserver
import stat
import struct
import subprocess
import sys
import threading
import time
from typing import Callable


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


def relay(client, upstream, allowed):
    connections = (client, upstream)
    while allowed():
        readable, _, _ = select.select(connections, [], [], 0.25)
        for source in readable:
            if not allowed():
                return
            data = source.recv(65536)
            if not data:
                return
            destination = upstream if source is client else client
            destination.sendall(data)


def close_connection(connection):
    try:
        connection.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass


class AgentHandler(socketserver.BaseRequestHandler):
    def handle(self):
        server = self.server
        if not isinstance(server, AgentServer):
            return
        pair = None
        try:
            if not server.allowed():
                return
            with server.lock:
                paths = list(server.upstreams)
                generation = server.generation
            with connect_agent(paths) as upstream:
                pair = (self.request, upstream)
                with server.lock:
                    if generation != server.generation:
                        return
                    server.connections.add(pair)
                relay(self.request, upstream, server.allowed)
        except (OSError, ValueError, ConnectionError):
            return
        finally:
            with server.lock:
                server.connections.discard(pair)


class AgentServer(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True

    def __init__(self, path, upstreams):
        self.upstreams = upstreams
        self.allowed: Callable[[], bool] = lambda: True
        self.generation = 0
        self.connections = set()
        self.lock = threading.RLock()
        super().__init__(str(path), AgentHandler)

    def set_upstreams(self, paths):
        with self.lock:
            if paths == self.upstreams:
                return
            self.upstreams = paths
            self.generation += 1
            for pair in self.connections:
                for connection in pair:
                    close_connection(connection)


BLOCK_ID = re.compile(r"block:([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\Z")
HEALTH_LEASE = 5


def pane_socket(directory, block_id):
    match = BLOCK_ID.fullmatch(block_id)
    if not match:
        raise ValueError("Invalid Rex block ID")
    path = directory / f"b-{match[1]}.sock"
    if len(os.fsencode(path)) >= 104:
        raise ValueError("Rex agent socket path is too long")
    return path


def unlink_socket(path):
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        return
    if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise ValueError("Refusing to replace an untrusted listener")
    path.unlink()


def client_source(client, sources):
    info = client.get("info", {})
    principal = client.get("principal", {})
    if info.get("kind") != "app":
        return None
    if principal.get("kind") == "tailscale":
        identity = principal.get("node", "").lower()
    elif principal.get("kind") == "peer" and principal.get("uid") == os.getuid():
        identity = info.get("label", "").lower()
    else:
        return None
    for source in sources:
        if identity in source["aliases"]:
            return source["label"]
    return None


class AgentRouter:
    def __init__(self, directory, sources):
        self.directory = directory
        self.sources = sources
        self.paths = {source["label"]: Path(source["path"]) for source in sources}
        self.clients = {}
        self.blocks = {}
        self.servers = {}
        self.cleanup = []
        self.lock = threading.RLock()
        self.last_seen = 0
        self.ready = False
        self.stopping = threading.Event()
        self.watcher = None

    def update_clients(self, clients):
        self.clients = {client["client_id"]: client_source(client, self.sources) for client in clients}

    def set_owner(self, block_id, owner):
        record = self.blocks.setdefault(block_id, {"owner": None, "last": None})
        record["owner"] = owner
        source = self.clients.get(owner)
        if source:
            record["last"] = source
        elif owner:
            record["last"] = None
        self.apply_route(block_id)

    def apply_route(self, block_id):
        record = self.blocks[block_id]
        source = self.clients.get(record["owner"]) if record["owner"] else record["last"]
        paths = [self.paths[source]] if self.ready and source else []
        self.servers[block_id].set_upstreams(paths)

    def add_block(self, block_id):
        if block_id in self.servers:
            return
        path = pane_socket(self.directory, block_id)
        unlink_socket(path)
        server = AgentServer(path, [])
        server.allowed = lambda: self.ready and time.monotonic() - self.last_seen <= HEALTH_LEASE
        self.servers[block_id] = server
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

    def remove_block(self, block_id):
        server = self.servers.pop(block_id)
        server.set_upstreams([])
        unlink_socket(pane_socket(self.directory, block_id))
        self.blocks.pop(block_id, None)

        def dispose():
            server.shutdown()
            server.server_close()

        thread = threading.Thread(target=dispose, daemon=True)
        self.cleanup = [item for item in self.cleanup if item.is_alive()]
        self.cleanup.append(thread)
        thread.start()

    def receive(self, event):
        with self.lock:
            kind = event.get("type")
            if kind == "snapshot":
                self.update_clients(event.get("clients") or [])
                blocks = event.get("blocks") or []
                current = {block["block_id"] for block in blocks}
                for block_id in set(self.servers) - current:
                    self.remove_block(block_id)
                self.ready = True
                for block in blocks:
                    block_id = block["block_id"]
                    self.add_block(block_id)
                    previous = self.blocks.get(block_id, {})
                    if previous.get("owner") and not block.get("owner"):
                        self.blocks.pop(block_id, None)
                    self.set_owner(block_id, block.get("owner"))
            elif kind == "owner" and self.ready:
                self.update_clients(event.get("clients") or [])
                block_id = event["block_id"]
                self.add_block(block_id)
                if event.get("reset_history"):
                    self.blocks.pop(block_id, None)
                self.set_owner(block_id, event.get("owner"))
            elif kind != "heartbeat":
                return
            self.last_seen = time.monotonic()

    def invalidate(self):
        with self.lock:
            self.ready = False
            self.blocks.clear()
            self.clients.clear()
            for server in self.servers.values():
                server.set_upstreams([])

    def expire(self):
        with self.lock:
            if self.ready and time.monotonic() - self.last_seen > HEALTH_LEASE:
                self.invalidate()

    def close(self):
        self.stopping.set()
        if self.watcher is not None and self.watcher.poll() is None:
            self.watcher.terminate()
            try:
                self.watcher.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.watcher.kill()
                self.watcher.wait()
        with self.lock:
            self.invalidate()
            for block_id in list(self.servers):
                self.remove_block(block_id)
        for thread in self.cleanup:
            thread.join()


def watch(router, rex, watcher):
    env = {key: value for key, value in os.environ.items() if not key.startswith("REX_")}
    while not router.stopping.is_set():
        router.invalidate()
        process = None
        try:
            process = subprocess.Popen([
                rex, "--autostart=false", "do", str(watcher), "--all", "--fail-fast", "--json",
            ], stdout=subprocess.PIPE, text=True, env=env)
            router.watcher = process
            assert process.stdout is not None
            for line in process.stdout:
                if router.stopping.is_set():
                    break
                event = json.loads(line)
                if isinstance(event, dict):
                    router.receive(event)
            process.wait()
        except (OSError, ValueError, KeyError) as error:
            print(f"Rex agent watcher failed: {error}", file=sys.stderr, flush=True)
        finally:
            router.invalidate()
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        router.stopping.wait(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--rex", required=True)
    args = parser.parse_args()
    directory = args.directory
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    metadata = directory.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise ValueError("Agent directory must be owned by this user with mode 0700")
    os.umask(0o177)
    unlink_socket(directory / "agent.sock")
    for path in directory.glob("b-*.sock"):
        unlink_socket(path)
    config = json.loads(args.config.read_text())
    if config.get("legacy_socket"):
        unlink_socket(Path(config["legacy_socket"]))
    router = AgentRouter(directory, config["sources"])
    watcher = Path(__file__).with_name("ssh-agent-watch.lua")
    thread = threading.Thread(target=watch, args=(router, args.rex, watcher), daemon=True)
    thread.start()
    signal.signal(signal.SIGTERM, lambda *_: router.stopping.set())
    try:
        while not router.stopping.is_set():
            router.expire()
            time.sleep(0.25)
    finally:
        router.close()


if __name__ == "__main__":
    main()
