return {
  {
    "MaximilianLloyd/tw-values.nvim",
    keys = {
      { "<Leader>cv", "<CMD>TWValues<CR>", desc = "Tailwind CSS values" },
    },
    opts = {
      show_unknown_classes = true, -- Shows the unknown classes popup
    },
  },
  {
    "dmmulroy/ts-error-translator.nvim",
    opts = {},
    config = function(_, opts)
      require("ts-error-translator").setup(opts)
    end,
  },
  {
    "artemave/workspace-diagnostics.nvim",
    dependencies = {
      "nvim-lspconfig",
    },
    opts = {},
    config = function()
      vim.keymap.set("n", "<leader>cW", function()
        for _, client in ipairs(vim.lsp.get_clients()) do
          if client.name ~= "copilot" then
            require("workspace-diagnostics").populate_workspace_diagnostics(client, 0)
          end
        end
      end, { desc = "Populate workspace diagnostics", noremap = true })
    end,
  },
}
