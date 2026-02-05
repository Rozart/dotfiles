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
            { "<leader>ss", false }, -- use namu instead
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
          -- Monorepo markers first to avoid multiple instances
          root_markers = {
            "nx.json",
            "pnpm-workspace.yaml",
            "eslint.config.ts",
            "eslint.config.js",
            "eslint.config.mjs",
            ".eslintrc.js",
            ".eslintrc.json",
          },
          -- Client-side debounce (Neovim 10+ uses pull diagnostics, bypassing server settings)
          flags = {
            debounce_text_changes = 1000, -- wait 1s after typing stops
          },
          settings = {
            -- "location" mode uses nearest eslint.config as working directory
            workingDirectories = { mode = "location" },
            -- Enable experimental flat config support
            experimental = {
              useFlatConfig = true,
            },
            -- Caching options
            options = {
              cache = true,
              cacheLocation = "node_modules/.cache/eslint-lsp",
            },
          },
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
          -- Monorepo markers first, then standard markers (order matters!)
          root_markers = {
            "nx.json",
            "pnpm-workspace.yaml",
            "tsconfig.base.json",
            "tsconfig.json",
            "package.json",
            ".git",
          },
          settings = {
            vtsls = {
              experimental = {
                autoUseWorkspaceTsdk = true,
                completion = {
                  enableServerSideFuzzyMatch = true,
                  entriesLimit = 50,
                },
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
        },
        oxfmt = {
          cmd = { "oxfmt", "--lsp" },
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
            "json",
            "jsonc",
            "yaml",
            "toml",
            "html",
            "htmlangular",
            "vue",
            "css",
            "scss",
            "less",
            "markdown",
            "mdx",
            "graphql",
            "handlebars",
          },
          root_markers = {
            "nx.json",
            "pnpm-workspace.yaml",
            ".oxfmtrc.json",
            "package.json",
            ".git",
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
