return {
     "saghen/blink.cmp",
     opts = {
          completion = {
               documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 200,
               },
          },
          keymap = {
               -- Optionally, keep the default behavior for Ctrl+P and Ctrl+N
               ["<C-p>"] = { "select_prev", "fallback" },
               ["<C-n>"] = { "select_next", "fallback" },
               -- Enter to confirm selection
               ["<CR>"] = { "select_and_accept", "fallback" },
          },
     },
}
