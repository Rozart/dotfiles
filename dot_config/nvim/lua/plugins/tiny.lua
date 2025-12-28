return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    priority = 2000,
    event = "LspAttach", -- Or `LspAttach`
    config = function()
      -- vim.diagnostic.config({ virtual_text = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics
      vim.diagnostic.config({ virtual_text = false, virtual_lines = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics
      -- Hack if you want to override the highlights
      require("tiny-inline-diagnostic.highlights").setup_highlights = function() end
      require("tiny-inline-diagnostic").setup({
        preset = "powerline",
        options = {
          show_source = {
            enabled = true,
          },
          use_icons_from_diagnostic = true,
        },
      })
    end,
  },
}
