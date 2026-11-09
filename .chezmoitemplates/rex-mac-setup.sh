set -eu
umask 077

{{ includeTemplate "rex-mac-client.sh" . }}

state="$HOME/.local/state/rex"
mkdir -p "$state/tunnels" "$state/launch-agents"
chmod 700 "$state" "$state/tunnels"
domain="gui/$(id -u)"
{{ range .rex.hosts }}
name="dev.rozart.rex-{{ .label }}"
plist="$HOME/Library/LaunchAgents/$name.plist"
fingerprint=$(shasum -a 256 "$plist" "$HOME/.config/rex/ssh_config" "$HOME/.config/rex/ssh-tunnel.py" | shasum -a 256 | cut -d ' ' -f 1)
previous=$(cat "$state/launch-agents/$name.sha256" 2>/dev/null || true)
if [ "$fingerprint" != "$previous" ] || ! launchctl print "$domain/$name" >/dev/null 2>&1; then
    if launchctl print "$domain/$name" >/dev/null 2>&1; then
        launchctl bootout "$domain/$name"
    fi
    attempt=0
    until launchctl bootstrap "$domain" "$plist"; do
        attempt=$((attempt + 1))
        [ "$attempt" -lt 5 ] || exit 1
        sleep 1
    done
    printf '%s\n' "$fingerprint" > "$state/launch-agents/$name.sha256"
fi
{{ end }}
"$rex_command" config reload
printf '%s\n' "$configuration_revision" > "$state/managed-configuration.sha256"
