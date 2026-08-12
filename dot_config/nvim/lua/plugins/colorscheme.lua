-- Active theme follows ~/.config/theme, written by the `theme` fish function,
-- so nvim, tmux and ghostty stay in step. Falls back to Sonokai Shusia when the
-- file is missing, which is what a fresh machine looks like before the first
-- `theme` call.
--
-- Per-theme highlight tuning lives in config/palettes.lua + config/autocmds.lua.

-- Sonokai's own hikari style is unfinished upstream: its dict omits bg_purple
-- and filled_red/green/blue, which colors/sonokai.vim dereferences, so loading
-- it bare throws E716. This override supplies those keys and replaces the hues
-- with a light counterpart to Shusia — a warm mauve paper, accents darkened to
-- 3.5-4.9:1 against it. sonokai#get_palette() ends in extend(palette, override),
-- so config/palettes.lua picks the result up without a second copy.
local hikari = {
  black = { "#bfa5b7", "249" },
  bg_dim = { "#f1e3ec", "255" },
  bg0 = { "#f7ebf2", "255" },
  bg1 = { "#efdfe9", "254" },
  bg2 = { "#e7d4e0", "253" },
  bg3 = { "#dbc5d4", "252" },
  bg4 = { "#ccb3c4", "250" },
  bg_red = { "#f7c4d5", "224" },
  bg_yellow = { "#f7ddc0", "223" },
  bg_green = { "#d8eac5", "188" },
  bg_blue = { "#cae4f2", "189" },
  bg_purple = { "#dfcff1", "189" },
  diff_red = { "#f7cedc", "224" },
  diff_yellow = { "#f7e0c9", "224" },
  diff_green = { "#deeacd", "253" },
  diff_blue = { "#d3e5f2", "189" },
  filled_red = { "#ef2e62", "197" },
  filled_green = { "#4ea919", "70" },
  filled_blue = { "#0d7f9b", "30" },
  fg = { "#4a3f48", "238" },
  red = { "#ef2e62", "197" },
  orange = { "#eb510f", "166" },
  yellow = { "#d08d06", "172" },
  green = { "#4ea919", "70" },
  blue = { "#0d7f9b", "30" },
  purple = { "#7754e8", "98" },
  grey = { "#6c5f6a", "241" },
  grey_dim = { "#9d8d9a", "246" },
}

local themes = {
  ["sonokai-shusia"] = { colorscheme = "sonokai", background = "dark", style = "shusia" },
  ["sonokai-hikari"] = { colorscheme = "sonokai", background = "light", style = "hikari", overrides = hikari },
  ["rose-pine-dawn"] = { colorscheme = "rose-pine-dawn", background = "light" },
  ["catppuccin-latte"] = { colorscheme = "catppuccin-latte", background = "light" },
  ["everforest-light"] = { colorscheme = "everforest", background = "light" },
  ["tokyonight-day"] = { colorscheme = "tokyonight-day", background = "light" },
  ["gruvbox-material-dark"] = { colorscheme = "gruvbox-material", background = "dark" },
  ["gruvbox-material-light"] = { colorscheme = "gruvbox-material", background = "light" },
}

local theme = themes[require("config.palettes").slug()] or themes["sonokai-shusia"]
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
