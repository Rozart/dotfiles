local actions = {}
local view
local swaps
local focus
local failures
local ctx = { session_id = "session:remote", block_id = "b", client_id = "client:mac", server = "dev-station" }

local function leaves(node, result)
  result = result or {}
  if node.block_id then
    result[#result + 1] = node
  elseif node.split then
    leaves(node.split.before, result)
    leaves(node.split.after, result)
  end
  return result
end

local function reset(ids)
  local node = { block_id = ids[#ids] }
  for index = #ids - 1, 1, -1 do
    node = { split = { before = { block_id = ids[index] }, after = node } }
  end
  view = {
    active_window_id = "other-window",
    windows = {
      { window_id = "other-window", layers = { { kind = "tiled", layout = { block_id = "other" } } } },
      { window_id = "target-window", layers = {
        { kind = "tiled", layout = node },
        { kind = "floating", layout = { block_id = "floating" } },
      } },
    },
  }
  swaps = {}
  focus = nil
  failures = {}
  ctx.block_id = ids[1]
end

local function order()
  local ids = {}
  for _, node in ipairs(leaves(view.windows[2].layers[1].layout)) do
    ids[#ids + 1] = node.block_id
  end
  return table.concat(ids, ",")
end

rex = {
  action = function(action) actions[action.name] = action.run end,
  session = {
    view = function(args)
      assert(args.session_id == ctx.session_id)
      return view
    end,
    swap_blocks = function(args)
      assert(args.session_id == ctx.session_id)
      swaps[#swaps + 1] = args
      if failures[#swaps] then return nil, "swap failed" end
      local found = {}
      for _, window in ipairs(view.windows) do
        for _, layer in ipairs(window.layers) do
          for _, node in ipairs(leaves(layer.layout)) do
            found[node.block_id] = node
          end
        end
      end
      local first = assert(found[args.block_id])
      local second = assert(found[args.other_block_id])
      first.block_id, second.block_id = second.block_id, first.block_id
      return {}
    end,
    focus_block = function(args)
      assert(args.session_id == ctx.session_id)
      focus = args.block_id
      return {}
    end,
  },
}

dofile(arg[1])

reset({ "a", "b", "c" })
ctx.block_id = "b"
actions.swap_pane(ctx, { direction = "previous" })
assert(order() == "b,a,c")
assert(focus == "b")

reset({ "a", "b", "c" })
actions.swap_pane(ctx, { direction = "previous" })
assert(order() == "c,b,a")
assert(focus == "a")

reset({ "a", "b", "c" })
ctx.block_id = "c"
actions.swap_pane(ctx, { direction = "next" })
assert(order() == "c,b,a")

reset({ "a", "b", "c", "d" })
ctx.block_id = "b"
actions.rotate_panes(ctx, { direction = "previous" })
assert(order() == "b,c,d,a")
assert(focus == "b")
actions.rotate_panes(ctx, { direction = "next" })
assert(order() == "a,b,c,d")
assert(focus == "b")

reset({ "a" })
actions.swap_pane(ctx, { direction = "next" })
actions.rotate_panes(ctx, { direction = "next" })
assert(#swaps == 0)

reset({ "a", "b" })
ctx.block_id = "floating"
actions.swap_pane(ctx, { direction = "next" })
actions.rotate_panes(ctx, { direction = "next" })
assert(#swaps == 0)
assert(order() == "a,b")

reset({ "a", "b" })
ctx.block_id = "missing"
assert(not pcall(actions.swap_pane, ctx, { direction = "next" }))
assert(#swaps == 0)

reset({ "a", "b" })
assert(not pcall(actions.swap_pane, ctx, { direction = "invalid" }))
assert(not pcall(actions.rotate_panes, ctx, { direction = "invalid" }))
assert(#swaps == 0)

reset({ "a", "b", "c" })
failures[2] = true
local ok, err = pcall(actions.rotate_panes, ctx, { direction = "previous" })
assert(not ok and tostring(err):find("swap failed", 1, true))
assert(order() == "a,b,c")

reset({ "a", "b", "c" })
failures[2], failures[3] = true, true
local ok, err = pcall(actions.rotate_panes, ctx, { direction = "previous" })
assert(not ok and tostring(err):find("rollback failed", 1, true))

print("Pane swaps, rotations, focus, remote context, floating isolation, and rollback passed")
