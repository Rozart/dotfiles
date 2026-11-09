local function collect(node, blocks)
  if not node then
    return
  end
  if node.block_id then
    blocks[#blocks + 1] = node.block_id
  elseif node.split then
    collect(node.split.before, blocks)
    collect(node.split.after, blocks)
  end
end

local function pane_order(ctx)
  local view, err = rex.session.view{ session_id = ctx.session_id }
  assert(view, err)
  for _, window in ipairs(view.windows) do
    for _, layer in ipairs(window.layers) do
      local blocks = {}
      collect(layer.layout, blocks)
      for index, block_id in ipairs(blocks) do
        if block_id == ctx.block_id then
          return blocks, index
        end
      end
    end
  end
  error("Focused pane is not in the session view")
end

local function swap(ctx, first, second)
  return rex.session.swap_blocks{
    session_id = ctx.session_id,
    block_id = first,
    other_block_id = second,
  }
end

local function restore_focus(ctx)
  local result, err = rex.session.focus_block{
    session_id = ctx.session_id,
    block_id = ctx.block_id,
  }
  assert(result, err)
  return result
end

local function direction_step(direction)
  assert(direction == "previous" or direction == "next", "Invalid pane direction")
  return direction == "previous" and -1 or 1
end

rex.action{
  name = "swap_pane",
  title = "Swap Pane",
  args = { direction = "string" },
  repeats = true,
  run = function(ctx, args)
    local step = direction_step(args.direction)
    local blocks, index = pane_order(ctx)
    if #blocks < 2 then
      return
    end
    local target = ((index - 1 + step) % #blocks) + 1
    local result, err = swap(ctx, ctx.block_id, blocks[target])
    assert(result, err)
    return restore_focus(ctx)
  end,
}

rex.action{
  name = "rotate_panes",
  title = "Rotate Panes",
  args = { direction = "string" },
  repeats = true,
  run = function(ctx, args)
    local step = direction_step(args.direction)
    local blocks = pane_order(ctx)
    if #blocks < 2 then
      return
    end
    local completed = {}
    local first, last, increment = 2, #blocks, 1
    if step == 1 then
      first, last, increment = #blocks, 2, -1
    end
    for index = first, last, increment do
      local result, err = swap(ctx, blocks[1], blocks[index])
      if not result then
        local restored = true
        for undo = #completed, 1, -1 do
          local reverted = swap(ctx, blocks[1], completed[undo])
          restored = reverted ~= nil and restored
        end
        error(tostring(err) .. (restored and "" or "; rollback failed"))
      end
      completed[#completed + 1] = blocks[index]
    end
    return restore_focus(ctx)
  end,
}
