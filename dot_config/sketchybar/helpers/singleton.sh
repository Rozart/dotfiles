claim_token() {
  TOKEN=${TMPDIR:-/tmp}/sketchybar-$1
  print $$ > $TOKEN
}

owns_token() {
  [[ $(<$TOKEN) == $$ ]]
}
