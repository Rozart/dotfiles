return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        actions = {},
      },
      -- picker = {
      --   layout = {
      --     preset = "default",
      --   },
      --   matcher = {
      --     frecency = true,
      --     history_bonus = true,
      --   },
      -- },
      zen = {
        toggles = {
          dim = false,
          git_signs = true,
        },
        win = {
          enter = true,
          fixbuf = false,
          minimal = false,
          width = 120,
          height = 0,
          backdrop = { transparent = true, blend = 80 },
          keys = { q = false },
          zindex = 40,
          wo = {
            winhighlight = "NormalFloat:Normal",
          },
          w = {
            snacks_main = true,
          },
        },
        zoom = {
          win = {
            enter = true,
            fixbuf = false,
            minimal = false,
            width = 120,
            height = 0,
            backdrop = { transparent = true, blend = 40 },
            keys = { q = false },
            zindex = 40,
            wo = {
              winhighlight = "NormalFloat:Normal",
            },
            w = {
              snacks_main = true,
            },
          },
        },
      },
    },
  },
}
