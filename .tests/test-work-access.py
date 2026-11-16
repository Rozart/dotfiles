import copy
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "dot_local/share/work-access"
sys.path.insert(0, str(SOURCE))
import work_access_health as HEALTH
import work_access_install as INSTALL
import manage as MANAGE


def render(path, hostname="roz-mini-laptop", platform="darwin", arch="arm64", data=None):
    override = {"chezmoi": {"os": platform, "hostname": hostname, "arch": arch, "homeDir": "/Users/fixture", "username": "fixture"}}
    if data:
        override.update(data)
    return subprocess.check_output(["chezmoi", "--source", str(ROOT), "--override-data", json.dumps(override), "execute-template", "--file", str(ROOT / path)], text=True, stderr=subprocess.PIPE)


def stage(directory):
    directory.mkdir()
    for name in ("settings.json", "config.json"):
        (directory / name).write_text(render("dot_local/share/work-access/" + name + ".tmpl"))
    shutil.copyfile(SOURCE / "launchdaemon.plist", directory / "launchdaemon.plist")


def native():
    return {"BackendState": "Running", "CurrentTailnet": {"Name": "rozart.github"}, "Self": {"ID": "personal-node", "TailscaleIPs": ["100.124.130.95"]}, "ExitNodeStatus": {"ID": "selected-exit", "Online": True}, "Peer": {}, "Health": []}


class RenderingTests(unittest.TestCase):
    def test_only_selected_mac_is_enabled(self):
        for name in ("roz-mini-laptop", "ROZ-MINI-LAPTOP"):
            self.assertEqual(render(".chezmoitemplates/work-access-enabled", name).strip(), "true")
            settings = json.loads(render("dot_local/share/work-access/settings.json.tmpl", name))
            self.assertEqual(settings["node_hostname"], "roz-mini-laptop-work-pilot")
            self.assertNotIn(".local/share/work-access", render(".chezmoiignore", name).splitlines())
        for platform, name in (("linux", "roz-mini-laptop"), ("darwin", "roz-laptop"), ("darwin", "unknown")):
            self.assertEqual(render(".chezmoitemplates/work-access-enabled", name, platform).strip(), "false")
            self.assertIn(".local/share/work-access", render(".chezmoiignore", name, platform).splitlines())
            self.assertFalse(render("dot_local/share/work-access/settings.json.tmpl", name, platform).strip())

    def test_unqualified_architecture_fails_explicitly(self):
        with self.assertRaises(subprocess.CalledProcessError) as raised:
            render("dot_local/share/work-access/settings.json.tmpl", arch="amd64")
        self.assertIn("not qualified", raised.exception.stderr)

    def test_rendered_bundle_matches_narrow_scope_and_real_binary(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "bundle"
            stage(directory)
            bundle = INSTALL.Bundle(directory)
            self.assertEqual(bundle.settings["routes"], ["100.85.168.15/32", "fd7a:115c:a1e0::d739:a810/128"])
            self.assertEqual(bundle.settings["domains"], ["internal.programium.dev", "tailbc7768.ts.net"])
            self.assertNotIn("auth_key", json.dumps(bundle.config))
            self.assertEqual(bundle.config["dns"]["rules"][0], {"inbound": ["ts-work"], "action": "reject"})
            self.assertEqual(bundle.check()["configuration"], "valid")
            plist = plistlib.loads((directory / "launchdaemon.plist").read_bytes())
            self.assertEqual(plist["UserName"], "root")
            self.assertTrue(plist["KeepAlive"])
            self.assertNotIn("/Users/", " ".join(plist["ProgramArguments"]))
            self.assertEqual(subprocess.run(["/usr/bin/plutil", "-lint", str(directory / "launchdaemon.plist")], capture_output=True).returncode, 0)
            wrapper = Path(temporary) / "work-access"
            wrapper.write_text(render("dot_local/bin/executable_work-access.tmpl"))
            self.assertEqual(subprocess.run(["/bin/sh", "-n", str(wrapper)]).returncode, 0)


class InstallationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets = tempfile.TemporaryDirectory()
        cls.rendered = Path(cls.assets.name) / "bundle"
        stage(cls.rendered)

    @classmethod
    def tearDownClass(cls):
        cls.assets.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name).resolve()
        self.layout = INSTALL.Layout(self.home / "system", os.getuid(), os.getgid())
        self.layout.root.mkdir(mode=0o700)
        self.directory = self.home / "bundle"
        shutil.copytree(self.rendered, self.directory)
        self.binary = self.home / "sing-box"
        self.binary.write_bytes(b"A test fixture that must never execute\n")
        settings = json.loads((self.directory / "settings.json").read_text())
        settings["binary"] = {"path": str(self.binary), "sha256": hashlib.sha256(self.binary.read_bytes()).hexdigest()}
        settings["pilot_state"] = str(self.home / ".local/state/private-access-migration/work-pilot/tailscale")
        (self.directory / "settings.json").write_text(json.dumps(settings))
        self.bundle = INSTALL.Bundle(self.directory)
        self.source = Path(settings["pilot_state"])
        self.source.mkdir(parents=True, mode=0o700)
        self.source.parent.chmod(0o700)
        self.state = self.source / "tailscaled.state"
        self.state.write_bytes(b"opaque fixture; not actual node credentials")
        self.state.chmod(0o600)
        self.inode = self.state.stat().st_ino
        self.commands = []
        self.fail_bootstrap = False
        for target, replacement in (("checked", self.command), ("native_status", native), ("idle_blockers", lambda: []), ("tun_collisions", lambda settings: [])):
            handle = patch.object(INSTALL, target, side_effect=replacement)
            handle.start()
            self.addCleanup(handle.stop)

    def command(self, arguments, timeout=15):
        self.commands.append(arguments)
        if arguments[:2] == ["/usr/bin/otool", "-L"]:
            return "fixture:\n\t/usr/lib/libSystem.B.dylib (compatibility version 1)\n"
        if Path(arguments[0]).name == "sing-box" and arguments[1] == "version":
            return "sing-box version 1.14.4\nTags: with_tailscale,with_gvisor\n"
        if Path(arguments[0]).name == "sing-box" and arguments[1] == "check":
            return ""
        if arguments[0] == "/bin/launchctl" and arguments[1] in ("disable", "enable", "bootstrap", "bootout"):
            if self.fail_bootstrap and arguments[1] == "bootstrap":
                raise RuntimeError("fixture bootstrap failure")
            return ""
        if arguments == ["/usr/bin/dscacheutil", "-flushcache"]:
            return ""
        self.fail("Unexpected external operation: " + repr(arguments))

    def install(self):
        return INSTALL.install(self.bundle, self.layout, self.source, os.getuid())

    def test_install_moves_identity_once_and_leaves_service_disabled(self):
        result = self.install()
        self.assertTrue(self.source.is_file())
        self.assertEqual(self.source.read_bytes(), INSTALL.STATE_MOVED)
        with self.assertRaises(FileExistsError):
            self.source.mkdir()
        protected = self.layout.state / "tailscale/tailscaled.state"
        self.assertEqual(protected.stat().st_ino, self.inode)
        self.assertEqual(stat.S_IMODE(protected.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.layout.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.layout.logs.stat().st_mode), 0o700)
        self.assertEqual(self.layout.read_record()["phase"], "installed")
        self.assertEqual(os.readlink(self.layout.runtime / "current"), "releases/" + result["release"])
        self.assertFalse(any(command[1] in ("enable", "bootstrap") for command in self.commands if command[0] == "/bin/launchctl"))
        self.assertEqual((self.layout.resolvers / "internal.programium.dev").read_text(), HEALTH.RESOLVER_CONTENT)
        release = self.layout.runtime / "current"
        self.assertEqual(stat.S_IMODE((release / "sing-box").stat().st_mode), 0o755)
        self.assertEqual(stat.S_IMODE((release / "config.json").stat().st_mode), 0o600)
        self.assertEqual(self.layout.plist.stat().st_uid, os.getuid())

    def test_validated_bundle_is_stable_while_staged_files_change(self):
        expected = self.bundle.release()
        original = self.bundle.files["config.json"]
        (self.directory / "config.json").write_text("{}")
        result = self.install()
        self.assertEqual(result["release"], expected)
        self.assertEqual((self.layout.runtime / "current/config.json").read_bytes(), original)
        INSTALL.assert_installed(self.layout)

    def test_reapply_preserves_identity_and_immutable_release(self):
        first = self.install()
        second = INSTALL.install(self.bundle, self.layout)
        self.assertEqual(first["release"], second["release"])
        self.assertEqual((self.layout.state / "tailscale/tailscaled.state").stat().st_ino, self.inode)
        self.assertEqual(len(list((self.layout.runtime / "releases").iterdir())), 1)
        with self.assertRaisesRegex(RuntimeError, "must not be replaced"):
            self.install()

    def test_configuration_update_can_roll_back_without_moving_identity(self):
        first = self.install()
        settings = copy.deepcopy(self.bundle.settings)
        config = copy.deepcopy(self.bundle.config)
        settings["routes"].append("100.80.92.125/32")
        config["inbounds"][0]["route_address"] = settings["routes"]
        config["route"]["rules"][2]["ip_cidr"] = settings["routes"]
        (self.directory / "settings.json").write_text(json.dumps(settings))
        (self.directory / "config.json").write_text(json.dumps(config))
        second = INSTALL.install(INSTALL.Bundle(self.directory), self.layout)
        self.assertNotEqual(first["release"], second["release"])
        result = INSTALL.rollback(self.layout)
        self.assertEqual(result["release"], first["release"])
        self.assertEqual((self.layout.state / "tailscale/tailscaled.state").stat().st_ino, self.inode)
        INSTALL.assert_installed(self.layout)

    def test_active_pilot_blocks_every_install_mutation(self):
        with patch.object(INSTALL, "idle_blockers", return_value=["pilot running"]):
            with self.assertRaisesRegex(RuntimeError, "pilot running"):
                self.install()
        self.assertFalse(self.layout.runtime.exists())
        self.assertTrue(self.state.exists())

    def test_foreign_resolver_is_preserved_before_state_moves(self):
        self.layout.directory(self.layout.resolvers)
        foreign = self.layout.resolvers / "internal.programium.dev"
        foreign.write_text("nameserver 192.168.0.31\n")
        foreign.chmod(0o644)
        with self.assertRaisesRegex(RuntimeError, "will not be overwritten"):
            self.install()
        self.assertEqual(foreign.read_text(), "nameserver 192.168.0.31\n")
        self.assertTrue(self.state.exists())
        self.assertFalse(self.layout.record.exists())

    def test_symlink_resolver_is_never_followed(self):
        self.layout.directory(self.layout.resolvers)
        foreign = self.home / "foreign"
        foreign.write_text("keep me")
        (self.layout.resolvers / "internal.programium.dev").symlink_to(foreign)
        with self.assertRaisesRegex(RuntimeError, "Unsafe installed path"):
            self.install()
        self.assertEqual(foreign.read_text(), "keep me")
        self.assertTrue(self.state.exists())

    def test_broad_routes_auth_keys_and_extra_listeners_are_rejected(self):
        config = copy.deepcopy(self.bundle.config)
        settings = copy.deepcopy(self.bundle.settings)
        for mutation in ("route", "auth", "listener"):
            with self.subTest(mutation=mutation):
                changed_config, changed_settings = copy.deepcopy(config), copy.deepcopy(settings)
                if mutation == "route":
                    changed_settings["routes"] = ["100.64.0.0/10"]
                elif mutation == "auth":
                    changed_config["endpoints"][0]["auth_key"] = "not-a-real-secret"
                else:
                    changed_config["inbounds"].append({"type": "mixed", "listen": "0.0.0.0", "listen_port": 1088})
                (self.directory / "settings.json").write_text(json.dumps(changed_settings))
                (self.directory / "config.json").write_text(json.dumps(changed_config))
                with self.assertRaises(RuntimeError):
                    INSTALL.Bundle(self.directory)
        self.assertTrue(self.state.exists())

    def test_changed_binary_is_not_executed_or_installed(self):
        self.binary.write_bytes(b"unreviewed update")
        with self.assertRaisesRegex(RuntimeError, "tested hash"):
            self.install()
        self.assertEqual(self.commands, [])
        self.assertFalse(self.layout.runtime.exists())

    def test_other_node_state_cannot_be_adopted(self):
        other = self.home / "rex" / "tailscale"
        other.mkdir(parents=True, mode=0o700)
        (other / "tailscaled.state").write_text("unrelated state fixture")
        with self.assertRaisesRegex(RuntimeError, "never use official or Rex"):
            INSTALL.install(self.bundle, self.layout, other, os.getuid())
        self.assertTrue(self.state.exists())
        self.assertTrue((other / "tailscaled.state").exists())
        self.assertFalse(self.layout.record.exists())

    def test_state_symlinks_and_hardlinks_are_rejected(self):
        target = self.home / "foreign"
        target.write_text("not node state")
        link = self.source / "unexpected"
        for kind in ("symbolic", "hard"):
            with self.subTest(kind=kind):
                if kind == "symbolic":
                    link.symlink_to(target)
                else:
                    os.link(target, link)
                with self.assertRaisesRegex(RuntimeError, "private owned"):
                    self.install()
                link.unlink()
        self.assertEqual(target.read_text(), "not node state")
        self.assertTrue(self.state.exists())

    def test_start_checks_integrity_and_bootstrap_failure_disables_service(self):
        self.install()
        self.fail_bootstrap = True
        with self.assertRaisesRegex(RuntimeError, "bootstrap failure"):
            INSTALL.start(self.layout)
        self.assertEqual(self.commands[-1], ["/bin/launchctl", "disable", "system/" + HEALTH.LABEL])
        self.fail_bootstrap = False
        result = INSTALL.start(self.layout)
        self.assertIn("submitted", result["service"])
        (self.layout.runtime / "current/config.json").write_text("{}")
        with self.assertRaisesRegex(RuntimeError, "integrity check"):
            INSTALL.start(self.layout)

    def test_stop_remains_available_when_dns_is_damaged(self):
        self.install()
        path = self.layout.resolvers / "internal.programium.dev"
        path.write_text("changed by another administrator")
        with patch.object(INSTALL, "run", return_value=subprocess.CompletedProcess([], 0, "", "")):
            result = INSTALL.stop(self.layout)
        self.assertIn("disabled", result["service"])
        self.assertIn(["/bin/launchctl", "bootout", "system/" + HEALTH.LABEL], self.commands)
        self.assertEqual(path.read_text(), "changed by another administrator")

    def test_restore_returns_same_state_and_retains_unrelated_files_and_releases(self):
        self.install()
        unrelated = self.layout.resolvers / "keep.example.test"
        unrelated.write_text("nameserver 192.168.0.31\n")
        releases = list((self.layout.runtime / "releases").iterdir())
        result = INSTALL.restore_pilot(self.layout)
        self.assertEqual(self.state.stat().st_ino, self.inode)
        self.assertFalse((self.layout.state / "tailscale").exists())
        self.assertFalse(self.layout.plist.exists())
        self.assertEqual(unrelated.read_text(), "nameserver 192.168.0.31\n")
        self.assertEqual(list((self.layout.runtime / "releases").iterdir()), releases)
        self.assertEqual(self.layout.read_record()["phase"], "restored")
        self.assertIn("returned", result["state"])

    def test_restore_refuses_changed_dns_without_moving_credentials(self):
        self.install()
        resolver = self.layout.resolvers / "internal.programium.dev"
        resolver.write_text("keep this new resolver")
        with self.assertRaisesRegex(RuntimeError, "will not be overwritten"):
            INSTALL.restore_pilot(self.layout)
        self.assertTrue((self.layout.state / "tailscale/tailscaled.state").exists())
        self.assertTrue(self.source.is_file())
        self.assertEqual(resolver.read_text(), "keep this new resolver")

    def test_interrupted_identity_move_can_be_restored_without_copying(self):
        original = os.chown
        failed = []

        def fail_once(path, uid, gid, **kwargs):
            if Path(path) == self.layout.state / "tailscale" and not failed:
                failed.append(True)
                raise OSError("fixture interrupted ownership change")
            return original(path, uid, gid, **kwargs)

        with patch.object(INSTALL.os, "chown", side_effect=fail_once):
            with self.assertRaisesRegex(OSError, "interrupted ownership"):
                self.install()
        self.assertEqual(self.layout.read_record()["phase"], "prepared")
        self.assertTrue(self.source.is_file())
        INSTALL.restore_pilot(self.layout)
        self.assertEqual(self.state.stat().st_ino, self.inode)


class HealthTests(unittest.TestCase):
    def test_native_identity_and_address_collisions_are_checked_without_mutation(self):
        settings = {"personal_tailnet": "rozart.github", "routes": ["100.85.168.15/32"]}
        status = native()
        original = copy.deepcopy(status)
        HEALTH.personal_preflight(settings, status)
        self.assertEqual(status, original)
        status["Peer"] = {"collision": {"TailscaleIPs": ["100.85.168.15"]}}
        with self.assertRaisesRegex(RuntimeError, "collides"):
            HEALTH.personal_preflight(settings, status)
        status = native()
        status["CurrentTailnet"]["Name"] = "programium.dev"
        with self.assertRaisesRegex(RuntimeError, "personal tailnet"):
            HEALTH.personal_preflight(settings, status)

    def test_incomplete_native_identity_blocks_network_changes(self):
        settings = {"personal_tailnet": "rozart.github", "routes": ["100.85.168.15/32"]}
        for self_node in (None, {}, {"ID": "personal-node", "TailscaleIPs": []}):
            with self.subTest(self_node=self_node):
                status = native()
                status["Self"] = self_node
                with self.assertRaisesRegex(RuntimeError, "complete personal node identity"):
                    HEALTH.personal_preflight(settings, status)
        self.assertIsNone(HEALTH.identity({"Self": None})["self_id"])

    def test_private_tun_collision_ignores_exit_node_default_routes(self):
        output = "default 1.2.3.4 UG utun4\n0/1 1.2.3.4 UG utun4\n172.31/16 192.168.0.1 UG en0\n192.168.0/23 1.2.3.4 UG utun4\n"
        def commands(arguments):
            return output if arguments[-1] == "inet" else "::/0 fe80::1 UG utun4\n"
        with patch.object(HEALTH, "checked", side_effect=commands):
            self.assertEqual(HEALTH.tun_collisions({"tun_addresses": ["172.31.255.1/30", "fdfe:dcba:2026::1/126"]}), ["172.31.0.0/16"])

    def test_verification_checks_work_dns_tls_routing_and_personal_nas(self):
        settings = json.loads(render("dot_local/share/work-access/settings.json.tmpl"))
        commands = []

        def routed(address):
            if address == "100.85.168.15":
                return {"gateway": "172.31.255.1", "interface": "utun7"}
            if address == "fd7a:115c:a1e0::d739:a810":
                return {"gateway": "fdfe:dcba:2026::1", "interface": "utun7"}
            return {"gateway": "100.100.100.100", "interface": "utun4"}

        def command(arguments, timeout=15):
            commands.append(arguments)
            if arguments[0] == "/usr/bin/dscacheutil":
                return "name: coolify.internal.programium.dev\nip_address: 100.85.168.15\n"
            if arguments[0] == "/usr/bin/curl":
                self.assertIn("--noproxy", arguments)
                self.assertNotIn("--insecure", arguments)
                return "200 0 https://coolify.internal.programium.dev/login"
            if arguments[0] == "/usr/bin/nc":
                return ""
            self.fail("Unexpected health operation")

        baseline = {"native": HEALTH.identity(native()), "internet_route": routed("1.1.1.1")}
        with patch.object(HEALTH, "native_status", side_effect=native), patch.object(HEALTH, "route", side_effect=routed), patch.object(HEALTH, "checked", side_effect=command):
            result = HEALTH.verify(settings, baseline)
            self.assertEqual(result["nas_tcp_445"], "reachable")
            with patch.object(HEALTH, "checked", return_value="ip_address: 100.99.126.85\n"):
                with self.assertRaisesRegex(RuntimeError, "System DNS"):
                    HEALTH.verify(settings, baseline)
            changed = native()
            changed["ExitNodeStatus"]["ID"] = "unexpected-exit"
            with patch.object(HEALTH, "native_status", return_value=changed):
                with self.assertRaisesRegex(RuntimeError, "exit-node selection"):
                    HEALTH.verify(settings, baseline)
            changed["ExitNodeStatus"]["Online"] = False
            with patch.object(HEALTH, "native_status", return_value=changed):
                with self.assertRaisesRegex(RuntimeError, "not confirmed online"):
                    HEALTH.verify(settings)
            with patch.object(HEALTH, "route", return_value=routed("1.1.1.1")):
                with self.assertRaisesRegex(RuntimeError, "expected TUN gateway"):
                    HEALTH.verify(settings)
        self.assertTrue(any(arguments[0] == "/usr/bin/nc" for arguments in commands))

    def test_a_running_pilot_does_not_count_as_managed_service_acceptance(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "bundle"
            stage(directory)
            with patch.object(MANAGE, "DIRECTORY", directory), patch.object(MANAGE, "service_loaded", return_value=False):
                with self.assertRaisesRegex(RuntimeError, "pilot success is not"):
                    MANAGE.main(["verify"])

    def test_deployed_verification_does_not_depend_on_staged_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            layout = INSTALL.Layout(root / "system", os.getuid(), os.getgid())
            current = layout.runtime / "current"
            current.mkdir(parents=True)
            settings = json.loads(render("dot_local/share/work-access/settings.json.tmpl"))
            (current / "settings.json").write_text(json.dumps(settings))
            desired = root / "missing-desired-files"
            with patch.object(MANAGE, "DIRECTORY", desired), patch.object(MANAGE, "Layout", return_value=layout), patch.object(MANAGE, "service_loaded", return_value=True), patch.object(HEALTH, "verify", return_value={"deployed": "checked"}) as probe:
                self.assertEqual(MANAGE.main(["verify"]), {"deployed": "checked"})
                probe.assert_called_once_with(settings, None)

    def test_privileged_commands_refuse_unprivileged_or_unconfirmed_execution(self):
        for command in ("install", "start", "stop", "rollback", "restore-pilot"):
            with self.subTest(command=command):
                with patch.object(MANAGE.os, "geteuid", return_value=501):
                    with self.assertRaisesRegex(RuntimeError, "directly with sudo"):
                        MANAGE.main([command, "--confirm"])
                with patch.object(MANAGE.os, "geteuid", return_value=0):
                    with self.assertRaisesRegex(RuntimeError, "directly with sudo"):
                        MANAGE.main([command])


if __name__ == "__main__":
    unittest.main()
