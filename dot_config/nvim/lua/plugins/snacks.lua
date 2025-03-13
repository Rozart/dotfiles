return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>fz", "<Cmd>lua Snacks.picker.zoxide()<Cr>", mode = { "n" }, desc = "Open from Zoxide" },
    },
    opts = {
      animate = {
        fps = 120,
      },
      picker = {
        matcher = {
          frecency = true,
        },
      },
      explorer = {
        git_status_open = true,
        actions = {},
        wo = {
          style = {
            winhighlight = "CursorLine:SnacksPickerListCursorLine",
          },
        },
      },
      zen = {
        toggles = {
          dim = false,
        },
        win = {
          backdrop = { transparent = true, blend = 40 },
          width = 0.5,
        },
        zindex = 40,
      },
      indent = {
        priority = 1,
        enabled = true,
        char = "│",
        only_current = true,
      },
    },
  },
}
