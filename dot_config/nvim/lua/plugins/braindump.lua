return {
  {
    dir = vim.fn.expand("~/.config/nvim/lua/rozart"),
    config = function()
      require("rozart.braindump").setup()
      vim.keymap.set("n", "<leader>aT", "<Cmd>AddTodo<CR>", { desc = "Add TODO In Daily Note" })
    end,
  },
}
