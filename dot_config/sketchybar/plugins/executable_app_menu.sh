#!/bin/zsh

CONFIG_DIR=${CONFIG_DIR:-$HOME/.config/sketchybar}
source $CONFIG_DIR/helpers/ax.sh

FRONT='first application process whose frontmost is true'

build() {
  local titles=(${(f)"$(ax_lines "tell application \"System Events\" to tell ($FRONT) to get (name of every menu bar item of menu bar 1) as text")"})
  sketchybar --remove '/app_menu\..*/' >/dev/null 2>&1
  local args=() i=1
  for title in $titles[2,-1]; do
    (( i++ ))
    args+=(--add item app_menu.$i popup.front_app
           --set app_menu.$i icon.drawing=off label="$title"
             click_script="$CONFIG_DIR/plugins/app_menu.sh open $i")
  done
  (( $#args )) && sketchybar $args
}

open_menu() {
  sketchybar --set front_app popup.drawing=off
  ax_press "tell ($FRONT) to click menu bar item $1 of menu bar 1"
}

case $1 in
  build) build ;;
  open) open_menu $2 ;;
  *) sketchybar --set front_app popup.drawing=toggle ;;
esac
