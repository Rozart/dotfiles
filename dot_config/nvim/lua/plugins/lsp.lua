return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.diagnostic.config({ virtual_text = false })
    end,
    opts = {
      servers = {
        ["*"] = {
          keys = {
            {
              "<leader>ca",
              function()
                require("actions-preview").code_actions()
              end,
              desc = "Source action [tiny]",
            },
            {
              "<leader>cA",
              function()
                require("actions-preview").code_actions({ context = { only = { "source" } } })
              end,
              desc = "Source action [tiny]",
            },
          },
        },
        eslint = {
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
            "vue",
            "svelte",
            "astro",
            "htmlangular",
            "json",
            "jsonc",
          },
        },
        vtsls = {
          settings = {
            typescript = {},
          },
          experimental = {
            autoUseWorkspaceTsdk = true,
            completion = {
              enableServerSideFuzzyMatch = true,
              entriesLimit = 50,
            },
          },
          typescript = {
            tsserver = {
              maxTsServerMemory = 16384,
            },
            preferences = {
              includeCompletionsForModuleExports = true,
              includeCompletionsForImportStatements = true,
              importModuleSpecifier = "non-relative",
              importModuleSpecifierPreference = "non-relative",
              importModuleSpecifierEnding = "minimal",
              noErrorTruncation = true,
            },
            suggest = {
              includeCompletionsForModuleExports = true,
            },
          },
        },
        copilot = {},
        gopls = {
          gofumpt = true,
        },
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                typeCheckingMode = "standard",
              },
            },
          },
        },
      },
    },
  },
  {
    "aznhe21/actions-preview.nvim",
    opts = {
      telescope = {
        layout_strategy = "horizontal",
        layout_config = {
          width = 0.6,
          preview_width = 0.6,
        },
      },
    },
    config = function(_, opts)
      require("actions-preview").setup(opts)
    end,
  },
}
