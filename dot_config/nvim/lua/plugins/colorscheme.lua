-- Active theme follows ~/.config/theme, written by the `theme` fish function,
-- so nvim, tmux and ghostty stay in step. Falls back to Sonokai Shusia when the
-- file is missing, which is what a fresh machine looks like before the first
-- `theme` call.
--
-- Per-theme highlight tuning lives in config/palettes.lua + config/autocmds.lua.

local themes = {
  ["sonokai-shusia"] = { colorscheme = "sonokai", background = "dark" },
  ["rose-pine-dawn"] = { colorscheme = "rose-pine-dawn", background = "light" },
  ["catppuccin-latte"] = { colorscheme = "catppuccin-latte", background = "light" },
  ["everforest-light"] = { colorscheme = "everforest", background = "light" },
  ["tokyonight-day"] = { colorscheme = "tokyonight-day", background = "light" },
}

local function active()
  local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/.config/theme"))
  local slug = ok and vim.trim(lines[1] or "") or ""
  return themes[slug] or themes["sonokai-shusia"]
end

local theme = active()
-- Must land before the colourscheme is applied; everforest and others read it.
vim.o.background = theme.background

return {
  {
    "rozart/sonokai",
    lazy = true,
    -- init, not config: under on-demand colourscheme loading `config` runs during
    -- the load triggered by ColorSchemePre, which is too late for these globals.
    init = function()
      vim.g.sonokai_enable_italic = 1
      vim.g.sonokai_transparent_background = vim.g.neovide and 0 or 1
      vim.g.sonokai_current_word = "high contrast background"
      vim.g.sonokai_diagnostic_line_highlight = 1
      vim.g.sonokai_diagnostic_text_highlight = 1
      vim.g.sonokai_menu_selection_background = "red"
      vim.g.sonokai_style = "shusia"
    end,
  },

  { "rose-pine/neovim", name = "rose-pine", lazy = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "folke/tokyonight.nvim", lazy = true },

  {
    "sainnhe/everforest",
    lazy = true,
    init = function()
      vim.g.everforest_background = "medium"
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_diagnostic_line_highlight = 1
      vim.g.everforest_diagnostic_text_highlight = 1
    end,
  },

  { "LazyVim/LazyVim", opts = { colorscheme = theme.colorscheme } },
}
