#!/bin/zsh

DB=$HOME/Library/DoNotDisturb/DB

mode=$(jq -r '.data[0].storeAssertionRecords[0].assertionDetails.assertionDetailsModeIdentifier // empty' $DB/Assertions.json 2>/dev/null)

if [[ -z $mode ]]; then
  sketchybar --set $NAME drawing=off
  exit 0
fi

name=$(jq -r --arg m $mode '.data[0].modeConfigurations[$m].mode.name // "Focus"' $DB/ModeConfigurations.json 2>/dev/null)

case $mode in
  *work*) icon=$'\U000f00d6' ;;
  *sleep*) icon=$'\U000f02e3' ;;
  *driving*) icon=$'\U000f010b' ;;
  *) icon=$'\U000f0594' ;;
esac

sketchybar --set $NAME drawing=on icon=$icon label="$name"
