#!/usr/bin/env bash

FONTS_HOME=$HOME/Library/Fonts/

if [ -d "$FONTS_HOME" ]; then
    for directory in */; do
        echo "Copying fonts from $directory into $FONTS_HOME"
        cp -R $directory. $FONTS_HOME/
    done
fi
