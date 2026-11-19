import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MODIFIER = ROOT / "dot_pi/agent/modify_settings.json"
MCP_MODIFIER = ROOT / "dot_pi/agent/modify_mcp.json"
DEFAULTS = {"defaultProvider": "openai", "defaultModel": "gpt-6.1-sol"}
PACKAGE = "https://github.com/earendil-works/pi-claude-code"
MANAGED = {**DEFAULTS, "packages": [PACKAGE]}


def main():
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        source = directory / "source"
        destination = directory / "home"
        modifier = source / "dot_pi/agent/modify_settings.json"
        modifier.parent.mkdir(parents=True)
        shutil.copyfile(MODIFIER, modifier)
        shutil.copyfile(MCP_MODIFIER, modifier.with_name("modify_mcp.json"))
        destination.mkdir()
        config = directory / "chezmoi.toml"
        config.write_text("")
        settings = destination / ".pi/agent/settings.json"
        mcp = destination / ".pi/agent/mcp.json"
        command = [
            "chezmoi", "--config", str(config), "--source", str(source),
            "--destination", str(destination), "--persistent-state", str(directory / "state.boltdb"),
            "apply",
        ]
        subprocess.run(command, check=True)
        assert json.loads(settings.read_text()) == MANAGED
        original = {
            "defaultProvider": "other", "defaultModel": "old", "deviceId": "local-device",
            "theme": "system", "hideThinkingBlock": True,
            "modelThinkingLevels": {"openai/gpt-6.1-sol": "high"},
        }
        settings.write_text(json.dumps(original))
        subprocess.run(command, check=True)
        assert json.loads(settings.read_text()) == {**original, **MANAGED}
        before = settings.read_bytes()
        subprocess.run(command, check=True)
        assert settings.read_bytes() == before
        other = {"source": "npm:other", "extensions": []}
        settings.write_text(json.dumps({**DEFAULTS, "packages": [other]}))
        subprocess.run(command, check=True)
        assert json.loads(settings.read_text())["packages"] == [other, PACKAGE]
        formatted = json.dumps({**original, **DEFAULTS, "packages": [{"source": PACKAGE}]}, separators=(",", ":"))
        settings.write_text(formatted)
        subprocess.run(command, check=True)
        assert settings.read_text() == formatted
        for invalid in ["{invalid", "[]", "null"]:
            settings.write_text(invalid)
            result = subprocess.run(command, capture_output=True)
            assert result.returncode != 0
            assert settings.read_text() == invalid
        settings.write_text(json.dumps(MANAGED))
        servers = json.loads(mcp.read_text())["mcpServers"]
        assert sorted(servers) == ["cadenza", "exa"]
        assert servers["exa"]["headers"] == {"x-api-key": "${EXA_API_KEY}"}
        local = {"mcpServers": {"exa": {"url": "https://local.example/mcp"}, "wiki": {"command": "wikimcp"}}}
        mcp.write_text(json.dumps(local))
        subprocess.run(command, check=True)
        merged = json.loads(mcp.read_text())["mcpServers"]
        assert merged == {**local["mcpServers"], "cadenza": servers["cadenza"]}
        before = mcp.read_bytes()
        subprocess.run(command, check=True)
        assert mcp.read_bytes() == before
        for invalid in ["{invalid", "[]", '{"mcpServers": []}']:
            mcp.write_text(invalid)
            result = subprocess.run(command, capture_output=True)
            assert result.returncode != 0
            assert mcp.read_text() == invalid
    print("ok — Pi defaults, packages, MCP servers, fresh install, preservation, idempotence, invalid-input safety")


if __name__ == "__main__":
    main()
