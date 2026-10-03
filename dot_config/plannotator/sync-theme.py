import argparse
import json
import os
from pathlib import Path
import tempfile


def sync_theme(palette, mode):
    directory = Path(os.environ.get("PLANNOTATOR_DATA_DIR", Path.home() / ".plannotator"))
    target = directory / "config.json"
    config = json.loads(target.read_text()) if target.exists() else {}
    if not isinstance(config, dict):
        raise ValueError("Plannotator config must be a JSON object")
    theme = config.get("theme", {})
    if not isinstance(theme, dict):
        raise ValueError("Plannotator theme must be a JSON object")
    config["theme"] = {"light": "plannotator", "dark": "plannotator", **theme, "mode": mode, mode: palette}
    directory.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".config-", suffix=".json", dir=directory)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(config, output, indent=2)
            output.write("\n")
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", required=True)
    parser.add_argument("--mode", choices=["light", "dark"], required=True)
    args = parser.parse_args()
    sync_theme(args.palette, args.mode)


if __name__ == "__main__":
    main()
