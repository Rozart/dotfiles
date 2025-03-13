return {
  {
    "sainnhe/sonokai",
    config = function()
      vim.g.sonokai_enable_italic = 1
      vim.g.sonokai_disable_italic_comments = 1
      vim.g.sonokai_transparent_background = 1
      vim.g.sonokai_current_word = "high contrast background"
      vim.g.sonokai_diagnostic_line_highlight = 1
      vim.g.sonokai_diagnostic_text_highlight = 1
      vim.g.sonokai_menu_selection_background = "green"
      vim.g.sonokai_style = "shusia"

      vim.cmd("colorscheme sonokai")
    end,
  },
}
