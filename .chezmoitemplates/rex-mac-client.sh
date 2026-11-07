{{ includeTemplate "rex-mac-app.sh" . }}
app=$(find_rex_app) || {
    printf '%s\n' "Install Rex before applying its client configuration" >&2
    exit 1
}
if command -v rex >/dev/null 2>&1; then
    rex_command=rex
else
    rex_command="$app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
    [ -x "$rex_command" ] || {
        printf '%s\n' "No bundled Rex CLI at $rex_command" >&2
        exit 1
    }
fi
