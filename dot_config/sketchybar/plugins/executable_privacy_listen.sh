#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/helpers/singleton.sh
claim_token privacy-listener

MARKER='Active activity attributions changed to'
PREDICATE="process == \"ControlCenter\" AND category == \"sensor-indicators\" AND eventMessage BEGINSWITH \"$MARKER\""

while owns_token; do
  /usr/bin/log stream --style compact --predicate $PREDICATE |
    while read -r line && owns_token; do
      [[ $line == *"$MARKER ["* ]] || continue
      sketchybar --trigger privacy_change ATTRIBUTIONS="${line##*$MARKER }" || exit 0
    done
  owns_token || exit 0
  sleep 2
done
