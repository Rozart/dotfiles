import ipaddress
import json
import re
import socket
import subprocess
from urllib.parse import urlsplit


LABEL = "dev.rozart.work-access"
TAILSCALE = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
RESOLVER_CONTENT = "# managed by dev.rozart.work-access\nnameserver 127.0.0.1\nport 1053\ntimeout 2\n"


def run(arguments, timeout=15):
    return subprocess.run(arguments, text=True, capture_output=True, timeout=timeout)


def checked(arguments, timeout=15):
    result = run(arguments, timeout)
    if result.returncode:
        raise RuntimeError("Command failed: " + arguments[0] + ": " + result.stderr.strip())
    return result.stdout


def native_status():
    return json.loads(checked([TAILSCALE, "status", "--json"]))


def identity(status):
    return {
        "tailnet": (status.get("CurrentTailnet") or {}).get("Name"),
        "self_id": (status.get("Self") or {}).get("ID"),
        "exit_node_id": (status.get("ExitNodeStatus") or {}).get("ID"),
    }


def personal_preflight(settings, status):
    if status.get("BackendState") != "Running" or identity(status)["tailnet"] != settings["personal_tailnet"]:
        raise RuntimeError("The official client must already be running on the expected personal tailnet; no profile will be switched")
    self_node = status.get("Self") or {}
    if not self_node.get("ID") or not self_node.get("TailscaleIPs"):
        raise RuntimeError("A complete personal node identity and address list are required")
    addresses = list(self_node["TailscaleIPs"])
    addresses += [address for peer in (status.get("Peer") or {}).values() for address in peer.get("TailscaleIPs", [])]
    for prefix in settings["routes"]:
        network = ipaddress.ip_network(prefix)
        if any(ipaddress.ip_address(address) in network for address in addresses):
            raise RuntimeError("Work address collides with a native personal node: " + prefix)


def route(address):
    arguments = ["/sbin/route", "-n", "get"]
    if ipaddress.ip_address(address).version == 6:
        arguments.append("-inet6")
    output = checked(arguments + [address])
    return dict(re.findall(r"^\s*(interface|gateway):\s*(\S+)", output, re.MULTILINE))


def tun_collisions(settings):
    collisions = []
    for family in ("inet", "inet6"):
        output = checked(["/usr/sbin/netstat", "-rn", "-f", family])
        for line in output.splitlines():
            token = line.split()[0] if line.split() else ""
            if "/" not in token or "%" in token:
                continue
            try:
                address, prefix = token.split("/")
                if family == "inet":
                    address = ".".join(address.split(".") + ["0"] * (4 - len(address.split("."))))
                network = ipaddress.ip_network(address + "/" + prefix, strict=False)
            except ValueError:
                continue
            if not network.is_private:
                continue
            for value in settings["tun_addresses"]:
                candidate = ipaddress.ip_interface(value).network
                if candidate.version == network.version and candidate.overlaps(network):
                    collisions.append(str(network))
    return sorted(set(collisions))


def snapshot(settings):
    status = native_status()
    personal_preflight(settings, status)
    return {"native": identity(status), "internet_route": route("1.1.1.1")}


def verify(settings, baseline=None):
    status = native_status()
    personal_preflight(settings, status)
    if status.get("Health"):
        raise RuntimeError("The native Tailscale client reports health warnings")
    if status.get("ExitNodeStatus") and status["ExitNodeStatus"].get("Online") is not True:
        raise RuntimeError("The selected native exit node is not confirmed online")
    if baseline and identity(status) != baseline["native"]:
        raise RuntimeError("Personal identity or exit-node selection differs from the supplied baseline")
    gateways = {ipaddress.ip_interface(value).version: ipaddress.ip_interface(value).ip for value in settings["tun_addresses"]}
    routes = {}
    for prefix in settings["routes"]:
        address = ipaddress.ip_network(prefix).network_address
        result = route(str(address))
        gateway = result.get("gateway", "").split("%")[0]
        if not result.get("interface", "").startswith("utun") or gateway != str(gateways[address.version]):
            raise RuntimeError("Work destination is not on the expected TUN gateway: " + str(address))
        routes[str(address)] = result
    internet = route("1.1.1.1")
    if internet.get("interface") in {value["interface"] for value in routes.values()}:
        raise RuntimeError("Ordinary internet traffic unexpectedly uses the work TUN")
    if baseline and internet != baseline["internet_route"]:
        raise RuntimeError("Ordinary internet routing differs from the supplied baseline")
    host = urlsplit(settings["health_url"]).hostname
    output = checked(["/usr/bin/dscacheutil", "-q", "host", "-a", "name", host])
    addresses = re.findall(r"^(?:ip_address|ipv6_address): (\S+)", output, re.MULTILINE)
    allowed = {str(ipaddress.ip_network(value).network_address) for value in settings["routes"]}
    if not addresses or not set(addresses).issubset(allowed):
        raise RuntimeError("System DNS did not return only configured work addresses")
    output = checked(["/usr/bin/curl", "--noproxy", "*", "--silent", "--show-error", "--location", "--max-redirs", "5", "--connect-timeout", "3", "--max-time", "12", "--output", "/dev/null", "--write-out", "%{http_code} %{ssl_verify_result} %{url_effective}", settings["health_url"]], timeout=15)
    if not output.startswith("200 0 "):
        raise RuntimeError("Work HTTPS verification failed: " + output)
    checked(["/usr/bin/nc", "-z", "-G", "3", settings["personal_nas"], "445"], timeout=5)
    return {"native": identity(status), "work_routes": routes, "internet_route": internet, "work_https": output.strip(), "nas_tcp_445": "reachable", "limits": "No authenticated UI, SSH authentication, ingress-isolation or failure-closed proof"}


def idle_blockers():
    blockers = []
    if run(["/bin/launchctl", "print", "system/" + LABEL]).returncode == 0:
        blockers.append("The managed service is loaded; stop it explicitly before changing installed files")
    if run(["/usr/bin/pgrep", "-x", "sing-box"]).returncode == 0:
        blockers.append("A sing-box process is running; do not run two instances or terminate unrelated instances")
    for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
        with socket.socket(socket.AF_INET, kind) as listener:
            try:
                listener.bind(("127.0.0.1", 1053))
            except OSError:
                protocol = "TCP" if kind == socket.SOCK_STREAM else "UDP"
                blockers.append("Loopback " + protocol + " DNS port 1053 is already in use")
    return blockers
