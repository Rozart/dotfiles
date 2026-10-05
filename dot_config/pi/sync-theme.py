import argparse
import json
import os
from pathlib import Path
import tempfile


THEME_NAME = "claude-system"


def generate_theme(source):
    base = source.get("base")
    if base not in {"light-ansi", "dark-ansi"}:
        raise ValueError("Claude theme must use light-ansi or dark-ansi")
    overrides = source.get("overrides", {})
    if not isinstance(overrides, dict):
        raise ValueError("Claude theme overrides must be an object")
    appearance = base.removesuffix("-ansi")
    accent = overrides.get("claude", 4)
    muted = overrides.get("subtle", overrides.get("inactive", 8))
    border = overrides.get("promptBorder", muted)
    surface = overrides.get("diffAddedDimmed", "")
    colors = {
        "accent": accent, "border": border, "borderAccent": accent,
        "borderMuted": border, "success": 2, "error": 1, "warning": 3,
        "muted": muted, "dim": overrides.get("inactive", muted), "text": "",
        "thinkingText": muted, "selectedBg": surface,
        "scrollbarTrack": surface, "scrollbarThumb": border,
        "searchMatchBg": surface, "searchMatchText": accent,
        "userMessageBg": surface, "userMessageText": "",
        "customMessageBg": surface, "customMessageText": muted,
        "customMessageLabel": overrides.get("permission", accent),
        "toolPendingBg": surface,
        "toolSuccessBg": overrides.get("diffAdded", surface),
        "toolErrorBg": overrides.get("diffRemoved", surface),
        "toolTitle": accent, "toolOutput": muted,
        "mdHeading": accent, "mdLink": overrides.get("professionalBlue", 4),
        "mdLinkUrl": muted, "mdCode": overrides.get("suggestion", 5),
        "mdCodeBlock": 2, "mdCodeBlockBorder": border,
        "mdQuote": muted, "mdQuoteBorder": border, "mdHr": border,
        "mdListBullet": accent, "toolDiffAdded": 2, "toolDiffRemoved": 1,
        "toolDiffContext": muted, "syntaxComment": muted,
        "syntaxKeyword": 5, "syntaxFunction": 4,
        "syntaxVariable": overrides.get("professionalBlue", 4),
        "syntaxString": 2, "syntaxNumber": 3, "syntaxType": 4,
        "syntaxOperator": muted, "syntaxPunctuation": muted,
        "thinkingOff": muted,
        "thinkingMinimal": overrides.get("inactiveShimmer", muted),
        "thinkingLow": overrides.get("claudeBlue_FOR_SYSTEM_SPINNER", accent),
        "thinkingMedium": accent,
        "thinkingHigh": overrides.get("permission", accent),
        "thinkingXhigh": overrides.get("autoAcceptShimmer", 5),
        "thinkingMax": overrides.get("warningShimmer", 3), "bashMode": 2,
    }
    return {"name": THEME_NAME, "appearance": appearance, "colors": colors}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.stem}-", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--agent-dir", type=Path, default=Path.home() / ".pi/agent")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        theme = generate_theme(json.loads(args.source.read_text()))
        settings_path = args.agent_dir / "settings.json"
        settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
        if not isinstance(settings, dict):
            raise ValueError("Pi settings must be an object")
        settings["theme"] = THEME_NAME
        if not args.check:
            write_json(args.agent_dir / "themes" / f"{THEME_NAME}.json", theme)
            write_json(settings_path, settings)
    except (OSError, ValueError, TypeError, AttributeError) as error:
        parser.exit(1, f"pi theme: {error}\n")


if __name__ == "__main__":
    main()
