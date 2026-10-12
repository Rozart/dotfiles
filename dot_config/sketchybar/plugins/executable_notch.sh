#!/bin/zsh

heights=($(osascript -l JavaScript -e '
ObjC.import("AppKit");
var screens = $.NSScreen.screens, top = 0;
for (var i = 0; i < screens.count; i++) top = Math.max(top, screens.objectAtIndex(i).safeAreaInsets.top);
Math.round($.NSMenu.menuBarHeight) + " " + Math.round(top);' 2>/dev/null))

(( ${#heights} == 2 && heights[1] > 0 && heights[2] >= 0 )) || exit 0
sketchybar --bar height=$heights[1] notch_display_height=$heights[2]
