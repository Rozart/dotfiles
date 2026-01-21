-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.o.encoding = "utf-8"
vim.o.fileencoding = "utf-8"

if vim.g.neovide then
  vim.o.guifont = "Pragmasevka Nerd Font:h11"
end

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
  },
}
