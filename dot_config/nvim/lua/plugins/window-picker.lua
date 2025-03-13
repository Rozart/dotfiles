return {
  {
    "s1n7ax/nvim-window-picker",
    version = "2.*",
    opts = {
      hint = "floating-big-letter",
      show_prompt = false,
    },
    config = function(_, opts)
      local picker = require("window-picker")
      picker.setup(opts)

      vim.keymap.set("n", "<leader>wg", function()
        local picked_window_id = picker.pick_window() or vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(picked_window_id)
      end, { desc = "Pick a window" })
    end,
  },
}
