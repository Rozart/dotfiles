return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        ["python"] = { "isort", "ruff" },
        ["astro"] = { "eslint", stop_after_first = true },
      },
    },
  },
}
