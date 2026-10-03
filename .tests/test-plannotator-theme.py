import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "dot_config/plannotator/sync-theme.py"
THEME = ROOT / "dot_config/fish/functions/executable_theme.fish"
EXPECTED = {
    "sonokai-shusia": ("monokai-pro", "dark"),
    "sonokai-hikari": ("gruvbox", "light"),
    "rose-pine-dawn": ("rose-pine", "light"),
    "catppuccin-latte": ("catppuccin", "light"),
    "everforest-light": ("everforest", "light"),
    "tokyonight-day": ("tokyo-night", "light"),
    "gruvbox-material-dark": ("gruvbox", "dark"),
    "gruvbox-material-light": ("gruvbox", "light"),
}


def main():
    fish = shutil.which("fish")
    assert fish, "fish is required"
    with tempfile.TemporaryDirectory(prefix="plannotator-theme-") as temporary:
        home = Path(temporary)
        binary = home / "bin"
        binary.mkdir()
        for name, body in {"uname": "echo Linux", "tmux": "exit 1", "pkill": "exit 1", "find": "exit 0"}.items():
            target = binary / name
            target.write_text(f"#!/bin/sh\n{body}\n")
            target.chmod(0o700)
        config = home / ".config"
        for slug in EXPECTED:
            for relative in [f"tmux/tmuxline/{slug}.tmux.conf", f"delta/themes/{slug}.gitconfig", f"claude-code/themes/{slug}.json", f"btop/themes/{slug}.theme"]:
                target = config / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("{}")
        (config / "ghostty").mkdir()
        (config / "plannotator").mkdir()
        shutil.copyfile(HELPER, config / "plannotator/sync-theme.py")
        data = home / "custom-data"
        data.mkdir()
        target = data / "config.json"
        original = {"displayName": "Keep me", "diffOptions": {"fontSize": "15px"}, "theme": {"light": "github", "dark": "vesper", "extra": True}}
        target.write_text(json.dumps(original))
        env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(config), "TMPDIR": str(home), "PLANNOTATOR_DATA_DIR": str(data), "PATH": f"{binary}:{os.environ['PATH']}"}
        for slug, (palette, mode) in EXPECTED.items():
            result = subprocess.run([fish, "--no-config", "-c", 'source "$argv[1]"; theme "$argv[2]" --local', str(THEME), slug], env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            value = json.loads(target.read_text())
            assert value["theme"][mode] == palette, (slug, value)
            assert value["theme"]["mode"] == mode
            assert value["theme"]["extra"] is True
            assert value["displayName"] == original["displayName"]
            assert value["diffOptions"] == original["diffOptions"]
            assert "reopen or reload" in result.stdout
        subprocess.run([fish, "--no-config", "-n", str(THEME)], check=True)
        for invalid in ["{invalid", "[]", '{"theme": []}']:
            target.write_text(invalid)
            result = subprocess.run(["python3", str(HELPER), "--palette", "gruvbox", "--mode", "light"], env=env, capture_output=True, text=True)
            assert result.returncode != 0
            assert target.read_text() == invalid
        target.unlink()
        subprocess.run(["python3", str(HELPER), "--palette", "monokai-pro", "--mode", "dark"], env=env, check=True)
        assert json.loads(target.read_text())["theme"] == {"light": "plannotator", "dark": "monokai-pro", "mode": "dark"}
        assert target.stat().st_mode & 0o077 == 0
        assert not list(data.glob(".config-*.json"))
    print("ok — eight theme mappings, fish integration, setting preservation, custom data directory, invalid config, private atomic writes")


if __name__ == "__main__":
    main()
