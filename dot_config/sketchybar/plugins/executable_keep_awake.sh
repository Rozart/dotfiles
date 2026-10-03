#!/bin/zsh

source ${CONFIG_DIR:-$HOME/.config/sketchybar}/palette.sh

PIDFILE=${TMPDIR:-/tmp}/sketchybar-keep-awake.pid
pid=
[[ -r $PIDFILE ]] && pid=$(<$PIDFILE)

awake() {
  [[ -n $pid ]] && [[ $(ps -p $pid -o comm= 2>/dev/null) == caffeinate ]]
}

if [[ $1 == toggle ]]; then
  if awake; then
    kill $pid
    rm -f $PIDFILE
    pid=
  else
    caffeinate -dims &!
    pid=$!
    print $pid > $PIDFILE
  fi
fi

if awake; then
  sketchybar --set ${NAME:-keep_awake} icon=$'\U000f0176' icon.color=$ACCENT
else
  sketchybar --set ${NAME:-keep_awake} icon=$'\U000f06ca' icon.color=$DIM
fi
