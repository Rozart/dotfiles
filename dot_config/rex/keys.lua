local terminal = "com.superlogical.terminal"

local function current_directory(ctx)
  local process, err = rex.block.call(terminal, "process", {
    session_id = ctx.session_id,
    block_id = ctx.block_id,
  })
  assert(process, err)
  local foreground = process.foreground or process.child
  return foreground and foreground.cwd or process.home
end

rex.action{
  name = "new_tab_here",
  title = "New Tab in Current Directory",
  run = function(ctx)
    local result, err = rex.session.new_window{
      session_id = ctx.session_id,
      focus = true,
      layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        options = { cwd = current_directory(ctx) },
      },
    }
    assert(result, err)
    return result
  end,
}

rex.action{
  name = "split_here",
  title = "Split in Current Directory",
  args = { direction = "string" },
  run = function(ctx, args)
    assert(args.direction == "horizontal" or args.direction == "vertical")
    local result, err = rex.session.new_split{
      session_id = ctx.session_id,
      anchor_id = ctx.block_id,
      direction = args.direction,
      side = "after",
      focus = true,
      layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        options = { cwd = current_directory(ctx) },
      },
    }
    assert(result, err)
    return result
  end,
}

rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })
rex.bind("ctrl+a>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+a>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+a>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+a>l", "pane.focus", { direction = "right" })
rex.bind("ctrl+a>c", "new_tab_here")
rex.bind("ctrl+a>shift+'", "split_here", { direction = "vertical" })
rex.bind("ctrl+a>shift+5", "split_here", { direction = "horizontal" })
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")
rex.bind("ctrl+a>z", "pane.zoom")
rex.bind("ctrl+a>r", "client.config.reload")
rex.bind("ctrl+a>ctrl+space", "session.switch")
rex.bind("ctrl+a>s", "session.switch")
rex.bind("ctrl+a>g", "client.host.switch")
rex.bind("ctrl+a>w", "pane.go_to")
rex.bind("ctrl+a>,", "client.tab.rename")
rex.bind("ctrl+a>shift+4", "session.rename")

for index = 1, 9 do
  rex.bind("ctrl+a>" .. index, "client.tab.goto", { index = index })
end
