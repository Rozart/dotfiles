-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Override snacks picker symbol keymaps with namu
vim.keymap.set("n", "<leader>ss", "<cmd>Namu symbols<cr>", { desc = "Namu symbols" })
vim.keymap.set("n", "<leader>sS", "<cmd>Namu workspace<cr>", { desc = "Namu workspace symbols" })
