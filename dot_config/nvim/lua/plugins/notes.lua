local dailies_folder = "notes/dailies/"
local zettelkasten_folder = "notes/zettelkasten/"

local base_path = vim.fn.expand("~/Documents/Rozart-Second-Brain/")

local templates_path = base_path .. "_templates"
local zettelkasten_path = base_path .. zettelkasten_folder
local dailies_path = base_path .. dailies_folder

return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        ["<leader>N"] = { name = "+Notes" },
      },
    },
  },
  -- Obsidian.nvim
  {
    "epwalsh/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    ft = "markdown",
    -- event = {
    --   "BufReadPre ~/Documents/Rozart-Second-Brain/*.md",
    --   "BufNewFile ~/Documents/Rozart-Second-Brain/*.md",
    -- },
    keys = {
      { "<leader>On", "<cmd>ObsidianNew<CR>", desc = "New Note" },
      { "<leader>Ot", "<cmd>ObsidianToday<CR>", desc = "Today's Daily Note" },
      { "<leader>Od", "<cmd>ObsidianDailies<CR>", desc = "Daily Notes" },
      { "<leader>Os", "<cmd>ObsidianSearch<CR>", desc = "Search Notes" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      daily_notes = {
        folder = dailies_folder,
      },
      workspaces = {
        {
          name = "personal",
          path = base_path,
        },
      },
    },
  },
  -- Telekasten.nvim
  {
    "nvim-telekasten/telekasten.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-telekasten/calendar-vim" },
    keys = {
      {
        mode = { "n" },
        "<leader>z",
        "<cmd>Telekasten panel<CR>",
        { desc = "Show Telekasten panel" },
      },
      { "<leader>zf", "<cmd>Telekasten find_notes<CR>", desc = "Find notes" },
      { "<leader>zg", "<cmd>Telekasten search_notes<CR>", desc = "Search notes" },
      { "<leader>zd", "<cmd>Telekasten goto_today<CR>", desc = "Go to today" },
      { "<leader>zz", "<cmd>Telekasten follow_link<CR>", desc = "Follow link" },
      {
        "<leader>zn",
        function()
          require("telekasten").new_note({ dir = zettelkasten_folder })
        end,
        desc = "New note",
      },
      { "<leader>zb", "<cmd>Telekasten show_backlinks<CR>", desc = "Show backlinks" },
      { "<leader>zI", "<cmd>Telekasten insert_img_link<CR>", desc = "Insert image link" },
      { "<leader>zr", "<cmd>Telekasten rename_note()<CR>", desc = "Rename note" },
      { "<leader>zp", "<cmd>Telekasten preview_img()<CR>", desc = "Preview image" },
      { "<leader>zm", "<cmd>Telekasten browse_media()<CR>", desc = "Browse media" },
      { "<leader>za", "<cmd>Telekasten show_tags()<CR>", desc = "Show tags" },
      { "<leader>zt", "<cmd>Telekasten toggle_todo({ i=true })<CR>", desc = "Toggle todo" },
    },
    opts = {
      extension = ".md",
      install_syntax = true,
      home = zettelkasten_path,
      dailies = dailies_path,
      template_new_daily = templates_path .. "daily.md",
      template_new_note = templates_path .. "note.md",
      journal_auto_open = true,
      auto_set_filepath = false,
    },
  },
}
