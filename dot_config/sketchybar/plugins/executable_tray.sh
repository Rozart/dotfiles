#!/bin/zsh

CONFIG_DIR=${CONFIG_DIR:-$HOME/.config/sketchybar}
source $CONFIG_DIR/helpers/ax.sh

TRAY_APPS=(1Password Tailscale eqMac "Beeper Desktop" supersonic AeroSpace BetterDisplay "Google Drive" Nextcloud)
CACHE=${TMPDIR:-/tmp}/sketchybar-tray

refresh() {
  local procs=(${(f)"$(pgrep -ilx "${(j:|:)TRAY_APPS}")"})
  procs=(${(L)procs#* })
  local running=()
  for app in $TRAY_APPS; do
    (( ${procs[(Ie)${(L)app}]} )) && running+=("$app")
  done
  [[ -r $CACHE && $(<$CACHE) == ${(j:|:)running} ]] && return

  source $CONFIG_DIR/helpers/icon_map.sh
  sketchybar --remove '/tray\.app\..*/' >/dev/null 2>&1
  local args=() i=0
  for app in $running; do
    (( i++ ))
    __icon_map "$app"
    args+=(--add item tray.app.$i popup.tray
           --set tray.app.$i icon="$icon_result" icon.font="sketchybar-app-font:Regular:15.0"
             label="$app" click_script="$CONFIG_DIR/plugins/tray.sh open '$app'")
  done
  (( $#args )) && sketchybar $args
  print -r -- ${(j:|:)running} > $CACHE
}

open_extra() {
  sketchybar --set tray popup.drawing=off
  ax_press "tell application process \"$1\" to click menu bar item 1 of menu bar 2"
}

case $1 in
  toggle) sketchybar --set tray popup.drawing=toggle; refresh ;;
  open) open_extra "$2" ;;
  *)
    if [[ $SENDER == mouse.exited.global ]]; then
      sketchybar --set tray popup.drawing=off
    else
      [[ $SENDER == forced ]] && rm -f $CACHE
      refresh
    fi
    ;;
esac
