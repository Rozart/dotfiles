return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        solidity = {
          cmd = {
            "nomicfoundation-solidity-language-server",
            "--stdio",
          },
          filetypes = { "solidity" },
          root_dir = require("lspconfig").util.find_git_ancestor,
          single_file_support = true,
        },
        gopls = {
          gofumpt = true,
        },
      },
    },
  },
}
