-- Active theme follows ~/.config/theme, written by the `theme` fish function,
-- so nvim, tmux and ghostty stay in step. Falls back to Sonokai Shusia when the
-- file is missing, which is what a fresh machine looks like before the first
-- `theme` call.
--
-- Per-theme highlight tuning lives in config/palettes.lua + config/autocmds.lua.

-- The themes table lives in config/palettes.lua, not here: this file returns a
-- lazy.nvim spec array, so nothing can require the table back out of it — and
-- `theme` needs it at runtime to switch a live instance.

local palettes = require("config.palettes")
local theme = palettes.active()
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
      vim.g.sonokai_diagnostic_text_highlight = 1
      vim.g.sonokai_menu_selection_background = "red"
      vim.g.sonokai_style = theme.style
      -- empty_dict, not {}: an empty Lua table crosses into Vimscript as a List,
      -- and get_palette ends in extend(palette, override) — E712 on a List.
      vim.g.sonokai_colors_override = theme.overrides or vim.empty_dict()
    end,
  },

  -- opts, not init: lazy.nvim's ColorSchemePre handler loads the plugin (running
  -- setup()) before `:colorscheme` executes, so opts land in time. Only the
  -- Vimscript themes below need init to beat their own colors/ file.
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = { styles = { transparency = true } },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = { transparent_background = true },
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = {
      transparent = true,
      styles = { sidebars = "transparent", floats = "transparent" },
    },
  },

  {
    "sainnhe/everforest",
    lazy = true,
    init = function()
      vim.g.everforest_background = "medium"
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_transparent_background = 1
      -- Must be explicit: everforest defaults current_word to plain 'bold' as
      -- soon as transparent_background is set (autoload/everforest.vim).
      vim.g.everforest_current_word = "high contrast background"
      vim.g.everforest_diagnostic_text_highlight = 1
    end,
  },

  {
    "sainnhe/gruvbox-material",
    lazy = true,
    init = function()
      vim.g.gruvbox_material_background = "medium"
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_transparent_background = 1
      vim.g.gruvbox_material_current_word = "high contrast background"
      vim.g.gruvbox_material_diagnostic_text_highlight = 1
    end,
  },

  { "LazyVim/LazyVim", opts = { colorscheme = theme.colorscheme } },
}
