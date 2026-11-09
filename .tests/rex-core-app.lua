local source = assert(rex.args.source_session)
local destination = assert(rex.args.destination_session)
local block = assert(rex.args.source_block)
local observer = assert(rex.args.observer)
local pid = tostring(assert(rex.args.pid))
if rex.args.module then
  dofile(rex.args.module)
end

for _, session_id in ipairs({ source, destination }) do
  local result, err = rex.session.attach{ session_id = session_id }
  assert(result, err)
end

local checks = 0
local function expect_title(session_label, pane_title)
  checks = checks + 1
  local letter = pane_title:match("^parity%-pane%-(%u)$")
  if letter then
    pane_title = rex.args["title_" .. letter:lower()] or pane_title
  end
  local last = ""
  for attempt = 1, 15 do
    local result, err = rex.exec({ "swift", observer, "--pid", pid, "--session", session_label }, { timeout = 10 })
    assert(result, err)
    last = result.stdout ~= "" and result.stdout or result.stderr
    if result.ok and last:find(pane_title, 1, true) then
      return last:gsub("%s+$", "")
    end
    rex.sleep(0.15)
  end
  error("Title check " .. checks .. ": expected " .. pane_title .. "; observed " .. last)
end

local function invoke(name, args)
  local _, err = rex.invoke(name, args)
  assert(not err, err)
end

rex.client.queue("session.select", { session_id = source, window_id = rex.args.source_window })
expect_title(rex.args.source_label, "parity-pane-A")
for _, title in ipairs({ "B", "C", "D", "A" }) do
  rex.client.queue("pane.focus", { direction = "right" })
  expect_title(rex.args.source_label, "parity-pane-" .. title)
end
rex.client.queue("pane.focus_next")
expect_title(rex.args.source_label, "parity-pane-B")
rex.client.queue("pane.focus", { direction = "left" })
expect_title(rex.args.source_label, "parity-pane-A")

invoke("swap_pane", { direction = "next" })
expect_title(rex.args.source_label, "parity-pane-A")
rex.client.queue("pane.focus", { direction = "left" })
expect_title(rex.args.source_label, "parity-pane-B")
rex.client.queue("pane.focus", { direction = "right" })
expect_title(rex.args.source_label, "parity-pane-A")
invoke("swap_pane", { direction = "previous" })
invoke("rotate_panes", { direction = "previous" })
expect_title(rex.args.source_label, "parity-pane-A")
rex.client.queue("pane.focus", { direction = "left" })
expect_title(rex.args.source_label, "parity-pane-D")
rex.client.queue("pane.focus", { direction = "right" })
expect_title(rex.args.source_label, "parity-pane-A")
invoke("rotate_panes", { direction = "next" })
rex.client.queue("pane.focus", { direction = "right" })
expect_title(rex.args.source_label, "parity-pane-B")
rex.client.queue("pane.focus", { direction = "left" })
expect_title(rex.args.source_label, "parity-pane-A")

local vertical, vertical_err = rex.session.move_block{
  session_id = source,
  block_id = assert(rex.args.last_block),
  anchor_block_id = block,
  direction = "vertical",
  side = "after",
  ratio = 0.5,
}
assert(vertical, vertical_err)
expect_title(rex.args.source_label, "parity-pane-A")
rex.client.queue("pane.focus", { direction = "down" })
expect_title(rex.args.source_label, "parity-pane-D")
rex.client.queue("pane.focus", { direction = "up" })
expect_title(rex.args.source_label, "parity-pane-A")

rex.client.queue("session.next")
expect_title(rex.args.destination_label, "parity-pane-E")
rex.client.queue("session.previous")
expect_title(rex.args.source_label, "parity-pane-A")
rex.client.queue("pane.move_to_new_tab")
expect_title(rex.args.source_label, "parity-pane-A")
rex.sleep(0.2)
local view, err = rex.session.view{ session_id = source }
assert(view, err)
assert(#view.windows == 2, "Break-pane did not create another tab")
local moved = false
for _, window in ipairs(view.windows) do
  local blocks = window.layers[1].blocks
  if #blocks == 1 and blocks[1].block_id == block then
    moved = true
  end
end
assert(moved, "Break-pane did not preserve the selected block")
return { passed = true, directional_focus = true, pane_cycle = true, swap = true, rotation = true, session_cycle = true, break_pane = true }
