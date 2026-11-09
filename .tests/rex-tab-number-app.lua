local source_session = assert(rex.args.source_session)
local source_window = assert(rex.args.source_window)
local destination_session = assert(rex.args.destination_session)
local index = assert(tonumber(rex.args.index))
local observer = assert(rex.args.observer)
local app_window = tostring(assert(rex.args.app_window))

for _, session_id in ipairs({ source_session, destination_session }) do
  local result, err = rex.session.attach{ session_id = session_id }
  assert(result, err)
end

local function select_source()
  rex.client.queue("session.select", { session_id = source_session, window_id = source_window })
  rex.sleep(0.3)
end

local function window_title()
  local result, err = rex.exec({ "swift", observer, app_window }, { timeout = 15 })
  assert(result, err)
  assert(result.ok, result.stderr)
  return result.stdout:gsub("%s+$", "")
end

select_source()
local source_title = window_title()
rex.client.queue("client.tab.goto", { index = index })
rex.sleep(0.3)
local expected = window_title()
assert(expected ~= source_title, "Native tab action did not select a different destination tab")
local destination, err = rex.session.view{ session_id = destination_session }
assert(destination, err)
assert(expected:find(destination.label, 1, true), "Native tab action did not cross sessions")
select_source()
assert(window_title() == source_title)

local execute = rex.exec
local answer = tostring(index)
rex.exec = function(argv, options)
  if argv[1] == "/usr/bin/osascript" then
    return { ok = true, stdout = answer, stderr = "" }
  end
  return execute(argv, options)
end
dofile(assert(rex.args.module))
local _, failure = rex.invoke("go_to_tab_number")
assert(not failure, failure)
rex.sleep(0.3)
assert(window_title() == expected, "Picker disagrees with native tab selection")
select_source()
answer = ""
local _, failure = rex.invoke("go_to_tab_number")
assert(not failure, failure)
assert(window_title() == source_title, "Cancel changed the visible source tab")
return {
  passed = true,
  index = index,
  native_window_title = expected,
  picker_window_title = expected,
  cancellation = true,
  dialog_input = "stubbed",
}
