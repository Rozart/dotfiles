return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = { "<leader>ca", false }
      keys[#keys + 1] = { "<leader>cA", false }
      vim.keymap.set("n", "<leader>ca", function()
        require("actions-preview").code_actions()
      end, { noremap = false, silent = true, desc = "Code action [tiny]" })
      vim.keymap.set("n", "<leader>cA", function()
        require("actions-preview").code_actions({ context = { only = { "source" } } })
      end, { noremap = true, silent = true, desc = "Source action [tiny]" })
      vim.diagnostic.config({ virtual_text = false })
    end,
    opts = {
      servers = {
        vtsls = {
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
          },
        },
        solidity = {
          cmd = {
            "nomicfoundation-solidity-language-server",
            "--stdio",
          },
          filetypes = { "solidity" },
          ---@diagnostic disable-next-line: deprecated
          root_dir = require("lspconfig").util.find_git_ancestor,
          single_file_support = true,
        },
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
  -- {
  --   "Chaitanyabsprip/fastaction.nvim",
  --   opts = {
  --     dismiss_keys = { "j", "k", "<c-c>", "q", "<Esc>" },
  --     keys = "asdfghlzxcvbnm",
  --   },
  --   config = function(_, opts)
  --     local fastaction = require("fastaction")
  --     fastaction.setup(opts)
  --     vim.keymap.set({ "n", "x" }, "<leader>ca", fastaction.code_action, { noremap = true, silent = true })
  --   end,
  -- },
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
  {
    "zeioth/garbage-day.nvim",
    dependencies = "neovim/nvim-lspconfig",
    event = "VeryLazy",
    opts = {},
  },
}
