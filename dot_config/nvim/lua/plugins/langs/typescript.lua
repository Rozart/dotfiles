-- local function find_tsconfig()
--   -- Try to find tsconfig.app.json first, then fall back to tsconfig.json
--   local configs = { "tsconfig.app.json", "tsconfig.lib.json", "tsconfig.json" }
--   for _, config in ipairs(configs) do
--     if vim.fn.filereadable(config) == 1 then
--       return config
--     end
--   end
--   return nil
-- end

return {
  {
    "dmmulroy/tsc.nvim",
    opts = {
      flags = {
        noEmit = true,
        -- project = find_tsconfig(),
        watch = true,
      },
      run_as_monorepo = true,
      use_diagnostics = true,
      max_tsconfig_files = 30,
      auto_open_qflist = true,
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
