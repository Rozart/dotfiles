#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/palette.sh

iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
wifi=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/ { getline; print $2 }')

if [[ -z $iface ]]; then
  sketchybar --set $NAME icon=$'\U000f05aa' icon.color=$ALERT
elif [[ $iface == $wifi ]]; then
  sketchybar --set $NAME icon=$'\U000f05a9' icon.color=$FG
else
  sketchybar --set $NAME icon=$'\U000f0200' icon.color=$FG
fi
