#!/bin/zsh

CONFIG_DIR=${CONFIG_DIR:-$HOME/.config/sketchybar}
source $CONFIG_DIR/palette.sh
source $CONFIG_DIR/helpers/icon_map.sh

typeset -A icons
for entry in ${(f)"$(aerospace list-windows --all --format '%{workspace}|%{app-name}')"}; do
  ws=${entry%%|*}
  __icon_map "${entry#*|}"
  [[ " ${icons[$ws]} " == *" $icon_result "* ]] || icons[$ws]+=" $icon_result"
done

workspaces=(${(f)"$(aerospace list-workspaces --all --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}|%{workspace-is-focused}|%{workspace-is-visible}')"})

args=()
for line in $workspaces; do
  IFS='|' read -r sid display focused visible <<< $line
  apps=${icons[$sid]# }
  item=(--set space.$sid display=$display label="$apps" label.drawing=${${apps:+on}:-off})
  if [[ $focused == true ]]; then
    item+=(background.drawing=on background.color=$ACCENT icon.color=$ACCENT_FG label.color=$ACCENT_FG)
    args+=(--set front_app display=$display --set aerospace_mode display=$display)
  elif [[ $visible == true ]]; then
    item+=(background.drawing=on background.color=$SURFACE icon.color=$FG label.color=$FG)
  elif [[ -n $apps ]]; then
    item+=(background.drawing=off icon.color=$FG label.color=$FG)
  else
    item+=(background.drawing=off icon.color=$DIM label.color=$DIM)
  fi
  args+=($item)
done

sketchybar $args
