return {
  {
    dir = vim.fn.expand("~/.config/nvim/lua/rozart"),
    config = function()
      require("rozart.braindump").setup()
      vim.keymap.set("n", "<leader>aT", "<Cmd>AddTodo<CR>", { desc = "Add TODO In Daily Note" })
      vim.keymap.set("n", "<leader>aB", "<Cmd>AddBraindump<CR>", { desc = "Add Braidump In Daily Note" })
      vim.keymap.set("n", "<leader>aJ", "<Cmd>AddJournal<CR>", { desc = "Add Journal In Daily Note" })
    end,
  },
}
