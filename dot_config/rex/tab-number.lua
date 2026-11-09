local dialog = [[
set deadline to (current date) + 25
set inputText to ""
set promptText to "Go to tab number (app-wide):"
try
  repeat
    set remaining to (deadline - (current date)) as integer
    if remaining < 1 then return ""
    set dialogReply to display dialog promptText default answer inputText buttons {"Cancel", "Go"} default button "Go" cancel button "Cancel" with title "Rex — Go to Tab" giving up after remaining
    if gave up of dialogReply then return ""
    set inputText to text returned of dialogReply
    set validNumber to (length of inputText > 0 and length of inputText ≤ 9)
    if validNumber then
      set codePoints to id of inputText
      if class of codePoints is integer then set codePoints to {codePoints}
      repeat with codePoint in codePoints
        if codePoint < 48 or codePoint > 57 then set validNumber to false
      end repeat
    end if
    if validNumber then
      if (inputText as integer) > 0 then return inputText
    end if
    set promptText to "Enter a positive tab number:"
  end repeat
on error number -128
  return ""
end try
]]

rex.action{
  name = "go_to_tab_number",
  title = "Go to Tab Number",
  run = function()
    local result, err = rex.exec({ "/usr/bin/osascript", "-e", dialog }, { timeout = 27 })
    assert(result, err)
    assert(result.ok, result.stderr)
    local input = result.stdout:match("^%s*(.-)%s*$")
    if input == "" then
      return
    end
    assert(input:match("^%d+$") and #input <= 9, "Invalid tab number")
    local index = tonumber(input)
    assert(index and index >= 1, "Invalid tab number")
    rex.client.queue("client.tab.goto", { index = index })
  end,
}

rex.bind("ctrl+a>'", "go_to_tab_number")
