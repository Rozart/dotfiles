#!/bin/zsh

height=$(osascript -l JavaScript -e '
ObjC.import("AppKit");
var screens = $.NSScreen.screens, top = 0;
for (var i = 0; i < screens.count; i++) top = Math.max(top, screens.objectAtIndex(i).safeAreaInsets.top);
Math.round(top);' 2>/dev/null)

(( height > 0 )) && sketchybar --bar notch_display_height=$height
