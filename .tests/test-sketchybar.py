import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SketchyBarTests(unittest.TestCase):
    def run_config(self, menu_height=30, notch_height=0):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            binary = home / "bin"
            binary.mkdir()
            config = home / "config"
            plugins = config / "plugins"
            plugins.mkdir(parents=True)
            shutil.copy(ROOT / "dot_config/sketchybar/palette.sh", config)
            (config / "colors.sh").write_text("BAR_COLOR=0xf0f9f2e9\n")
            shutil.copy(
                ROOT / "dot_config/sketchybar/plugins/executable_notch.sh",
                plugins / "notch.sh",
            )
            (plugins / "notch.sh").chmod(0o755)
            log = home / "commands.jsonl"
            (binary / "sketchybar").write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['COMMAND_LOG'], 'a') as log:\n"
                "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            )
            (binary / "aerospace").write_text("#!/bin/sh\nprintf '1\\n'\n")
            (binary / "osascript").write_text(
                f"#!/bin/sh\nprintf '{menu_height} {notch_height}\\n'\n"
            )
            for name in ("aerospace_listen.sh", "privacy_listen.sh"):
                (plugins / name).write_text("#!/bin/sh\nexit 0\n")
                (plugins / name).chmod(0o755)
            for command in binary.iterdir():
                command.chmod(0o755)
            environment = {
                **os.environ,
                "PATH": f"{binary}:{os.environ['PATH']}",
                "HOME": str(home),
                "CONFIG_DIR": str(config),
                "COMMAND_LOG": str(log),
            }
            subprocess.run(
                ["zsh", str(ROOT / "dot_config/sketchybar/executable_sketchybarrc")],
                env=environment,
                check=True,
                capture_output=True,
                timeout=10,
            )
            return list(map(json.loads, log.read_text().splitlines()))

    def test_bar_leaves_native_fullscreen_spaces(self):
        command = next(args for args in self.run_config() if args[0] == "--bar")
        self.assertIn("sticky=off", command)
        self.assertIn("show_in_fullscreen=off", command)
        self.assertIn("topmost=on", command)

    def test_bar_fits_the_reserved_menu_row(self):
        for height in (24, 30):
            with self.subTest(height=height):
                commands = self.run_config(menu_height=height)
                self.assertTrue(
                    any(args[0] == "--bar" and f"height={height}" in args for args in commands)
                )

    def test_notch_override_resets_on_external_displays(self):
        for notch in (0, 38):
            with self.subTest(notch=notch):
                commands = self.run_config(notch_height=notch)
                self.assertTrue(
                    any(
                        args[0] == "--bar" and f"notch_display_height={notch}" in args
                        for args in commands
                    )
                )

    def test_aerospace_accounts_for_the_main_display_menu_row(self):
        config = (ROOT / "dot_config/aerospace/aerospace.toml.tmpl").read_text()
        self.assertTrue("outer.top = [{ monitor.main = 10 }, 42]" in config)

    def test_bar_background_covers_the_native_menu_bar(self):
        command = next(args for args in self.run_config() if args[0] == "--bar")
        self.assertIn("color=0xfff9f2e9", command)

    def test_geometry_is_set_before_items_are_created(self):
        commands = self.run_config()
        first_item = next(i for i, args in enumerate(commands) if args[:2] == ["--add", "item"])
        self.assertTrue(
            any(args[0] == "--bar" and "height=30" in args for args in commands[:first_item])
        )

    def test_invalid_geometry_keeps_the_fallback_height(self):
        commands = self.run_config(menu_height=0)
        bars = [args for args in commands if args[0] == "--bar"]
        self.assertEqual(len(bars), 1)
        self.assertIn("height=24", bars[0])

    def test_menu_bar_setup_is_macos_only(self):
        template = ROOT / "run_onchange_before_setup-sketchybar.sh.tmpl"
        for system in ("darwin", "linux", "windows"):
            with self.subTest(system=system):
                result = subprocess.run(
                    [
                        "chezmoi", "execute-template", "--override-data",
                        json.dumps({"chezmoi": {"os": system}}),
                        "--file", str(template),
                    ],
                    check=True, capture_output=True, text=True, timeout=10,
                )
                if system == "darwin":
                    self.assertIn("defaults write -g _HIHideMenuBar -bool false", result.stdout)
                    self.assertIn("defaults write com.apple.controlcenter AutoHideMenuBarOption -int 2", result.stdout)
                else:
                    self.assertEqual(result.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
