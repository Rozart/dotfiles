return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>fz", "<Cmd>lua Snacks.picker.zoxide()<Cr>", mode = { "n" }, desc = "Open from Zoxide" },
    },
    opts = function()
      return {
        animate = {
          fps = 120,
        },
        picker = {
          matcher = {
            frecency = true,
          },
          sources = {
            explorer = {
              layout = {
                layout = { width = 60 },
              },
            },
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
          char = "│",
          enabled = true,
          only_current = true,
          only_scope = true,
          scope = {
            hl = {
              "RainbowLevel0",
              "RainbowLevel1",
              "RainbowLevel2",
              "RainbowLevel3",
              "RainbowLevel4",
              "RainbowLevel5",
              "RainbowLevel6",
              "RainbowLevel7",
              "RainbowLevel8",
            },
          },
        },
      }
    end,
  },
}
