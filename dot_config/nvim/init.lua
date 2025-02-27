-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.o.encoding = "utf-8"
vim.o.fileencoding = "utf-8"

-- set highlights for telekasten.nvim that match the sonokai shusia theme
vim.api.nvim_set_hl(0, "tkLink", { fg = "#7accd7", bold = true, underline = true })
vim.api.nvim_set_hl(0, "tkBrackets", { fg = "#605d68" })
vim.api.nvim_set_hl(0, "tkHighlight", { fg = "#2d2a2e", bg = "#e5c463", bold = true })
vim.api.nvim_set_hl(0, "tkTag", { fg = "#ab9df2", bold = true })
vim.api.nvim_set_hl(0, "tkTagSep", { fg = "#848089" })
vim.api.nvim_set_hl(0, "tkAliasedLink", { fg = "#ef9062", bold = true, underline = true })

-- Make navigation buttons in the calendar less prominent
vim.api.nvim_set_hl(0, "CalNavi", { link = "tkBrackets" })
