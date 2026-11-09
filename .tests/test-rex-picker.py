import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "dot_local/share/rex-picker"
HOOK = "run_onchange_after_zz-build-rex-picker.sh.tmpl"
HOSTS = tomllib.loads((ROOT / ".chezmoidata.toml").read_text())["rex"]["mac_hostnames"]


def render(relative, platform="darwin", hostname=HOSTS[0], source=ROOT, home="/Users/test"):
    return subprocess.check_output(
        ["chezmoi", "--source", str(source), "--override-data",
         json.dumps({"chezmoi": {"os": platform, "hostname": hostname, "homeDir": home}}),
         "execute-template", "--file", str(source / relative)], text=True,
    )


def executable(path, content):
    path.write_text("#!/bin/sh\n" + content)
    path.chmod(0o755)


class ProvisioningTests(unittest.TestCase):
    def test_platform_and_hostname_gates(self):
        for hostname in [*HOSTS, "Roz-Laptop", "Roz-Mini-Laptop"]:
            with self.subTest(hostname=hostname):
                script = render(HOOK, hostname=hostname)
                self.assertIn("build-app.sh", script)
                self.assertIn("--autostart=false config reload", script)
                self.assertIn("unset REX_SERVER REX_CLIENT REX_SESSION REX_BLOCK", script)
                subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
                ignored = render(".chezmoiignore", hostname=hostname).splitlines()
                self.assertNotIn(".local/share/rex-picker", ignored)
                self.assertNotIn("Dev/rex-picker", ignored)
                self.assertIn(".local/share/rex-picker/.build", ignored)
                self.assertIn(".local/share/rex-picker/.swiftpm", ignored)
        for platform, hostname in [("linux", "roz-dev-station"), ("windows", HOSTS[0]), ("darwin", "other-mac")]:
            with self.subTest(platform=platform, hostname=hostname):
                self.assertFalse(render(HOOK, platform, hostname).strip())
                ignored = render(".chezmoiignore", platform, hostname).splitlines()
                self.assertIn(".local/share/rex-picker", ignored)
                self.assertIn("Dev/rex-picker", ignored)

    def test_input_hashes_include_changes_additions_and_removals(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            for name in [".chezmoidata.toml", HOOK]:
                shutil.copy(ROOT / name, source / name)
            shutil.copytree(ROOT / ".chezmoitemplates", source / ".chezmoitemplates")
            shutil.copytree(PROJECT, source / "dot_local/share/rex-picker", ignore=shutil.ignore_patterns(".build", ".swiftpm"))
            module = source / "dot_config/rex/fuzzy-picker.lua"
            module.parent.mkdir(parents=True)
            shutil.copy(ROOT / "dot_config/rex/fuzzy-picker.lua", module)
            baseline = render(HOOK, source=source)
            inputs = ["Package.swift", "Info.plist", "build-app.sh", "Sources/PickerCore/Destination.swift"]
            for relative in inputs:
                with self.subTest(relative=relative):
                    path = source / "dot_local/share/rex-picker" / relative
                    original = path.read_text()
                    path.write_text(original + "\n")
                    self.assertNotEqual(baseline, render(HOOK, source=source))
                    path.write_text(original)
            module.write_text(module.read_text() + "\n")
            self.assertNotEqual(baseline, render(HOOK, source=source))
            shutil.copy(ROOT / "dot_config/rex/fuzzy-picker.lua", module)
            added = source / "dot_local/share/rex-picker/Sources/PickerCore/HashProbe.swift"
            added.write_text("struct HashProbe {}\n")
            self.assertNotEqual(baseline, render(HOOK, source=source))
            added.unlink()
            self.assertEqual(baseline, render(HOOK, source=source))

    def test_scoped_deployment_and_development_link(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            home.mkdir()
            config = root / "config.toml"
            config.write_text("")
            result = subprocess.run(
                ["chezmoi", "--source", str(ROOT), "--destination", str(home),
                 "--config", str(config), "--persistent-state", str(root / "state"),
                 "--override-data", json.dumps({"chezmoi": {"os": "darwin", "hostname": HOSTS[0], "homeDir": str(home)}}),
                 "apply", "--parent-dirs", "--include", "files,dirs,symlinks",
                 str(home / ".local/share/rex-picker"), str(home / "Dev/rex-picker")], capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            deployed = home / ".local/share/rex-picker"
            self.assertEqual((deployed / "Package.swift").read_bytes(), (PROJECT / "Package.swift").read_bytes())
            self.assertEqual((deployed / "Sources/RexPicker/App.swift").read_bytes(), (PROJECT / "Sources/RexPicker/App.swift").read_bytes())
            self.assertEqual((home / "Dev/rex-picker").readlink(), deployed)
            self.assertFalse((deployed / "rex/fuzzy-picker.lua").exists())
            self.assertFalse((deployed / ".build").exists())
            self.assertFalse((home / "Applications").exists())


class HookTests(unittest.TestCase):
    def test_local_reload_and_unreachable_server(self):
        for running in ["0", "1"]:
            with self.subTest(running=running), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                home = root / "home"
                project = home / ".local/share/rex-picker"
                project.mkdir(parents=True)
                executable(project / "build-app.sh", 'printf built > "$TEST_ROOT/build.log"\n')
                app = home / "Applications/Rex Beta.app/Contents"
                (app / "MacOS").mkdir(parents=True)
                (app / "Info.plist").write_text("fixture")
                executable(app / "MacOS/Rex", "exit 99\n")
                bin_dir = root / "bin"
                bin_dir.mkdir()
                executable(bin_dir / "rex", '''printf '%s|%s|%s|%s|%s\\n' "$*" "${REX_SERVER-unset}" "${REX_CLIENT-unset}" "${REX_SESSION-unset}" "${REX_BLOCK-unset}" >> "$TEST_ROOT/rex.log"
case "$*" in
    *'server status') [ "$SERVER_RUNNING" = 1 ] ;;
    *'config reload') exit 0 ;;
    *) exit 99 ;;
esac
''')
                env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + ":" + os.environ["PATH"],
                           TEST_ROOT=str(root), SERVER_RUNNING=running, REX_SERVER="remote", REX_CLIENT="other-mac",
                           REX_SESSION="remote-session", REX_BLOCK="remote-pane")
                result = subprocess.run(["/bin/sh"], input=render(HOOK), env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((root / "build.log").read_text(), "built")
                calls = (root / "rex.log").read_text().splitlines()
                self.assertEqual(len(calls), 2 if running == "1" else 1)
                self.assertTrue(all(call.endswith("|unset|unset|unset|unset") for call in calls))
                self.assertTrue(all(call.startswith("--timeout 4s --autostart=false ") for call in calls))
                if running == "1":
                    self.assertIn("config reload", calls[-1])
                else:
                    self.assertIn("not reachable", result.stdout)


class BuilderTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.binary = self.root / "release"
        self.binary.mkdir()
        executable(self.binary / "RexPicker", "printf '%s\\n' new-build\n")
        self.app = self.home / "Applications/Rex Picker.app"
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ":" + os.environ["PATH"],
                        TEST_ROOT=str(self.root), SWIFT_MAJOR="6", BUILD_FAIL="0", SIGN_FAIL="0",
                        VERIFY_FAIL="0", XCODE_FAIL="0", MOVE_FAIL="0", PLATFORM="Darwin")
        executable(self.bin / "uname", 'printf "%s\\n" "$PLATFORM"\n')
        executable(self.bin / "xcode-select", 'exit "$XCODE_FAIL"\n')
        executable(self.bin / "swift", '''if [ "$1" = --version ]; then
    printf 'Apple Swift version %s.0\\n' "$SWIFT_MAJOR"
    exit 0
fi
printf '%s\\n' "$*" >> "$TEST_ROOT/build.log"
case "$*" in
    *--show-bin-path*) printf '%s/release\\n' "$TEST_ROOT" ;;
    *) exit "$BUILD_FAIL" ;;
esac
''')
        executable(self.bin / "plutil", '''if grep -q '<string>dev.rozart.rex-picker</string>' "$4"; then
    printf '%s\\n' dev.rozart.rex-picker
else
    exit 1
fi
''')
        executable(self.bin / "codesign", '''printf '%s\\n' "$*" >> "$TEST_ROOT/sign.log"
case "$1" in
    --verify) exit "$VERIFY_FAIL" ;;
    *) exit "$SIGN_FAIL" ;;
esac
''')
        executable(self.bin / "mv", '''if [ "$MOVE_FAIL" = 1 ] && [ "${1##*/}" = 'Rex Picker.app' ] && [ "$2" = "$HOME/Applications/Rex Picker.app" ]; then
    exit 1
fi
exec /bin/mv "$@"
''')

    def existing_app(self, identifier="dev.rozart.rex-picker"):
        (self.app / "Contents/MacOS").mkdir(parents=True)
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": identifier}))
        executable(self.app / "Contents/MacOS/RexPicker", "printf old-build\n")

    def run_builder(self):
        return subprocess.run(["/bin/sh", str(PROJECT / "build-app.sh")], env=self.env, capture_output=True, text=True)

    def assert_old_app(self):
        self.assertEqual((self.app / "Contents/MacOS/RexPicker").read_text(), "#!/bin/sh\nprintf old-build\n")
        self.assertFalse(list(self.app.parent.glob(".rex-picker-install.*")))

    def test_fresh_install_is_signed_and_verified(self):
        result = self.run_builder()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.app / "Contents/MacOS/RexPicker").read_bytes(), (self.binary / "RexPicker").read_bytes())
        self.assertTrue(os.access(self.app / "Contents/MacOS/RexPicker", os.X_OK))
        signature_log = (self.root / "sign.log").read_text()
        self.assertIn("--force --sign -", signature_log)
        self.assertIn("--verify --strict", signature_log)
        self.assertIn("quit and reopen", result.stdout)

    def test_replaces_only_the_managed_bundle(self):
        self.existing_app()
        result = self.run_builder()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.app / "Contents/MacOS/RexPicker").read_bytes(), (self.binary / "RexPicker").read_bytes())
        self.assertFalse(list(self.app.parent.glob(".rex-picker-install.*")))

    def test_build_sign_and_verification_failures_preserve_installation(self):
        self.existing_app()
        for variable in ["BUILD_FAIL", "SIGN_FAIL", "VERIFY_FAIL"]:
            with self.subTest(variable=variable):
                self.env[variable] = "1"
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assert_old_app()
                self.env[variable] = "0"

    def test_replacement_failure_restores_previous_bundle(self):
        self.existing_app()
        self.env["MOVE_FAIL"] = "1"
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assert_old_app()

    def test_unrelated_bundle_is_preserved(self):
        self.existing_app("org.example.unmanaged")
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to replace", result.stderr)
        self.assert_old_app()
        self.assertFalse((self.root / "build.log").exists())

    def test_regular_file_and_symlink_are_preserved(self):
        self.app.parent.mkdir(parents=True)
        self.app.write_text("unmanaged")
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.app.read_text(), "unmanaged")
        self.app.unlink()
        self.app.symlink_to(self.root / "missing")
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.app.is_symlink())

    def test_compiler_and_platform_preflight_preserve_installation(self):
        self.existing_app()
        for variable, value in [("XCODE_FAIL", "1"), ("SWIFT_MAJOR", "5"), ("SWIFT_MAJOR", "invalid"), ("PLATFORM", "Linux")]:
            with self.subTest(variable=variable, value=value):
                previous = self.env[variable]
                self.env[variable] = value
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assert_old_app()
                self.env[variable] = previous
        self.assertFalse((self.root / "build.log").exists())


if __name__ == "__main__":
    unittest.main()
