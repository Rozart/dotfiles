import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "dot_config/pi/sync-theme.py"
spec = importlib.util.spec_from_file_location("pi_theme", HELPER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def main():
    for path in (ROOT / "dot_config/claude-code/themes").glob("*.json"):
        source = json.loads(path.read_text())
        theme = module.generate_theme(source)
        assert theme["name"] == "claude-system"
        assert theme["appearance"] == source["base"].removesuffix("-ansi")
        assert theme["colors"]["accent"] == source["overrides"]["claude"]
        assert theme["colors"]["toolSuccessBg"] == source["overrides"]["diffAdded"]
        assert theme["colors"]["toolErrorBg"] == source["overrides"]["diffRemoved"]
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        source = ROOT / "dot_config/claude-code/themes/sonokai-hikari.json"
        settings = directory / "settings.json"
        original = {"theme": "system", "defaultModel": "keep", "extensions": ["keep"]}
        settings.write_text(json.dumps(original))
        command = [sys.executable, str(HELPER), "--source", str(source), "--agent-dir", str(directory)]
        subprocess.run(command + ["--check"], check=True)
        assert json.loads(settings.read_text()) == original
        assert not (directory / "themes").exists()
        subprocess.run(command, check=True)
        expected = {**original, "theme": "claude-system"}
        assert json.loads(settings.read_text()) == expected
        theme_path = directory / "themes/claude-system.json"
        theme = json.loads(theme_path.read_text())
        assert theme["colors"]["border"] == "#a89684"
        assert theme["colors"]["muted"] == "#6c5f6a"
        assert theme["colors"]["thinkingMedium"] == "#0d7f9b"
        before = theme_path.read_bytes()
        for invalid in ["{invalid", "[]"]:
            settings.write_text(invalid)
            result = subprocess.run(command, capture_output=True)
            assert result.returncode != 0
            assert settings.read_text() == invalid
            assert theme_path.read_bytes() == before
        settings.write_text(json.dumps(expected))
        bad_source = directory / "bad.json"
        bad_source.write_text('{"base":"dark"}')
        result = subprocess.run([*command[:3], str(bad_source), *command[4:]], capture_output=True)
        assert result.returncode != 0
        assert json.loads(settings.read_text()) == expected
        assert theme_path.read_bytes() == before
    print("ok — all Claude palettes, exact overrides, settings preservation, check-only, invalid-input safety")


if __name__ == "__main__":
    main()
