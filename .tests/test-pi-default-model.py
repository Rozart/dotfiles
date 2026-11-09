import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MODIFIER = ROOT / "dot_pi/agent/modify_settings.json"
DEFAULTS = {"defaultProvider": "openai", "defaultModel": "gpt-6.1-sol"}


def main():
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        source = directory / "source"
        destination = directory / "home"
        modifier = source / "dot_pi/agent/modify_settings.json"
        modifier.parent.mkdir(parents=True)
        shutil.copyfile(MODIFIER, modifier)
        destination.mkdir()
        config = directory / "chezmoi.toml"
        config.write_text("")
        settings = destination / ".pi/agent/settings.json"
        command = [
            "chezmoi", "--config", str(config), "--source", str(source),
            "--destination", str(destination), "--persistent-state", str(directory / "state.boltdb"),
            "apply",
        ]
        subprocess.run(command, check=True)
        assert json.loads(settings.read_text()) == DEFAULTS
        original = {
            "defaultProvider": "other", "defaultModel": "old", "deviceId": "local-device",
            "theme": "system", "hideThinkingBlock": True,
            "modelThinkingLevels": {"openai/gpt-6.1-sol": "high"},
        }
        settings.write_text(json.dumps(original))
        subprocess.run(command, check=True)
        assert json.loads(settings.read_text()) == {**original, **DEFAULTS}
        before = settings.read_bytes()
        subprocess.run(command, check=True)
        assert settings.read_bytes() == before
        formatted = json.dumps({**original, **DEFAULTS}, separators=(",", ":"))
        settings.write_text(formatted)
        subprocess.run(command, check=True)
        assert settings.read_text() == formatted
        for invalid in ["{invalid", "[]", "null"]:
            settings.write_text(invalid)
            result = subprocess.run(command, capture_output=True)
            assert result.returncode != 0
            assert settings.read_text() == invalid
    print("ok — Pi defaults, fresh install, settings preservation, idempotence, invalid-input safety")


if __name__ == "__main__":
    main()
