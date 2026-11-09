local actions = {}
local bindings = {}
local queued = {}
local commands = {}
local response = { ok = true, stdout = "12\n", stderr = "" }

rex = {
  action = function(action)
    actions[action.name] = action.run
  end,
  bind = function(key, action)
    bindings[key] = action
  end,
  mode = function() end,
  session = setmetatable({}, {
    __index = function()
      return function() error("Remote session API must not be called by the client-local picker") end
    end,
  }),
  block = {
    call = function() error("Remote block API must not be called by the client-local picker") end,
  },
  layout = { block = function(args) return args end },
  exec = function(argv, options)
    commands[#commands + 1] = { argv = argv, options = options }
    assert(argv[1] == "/usr/bin/osascript")
    assert(argv[2] == "-e")
    assert(argv[3]:find("display dialog", 1, true))
    assert(argv[3]:find("25", 1, true))
    assert(options.timeout < 30)
    return response
  end,
  client = {
    queue = function(name, args)
      queued[#queued + 1] = { name = name, args = args }
    end,
  },
}

dofile(arg[1])
assert(bindings["ctrl+a>'"] == "go_to_tab_number")

for _, server in ipairs({ "local", "dev-station", "docker-host" }) do
  queued = {}
  actions.go_to_tab_number({ client_id = "client:mac", server = server, session_id = "session:remote" })
  assert(#queued == 1)
  assert(queued[1].name == "client.tab.goto")
  assert(queued[1].args.index == 12)
end

for _, input in ipairs({ "", "\n", "  " }) do
  queued = {}
  response.stdout = input
  actions.go_to_tab_number({ client_id = "client:mac", server = "dev-station" })
  assert(#queued == 0)
end

for _, input in ipairs({ "0", "abc", "-1", "1.5", "1234567890" }) do
  queued = {}
  response.stdout = input
  local ok = pcall(actions.go_to_tab_number, { client_id = "client:mac", server = "dev-station" })
  assert(not ok)
  assert(#queued == 0)
end

queued = {}
response = { ok = false, stdout = "", stderr = "Dialog failed" }
local ok, err = pcall(actions.go_to_tab_number, { server = "dev-station" })
assert(not ok and tostring(err):find("Dialog failed", 1, true))
assert(#queued == 0)

print("Client-local prompt, remote contexts, tab 12, cancellation, and invalid input passed")
