#!/bin/zsh

name=$(defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null |
  awk -F' = ' '/"KeyboardLayout Name"|"Input Mode"/ { gsub(/[";]/, "", $2); print $2; exit }')

case $name in
  "Polish"*) label=PL ;;
  "U.S."*|"ABC"*|"US"*) label=US ;;
  "British"*) label=GB ;;
  "German"*) label=DE ;;
  *) label=${(U)${name##*.}[1,2]} ;;
esac

sketchybar --set $NAME label="${label:-??}"
