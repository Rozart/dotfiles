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


def executable(path, content):
    path.write_text("#!/bin/sh\n" + content)
    path.chmod(0o755)


class RexTests(unittest.TestCase):
    def test_platform_gates(self):
        for host in DATA["hosts"]:
            script = render("run_onchange_after_setup-rex.sh.tmpl", hostname=host["hostname"])
            self.assertIn("systemctl --user", script)
            subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
        for platform, hostname in [("linux", "unmanaged"), ("windows", "desktop"), ("darwin", "other-mac")]:
            self.assertFalse(render("run_onchange_after_setup-rex.sh.tmpl", platform, hostname).strip())
        script = render("run_onchange_after_setup-rex.sh.tmpl", "darwin", DATA["mac_hostname"])
        subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
        self.assertEqual(script.count("launchctl bootstrap"), 6)

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
        for host in DATA["hosts"]:
            path = f'Library/LaunchAgents/dev.rozart.rex-{host["label"]}.plist.tmpl'
            plist = plistlib.loads(render(path, "darwin", DATA["mac_hostname"]).encode())
            args = plist["ProgramArguments"]
            self.assertEqual(args[:2], ["/usr/bin/ssh", "-F"])
            self.assertIn(f'/run/user/{host["uid"]}/rex/server.sock', args[6])
            self.assertTrue(plist["KeepAlive"])
        config = render("dot_config/rex/ssh_config.tmpl", "darwin", DATA["mac_hostname"])
        for setting in ["RemoteCommand none", "ControlPath none", "StrictHostKeyChecking yes", "BatchMode yes"]:
            self.assertIn(setting, config)
        self.assertNotIn("RemoteForward", config)

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
            for host in DATA["hosts"]:
                name = f'dev.rozart.rex-{host["label"]}.plist'
                (agents / name).write_text(render("Library/LaunchAgents/" + name + ".tmpl",
                                                 "darwin", DATA["mac_hostname"], str(home)))
            executable(tools / "rex", "exit 0\n")
            executable(tools / "launchctl",
                       'printf "%s\\n" "$*" >> "$HOME/launchctl.log"\n'
                       'case "$1" in\n'
                       'print) test -e "$HOME/loaded/${2##*/}" ;;\n'
                       'bootstrap) name=${3##*/}; touch "$HOME/loaded/${name%.plist}" ;;\n'
                       'bootout) rm "$HOME/loaded/${2##*/}" ;;\n'
                       'esac\n')
            script = render("run_onchange_after_setup-rex.sh.tmpl", "darwin", DATA["mac_hostname"], str(home))
            env = {**os.environ, "HOME": str(home), "PATH": f"{tools}:{os.environ['PATH']}"}
            for attempt in range(2):
                result = self.run_script(script, env)
                self.assertEqual(result.returncode, 0, result.stderr)
            calls = (home / "launchctl.log").read_text().splitlines()
            self.assertEqual(sum(line.startswith("bootstrap ") for line in calls), 6)
            self.assertFalse(any(line.startswith("bootout ") for line in calls))

    def test_lua_loads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy(ROOT / "dot_config/rex/keys.lua", root / "keys.lua")
            for platform, hostname in [("linux", "proxmox"), ("darwin", DATA["mac_hostname"])]:
                (root / "init.lua").write_text(render("dot_config/rex/init.lua.tmpl", platform, hostname))
                result = subprocess.run(["rex", "config", "check", str(root / "init.lua"), "--json"], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_custom_actions_on_isolated_server(self):
        with tempfile.TemporaryDirectory(prefix="rx-") as directory:
            root = Path(directory)
            shutil.copy(ROOT / "dot_config/rex/keys.lua", root / "keys.lua")
            (root / "init.lua").write_text('require("keys")\n')
            socket = root / "server.sock"
            env = {key: value for key, value in os.environ.items() if not key.startswith("REX_")}
            server = subprocess.Popen(
                ["rex", "server", "run", "--listen", str(socket), "--state-dir", str(root / "state"),
                 "--config", str(root / "init.lua")], env=env,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )

            def call(*args):
                return json.loads(subprocess.check_output(
                    ["rex", "--autostart=false", "-S", str(socket), *args], env=env, text=True,
                ))

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

    def run_script(self, script, env):
        return subprocess.run(["/bin/sh"], input=script, env=env, capture_output=True, text=True)

    def test_install_and_reapply(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            first = self.run_script(script, env)
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            binary = home / ".local/bin/rex"
            previous = binary.stat().st_mtime_ns
            second = self.run_script(script, env)
            self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
            self.assertEqual(binary.stat().st_mtime_ns, previous)
            self.assertNotIn("--user stop", (home / "systemctl.log").read_text())

    def test_bad_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            script = script.replace(hashlib.sha256((home / "fixture.tar.gz").read_bytes()).hexdigest(), "0" * 64)
            result = self.run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((home / ".local/bin/rex").exists())
            self.assertNotIn("--user start", (home / "systemctl.log").read_text())

    def test_unsupported_architecture(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            result = self.run_script(script, {**env, "TEST_ARCH": "armv7l"})
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
            result = self.run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unmanaged", result.stderr)
            self.assertEqual(before, binary.read_bytes())

    def test_refuse_restart_with_sessions(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            script, env = self.fixture(home)
            first = self.run_script(script, env)
            self.assertEqual(first.returncode, 0, first.stderr)
            binary = home / ".local/bin/rex"
            binary.write_text(binary.read_text().replace('"session_count":0', '"session_count":1'))
            state = home / ".local/state/rex"
            (state / "managed-binary.sha256").write_text(hashlib.sha256(binary.read_bytes()).hexdigest() + "\n")
            (state / "managed-unit.sha256").write_text("changed\n")
            result = self.run_script(script, env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("active sessions", result.stderr)
            self.assertNotIn("--user stop", (home / "systemctl.log").read_text())


if __name__ == "__main__":
    unittest.main()
