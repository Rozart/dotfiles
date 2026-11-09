#!/bin/sh
set -eu

cd "$(dirname "$0")"
[ "$(uname -s)" = Darwin ] || { printf '%s\n' 'Rex Picker builds only on macOS.' >&2; exit 1; }
if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
    printf '%s\n' 'Rex Picker requires existing Xcode or Command Line Tools; install them before applying.' >&2
    exit 1
fi
command -v swift >/dev/null 2>&1 || { printf '%s\n' 'Rex Picker requires Swift 6 or newer.' >&2; exit 1; }
major=$(swift --version | awk '/Swift version/ { for (i = 1; i <= NF; i++) if ($i == "version") { split($(i + 1), version, "."); print version[1]; exit } }')
case "$major" in
    ''|*[!0-9]*) printf '%s\n' 'Cannot determine the Swift compiler version.' >&2; exit 1 ;;
esac
[ "$major" -ge 6 ] || { printf '%s\n' 'Rex Picker requires Swift 6 or newer.' >&2; exit 1; }

app="$HOME/Applications/Rex Picker.app"
if [ -e "$app" ] || [ -L "$app" ]; then
    if [ -L "$app" ] || [ ! -d "$app" ] || [ "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist" 2>/dev/null || true)" != dev.rozart.rex-picker ]; then
        printf '%s\n' "Refusing to replace an unmanaged path: $app" >&2
        exit 1
    fi
fi

swift build -c release
binary_dir=$(swift build -c release --show-bin-path)
[ -x "$binary_dir/RexPicker" ] || { printf '%s\n' 'The Rex Picker build produced no executable.' >&2; exit 1; }
mkdir -p "$HOME/Applications"
stage=$(mktemp -d "$HOME/Applications/.rex-picker-install.XXXXXX")
installed=no
cleanup() {
    if [ "$installed" = no ] && [ -d "$stage/previous.app" ]; then
        if [ -e "$app" ] || [ -L "$app" ] || ! mv "$stage/previous.app" "$app"; then
            printf 'Previous app preserved at %s\n' "$stage/previous.app" >&2
            return
        fi
    fi
    rm -rf "$stage"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$stage/Rex Picker.app/Contents/MacOS"
cp "$binary_dir/RexPicker" "$stage/Rex Picker.app/Contents/MacOS/RexPicker"
cp Info.plist "$stage/Rex Picker.app/Contents/Info.plist"
codesign --force --sign - "$stage/Rex Picker.app"
codesign --verify --strict "$stage/Rex Picker.app"

if [ -d "$app" ]; then
    mv "$app" "$stage/previous.app"
fi
if ! mv "$stage/Rex Picker.app" "$app"; then
    exit 1
fi
installed=yes
printf 'Installed %s\n' "$app"
printf '%s\n' 'If Rex Picker is running, quit and reopen it to use the new build.'
