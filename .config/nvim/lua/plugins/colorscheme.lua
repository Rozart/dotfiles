return {
     {
          "loctvl842/monokai-pro.nvim",
          config = function()
               require("monokai-pro").setup({
                    -- transparent_background = true,
                    terminal_colors = false,
                    filter = "pro", -- Options: "classic", "octagon", "pro", "machine", "ristretto", "spectrum"
                    devicons = true,
                    styles = {
                         comment = { italic = true },
                         keyword = { italic = true }, -- any other keyword
                         type = { italic = true, bold = true }, -- (preferred) int, long, char, etc
                         storageclass = { italic = true }, -- static, register, volatile, etc
                         structure = { italic = true }, -- struct, union, enum, etc
                         parameter = { italic = true }, -- parameter pass in function
                         annotation = { italic = true },
                         tag_attribute = { italic = true }, -- attribute of tag in reactjs
                    },
               })

               -- Override highlight for indent lines
          end,
     },
     {
          "LazyVim/LazyVim",
          opts = {
               colorscheme = "monokai-pro",
          },
     },
}
