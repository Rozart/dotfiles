#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/palette.sh

state=$(system_profiler SPBluetoothDataType -json 2>/dev/null |
  jq -r '.SPBluetoothDataType[0] | "\(.controller_properties.controller_state) \([.device_connected[]?] | length)"')
read -r power connected <<< $state

if [[ $power != attrib_on ]]; then
  sketchybar --set $NAME icon=$'\U000f00b2' icon.color=$DIM label.drawing=off
elif (( connected > 0 )); then
  sketchybar --set $NAME icon=$'\U000f00b1' icon.color=$FG label.drawing=on label=$connected
else
  sketchybar --set $NAME icon=$'\U000f00af' icon.color=$FG label.drawing=off
fi
