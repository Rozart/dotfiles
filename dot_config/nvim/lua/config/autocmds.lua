-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Plugin highlight tuning, applied to every colourscheme we have a palette for
-- (see config/palettes.lua). Colourschemes without an entry are left alone.
local function apply_highlights()
    local palette = require("config.palettes").get()
    if not palette then
      return
    end

    -- (group, fg, bg, attrs, sp) — attrs is a comma-separated string, nil for none.
    local function set_hl(group, fg, bg, attrs, sp)
      local opts = { fg = fg, bg = bg, sp = sp }
      if attrs then
        for _, attr in ipairs(vim.split(attrs, ",")) do
          opts[attr] = true
        end
      end
      vim.api.nvim_set_hl(0, group, opts)
    end

    -- General adjustments of base highlights
    set_hl("Comment", palette.grey, nil, "italic")
    set_hl("@comment", palette.grey, nil)
    set_hl("LineNr", palette.grey, nil)
    set_hl("NormalFloat", palette.fg, nil)
    set_hl("FloatBorder", palette.grey, nil)
    set_hl("FloatTitle", palette.red, palette.bg0, "bold")

    set_hl("Italic", palette.fg, nil, "italic")
    set_hl("Bold", palette.fg, nil, "bold")
    set_hl("Visual", nil, palette.bg3)

    -- Custom highlights for Snacks
    set_hl("SnacksPickerListCursorLine", nil, palette.bg2, "bold")
    set_hl("SnacksPickerListCursorLineNC", nil, palette.bg_red, "bold")
    set_hl("SnacksPickerPreviewCursorLine", nil, palette.bg1)
    set_hl("SnacksPickerMatch", nil, palette.grey_dim)
    set_hl("SnacksPickerSearch", nil, palette.grey_dim)

    set_hl("SnacksPickerGitDetached", palette.orange, nil)
    set_hl("SnacksPickerGitStatusUnmerged", palette.red, nil)
    set_hl("SnacksPickerGitStatusModified", palette.orange, nil)

    set_hl("SnacksNotifierTitleWarn", palette.orange, nil)
    set_hl("SnacksNotifierTitleInfo", palette.blue, nil)
    set_hl("SnacksNotifierTitleError", palette.red, nil)
    set_hl("SnacksNotifierBorderWarn", palette.orange, nil)
    set_hl("SnacksNotifierBorderError", palette.red, nil)
    set_hl("SnacksNotifierBorderInfo", palette.blue, nil)

    -- Custom highlights for diagnostics
    set_hl("DiagnosticError", palette.red, palette.diff_red)
    set_hl("DiagnosticUnderlineError", nil, palette.diff_red, "undercurl", palette.red)
    set_hl("DiagnosticWarn", palette.orange, palette.diff_orange)
    set_hl("DiagnosticUnderlineWarn", nil, palette.diff_orange, "undercurl", palette.orange)
    set_hl("DiagnosticInfo", palette.blue, palette.diff_blue)
    set_hl("DiagnosticUnderlineInfo", nil, palette.diff_blue, "undercurl", palette.blue)
    set_hl("DiagnosticHint", palette.green, palette.diff_green)
    set_hl("DiagnosticUnderlineHint", nil, palette.diff_green, "undercurl", palette.green)

    -- Custom highlight for tiny-inline-diagnostic.nvim
    set_hl("TinyInlineDiagnosticVirtualTextWarn", palette.orange, palette.diff_orange, "italic")
    set_hl("TinyInlineDiagnosticVirtualTextError", palette.red, palette.diff_red, "italic")
    set_hl("TinyInlineDiagnosticVirtualTextInfo", palette.blue, palette.diff_blue, "italic")
    set_hl("TinyInlineDiagnosticVirtualTextHint", palette.green, palette.diff_green, "italic")

    set_hl("TinyInlineInvDiagnosticVirtualTextWarn", palette.diff_orange, nil, "italic")
    set_hl("TinyInlineInvDiagnosticVirtualTextError", palette.diff_red, nil, "italic")
    set_hl("TinyInlineInvDiagnosticVirtualTextInfo", palette.diff_blue, nil, "italic")
    set_hl("TinyInlineInvDiagnosticVirtualTextHint", palette.diff_green, nil, "italic")

    set_hl("TinyInlineDiagnosticVirtualTextArrow", palette.grey, nil, "bold")

    -- Custom highlight for blink.cmp
    set_hl("BlinkCmpMenu", nil, palette.bg0)
    set_hl("BlinkCmpMenuBorder", palette.green, nil)
    set_hl("BlinkCmpMenuSelection", palette.bg0, palette.yellow, "bold")
    set_hl("BlinkCmpDocBorder", palette.green, nil)
    set_hl("BlinkCmpDoc", nil, nil, "italic")
    set_hl("BlinkCmpDocSeparator", palette.green, nil)
    set_hl("BlinkCmpLabelDescription", palette.blue, nil, "italic")

    -- Custom highlight for telekasten.nvim
    set_hl("tkLink", palette.blue, nil, "undercurl,bold")
    set_hl("tkBrackets", palette.grey, nil)
    set_hl("tkHighlight", palette.bg2, palette.yellow, "bold")
    set_hl("tkTag", palette.purple, nil, "bold")
    set_hl("tkTagSep", palette.grey, nil)
    set_hl("tkAliasedLink", palette.orange, nil, "undercurl,bold")

    set_hl("BlinkIndent", palette.bg1, nil)

    -- Custom highlight for calendar-vim
    set_hl("CalNavi", palette.grey, nil)

    set_hl("IblScope", palette.purple, nil)

    -- Custom highlights for diffview.nvim
    -- Use green for additions instead of blue
    set_hl("DiffAdd", nil, palette.diff_green)
    set_hl("DiffChange", nil, palette.diff_yellow)
    set_hl("DiffDelete", nil, palette.diff_red)
    set_hl("DiffText", palette.bg0, palette.blue)

    -- Diffview specific highlights
    set_hl("DiffviewDiffAdd", nil, palette.diff_green)
    set_hl("DiffviewDiffAddAsDelete", nil, palette.diff_red)
    set_hl("DiffviewDiffChange", nil, palette.diff_green)
    set_hl("DiffviewDiffDelete", nil, palette.diff_red)
    set_hl("DiffviewDiffText", palette.bg0, palette.green)

    -- Custom highlights for namu.nvim
    set_hl("NamuNormal", palette.fg, palette.bg0)
    set_hl("NamuBorder", palette.green, nil)
    set_hl("NamuCursorLine", nil, palette.bg2, "bold")
    set_hl("NamuPreview", nil, palette.bg2)
    set_hl("NamuParent", palette.grey, nil)
    set_hl("NamuNested", palette.blue, nil)
    -- Symbol kind highlights
    set_hl("NamuFunction", palette.green, nil)
    set_hl("NamuMethod", palette.green, nil)
    set_hl("NamuClass", palette.yellow, nil)
    set_hl("NamuInterface", palette.blue, nil)
    set_hl("NamuVariable", palette.fg, nil)
    set_hl("NamuConstant", palette.purple, nil)
    set_hl("NamuProperty", palette.orange, nil)
    set_hl("NamuField", palette.orange, nil)
    set_hl("NamuModule", palette.blue, nil)
    set_hl("NamuEnum", palette.yellow, nil)
    set_hl("NamuStruct", palette.yellow, nil)
    set_hl("NamuTypeParameter", palette.blue, nil)
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("custom_highlights", {}),
  pattern = "*",
  callback = apply_highlights,
})

-- ...and once right now. LazyVim applies the colourscheme at the end of its
-- setup() but only loads this file on VeryLazy when nvim starts with no file
-- argument, so on a bare `nvim` the ColorScheme event has already fired by the
-- time we get here and the autocmd alone would never run.
apply_highlights()
