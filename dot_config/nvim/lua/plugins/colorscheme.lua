return {
     {
          "sainnhe/sonokai",
          config = function()
               vim.g.sonokai_enable_italic = 1
               vim.g.sonokai_transparent_background = 1
               vim.g.sonokai_disable_italic_comments = 1
               vim.g.sonokai_current_word = "high contrast background"
               vim.g.sonokai_diagnostic_virtual_text = "highlighted"
               vim.g.sonokai_style = "shusia"
          end,
     },
     {
          "LazyVim/LazyVim",
          opts = {
               colorscheme = "sonokai",
          },
     },
}
