#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/palette.sh

TAILSCALE=/Applications/Tailscale.app/Contents/MacOS/Tailscale
if [[ ! -x $TAILSCALE ]]; then
  sketchybar --set $NAME drawing=off
  exit 0
fi

read -r state exit_node <<< "$($TAILSCALE status --json 2>/dev/null |
  jq -r '[.BackendState // "Stopped", ([.Peer[]? | select(.ExitNode) | .HostName][0] // "")] | join(" ")')"

if [[ $state == Running ]]; then
  sketchybar --set $NAME drawing=on icon=$'\U000f0582' icon.color=$FG \
    label="$exit_node" label.drawing=${${exit_node:+on}:-off}
else
  sketchybar --set $NAME drawing=on icon=$'\U000f099e' icon.color=$DIM label.drawing=off
fi
