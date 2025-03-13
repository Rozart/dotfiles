-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("custom_highlights_sonokai", {}),
  pattern = "sonokai",
  callback = function()
    local config = vim.fn["sonokai#get_configuration"]()
    local palette = vim.fn["sonokai#get_palette"](config.style, config.colors_override)
    local set_hl = vim.fn["sonokai#highlight"]

    local diff_orange = { "#604139", "54" }

    -- General adjustments of base highlights
    set_hl("NormalFloat", palette.fg, palette.none)
    set_hl("FloatBorder", palette.grey, palette.none)
    set_hl("FloatTitle", palette.red, palette.bg0, "bold")
    set_hl("Italic", palette.fg, palette.none, "italic")
    set_hl("Bold", palette.fg, palette.none, "bold")

    -- Custom highlights for Snacks
    set_hl("SnacksPickerListCursorLine", palette.none, palette.bg2, "bold")
    set_hl("SnacksPickerListCursorLineNC", palette.none, palette.bg_red, "bold")

    set_hl("SnacksPickerGitDetached", palette.orange, palette.none)
    set_hl("SnacksPickerGitStatusUnmerged", palette.red, palette.none)
    set_hl("SnacksPickerGitStatusModified", palette.orange, palette.none)

    set_hl("SnacksNotifierTitleWarn", palette.orange, palette.none)
    set_hl("SnacksNotifierTitleInfo", palette.blue, palette.none)
    set_hl("SnacksNotifierTitleError", palette.red, palette.none)
    set_hl("SnacksNotifierBorderWarn", palette.orange, palette.none)
    set_hl("SnacksNotifierBorderError", palette.red, palette.none)
    set_hl("SnacksNotifierBorderInfo", palette.blue, palette.none)

    -- Custom highlights for diagnostics
    set_hl("DiagnosticError", palette.red, palette.diff_red)
    set_hl("DiagnosticUnderlineError", palette.none, palette.diff_red, "undercurl", palette.red)
    set_hl("DiagnosticWarn", palette.orange, diff_orange)
    set_hl("DiagnosticUnderlineWarn", palette.none, diff_orange, "undercurl", palette.orange)
    set_hl("DiagnosticInfo", palette.blue, palette.diff_blue)
    set_hl("DiagnosticUnderlineInfo", palette.none, palette.diff_blue, "undercurl", palette.blue)
    set_hl("DiagnosticHint", palette.green, palette.diff_green)
    set_hl("DiagnosticUnderlineHint", palette.none, palette.diff_green, "undercurl", palette.green)

    -- Custom highlight for tiny-inline-diagnostic.nvim
    set_hl("TinyInlineDiagnosticVirtualTextWarn", palette.orange, diff_orange, "italic")
    set_hl("TinyInlineDiagnosticVirtualTextError", palette.red, palette.diff_red, "italic")
    set_hl("TinyInlineDiagnosticVirtualTextInfo", palette.blue, palette.diff_blue, "italic")
    set_hl("TinyInlineDiagnosticVirtualTextHint", palette.green, palette.diff_green, "italic")

    set_hl("TinyInlineInvDiagnosticVirtualTextWarn", diff_orange, palette.none, "italic")
    set_hl("TinyInlineInvDiagnosticVirtualTextError", palette.diff_red, palette.none, "italic")
    set_hl("TinyInlineInvDiagnosticVirtualTextInfo", palette.diff_blue, palette.none, "italic")
    set_hl("TinyInlineInvDiagnosticVirtualTextHint", palette.diff_green, palette.none, "italic")

    set_hl("TinyInlineDiagnosticVirtualTextArrow", palette.bg4, palette.none, "bold")

    -- Custom highlight for blink.cmp
    set_hl("BlinkCmpMenu", palette.none, palette.none)
    set_hl("BlinkCmpMenuSelection", palette.bg0, palette.bg_green, "bold")
    set_hl("BlinkCmpDocBorder", palette.green, palette.none)
    set_hl("BlinkCmpDoc", palette.none, palette.none, "italic")
    set_hl("BlinkCmpDocSeparator", palette.green, palette.none)
    set_hl("BlinkCmpLabelDescription", palette.blue, palette.none, "italic")

    -- Custom highlight for telekasten.nvim
    set_hl("tkLink", palette.blue, palette.none, "undercurl,bold")
    set_hl("tkBrackets", palette.grey, palette.none)
    set_hl("tkHighlight", palette.bg2, palette.yellow, "bold")
    set_hl("tkTag", palette.purple, palette.none, "bold")
    set_hl("tkTagSep", palette.grey, palette.none)
    set_hl("tkAliasedLink", palette.orange, palette.none, "undercurl,bold")

    -- Custom highlight for calendar-vim
    set_hl("CalNavi", palette.grey, palette.none)
  end,
})
