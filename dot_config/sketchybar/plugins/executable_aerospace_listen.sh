#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/helpers/singleton.sh
claim_token aerospace-listener

forward() {
  local event=$1
  if [[ $event != *'"mode-changed"'* ]]; then
    sketchybar --trigger aerospace_workspace_change
    return
  fi
  local mode=${${event#*\"mode\":\"}%%\"*}
  if [[ $mode == main ]]; then
    sketchybar --set aerospace_mode drawing=off
  else
    sketchybar --set aerospace_mode drawing=on label=${(U)mode}
  fi
}

while owns_token; do
  aerospace subscribe focused-workspace-changed focus-changed focused-monitor-changed window-detected mode-changed |
    while read -r event && owns_token; do
      forward $event || exit 0
    done
  owns_token || exit 0
  sleep 2
done
