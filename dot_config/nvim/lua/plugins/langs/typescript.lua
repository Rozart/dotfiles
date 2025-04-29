return {
  {
    "dmmulroy/tsc.nvim",
    opts = {
      use_diagnostics = true,
      flags = {
        watch = true,
      },
    },
  },
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
}
