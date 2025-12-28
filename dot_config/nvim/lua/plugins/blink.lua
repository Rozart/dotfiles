return {
  {
    "Kaiser-Yang/blink-cmp-git",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  { "fang2hou/blink-copilot", opts = {} },
  {
    "saghen/blink.cmp",
    dependencies = {
      "xzbdmw/colorful-menu.nvim",
      "rozart/sonokai",
      "fang2hou/blink-copilot",
    },
    opts = {
      sources = {
        default = { "copilot", "lsp", "git", "path", "snippets", "buffer" },
        providers = {
          copilot = {
            score_offset = 7,
            module = "blink-copilot",
            async = true,
            opts = {
              max_completions = 2,
            },
          },
          lsp = {
            score_offset = 5,
          },
          path = {
            score_offset = 1,
          },
          snippets = {
            score_offset = 6,
          },
          buffer = { score_offset = 4 },
          git = {
            score_offset = 4,
            module = "blink-cmp-git",
            name = "Git",
            enabled = function()
              return vim.tbl_contains({ "octo", "gitcommit", "markdown" }, vim.bo.filetype)
            end,
            opts = {},
          },
        },
      },
      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
      },
      cmdline = {
        completion = {
          menu = {
            auto_show = true,
          },
          ghost_text = {
            enabled = true,
          },
        },
        keymap = {
          preset = "inherit",
        },
      },
      completion = {
        ghost_text = {
          enabled = false,
          show_with_menu = false,
        },
        menu = {
          max_height = 30,
          min_width = 50,
          border = "single",
          draw = {
            columns = { { "label", gap = 2 }, { "kind_icon", "kind" }, { "source_name" } },
            components = {
              label = {
                width = { fill = true },
                text = require("colorful-menu").blink_components_text,
                highlight = require("colorful-menu").blink_components_highlight,
              },
              source_name = {
                width = { fill = true },
              },
            },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = {
            max_height = 40,
            border = "single",
          },
        },
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        trigger = {
          show_in_snippet = false,
        },
        list = {
          selection = {
            auto_insert = true,
          },
        },
      },
      keymap = {
        preset = "enter",
      },
    },
  },
}
