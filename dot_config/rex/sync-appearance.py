import argparse
import copy
import ctypes
import datetime
import json
import math
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import uuid


DOMAIN = "com.superlogical.rex"
BUILD = "1853"
THEMES_KEY = "Workspace.customThemes"
PREFERENCE_TYPES = {
    "Workspace.activePaneBorderColor": str,
    "Workspace.activePaneBorderTransition": str,
    "Workspace.animationStyle": str,
    "Workspace.appIconVisibility": str,
    "Workspace.appearance": str,
    "Workspace.cursorShader": str,
    "Workspace.cursorShadersEnabled": bool,
    "Workspace.darkThemeID": str,
    "Workspace.experiments.usesNewQuickSwitcher": bool,
    "Workspace.inactivePaneFadeMode": str,
    "Workspace.interfaceStyle": str,
    "Workspace.lightThemeID": str,
    "Workspace.paneDensity": str,
    "Workspace.shellIconTheme": str,
    "Workspace.showsActivePaneBorder": bool,
    "Workspace.sidebarPosition": str,
    "Workspace.sidebarShowsActivity": bool,
    "Workspace.tabIconColorMode": str,
    "Workspace.tabIconCount": int,
    "Workspace.tabIconTintMode": str,
    "Workspace.tabStyle": str,
    "Workspace.tabsFillAvailableSpace": bool,
    "Workspace.terminalAllowsLigatures": bool,
    "Workspace.terminalCellHeightPercent": float,
    "Workspace.terminalCharacterSpacing": str,
    "Workspace.terminalCursorStyle": str,
    "Workspace.terminalCursorStyleForced": bool,
    "Workspace.terminalFontName": str,
    "Workspace.terminalFontPointSize": float,
    "Workspace.terminalFontSmoothing": bool,
    "Workspace.terminalPaddingColor": str,
    "Workspace.terminalSynthesizesMissingStyles": bool,
    "Workspace.terminalUseThemePalette": bool,
    "Workspace.terminalUsesBoldFace": bool,
    "Workspace.terminalUsesDisplayP3": bool,
    "Workspace.terminalUsesItalicFace": bool,
    "Workspace.usesStandardInactiveWindowPaneStyles": bool,
}


def run(arguments):
    result = subprocess.run(arguments, capture_output=True, timeout=20)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors="replace").strip() or f"Command failed: {arguments[0]}")
    return result.stdout


def preferences():
    return plistlib.loads(run(["defaults", "export", DOMAIN, "-"]))


def gui_running():
    result = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "Rex"], capture_output=True, timeout=5)
    if result.returncode not in {0, 1}:
        raise ValueError("Cannot determine whether the Rex GUI is running")
    return result.returncode == 0


def installed_font(name):
    core = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    text = ctypes.CDLL("/System/Library/Frameworks/CoreText.framework/CoreText")
    core.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
    core.CFStringCreateWithCString.restype = ctypes.c_void_p
    core.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long, ctypes.c_uint32]
    core.CFStringGetCString.restype = ctypes.c_bool
    core.CFRelease.argtypes = [ctypes.c_void_p]
    core.CFRelease.restype = None
    text.CTFontCreateWithName.argtypes = [ctypes.c_void_p, ctypes.c_double, ctypes.c_void_p]
    text.CTFontCreateWithName.restype = ctypes.c_void_p
    text.CTFontCopyFamilyName.argtypes = [ctypes.c_void_p]
    text.CTFontCopyFamilyName.restype = ctypes.c_void_p
    requested = font = family = None
    try:
        requested = core.CFStringCreateWithCString(None, name.encode(), 0x08000100)
        if not requested:
            return False
        font = text.CTFontCreateWithName(requested, 11.0, None)
        if not font:
            return False
        family = text.CTFontCopyFamilyName(font)
        buffer = ctypes.create_string_buffer(4096)
        return bool(family and core.CFStringGetCString(family, buffer, len(buffer), 0x08000100)
                    and buffer.value.decode().casefold() == name.casefold())
    finally:
        for value in (family, font, requested):
            if value:
                core.CFRelease(value)


def validate_themes(themes):
    if not isinstance(themes, list):
        raise ValueError("Unknown native custom-theme format; expected a list")
    identities = set()
    for theme in themes:
        if not isinstance(theme, dict):
            raise ValueError("Invalid native custom theme")
        identity = theme.get("id", "")
        if not isinstance(identity, str) or not identity.startswith("custom-"):
            raise ValueError("Invalid custom-theme identity")
        canonical = str(uuid.UUID(identity.removeprefix("custom-")))
        if canonical in identities:
            raise ValueError("Duplicate custom-theme identity")
        identities.add(canonical)
        if not isinstance(theme.get("name"), str) or not theme["name"] or theme.get("appearance") not in {"light", "dark"}:
            raise ValueError("Invalid custom-theme name or appearance")
        palette = theme.get("palette")
        if not isinstance(palette, dict) or not isinstance(palette.get("ansi"), list) or len(palette["ansi"]) != 16:
            raise ValueError("Invalid custom-theme palette")
        colors = list(palette["ansi"])
        for key in ("background", "foreground", "cursor", "cursorText", "selectionBackground", "selectionForeground"):
            colors.append(palette.get(key))
        for key in ("paletteBase", "paletteOverrides"):
            values = palette.get(key, {})
            if not isinstance(values, dict):
                raise ValueError("Invalid custom-theme palette map")
            colors.extend(values.values())
        for color in colors:
            if not isinstance(color, dict) or color.get("colorSpace") != "srgb":
                raise ValueError("Unsupported native theme color format")
            for channel in ("red", "green", "blue", "alpha"):
                value = color.get(channel)
                if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value) or not 0 <= value <= 1:
                    raise ValueError("Invalid native theme color channel")
    return themes


def validate_profile(config):
    if not isinstance(config, dict) or type(config.get("formatVersion")) is not int or config["formatVersion"] != 1:
        raise ValueError("Unknown managed appearance profile format")
    if config.get("build") != BUILD:
        raise ValueError(f"Appearance sync supports only reviewed build {BUILD}")
    values = config.get("preferences")
    if not isinstance(values, dict) or set(values) != set(PREFERENCE_TYPES):
        raise ValueError("Appearance profile must contain exactly the approved preference allowlist")
    for key, expected in PREFERENCE_TYPES.items():
        value = values[key]
        if expected is float:
            valid = type(value) in {int, float} and math.isfinite(value)
        else:
            valid = type(value) is expected
        if not valid or isinstance(value, str) and (not value or "\x00" in value or len(value) > 256):
            raise ValueError(f"Invalid appearance preference: {key}")
    if not 1 <= values["Workspace.terminalFontPointSize"] <= 200:
        raise ValueError("Invalid terminal font size")
    themes = validate_themes(config.get("themes"))
    if len(themes) != 2:
        raise ValueError("Appearance profile requires one light and one dark theme")
    for mode in ("light", "dark"):
        selected = values[f"Workspace.{mode}ThemeID"]
        if not any(theme["id"] == selected and theme["appearance"] == mode for theme in themes):
            raise ValueError(f"Managed {mode} theme selection is missing")


def desired_preferences(original, config):
    raw = original.get(THEMES_KEY)
    if raw is not None and not isinstance(raw, bytes):
        raise ValueError("Native custom themes are not Data; refusing to replace them")
    existing = validate_themes(json.loads(raw)) if raw is not None else []
    merged = copy.deepcopy(existing)
    indices = {theme["id"]: index for index, theme in enumerate(merged)}
    for desired in config["themes"]:
        if desired["id"] in indices:
            target = merged[indices[desired["id"]]]
            palette = dict(target["palette"], **copy.deepcopy(desired["palette"]))
            target.update(copy.deepcopy(desired))
            target["palette"] = palette
        else:
            if any(theme["id"].casefold() == desired["id"].casefold() for theme in merged):
                raise ValueError("Ambiguous custom-theme identity casing")
            merged.append(copy.deepcopy(desired))
    values = copy.deepcopy(config["preferences"])
    values[THEMES_KEY] = raw if existing == merged and raw is not None else json.dumps(merged, separators=(",", ":"), allow_nan=False).encode()
    return values


def snapshot(preferences_value, keys):
    return {key: {"present": key in preferences_value, **({"value": preferences_value[key]} if key in preferences_value else {})}
            for key in keys}


def same_snapshot(left, right):
    return plistlib.dumps(left, fmt=plistlib.FMT_BINARY) == plistlib.dumps(right, fmt=plistlib.FMT_BINARY)


def backup(original, state):
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    state.chmod(0o700)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = state / f"{stamp}-{uuid.uuid4().hex[:8]}.plist"
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        plistlib.dump({"domain": DOMAIN, "preferences": original}, stream)
    return path


def write_preference(key, value):
    kinds = {bool: "-bool", str: "-string", float: "-float", int: "-int", bytes: "-data"}
    encoded = value.hex() if isinstance(value, bytes) else str(value).lower() if isinstance(value, bool) else str(value)
    run(["defaults", "write", DOMAIN, key, kinds[type(value)], encoded])


def synchronize(config, app, state, check=False):
    validate_profile(config)
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if str(info.get("CFBundleVersion")) != BUILD or info.get("CFBundleIdentifier") != DOMAIN or info.get("CFBundleExecutable") != "Rex":
        raise ValueError(f"Appearance sync supports only Rex build {BUILD}; existing app is preserved")
    font = config["preferences"]["Workspace.terminalFontName"]
    if not installed_font(font):
        raise ValueError(f"Required font is not installed: {font}; install it and reapply. No font fallback or installation was performed")
    original = preferences()
    desired = desired_preferences(original, config)
    changed = [key for key, value in desired.items() if key not in original or type(original[key]) is not type(value) or original[key] != value]
    result = {"changed": False, "pending": bool(changed), "keys": changed}
    if not changed:
        return result
    if gui_running():
        return dict(result, reason="Rex is running; quit only the GUI yourself, reapply, then reopen it. Servers and sessions are not stopped")
    if check:
        return dict(result, reason="Check only; keep Rex closed during a changed apply")
    expected = snapshot(original, desired)
    if gui_running() or not same_snapshot(snapshot(preferences(), desired), expected):
        raise ValueError("Rex started or appearance preferences changed during discovery; reapply with Rex closed")
    saved = backup(expected, state)
    order = sorted(changed, key=lambda key: (key != THEMES_KEY, key in {"Workspace.lightThemeID", "Workspace.darkThemeID", "Workspace.appearance"}, key))
    try:
        for key in order:
            if gui_running() or not same_snapshot(snapshot(preferences(), desired), expected):
                raise ValueError("Rex started or appearance preferences changed during synchronization")
            write_preference(key, desired[key])
            expected[key] = {"present": True, "value": desired[key]}
            if not same_snapshot(snapshot(preferences(), desired), expected):
                raise ValueError(f"Appearance preferences did not retain the expected values after writing {key}")
    except (ValueError, OSError, subprocess.TimeoutExpired, plistlib.InvalidFileException) as error:
        raise ValueError(f"{error}; original appearance backup: {saved}. No automatic rollback or restart was attempted") from error
    return {"changed": True, "pending": False, "keys": changed, "backup": str(saved)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("appearance.json"))
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--state", type=Path, default=Path.home() / ".local/state/rex/appearance-backups")
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    try:
        if sys.platform != "darwin":
            raise ValueError("Native Rex appearance synchronization is macOS-only")
        result = synchronize(json.loads(arguments.config.read_text()), arguments.app, arguments.state, arguments.check)
    except (ValueError, KeyError, TypeError, OSError, subprocess.TimeoutExpired, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Rex appearance sync: {error}\n")
    print(json.dumps(result))
    if result.get("reason"):
        print(result["reason"])


if __name__ == "__main__":
    main()
