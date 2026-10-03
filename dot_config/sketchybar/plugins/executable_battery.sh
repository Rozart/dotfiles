#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/palette.sh

batt=$(pmset -g batt)
if [[ ! $batt =~ '([0-9]+)%' ]]; then
  sketchybar --set $NAME drawing=off
  exit 0
fi
percent=$match[1]

levels=($'\U000f0083' $'\U000f007a' $'\U000f007b' $'\U000f007c' $'\U000f007d'
        $'\U000f007e' $'\U000f007f' $'\U000f0080' $'\U000f0081' $'\U000f0082' $'\U000f0079')
icon=$levels[$(( percent / 10 + 1 ))]
color=$FG

if [[ $batt == *"'AC Power'"* ]]; then
  icon=$'\U000f0084'
elif (( percent < 20 )); then
  color=$ALERT
fi

sketchybar --set $NAME drawing=on icon=$icon icon.color=$color label="$percent%"
