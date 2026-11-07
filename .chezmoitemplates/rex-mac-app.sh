find_rex_app() {
    for candidate in "$HOME/Applications/Rex Beta.app" "$HOME/Applications/Rex.app" "/Applications/Rex Beta.app" "/Applications/Rex.app"; do
        if [ -e "$candidate" ] || [ -L "$candidate" ]; then
            if [ ! -f "$candidate/Contents/Info.plist" ] || [ ! -x "$candidate/Contents/MacOS/Rex" ]; then
                printf '%s\n' "Refusing conflicting Rex application path: $candidate" >&2
                return 2
            fi
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}
