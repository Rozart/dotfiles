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

local picker = io.open(os.getenv("HOME") .. "/Applications/Rex Picker.app/Contents/Info.plist", "r")
if picker then
  picker:close()
  require("fuzzy-picker")
else
  require("tab-number")
end
require("panes")
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })
rex.bind("ctrl+a>ctrl+b", "pane.send_key", { key = "ctrl+a" })
rex.bind("ctrl+a>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+a>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+a>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+a>l", "pane.focus", { direction = "right" })
rex.bind("ctrl+a>c", "new_tab_here")
rex.bind("ctrl+a>shift+c", "session.new")
rex.bind("ctrl+a>shift+9", "session.previous")
rex.bind("ctrl+a>shift+0", "session.next")
rex.bind("ctrl+a>shift+'", "split_here", { direction = "vertical" })
rex.bind("ctrl+a>shift+5", "split_here", { direction = "horizontal" })
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")
rex.bind("ctrl+a>o", "pane.focus_next")
rex.bind("ctrl+a>shift+1", "pane.move_to_new_tab")
rex.bind("ctrl+a>shift+t", "pane.rename")
rex.bind("ctrl+a>x", "pane.close")
rex.bind("ctrl+a>shift+7", "client.tab.close")
rex.bind("ctrl+a>z", "pane.zoom")
rex.bind("ctrl+a>shift+e", "pane.balance")
rex.bind("ctrl+a>[", "client.scroll.page_up")
rex.bind("ctrl+a>pageup", "client.scroll.page_up")
rex.bind("ctrl+a>]", "pane.paste")
rex.bind("ctrl+a>/", "client.find.open")
rex.bind("ctrl+a>y", "pane.copy")
rex.bind("ctrl+a>r", "client.config.reload")
rex.bind("ctrl+a>ctrl+space", "session.switch")
rex.bind("ctrl+a>s", "session.switch")
rex.bind("ctrl+a>g", "client.host.switch")
rex.bind("ctrl+a>f", "pane.go_to")
rex.bind("ctrl+a>w", "pane.go_to")
rex.bind("ctrl+a>,", "client.tab.rename")
rex.bind("ctrl+a>shift+4", "session.rename")

rex.bind("ctrl+a>shift+[", "swap_pane", { direction = "previous" })
rex.bind("ctrl+a>shift+]", "swap_pane", { direction = "next" })
rex.bind("ctrl+a>ctrl+o", "rotate_panes", { direction = "previous" })
rex.bind("ctrl+a>alt+o", "rotate_panes", { direction = "next" })

for _, direction in ipairs({ "left", "down", "up", "right" }) do
  rex.bind("ctrl+a>" .. direction, "pane.focus", { direction = direction })
  rex.bind("ctrl+a>ctrl+" .. direction, "pane.resize", { direction = direction, amount = 1 })
  rex.bind("ctrl+a>alt+" .. direction, "pane.resize", { direction = direction, amount = 5 })
end

for index = 1, 9 do
  rex.bind("ctrl+a>" .. index, "client.tab.goto", { index = index })
end
