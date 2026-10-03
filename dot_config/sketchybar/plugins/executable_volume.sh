#!/bin/zsh

volume=$INFO
[[ $SENDER == volume_change ]] || volume=$(osascript -e 'output volume of (get volume settings)')

if [[ $volume != <-> ]]; then
  sketchybar --set $NAME icon=$'\U000f057e' label.drawing=off
  exit 0
fi

if (( volume == 0 )); then
  icon=$'\U000f0581'
elif (( volume < 34 )); then
  icon=$'\U000f057f'
elif (( volume < 67 )); then
  icon=$'\U000f0580'
else
  icon=$'\U000f057e'
fi

sketchybar --set $NAME icon=$icon label.drawing=on label="$volume%"
