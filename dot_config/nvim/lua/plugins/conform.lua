return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["solidity "] = { "prettierd" },
        ["javascript"] = { "biome" },
        ["javascript.jsx"] = { "biome" },
        ["javascriptreact"] = { "biome" },
        ["typescript"] = { "biome" },
        ["typescript.tsx"] = { "biome" },
        ["typescriptreact"] = { "biome" },
        ["json"] = { "biome" },
        ["jsonc"] = { "biome" },
        ["python"] = { "isort", "ruff" },
      },
    },
  },
}
