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
-- Both sonokai styles are derived at runtime from the plugin's own API, so
-- Shusia stays pixel-identical to what it was before this file existed and
-- Hikari picks up the colours_override set in plugins/colorscheme.lua. The rest
-- are literal, taken from each theme's published palette.
--
-- Keyed by the slug in ~/.config/theme, not by vim.g.colors_name: the plugins
-- report a name they choose, and it collides — "sonokai" for both shusia and
-- hikari, "gruvbox-material" for both backgrounds, "rose-pine" for every variant.
--
-- Caveat: only Everforest publishes diff_* surfaces. For the other light themes
-- the diff_*/bg_red values are hand-mixed tints of that theme's own accent
-- against its base — they are the one set of values here with no upstream
-- source. Adjust to taste.

local M = {}

M.palettes = {
  -- https://rosepinetheme.com/palette/ingredients/ (dawn)
  ["rose-pine-dawn"] = {
    fg = "#575279", -- text
    grey = "#716d8b", -- subtle (darkened to WCAG AA ≥4.5:1 on bg0)
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
    grey = "#6a6d82", -- subtext0 (darkened to WCAG AA ≥4.5:1 on bg0)
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
  ["everforest-light"] = {
    fg = "#5c6a72",
    grey = "#687566", -- grey1 (darkened to WCAG AA ≥4.5:1 on bg0)
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
    grey = "#586293", -- comment (darkened to WCAG AA ≥4.5:1 on bg0)
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

  -- sainnhe/gruvbox-material, dark / medium. Literal rather than derived from
  -- gruvbox_material#get_palette(): its role names diverge far enough
  -- (fg0/fg1, grey0..2, aqua, bg1..bg9, no diff_*) that reuse becomes a
  -- mapping table.
  ["gruvbox-material-dark"] = {
    fg = "#d4be98", -- fg0
    grey = "#a89984", -- grey2
    grey_dim = "#7c6f64", -- grey1
    red = "#ea6962",
    orange = "#e78a4e",
    yellow = "#d8a657",
    green = "#a9b665",
    blue = "#7daea3",
    purple = "#d3869b",
    bg0 = "#282828",
    bg1 = "#32302f",
    bg2 = "#3c3836",
    bg3 = "#45403d",
    bg4 = "#5a524c",
    bg_red = "#4c3432",
    diff_red = "#3c2f2c",
    diff_green = "#34381b",
    diff_blue = "#0e363e",
    diff_yellow = "#4a3a1d",
    diff_orange = "#432e1e",
  },

  -- sainnhe/gruvbox-material, light / medium.
  ["gruvbox-material-light"] = {
    fg = "#654735", -- fg0
    grey = "#7c6f64", -- grey2 (darkened to WCAG AA ≥4.5:1 on bg0)
    grey_dim = "#a89984", -- grey1
    red = "#c14a4a",
    orange = "#c35e0a",
    yellow = "#b47109",
    green = "#6c782e",
    blue = "#45707a",
    purple = "#945e80",
    bg0 = "#fbf1c7",
    bg1 = "#f4e8be",
    bg2 = "#eee0b7",
    bg3 = "#e6d8ad",
    bg4 = "#ddccab",
    bg_red = "#f4d3c8",
    diff_red = "#f7dcc4",
    diff_green = "#e8e3bc",
    diff_blue = "#e0e7c4",
    diff_yellow = "#f7e3b4",
    diff_orange = "#f7dfc0",
  },
}

-- Sonokai has no diff_orange role, so the ColorScheme overrides need one mixed
-- against each style's own base.
local sonokai_diffs = {
  ["sonokai-shusia"] = { diff_orange = "#604139" },
  ["sonokai-hikari"] = { diff_orange = "#f9dbc9" },
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
  return out
end

--- Active theme slug, from the file the `theme` fish function writes.
function M.slug()
  local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/.config/theme"))
  local slug = ok and vim.trim(lines[1] or "") or ""
  return slug ~= "" and slug or "sonokai-shusia"
end

--- Palette for the active theme, or nil if we have no tuning for it.
function M.get()
  local slug = M.slug()
  local diffs = sonokai_diffs[slug]
  if diffs then
    local p = sonokai_palette()
    return p and vim.tbl_extend("force", p, diffs)
  end
  return M.palettes[slug]
end

-- Sonokai's own hikari style is unfinished upstream: its dict omits bg_purple
-- and filled_red/green/blue, which colors/sonokai.vim dereferences, so loading
-- it bare throws E716. This override supplies those keys and replaces the hues
-- with a light counterpart to Shusia — a warm sand paper, accents held at
-- S74-94 so they stay vivid on it.
-- sonokai#get_palette() ends in extend(palette, override), so sonokai_palette()
-- above picks the result up without a second copy.
local hikari = {
  black = { "#c5b6a0", "181" },
  bg_dim = { "#f4ece1", "255" },
  bg0 = { "#f9f2e9", "255" },
  bg1 = { "#f3eadd", "254" },
  bg2 = { "#ebe0d1", "253" },
  bg3 = { "#e0d4c2", "187" },
  bg4 = { "#d1c2ad", "181" },
  bg_red = { "#f8cacd", "224" },
  bg_yellow = { "#f9e3b9", "223" },
  bg_green = { "#daefbe", "193" },
  bg_blue = { "#cce9eb", "254" },
  bg_purple = { "#e1d5ea", "254" },
  diff_red = { "#f8d4d4", "224" },
  diff_yellow = { "#f9e5c2", "223" },
  diff_green = { "#dff0c6", "194" },
  diff_blue = { "#d5ebea", "254" },
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

--- Colourscheme, background and plugin style per slug. Lives here rather than in
--- plugins/colorscheme.lua because that file returns a lazy.nvim spec array and
--- nothing can require the table back out of it. Read at startup by the spec,
--- and by M.apply() when the theme changes under a running instance.
M.themes = {
  ["sonokai-shusia"] = { colorscheme = "sonokai", background = "dark", style = "shusia" },
  ["sonokai-hikari"] = { colorscheme = "sonokai", background = "light", style = "hikari", overrides = hikari },
  ["rose-pine-dawn"] = { colorscheme = "rose-pine-dawn", background = "light" },
  ["catppuccin-latte"] = { colorscheme = "catppuccin-latte", background = "light" },
  ["everforest-light"] = { colorscheme = "everforest", background = "light" },
  ["tokyonight-day"] = { colorscheme = "tokyonight-day", background = "light" },
  ["gruvbox-material-dark"] = { colorscheme = "gruvbox-material", background = "dark" },
  ["gruvbox-material-light"] = { colorscheme = "gruvbox-material", background = "light" },
}

--- Theme entry for the active slug, falling back to Shusia on an unknown one.
function M.active()
  return M.themes[M.slug()] or M.themes["sonokai-shusia"]
end

--- Re-read ~/.config/theme and switch this instance to it. Called over
--- --remote-expr by the `theme` fish function, and by hand as
---   :lua require("config.palettes").apply()
---
--- Only sonokai's style and override are slug-dependent — everforest's and
--- gruvbox-material's globals are constants, so their init functions keep them
--- and this never touches them. :colorscheme fires ColorScheme, which re-runs
--- the highlight overrides in config/autocmds.lua; M.get() reads the slug file
--- uncached, so those land on the new palette.
function M.apply()
  local t = M.active()
  -- Before :colorscheme, not after: everforest and gruvbox-material read it
  -- while loading.
  vim.o.background = t.background
  vim.g.sonokai_style = t.style
  vim.g.sonokai_colors_override = t.overrides or vim.empty_dict()
  vim.cmd.colorscheme(t.colorscheme)
end

return M
