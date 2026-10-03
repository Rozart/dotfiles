ax() {
  perl -e 'alarm shift; exec @ARGV' 4 osascript -e "$1" 2>/dev/null
}

ax_lines() {
  ax "set AppleScript's text item delimiters to linefeed
$1"
}

ax_press() {
  ax "tell application \"System Events\"
  ignoring application responses
    $1
  end ignoring
end tell" >/dev/null
}
