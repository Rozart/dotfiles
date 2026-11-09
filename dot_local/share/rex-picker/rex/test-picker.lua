local actions = {}
local bindings = { ["ctrl+a>'"] = "go_to_tab_number" }
local commands = {}
local installed = arg[2] == "installed"
local closed = false
local original_open = io.open

io.open = function(path, mode)
  if path:find("/Rex Picker.app/Contents/Info.plist", 1, true) then
    if installed then
      return { close = function() closed = true end }
    end
    return nil
  end
  return original_open(path, mode)
end

rex = {
  action = function(action) actions[action.name] = action.run end,
  bind = function(key, action) bindings[key] = action end,
  exec = function(argv, options)
    assert(argv[1] == "/usr/bin/open" and argv[2] == "-a")
    assert(argv[3] == os.getenv("HOME") .. "/Applications/Rex Picker.app")
    assert(options.timeout == 5)
    commands[#commands + 1] = argv[4]
    return { ok = true, stdout = "", stderr = "" }
  end,
}

dofile(arg[1])

if installed then
  assert(closed)
  assert(bindings["ctrl+a>f"] == nil)
  assert(actions.open_fuzzy_picker == nil)
  assert(bindings["ctrl+a>'"] == "open_numbered_tabs")
  for _, server in ipairs({ "local", "dev-station", "docker-host" }) do
    actions.open_numbered_tabs({ server = server })
    assert(commands[#commands] == "rex-picker://tabs")
  end
  rex.exec = function() return { ok = false, stderr = "Launch failed" } end
  local ok, err = pcall(actions.open_numbered_tabs)
  assert(not ok and tostring(err):find("Launch failed", 1, true))
else
  assert(next(actions) == nil)
  assert(bindings["ctrl+a>'"] == "go_to_tab_number")
  assert(bindings["ctrl+a>f"] == nil)
end

print("Picker bindings, local launch, mode URLs, fallback, and errors passed: " .. arg[2])
