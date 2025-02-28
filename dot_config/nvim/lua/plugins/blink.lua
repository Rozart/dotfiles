return {
  "saghen/blink.cmp",
  opts = {
    completion = {
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "single" },
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
}
