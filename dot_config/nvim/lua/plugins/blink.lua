return {
  { import = "lazyvim.plugins.extras.ai.copilot" },
  {
    "giuxtaposition/blink-cmp-copilot",
    enabled = false,
  },
  {
    "saghen/blink.cmp",
    dependencies = {
      "xzbdmw/colorful-menu.nvim",
      "rozart/sonokai",
      "fang2hou/blink-copilot",
    },
    opts = {
      sources = {
        providers = {
          copilot = {
            module = "blink-copilot",
          },
        },
      },
      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
      },
      completion = {
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
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
    },
  },
}
