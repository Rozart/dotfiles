return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      ensure_installed = { "biome" },
      linters_by_ft = {
        css = { "biomejs" },
        javascript = { "biomejs" },
        typescript = { "biomejs" },
        javascriptreact = { "biomejs" },
        typescriptreact = { "biomejs" },
        json = { "biomejs" },
        jsonc = { "biomejs" },
        solidity = { "solhint" },
      },
    },
  },
}
