#!/bin/zsh

[[ $SENDER == privacy_change ]] || exit 0

entries=(${(s:, :)${${ATTRIBUTIONS#\[}%\]}})
entries=(${entries//\"/})

typeset -A apps
for entry in $entries; do
  kind=${entry%%:*}
  name=$(lsappinfo info -only name -app ${entry#*:} | head -1 | cut -d'"' -f2)
  apps[$kind]+="${apps[$kind]:+, }${name:-${entry#*:}}"
done

args=()
for kind in mic cam scr loc; do
  if [[ -n ${apps[$kind]} ]]; then
    args+=(--set privacy.$kind drawing=on label="${apps[$kind]}")
  else
    args+=(--set privacy.$kind drawing=off)
  fi
done

sketchybar $args
