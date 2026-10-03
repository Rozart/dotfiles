#!/bin/zsh

CONFIG_DIR=${CONFIG_DIR:-$HOME/.config/sketchybar}

case $SENDER in
  front_app_switched)
    source $CONFIG_DIR/helpers/icon_map.sh
    __icon_map "$INFO"
    sketchybar --set $NAME icon="$icon_result" label="$INFO" popup.drawing=off
    $CONFIG_DIR/plugins/app_menu.sh build &!
    ;;
  mouse.exited.global)
    sketchybar --set $NAME popup.drawing=off
    ;;
esac
