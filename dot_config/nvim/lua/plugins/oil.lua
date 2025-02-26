return {
  "stevearc/oil.nvim",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>fo", "<cmd>Oil<CR>", desc = "Oil File Explorer" },
  },
  opts = {
    default_file_explorer = false,
    columns = {
      "icon",
      "size",
      "mtime",
    },
    delete_to_trash = true,
    view_options = {
      show_hidden = true,
    },
  },
}
