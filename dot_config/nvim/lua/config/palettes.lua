-- Palette roles shared by every colourscheme, consumed by the ColorScheme
-- autocmd in config/autocmds.lua.
--
-- The role names are Sonokai's, because that is where these overrides started:
--   bg0..bg4   base background, then increasing contrast against it.
--              On light themes bg0 is the lightest and bg4 the darkest — the
--              direction is "further from the base", not "darker".
--   bg_red     reddish surface (non-current picker cursorline)
--   diff_*     muted tinted surfaces for diffs and diagnostic backgrounds
--   grey       comments; grey_dim  fainter still
--
-- Sonokai is derived at runtime from its own API so Shusia stays pixel-identical
-- to what it was before this file existed. The light themes are literal, taken
-- from each theme's published palette.
--
-- Caveat: only Everforest publishes diff_* surfaces. For the other three light
-- themes the diff_*/bg_red values are hand-mixed tints of that theme's own
-- accent against its base — they are the one set of values here with no upstream
-- source. Adjust to taste.

local M = {}

M.palettes = {
  -- https://rosepinetheme.com/palette/ingredients/ (dawn)
  -- Keyed "rose-pine": the plugin sets colors_name to the family, not the
  -- variant, even when loaded via `:colorscheme rose-pine-dawn`. We only ever
  -- load dawn (see plugins/colorscheme.lua), so this is unambiguous.
  ["rose-pine"] = {
    fg = "#575279", -- text
    grey = "#797593", -- subtle
    grey_dim = "#9893a5", -- muted
    red = "#b4637a", -- love
    orange = "#d7827e", -- rose
    yellow = "#ea9d34", -- gold
    green = "#286983", -- pine
    blue = "#56949f", -- foam
    purple = "#907aa9", -- iris
    bg0 = "#faf4ed", -- base
    bg1 = "#f4ede8", -- highlight-low
    bg2 = "#f2e9e1", -- overlay
    bg3 = "#dfdad9", -- highlight-med
    bg4 = "#cecacd", -- highlight-high
    bg_red = "#eee0e2",
    diff_red = "#f5e0e2",
    diff_green = "#dfe8e6",
    diff_blue = "#dfe9ea",
    diff_yellow = "#f7ecd9",
    diff_orange = "#f7e5e0",
  },

  -- https://catppuccin.com/palette (latte)
  ["catppuccin-latte"] = {
    fg = "#4c4f69", -- text
    grey = "#6c6f85", -- subtext0
    grey_dim = "#9ca0b0", -- overlay0
    red = "#d20f39",
    orange = "#fe640b", -- peach
    yellow = "#df8e1d",
    green = "#40a02b",
    blue = "#1e66f5",
    purple = "#8839ef", -- mauve
    bg0 = "#eff1f5", -- base
    bg1 = "#e6e9ef", -- mantle
    bg2 = "#dce0e8", -- crust
    bg3 = "#ccd0da", -- surface0
    bg4 = "#bcc0cc", -- surface1
    bg_red = "#f2dde1",
    diff_red = "#f5dce1",
    diff_green = "#dfeddb",
    diff_blue = "#dbe4f7",
    diff_yellow = "#f5ebd8",
    diff_orange = "#fbe4d5",
  },

  -- sainnhe/everforest, light / medium. Ships bg_* surfaces directly.
  ["everforest"] = {
    fg = "#5c6a72",
    grey = "#939f91", -- grey1
    grey_dim = "#a6b0a0", -- grey0
    red = "#f85552",
    orange = "#f57d26",
    yellow = "#dfa000",
    green = "#8da101",
    blue = "#3a94c5",
    purple = "#df69ba",
    bg0 = "#fdf6e3",
    bg1 = "#f4f0d9",
    bg2 = "#efebd4",
    bg3 = "#e6e2cc",
    bg4 = "#e0dcc7",
    bg_red = "#ffe7de",
    diff_red = "#ffe7de",
    diff_green = "#f3f5d9",
    diff_blue = "#ecf5ed",
    diff_yellow = "#fef2d5",
    diff_orange = "#fdead3",
  },

  -- folke/tokyonight.nvim, day variant
  ["tokyonight-day"] = {
    fg = "#3760bf",
    grey = "#848cb5", -- comment
    grey_dim = "#a8aecb",
    red = "#f52a65",
    orange = "#b15c00",
    yellow = "#8c6c3e",
    green = "#587539",
    blue = "#2e7de9",
    purple = "#9854f1",
    bg0 = "#e1e2e7",
    bg1 = "#dcdde3",
    bg2 = "#d0d5e3", -- bg_dark
    bg3 = "#c4c8da", -- bg_highlight
    bg4 = "#b7c1e3", -- bg_visual
    bg_red = "#e5cad4",
    diff_red = "#e5cad4",
    diff_green = "#cfdcc8",
    diff_blue = "#cfd9ee",
    diff_yellow = "#e5dcc4",
    diff_orange = "#e8d8c4",
  },
}

-- Sonokai's API hands back { hex, term256 } pairs; we only want the hex.
local function sonokai_palette()
  local ok, config = pcall(vim.fn["sonokai#get_configuration"])
  if not ok then
    return nil
  end
  local p = vim.fn["sonokai#get_palette"](config.style, config.colors_override)
  local out = {}
  for _, role in ipairs({
    "fg",
    "grey",
    "grey_dim",
    "red",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
    "bg0",
    "bg1",
    "bg2",
    "bg3",
    "bg4",
    "bg_red",
    "diff_red",
    "diff_green",
    "diff_blue",
    "diff_yellow",
  }) do
    if p[role] then
      out[role] = p[role][1]
    end
  end
  -- Sonokai has no diff_orange; this was a local in autocmds.lua before.
  out.diff_orange = "#604139"
  return out
end

--- Palette for the active colourscheme, or nil if we have no tuning for it.
function M.get()
  local name = vim.g.colors_name
  if name == "sonokai" then
    return sonokai_palette()
  end
  return M.palettes[name]
end

return M
