return {
     {
          "nvim-lualine/lualine.nvim",
          event = "VeryLazy",
          opts = function(_, opts)
               table.insert(opts.sections.lualine_c, {
                    function()
                         return table.insert(opts.sections.lualine_c, { "navic", collor_correction = "dynamic" })
                    end,
               })
          end,
     },
}
