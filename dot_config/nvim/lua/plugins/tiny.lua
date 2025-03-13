return {
  -- {
  --   "rachartier/tiny-code-action.nvim",
  --   event = "LspAttach",
  --   dependencies = {
  --     { "nvim-lua/plenary.nvim" },
  --     { "nvim-telescope/telescope.nvim" },
  --   },
  --   opts = {
  --     backend = "vim",
  -- telescope_opts = {
  --   layout_strategy = "horizontal",
  --   layout_config = {
  --     width = 0.6,
  --     preview_width = 0.6,
  --   },
  -- },
  --   },
  --   config = function(_, opts)
  --     require("tiny-code-action").setup(opts)
  --   end,
  -- },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    priority = 2000,
    event = "LspAttach", -- Or `LspAttach`
    config = function()
      vim.diagnostic.config({ virtual_text = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics
      -- Hack if you want to override the highlights
      require("tiny-inline-diagnostic.highlights").setup_highlights = function() end
      require("tiny-inline-diagnostic").setup({
        preset = "powerline",
        options = {
          use_icons_from_diagnostic = true,
        },
      })
    end,
  },
}
