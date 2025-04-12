local base_path = vim.fn.expand("~/Documents/Rozart-Second-Brain/data")

local dailies_path = base_path .. "/00_dailies"
local templates_path = base_path .. "/99_templates"

local images_dir = "98_images"

return {
  {
    dir = "~/Dev/nvim-picker-bridge",
    name = "picker_bridge",
    lazy = false,
    keys = {
      {
        "<leader>zT",
        function()
          local picker_bridge = require("picker_bridge")
          picker_bridge.picker({
            title = "Picker bridge",
            items = { "orange", "blue", "green", "red" },
          })
        end,
        desc = "Picker bridge",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>z", group = "+zettelkasten" },
      },
    },
  },
  -- Telekasten.nvim
  {
    "nvim-telekasten/telekasten.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>zf", "<cmd>Telekasten find_notes<CR>", desc = "Find notes" },
      { "<leader>zg", "<cmd>Telekasten search_notes<CR>", desc = "Grep notes" },
      { "<leader>zd", "<cmd>Telekasten goto_today<CR>", desc = "Go to today" },
      { "<leader>zz", "<cmd>Telekasten follow_link<CR>", desc = "Follow link" },
      { "<leader>zi", "<cmd>Telekasten insert_link<CR>", desc = "Insert link" },
      { "<leader>zy", "<cmd>Telekasten yank_notelink<CR>", desc = "Copy current note link" },
      { "<leader>zn", "<cmd>Telekasten new_note<CR>", desc = "New note" },
      { "<leader>zb", "<cmd>Telekasten show_backlinks<CR>", desc = "Show backlinks" },
      { "<leader>zI", "<cmd>Telekasten insert_img_link<CR>", desc = "Insert image link" },
      { "<leader>zr", "<cmd>Telekasten rename_note<CR>", desc = "Rename note" },
      { "<leader>zp", "<cmd>Telekasten preview_img<CR>", desc = "Preview image" },
      { "<leader>zm", "<cmd>Telekasten browse_media<CR>", desc = "Browse media" },
      { "<leader>za", "<cmd>Telekasten show_tags<CR>", desc = "Show tags" },
      { "<leader>zt", "<cmd>Telekasten toggle_todo({ i=true })<CR>", desc = "Toggle todo" },
    },
    opts = {
      extension = ".md",
      install_syntax = true,
      home = base_path,
      dailies = dailies_path,
      image_subdir = images_dir,
      templates = templates_path,
      template_new_daily = templates_path .. "/daily.md",
      template_new_note = templates_path .. "/note.md",
      journal_auto_open = true,
      auto_set_filepath = false,
      auto_set_filetype = false,
    },
  },
}
