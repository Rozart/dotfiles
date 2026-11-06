set -eu
umask 077
unset REX_SERVER REX_SESSION REX_BLOCK REX_CLIENT
export REX_AUTOSTART=0

binary="$HOME/.local/bin/rex"
state="$HOME/.local/state/rex"
unit="$HOME/.config/systemd/user/rex.service"
version={{ .rex.version | quote }}
case "$(uname -m)" in
    x86_64) architecture=amd64; expected={{ .rex.arch.amd64.sha256 | quote }} ;;
    aarch64) architecture=arm64; expected={{ .rex.arch.arm64.sha256 | quote }} ;;
    *) echo "Unsupported Rex architecture" >&2; exit 1 ;;
esac

mkdir -p "$HOME/.local/bin" "$state"
chmod 700 "$state"
unit_hash=$(sha256sum "$unit" | cut -d ' ' -f 1)
restart=no

if [ -e "$binary" ]; then
    if [ ! -f "$state/managed-binary.sha256" ]; then
        echo "Refusing to replace an unmanaged Rex binary: $binary" >&2
        exit 1
    fi
    actual=$(sha256sum "$binary" | cut -d ' ' -f 1)
    [ "$actual" = "$(cat "$state/managed-binary.sha256")" ] || {
        echo "Managed Rex binary changed outside chezmoi" >&2
        exit 1
    }
fi

if systemctl --user is-active --quiet rex.service; then
    if [ ! -f "$state/managed-unit.sha256" ] ||
       [ "$unit_hash" != "$(cat "$state/managed-unit.sha256")" ] ||
       [ "$("$binary" version | head -n 1)" != "rex $version" ]; then
        sessions=$("$binary" whoami --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["session_count"])')
        [ "$sessions" = 0 ] || {
            echo "Rex has active sessions; approve and perform its restart separately" >&2
            exit 1
        }
        restart=yes
    fi
fi

temporary=$(mktemp -d "$state/setup.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

if [ ! -e "$binary" ] || [ "$("$binary" version | head -n 1)" != "rex $version" ]; then
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --max-time 180 \
        {{ printf "https://blob.superlogical.com/download/rex/%s/%s/rex-linux-" .rex.channel .rex.commit | quote }}"$architecture.tar.gz" \
        -o "$temporary/rex.tar.gz"
    printf '%s  %s\n' "$expected" "$temporary/rex.tar.gz" | sha256sum -c -
    tar -xzf "$temporary/rex.tar.gz" -C "$temporary" rex
    [ "$("$temporary/rex" version | head -n 1)" = "rex $version" ]
    install -m 755 "$temporary/rex" "$HOME/.local/bin/.rex-new"
    mv "$HOME/.local/bin/.rex-new" "$binary"
    sha256sum "$binary" | cut -d ' ' -f 1 > "$state/managed-binary.sha256"
fi

"$binary" config check
"$binary" terminfo show > "$temporary/xterm-rex"
tic -x -o "$HOME/.terminfo" "$temporary/xterm-rex"

user=$(id -un)
if [ "$(loginctl show-user "$user" -p Linger --value)" != yes ]; then
    if [ ! -e "$state/previous-linger" ]; then
        printf 'no\n' > "$state/previous-linger"
    fi
    if [ "$(id -u)" = 0 ]; then
        loginctl enable-linger "$user"
    else
        sudo -n loginctl enable-linger "$user"
    fi
fi

if [ "$restart" = yes ]; then
    systemctl --user stop rex.service
fi
systemctl --user daemon-reload
systemctl --user enable rex.service
systemctl --user start rex.service

ready=no
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if "$binary" whoami --json > "$temporary/identity.json" 2>/dev/null; then
        ready=yes
        break
    fi
    sleep 1
done
[ "$ready" = yes ] || { echo "Rex did not become ready" >&2; exit 1; }
"$binary" config reload
printf '%s\n' "$unit_hash" > "$state/managed-unit.sha256"
printf '%s\n' "$configuration_revision" > "$state/managed-configuration.sha256"
"$binary" version
systemctl --user is-active rex.service
