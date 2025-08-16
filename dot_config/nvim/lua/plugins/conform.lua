return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["solidity "] = { "prettierd" },
        ["javascript"] = { "biome", "prettierd" },
        ["javascript.jsx"] = { "biome", "prettierd" },
        ["javascriptreact"] = { "biome", "prettierd" },
        ["typescript"] = { "biome", "prettierd" },
        ["typescript.tsx"] = { "biome", "prettierd" },
        ["typescriptreact"] = { "biome", "prettierd" },
        ["json"] = { "biome", "prettierd" },
        ["jsonc"] = { "biome", "prettierd" },
        ["python"] = { "isort", "ruff" },
        ["astro"] = { "eslint", stop_after_first = true },
        ["html"] = { "biome", "prettierd", stop_after_first = true },
      },
    },
  },
}
