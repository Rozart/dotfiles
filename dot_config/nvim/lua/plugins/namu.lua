return {
  {
    "bassamsdata/namu.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = "Namu",
    keys = {
      { "<leader>ss", "<cmd>Namu symbols<cr>", desc = "Namu symbols" },
    },
    opts = {
      namu_symbols = {
        options = {
          row_position = "top10",
          window = {
            auto_size = true,
            min_height = 1,
            max_height = 30,
            border = "rounded",
          },
          display = {
            format = "tree_guides",
            mode = "icon",
            padding = 2,
          },
          preview = {
            highlight_on_move = true,
          },
          movement = {
            next = { "<C-n>", "<Down>", "<Tab>" },
            previous = { "<C-p>", "<Up>", "<S-Tab>" },
            close = { "<Esc>", "q" },
            select = { "<CR>" },
          },
        },
      },
    },
  },
}
