return {
     "telescope.nvim",
     dependencies = {
          {
               "nvim-telescope/telescope-fzf-native.nvim",
               build = "make",
          },
     },
     config = function(_, opts)
          local telescope = require("telescope")
          telescope.setup(opts)
          require("telescope").load_extension("fzf")
     end,
}
