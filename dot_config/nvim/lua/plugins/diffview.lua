local Snacks = require("snacks")

Snacks.toggle({
  name = "Diffview",
  get = function()
    return next(require("diffview.lib").views) ~= nil
  end,
  set = function()
    if next(require("diffview.lib").views) == nil then
      vim.cmd("DiffviewOpen")
    else
      vim.cmd("DiffviewClose")
    end
  end,
}):map("<leader>gD")

return {
  {
    "sindrets/diffview.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>gH", "<cmd>DiffviewFileHistory --follow %<CR>", mode = { "n" }, desc = "Git File History" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_horizontal",
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
      keymaps = {
        view = {
          { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
        },
        file_panel = {
          { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
        },
        file__history_panel = {
          { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
        },
      },
    },
  },
}
