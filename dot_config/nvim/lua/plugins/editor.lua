return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
      fast_wrap = {
        check_comma = true,
      },
    },
    config = function(_, opts)
      require("nvim-autopairs").setup(opts)
    end,
  },
  {
    "echasnovski/mini.pairs",
    enabled = false,
  },
  {
    "catgoose/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup({
        filetypes = { "*" },
        user_default_options = {
          names = false,
        },
      })
    end,
  },
  -- {
  --   "stevearc/quicker.nvim",
  --   event = "FileType qf",
  --   opts = {},
  -- },
}
