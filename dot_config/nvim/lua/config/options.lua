-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_picker = "snacks"
vim.opt.swapfile = false
vim.opt.spelllang = { "en", "pl" }
vim.o.termguicolors = true
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
vim.opt.title = true
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 0

-- Python specific settings
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"
-- vim.o.tabstop = 4
-- vim.o.shiftwidth = 4
