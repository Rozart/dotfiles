import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile
import tempfile
import time
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
DATA = tomllib.loads((ROOT / ".chezmoidata.toml").read_text())["rex"]


def render(relative, platform="linux", hostname="roz-dev-station", home="/home/rozart", username="rozart"):
    return subprocess.check_output(
        ["chezmoi", "--source", str(ROOT), "--override-data",
         json.dumps({"chezmoi": {"os": platform, "hostname": hostname, "homeDir": home, "username": username}}),
         "execute-template", "--file", str(ROOT / relative)],
        text=True,
    )


def copy_rex_modules(destination):
    for path in (ROOT / "dot_config/rex").glob("*.lua"):
        shutil.copy(path, destination / path.name)


def executable(path, content):
    path.write_text("#!/bin/sh\n" + content)
    path.chmod(0o755)


def run_script(script, env):
    return subprocess.run(["/bin/sh"], input=script, env=env, capture_output=True, text=True)


class RexTests(unittest.TestCase):
    def test_platform_gates(self):
        for host in DATA["hosts"]:
            script = render("run_onchange_after_setup-rex.sh.tmpl", hostname=host["hostname"])
            self.assertIn("systemctl --user", script)
            subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
        for platform, hostname in [("linux", "unmanaged"), ("windows", "desktop"), ("darwin", "other-mac")]:
            self.assertFalse(render("run_onchange_after_setup-rex.sh.tmpl", platform, hostname).strip())
        for hostname in [*DATA["mac_hostnames"], "Roz-Laptop", "Roz-Mini-Laptop"]:
            script = render("run_onchange_after_setup-rex.sh.tmpl", "darwin", hostname)
            subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
            self.assertEqual(script.count("launchctl bootstrap"), 6)
            script = render("run_onchange_before_install-rex-client.sh.tmpl", "darwin", hostname)
            subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
            self.assertIn(DATA["mac_app"]["url"], script)
            sync = render("run_after_sync-rex-client-hosts.sh.tmpl", "darwin", hostname)
            subprocess.run(["/bin/sh", "-n"], input=sync, text=True, check=True)
            self.assertIn("sync-client-hosts.py", sync)
            appearance = render("run_after_sync-rex-appearance.sh.tmpl", "darwin", hostname)
            subprocess.run(["/bin/sh", "-n"], input=appearance, text=True, check=True)
            self.assertIn("sync-appearance.py", appearance)
            self.assertNotIn("launchctl", appearance)
            self.assertNotIn("rex_command", appearance)
        for platform, hostname in [("linux", "roz-laptop"), ("windows", "roz-laptop"), ("darwin", "other-mac")]:
            self.assertFalse(render("run_onchange_before_install-rex-client.sh.tmpl", platform, hostname).strip())
            self.assertFalse(render("run_after_sync-rex-client-hosts.sh.tmpl", platform, hostname).strip())
            self.assertFalse(render("run_after_sync-rex-appearance.sh.tmpl", platform, hostname).strip())

    def test_proxmox_never_activates_root_rex(self):
        self.assertFalse(render("run_onchange_after_setup-rex.sh.tmpl", hostname="proxmox", username="root").strip())
        self.assertIn("systemctl --user", render("run_onchange_after_setup-rex.sh.tmpl", hostname="proxmox"))
        self.assertFalse(render("run_onchange_after_setup-rex.sh.tmpl", hostname="roz-dev-station", username="root").strip())
        host = next(host for host in DATA["hosts"] if host["label"] == "proxmox")
        self.assertEqual(host["user"], "rozart")
        self.assertNotEqual(host["uid"], 0)

    def test_proxmox_account_bootstrap_gate(self):
        path = "run_once_before_setup-rex-proxmox-account.sh.tmpl"
        script = render(path, hostname="proxmox", username="root")
        self.assertIn("useradd --create-home --user-group", script)
        self.assertNotIn("sudo", script)
        subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
        for platform, hostname, username in [
            ("linux", "proxmox", "rozart"),
            ("linux", "roz-dev-station", "root"),
            ("darwin", "proxmox", "root"),
        ]:
            self.assertFalse(render(path, platform, hostname, username=username).strip())

    def test_plists_and_dedicated_ssh(self):
        for hostname in DATA["mac_hostnames"]:
            for host in DATA["hosts"]:
                home = "/Users/another-account"
                path = f'Library/LaunchAgents/dev.rozart.rex-{host["label"]}.plist.tmpl'
                plist = plistlib.loads(render(path, "darwin", hostname, home).encode())
                args = plist["ProgramArguments"]
                self.assertEqual(args[:2], ["/usr/bin/env", "python3"])
                self.assertEqual(args[4], home + "/.config/rex/ssh_config")
                self.assertEqual(args[8], f'{home}/.local/state/rex/tunnels/{host["label"]}.sock')
                self.assertEqual(args[10], f'/run/user/{host["uid"]}/rex/server.sock')
                self.assertTrue(plist["KeepAlive"])
        config = render("dot_config/rex/ssh_config.tmpl", "darwin", DATA["mac_hostnames"][0])
        for setting in ["RemoteCommand none", "ControlPath none", "StrictHostKeyChecking yes", "BatchMode yes"]:
            self.assertIn(setting, config)
        self.assertNotIn("RemoteForward", config)

    def test_laptop_hostname_scoped_apply(self):
        for hostname in ["laptop", "Laptop"]:
            with self.subTest(hostname=hostname), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                home = root / "home"
                home.mkdir()
                config = root / "config.toml"
                config.write_text("")
                result = subprocess.run(
                    ["chezmoi", "--source", str(ROOT), "--destination", str(home),
                     "--config", str(config), "--persistent-state", str(root / "state"),
                     "--override-data", json.dumps({"chezmoi": {"os": "darwin", "hostname": hostname,
                                                                "homeDir": str(home), "username": "rozart"}}),
                     "apply", "--parent-dirs", "--include", "files,dirs", "--source-path",
                     str(ROOT / "dot_config/rex/init.lua.tmpl")],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                target = home / ".config/rex/init.lua"
                self.assertEqual(target.read_text().count("rex.host{"), 7)
                self.assertIn(str(home / ".local/state/rex/tunnels/dev-station.sock"), target.read_text())
                self.assertFalse((home / "Applications").exists())

    def test_mac_appearance_scoped_files_and_linux_ignore(self):
        for hostname in [*DATA["mac_hostnames"], "Laptop"]:
            with self.subTest(hostname=hostname), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                home = root / "home"
                home.mkdir()
                config = root / "config.toml"
                config.write_text("")
                result = subprocess.run(
                    ["chezmoi", "--source", str(ROOT), "--destination", str(home),
                     "--config", str(config), "--persistent-state", str(root / "state"),
                     "--override-data", json.dumps({"chezmoi": {"os": "darwin", "hostname": hostname,
                                                                "homeDir": str(home), "username": "rozart"}}),
                     "apply", "--parent-dirs", "--include", "files,dirs", "--source-path",
                     str(ROOT / "dot_config/rex/appearance.json"), str(ROOT / "dot_config/rex/sync-appearance.py")],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((home / ".config/rex/appearance.json").read_bytes(),
                                 (ROOT / "dot_config/rex/appearance.json").read_bytes())
                self.assertTrue((home / ".config/rex/sync-appearance.py").is_file())
                self.assertFalse((home / "Applications").exists())
        ignored = render(".chezmoiignore")
        self.assertIn(".config/rex/appearance.json", ignored)
        self.assertIn(".config/rex/sync-appearance.py", ignored)
        self.assertFalse(render("run_after_sync-rex-appearance.sh.tmpl").strip())

    def test_mac_registration_guide(self):
        for hostname in DATA["mac_hostnames"]:
            guide = render("dot_config/rex/client-hosts.txt.tmpl", "darwin", hostname, "/Users/another-account")
            for host in DATA["hosts"]:
                self.assertIn(f'/Users/another-account/.local/state/rex/tunnels/{host["label"]}.sock', guide)
            self.assertNotIn("/Users/rozart/", guide)
            self.assertIn("not the CLI label", guide)
            self.assertNotIn(".config/rex/client-hosts.txt", render(".chezmoiignore", "darwin", hostname))
            config = json.loads(render("dot_config/rex/client-hosts.json.tmpl", "darwin", hostname, "/Users/another-account"))
            self.assertEqual(config["build"], DATA["mac_app"]["build"])
            self.assertEqual([host["endpoint"] for host in config["hosts"]],
                             [f'/Users/another-account/.local/state/rex/tunnels/{host["label"]}.sock' for host in DATA["hosts"]])
        self.assertIn(".config/rex/client-hosts.*", render(".chezmoiignore"))
        self.assertIn(".config/rex/sync-client-hosts.py", render(".chezmoiignore"))

    def test_selective_apply_creates_parents_without_unrelated_scripts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            destination = root / "home"
            source.mkdir()
            destination.mkdir()
            config = root / "config.toml"
            config.write_text("")
            target = source / "dot_config/rex/keys.lua"
            target.parent.mkdir(parents=True)
            target.write_text("return {}\n")
            unrelated = source / "run_after_unrelated.sh"
            unrelated.write_text("#!/bin/sh\nexit 99\n")
            subprocess.run(
                ["chezmoi", "--source", str(source), "--destination", str(destination),
                 "--config", str(config), "--persistent-state", str(root / "state"),
                 "apply", "--parent-dirs", "--include", "files,dirs,scripts",
                 "--source-path", str(target)],
                check=True, capture_output=True, text=True,
            )
            self.assertTrue((destination / ".config/rex/keys.lua").is_file())

    def test_mac_reapply_keeps_running_tunnels(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            tools = home / "tools"
            tools.mkdir()
            markers = home / "loaded"
            markers.mkdir()
            agents = home / "Library/LaunchAgents"
            agents.mkdir(parents=True)
            config = home / ".config/rex/ssh_config"
            config.parent.mkdir(parents=True)
            config.write_text("Host *\n    BatchMode yes\n")
            launcher = config.with_name("ssh-tunnel.py")
            shutil.copy(ROOT / "dot_config/rex/ssh-tunnel.py", launcher)
            for host in DATA["hosts"]:
                name = f'dev.rozart.rex-{host["label"]}.plist'
                (agents / name).write_text(render("Library/LaunchAgents/" + name + ".tmpl",
                                                 "darwin", DATA["mac_hostnames"][0], str(home)))
            app = home / "Applications/Rex Beta.app/Contents"
            (app / "MacOS").mkdir(parents=True)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": DATA["mac_app"]["build"]}))
            executable(app / "MacOS/Rex", "exit 0\n")
            executable(tools / "rex", "exit 0\n")
            executable(tools / "launchctl",
                       'printf "%s\\n" "$*" >> "$HOME/launchctl.log"\n'
                       'case "$1" in\n'
                       'print) test -e "$HOME/loaded/${2##*/}" ;;\n'
                       'bootstrap) name=${3##*/}; touch "$HOME/loaded/${name%.plist}" ;;\n'
                       'bootout) rm "$HOME/loaded/${2##*/}" ;;\n'
                       'esac\n')
            script = render("run_onchange_after_setup-rex.sh.tmpl", "darwin", DATA["mac_hostnames"][0], str(home))
            env = {**os.environ, "HOME": str(home), "PATH": f"{tools}:{os.environ['PATH']}"}
            for attempt in range(2):
                result = run_script(script, env)
                self.assertEqual(result.returncode, 0, result.stderr)
            calls = (home / "launchctl.log").read_text().splitlines()
            self.assertEqual(sum(line.startswith("bootstrap ") for line in calls), 6)
            self.assertFalse(any(line.startswith("bootout ") for line in calls))
            launcher.write_text(launcher.read_text() + "\n")
            result = run_script(script, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = (home / "launchctl.log").read_text().splitlines()
            self.assertEqual(sum(line.startswith("bootstrap ") for line in calls), 12)
            self.assertEqual(sum(line.startswith("bootout ") for line in calls), 6)

    def test_lua_loads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            copy_rex_modules(root)
            for platform, hostname in [("linux", "proxmox"), *[("darwin", name) for name in DATA["mac_hostnames"]]]:
                (root / "init.lua").write_text(render("dot_config/rex/init.lua.tmpl", platform, hostname))
                result = subprocess.run(
                    ["rex", "config", "check", str(root / "init.lua"), "--json"],
                    env={**os.environ, "HOME": str(root)}, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                self.assertGreaterEqual(json.loads(result.stdout)["bindings"], 59)
                config = (root / "init.lua").read_text()
                self.assertEqual(config.count("rex.host{"), 7 if platform == "darwin" else 0)
        self.assertIn('rex.bind("ctrl+a>g", "client.host.switch")', (ROOT / "dot_config/rex/keys.lua").read_text())

    def test_pane_actions(self):
        lua = shutil.which("lua") or shutil.which("luajit")
        if not lua:
            self.skipTest("Lua interpreter is unavailable")
        result = subprocess.run(
            [lua, str(ROOT / ".tests/rex-panes.lua"), str(ROOT / "dot_config/rex/panes.lua")],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_custom_actions_on_isolated_server(self):
        with tempfile.TemporaryDirectory(prefix="rx-") as directory:
            root = Path(directory)
            copy_rex_modules(root)
            (root / "init.lua").write_text(
                'require("keys")\n'
                'local execute = rex.exec\n'
                'rex.exec = function(argv, options)\n'
                '  assert(argv[1] == "/usr/bin/osascript")\n'
                '  local result, err = execute({"/usr/bin/uname", "-s"}, options)\n'
                '  assert(result, err)\n'
                '  assert(result.ok, result.stderr)\n'
                '  assert(result.stdout == ' + json.dumps(os.uname().sysname + "\n") + ')\n'
                '  result.stdout = "12\\n"\n'
                '  return result\n'
                'end\n'
            )
            socket = root / "server.sock"
            env = {key: value for key, value in os.environ.items() if not key.startswith("REX_")}
            env["HOME"] = str(root)
            env["XDG_CONFIG_HOME"] = str(root / "config")
            env["REX_RUNTIME_DIR"] = str(root)
            server = subprocess.Popen(
                ["rex", "server", "run", "--listen", str(socket), "--state-dir", str(root / "state"),
                 "--config", str(root / "init.lua")], env=env,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )

            def call(*args):
                output = subprocess.check_output(
                    ["rex", "--autostart=false", "-S", str(socket), *args], env=env, text=True,
                )
                return json.loads(output) if output.strip() else None

            try:
                for attempt in range(50):
                    if socket.exists():
                        break
                    self.assertIsNone(server.poll())
                    time.sleep(0.1)
                created = call("new", "isolated-test", "-c", str(root), "--shell", "none", "--json",
                               "--", "/bin/sh", "-c", "sleep 60")
                session = created["session_id"]
                block = created["initial_windows"][0]["block_ids"][0]
                keymap = call("keymap", "--json")
                self.assertEqual(keymap["diagnostics"], [])
                bindings = {tuple(binding["keys"]): (binding["action"], binding.get("args", {}))
                            for binding in keymap["bindings"]}
                self.assertEqual(len(bindings), len(keymap["bindings"]))
                expected = {
                    "'": ("go_to_tab_number", {}),
                    "x": ("pane.close", {}),
                    "shift+7": ("client.tab.close", {}),
                    "shift+c": ("session.new", {}),
                    "shift+e": ("pane.balance", {}),
                    "s": ("session.switch", {}),
                    "w": ("pane.go_to", {}),
                    "o": ("pane.focus_next", {}),
                    "shift+9": ("session.previous", {}),
                    "shift+0": ("session.next", {}),
                    "shift+1": ("pane.move_to_new_tab", {}),
                    "shift+t": ("pane.rename", {}),
                    "ctrl+a": ("pane.send_key", {"key": "ctrl+a"}),
                    "ctrl+b": ("pane.send_key", {"key": "ctrl+a"}),
                    "c": ("new_tab_here", {}),
                    "shift+'": ("split_here", {"direction": "vertical"}),
                    "shift+5": ("split_here", {"direction": "horizontal"}),
                    "n": ("client.tab.next", {}),
                    "p": ("client.tab.previous", {}),
                    "z": ("pane.zoom", {}),
                    "r": ("client.config.reload", {}),
                    "ctrl+space": ("session.switch", {}),
                    "[": ("client.scroll.page_up", {}),
                    "pageup": ("client.scroll.page_up", {}),
                    "]": ("pane.paste", {}),
                    "/": ("client.find.open", {}),
                    "y": ("pane.copy", {}),
                    "g": ("client.host.switch", {}),
                    ",": ("client.tab.rename", {}),
                    "shift+4": ("session.rename", {}),
                    "shift+[": ("swap_pane", {"direction": "previous"}),
                    "shift+]": ("swap_pane", {"direction": "next"}),
                    "ctrl+o": ("rotate_panes", {"direction": "previous"}),
                    "alt+o": ("rotate_panes", {"direction": "next"}),
                }
                for direction in ("left", "down", "up", "right"):
                    expected[direction] = ("pane.focus", {"direction": direction})
                    expected[{"left": "h", "down": "j", "up": "k", "right": "l"}[direction]] = (
                        "pane.focus", {"direction": direction})
                    for modifier, amount in (("ctrl", 1), ("alt", 5)):
                        expected[f"{modifier}+{direction}"] = (
                            "pane.resize", {"direction": direction, "amount": amount})
                for index in range(1, 10):
                    expected[str(index)] = ("client.tab.goto", {"index": index})
                for key, binding in expected.items():
                    with self.subTest(key=key):
                        self.assertEqual(bindings.get(("ctrl+a", key)), binding)
                for action, arguments in [("new_tab_here", []), ("split_here", ["direction=horizontal"]),
                                          ("split_here", ["direction=vertical"])]:
                    result = call("do", action, "-s", session, "-b", block, "--json", *arguments)
                    target = result["block_ids"][0]
                    for attempt in range(50):
                        process = call("block", "call", "-s", session, "-b", target, "process")
                        foreground = process.get("foreground") or process.get("child") or {}
                        if foreground.get("cwd"):
                            break
                        time.sleep(0.1)
                    self.assertEqual(os.path.realpath(foreground["cwd"]), str(root.resolve()))
                def pane_order():
                    view = call("session", "inspect", session, "--json")
                    for window in view["windows"]:
                        for layer in window["layers"]:
                            if any(item["block_id"] == block for item in layer["blocks"]):
                                def collect(node):
                                    if "block_id" in node:
                                        return [node["block_id"]]
                                    split = node["split"]
                                    return collect(split["before"]) + collect(split["after"])
                                self.assertEqual(window["focused_block_id"], block)
                                return collect(layer["layout"])
                    self.fail("Source pane disappeared")

                call("api", "call", "session.focus_block", json.dumps({"session_id": session, "block_id": block}))
                original = pane_order()
                processes = {item: call("block", "call", "-s", session, "-b", item, "process")["child"]["pid"]
                             for item in original}
                position = original.index(block)
                neighbor = (position + 1) % len(original)
                swapped = original.copy()
                swapped[position], swapped[neighbor] = swapped[neighbor], swapped[position]
                call("do", "swap_pane", "-s", session, "-b", block, "direction=next", "--json")
                self.assertEqual(pane_order(), swapped)
                call("do", "swap_pane", "-s", session, "-b", block, "direction=previous", "--json")
                self.assertEqual(pane_order(), original)
                call("do", "rotate_panes", "-s", session, "-b", block, "direction=previous", "--json")
                self.assertEqual(pane_order(), original[1:] + original[:1])
                call("do", "rotate_panes", "-s", session, "-b", block, "direction=next", "--json")
                self.assertEqual(pane_order(), original)
                for item, pid in processes.items():
                    self.assertEqual(call("block", "call", "-s", session, "-b", item, "process")["child"]["pid"], pid)
                self.assertEqual(keymap.get("modes", []), [])
                for host in ("dev-station", "docker-host"):
                    response = call("api", "call", "client.action", json.dumps({
                        "action": "go_to_tab_number",
                        "origin": "key",
                        "server": host,
                        "servers": [{"name": host, "id": "remote-host"}],
                        "session_id": session,
                        "block_id": block,
                    }))
                    self.assertEqual(response["client_actions"], [
                        {"action": "client.tab.goto", "args": {"index": 12}}])
                picker = root / "Applications/Rex Picker.app/Contents/Info.plist"
                picker.parent.mkdir(parents=True)
                picker.write_text("")
                call("config", "reload", "--json")
                installed_map = call("keymap", "--json")
                installed_bindings = {tuple(item["keys"]): item["action"] for item in installed_map["bindings"]}
                self.assertEqual(len(installed_bindings), len(installed_map["bindings"]))
                self.assertEqual(installed_bindings[("ctrl+a", "'")], "open_numbered_tabs")
                self.assertEqual(installed_bindings[("ctrl+a", "f")], "pane.go_to")
                self.assertEqual(installed_bindings[("ctrl+a", "w")], "pane.go_to")
                self.assertNotIn("open_fuzzy_picker", {item["name"] for item in installed_map["actions"]})
                self.assertNotIn("go_to_tab_number", {item["name"] for item in installed_map["actions"]})
                picker.unlink()
                call("config", "reload", "--json")
                fallback_map = call("keymap", "--json")
                fallback_bindings = {tuple(item["keys"]): item["action"] for item in fallback_map["bindings"]}
                self.assertEqual(len(fallback_bindings), len(fallback_map["bindings"]))
                self.assertEqual(fallback_bindings[("ctrl+a", "'")], "go_to_tab_number")
                self.assertEqual(fallback_bindings[("ctrl+a", "f")], "pane.go_to")
                self.assertEqual(fallback_bindings[("ctrl+a", "w")], "pane.go_to")
                subprocess.run(["rex", "--autostart=false", "-S", str(socket), "kill", session],
                               env=env, check=True, capture_output=True)
            finally:
                server.terminate()
                server.wait(timeout=10)

    def fixture(self, home):
        tools = home / "tools"
        tools.mkdir()
        unit = home / ".config/systemd/user/rex.service"
        unit.parent.mkdir(parents=True)
        unit.write_text(render("dot_config/systemd/user/rex.service.tmpl", home=str(home)))
        fake_rex = '#!/bin/sh\ncase "$1" in version) echo "rex ' + DATA["version"] + '" ;; whoami) echo \'{"session_count":0}\' ;; esac\n'
        archive = home / "fixture.tar.gz"
        with tarfile.open(archive, "w:gz") as stream:
            info = tarfile.TarInfo("rex")
            info.mode = 0o755
            info.size = len(fake_rex.encode())
            stream.addfile(info, io.BytesIO(fake_rex.encode()))
        executable(tools / "curl", 'while [ "$1" != -o ]; do shift; done\ncp "$FIXTURE_ARCHIVE" "$2"\n')
        executable(tools / "uname", 'echo "${TEST_ARCH:-x86_64}"\n')
        executable(tools / "tic", "exit 0\n")
        executable(tools / "loginctl", 'echo yes\n')
        executable(tools / "systemctl", 'printf "%s\n" "$*" >> "$HOME/systemctl.log"\ncase "$2" in is-active) test -f "$HOME/active" ;; start) touch "$HOME/active" ;; esac\n')
        env = {**os.environ, "HOME": str(home), "PATH": f"{tools}:{os.environ['PATH']}", "FIXTURE_ARCHIVE": str(archive)}
        script = render("run_onchange_after_setup-rex.sh.tmpl", home=str(home))
        script = script.replace(DATA["arch"]["amd64"]["sha256"], hashlib.sha256(archive.read_bytes()).hexdigest())
        return script, env

    def test_install_and_reapply(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            first = run_script(script, env)
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            binary = home / ".local/bin/rex"
            previous = binary.stat().st_mtime_ns
            second = run_script(script, env)
            self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
            self.assertEqual(binary.stat().st_mtime_ns, previous)
            self.assertNotIn("--user stop", (home / "systemctl.log").read_text())

    def test_bad_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            script = script.replace(hashlib.sha256((home / "fixture.tar.gz").read_bytes()).hexdigest(), "0" * 64)
            result = run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((home / ".local/bin/rex").exists())
            self.assertNotIn("--user start", (home / "systemctl.log").read_text())

    def test_unsupported_architecture(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            result = run_script(script, {**env, "TEST_ARCH": "armv7l"})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsupported", result.stderr)
            self.assertFalse((home / ".local/bin/rex").exists())

    def test_unmanaged_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            binary = home / ".local/bin/rex"
            binary.parent.mkdir(parents=True)
            executable(binary, "exit 0\n")
            before = binary.read_bytes()
            result = run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unmanaged", result.stderr)
            self.assertEqual(before, binary.read_bytes())

    def test_refuse_restart_with_sessions(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            first = run_script(script, env)
            self.assertEqual(first.returncode, 0, first.stderr)
            binary = home / ".local/bin/rex"
            binary.write_text(binary.read_text().replace('"session_count":0', '"session_count":1'))
            state = home / ".local/state/rex"
            (state / "managed-binary.sha256").write_text(hashlib.sha256(binary.read_bytes()).hexdigest() + "\n")
            (state / "managed-unit.sha256").write_text("changed\n")
            result = run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("active sessions", result.stderr)
            self.assertNotIn("--user stop", (home / "systemctl.log").read_text())


class RexMacClientTests(unittest.TestCase):
    def fixture(self, home):
        tools = home / "tools"
        tools.mkdir()
        app = home / "fixture-app"
        (app / "Contents/MacOS").mkdir(parents=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": DATA["mac_app"]["build"]}))
        executable(app / "Contents/MacOS/Rex", "exit 0\n")
        cli = app / "Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
        cli.parent.mkdir(parents=True)
        executable(cli, 'printf "%s\\n" "$*" >> "$HOME/cli.log"\n')
        image = home / "fixture.dmg"
        image.write_bytes(b"fixture disk image")
        executable(tools / "sw_vers", 'printf "%s\\n" "${TEST_MACOS_VERSION:-15.0}"\n')
        executable(tools / "curl",
                   'printf "%s\\n" "$*" >> "$HOME/curl.log"\n'
                   '[ "${TEST_CURL_EXIT:-0}" -eq 0 ] || exit "$TEST_CURL_EXIT"\n'
                   'while [ "$1" != -o ]; do shift; done\ncp "$HOME/fixture.dmg" "$2"\n')
        executable(tools / "hdiutil",
                   'printf "%s\\n" "$*" >> "$HOME/hdiutil.log"\n'
                   'case "$1" in\n'
                   'attach) while [ "$1" != -mountpoint ]; do shift; done\n'
                   'cp -R "$HOME/fixture-app" "$2/Rex Beta.app" ;;\n'
                   'detach) exit 0 ;;\n'
                   'esac\n')
        executable(tools / "codesign",
                   'printf "%s\\n" "$*" >> "$HOME/codesign.log"\n'
                   'exit "${TEST_CODESIGN_EXIT:-0}"\n')
        executable(tools / "ditto", 'cp -R "$1" "$2"\n')
        script = render("run_onchange_before_install-rex-client.sh.tmpl", "darwin", DATA["mac_hostnames"][1], str(home))
        script = script.replace('"/Applications/', '"$HOME/global-apps/')
        script = script.replace(DATA["mac_app"]["sha256"], hashlib.sha256(image.read_bytes()).hexdigest())
        env = {**os.environ, "HOME": str(home), "PATH": f"{tools}:/usr/bin:/bin:/usr/sbin:/sbin"}
        return script, env

    def test_install_and_preserve_existing_version(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            result = run_script(script, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            app = home / "Applications/Rex Beta.app"
            info = app / "Contents/Info.plist"
            self.assertEqual(plistlib.loads(info.read_bytes())["CFBundleVersion"], DATA["mac_app"]["build"])
            info.write_bytes(plistlib.dumps({"CFBundleVersion": "9999"}))
            result = run_script(script, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(plistlib.loads(info.read_bytes())["CFBundleVersion"], "9999")
            self.assertEqual(len((home / "curl.log").read_text().splitlines()), 1)
            self.assertIn(DATA["mac_app"]["team_id"], (home / "codesign.log").read_text())
            self.assertTrue((home / "hdiutil.log").read_text().splitlines()[-1].startswith("detach "))
            self.assertFalse(list((home / "Applications").glob(".rex-install.*")))
            self.assertFalse((home / "cli.log").exists())

    def test_preserve_existing_application_locations(self):
        for location in ["Applications/Rex.app", "global-apps/Rex Beta.app", "global-apps/Rex.app"]:
            with self.subTest(location=location), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                script, env = self.fixture(home)
                target = home / location
                shutil.copytree(home / "fixture-app", target)
                info = target / "Contents/Info.plist"
                info.write_bytes(plistlib.dumps({"CFBundleVersion": "1700"}))
                result = run_script(script, env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(plistlib.loads(info.read_bytes())["CFBundleVersion"], "1700")
                self.assertFalse((home / "curl.log").exists())
                self.assertFalse((home / "Applications/Rex Beta.app").exists())

    def test_refuse_conflicting_application_path(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            target = home / "Applications/Rex Beta.app"
            target.parent.mkdir()
            target.write_text("preserve me")
            result = run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("conflicting", result.stderr)
            self.assertEqual(target.read_text(), "preserve me")
            self.assertFalse((home / "curl.log").exists())

    def test_refuse_failed_installation_checks(self):
        for failure in ["checksum", "signature", "build", "os", "download"]:
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                script, env = self.fixture(home)
                if failure == "checksum":
                    script = script.replace(hashlib.sha256((home / "fixture.dmg").read_bytes()).hexdigest(), "0" * 64)
                elif failure == "signature":
                    env["TEST_CODESIGN_EXIT"] = "1"
                elif failure == "build":
                    (home / "fixture-app/Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": "1700"}))
                elif failure == "os":
                    env["TEST_MACOS_VERSION"] = "14.7"
                else:
                    env["TEST_CURL_EXIT"] = "1"
                result = run_script(script, env)
                self.assertNotEqual(result.returncode, 0, failure)
                self.assertFalse((home / "Applications/Rex Beta.app").exists())
                if failure in ["signature", "build"]:
                    self.assertTrue((home / "hdiutil.log").read_text().splitlines()[-1].startswith("detach "))
                else:
                    self.assertFalse((home / "hdiutil.log").exists())
                self.assertFalse((home / "cli.log").exists())

    def test_setup_uses_bundled_cli_without_path_entry(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            result = run_script(script, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            config = home / ".config/rex/ssh_config"
            config.parent.mkdir(parents=True)
            config.write_text("Host *\n    BatchMode yes\n")
            shutil.copy(ROOT / "dot_config/rex/ssh-tunnel.py", config.with_name("ssh-tunnel.py"))
            agents = home / "Library/LaunchAgents"
            agents.mkdir(parents=True)
            for host in DATA["hosts"]:
                (agents / f'dev.rozart.rex-{host["label"]}.plist').write_text("fixture plist\n")
            executable(home / "tools/launchctl",
                       'printf "%s\\n" "$*" >> "$HOME/launchctl.log"\n'
                       '[ "$1" != print ]\n')
            setup = render("run_onchange_after_setup-rex.sh.tmpl", "darwin", DATA["mac_hostnames"][1], str(home))
            setup = setup.replace('"/Applications/', '"$HOME/global-apps/')
            result = run_script(setup, env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / "cli.log").read_text(), "config reload\n")
            self.assertEqual(sum(line.startswith("bootstrap ") for line in (home / "launchctl.log").read_text().splitlines()), 6)


if __name__ == "__main__":
    unittest.main()
