local picker = os.getenv("HOME") .. "/Applications/Rex Picker.app"
local installed = io.open(picker .. "/Contents/Info.plist", "r")

local function open_picker(mode)
  local result, err = rex.exec({ "/usr/bin/open", "-a", picker, "rex-picker://" .. mode }, { timeout = 5 })
  assert(result, err)
  assert(result.ok, result.stderr)
end

if installed then
  installed:close()

  rex.action{
    name = "open_numbered_tabs",
    title = "Preview Numbered Tabs",
    keywords = "tab number preview list switch jump",
    run = function()
      open_picker("tabs")
    end,
  }

  rex.bind("ctrl+a>'", "open_numbered_tabs")
end
