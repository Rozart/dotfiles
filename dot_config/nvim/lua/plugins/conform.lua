return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["solidity "] = { "prettierd" },
        ["javascript"] = { "prettierd" },
        ["javascript.jsx"] = { "prettierd" },
        ["javascriptreact"] = { "prettierd" },
        ["typescript"] = { "prettierd" },
        ["typescript.tsx"] = { "prettierd" },
        ["typescriptreact"] = { "prettierd" },
        ["json"] = { "prettierd" },
        ["jsonc"] = { "prettierd" },
        ["python"] = { "isort", "ruff" },
        ["astro"] = { "eslint", stop_after_first = true },
        ["html"] = { "prettierd", stop_after_first = true },
      },
    },
  },
}
