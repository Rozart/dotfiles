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
    opts = {
      auto_attach = true,
      servers = {
        "astro",
        "svelte",
        "ts_ls",
        "tsserver",
        "typescript-tools",
        "volar",
        "vtsls",
        "tsgo",
      },
    },
    config = function(_, opts)
      require("ts-error-translator").setup(opts)
    end,
  },
}
