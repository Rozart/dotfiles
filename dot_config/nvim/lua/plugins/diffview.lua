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

-- Help popup for merge keybindings
local function show_merge_help()
  local lines = {
    "┌───────────────────────────────────────────────┐",
    "│         Diffview Merge Keybindings           │",
    "├───────────────────────────────────────────────┤",
    "│  NAVIGATION                                  │",
    "│    ]x          Next conflict                 │",
    "│    [x          Previous conflict             │",
    "│    <Tab>       Next file                     │",
    "│    <S-Tab>     Previous file                 │",
    "├───────────────────────────────────────────────┤",
    "│  RESOLVE CONFLICT (cursor)     <leader>m    │",
    "│    <leader>mo  Choose OURS                   │",
    "│    <leader>mt  Choose THEIRS                 │",
    "│    <leader>mb  Choose BASE                   │",
    "│    <leader>ma  Choose ALL (ours+theirs)      │",
    "│    <leader>md  Delete conflict               │",
    "├───────────────────────────────────────────────┤",
    "│  RESOLVE WHOLE FILE            <leader>M    │",
    "│    <leader>MO  OURS for whole file           │",
    "│    <leader>MT  THEIRS for whole file         │",
    "│    <leader>MB  BASE for whole file           │",
    "│    <leader>MA  ALL for whole file            │",
    "│    <leader>MD  Delete all conflicts          │",
    "├───────────────────────────────────────────────┤",
    "│  OTHER                                       │",
    "│    <leader>mx  Cycle layout                  │",
    "│    g?          Show this help                │",
    "│    q           Close diffview                │",
    "└───────────────────────────────────────────────┘",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = 49
  local height = #lines
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2 - 2,
    style = "minimal",
    border = "rounded",
  })

  vim.wo[win].winblend = 0
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<esc>", "<cmd>close<cr>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "g?", "<cmd>close<cr>", { noremap = true, silent = true })
end

-- Diffview actions for keymaps
local function get_diffview_actions()
  return require("diffview.actions")
end

return {
  {
    "sindrets/diffview.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>gH", "<cmd>DiffviewFileHistory --follow %<CR>", mode = { "n" }, desc = "Git File History" },
    },
    opts = function()
      local actions = get_diffview_actions()
      return {
        enhanced_diff_hl = true,
        view = {
          default = {
            layout = "diff2_horizontal",
          },
          merge_tool = {
            disable_diagnostics = false,
            winbar_info = true,
            layout = "diff3_horizontal",
          },
          file_history = {
            layout = "diff2_horizontal",
          },
        },
        keymaps = {
          view = {
            { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
            { "n", "g?", show_merge_help, { desc = "Show merge help" } },
            -- Conflict navigation
            { "n", "]x", actions.next_conflict, { desc = "Next conflict" } },
            { "n", "[x", actions.prev_conflict, { desc = "Previous conflict" } },
            -- Single conflict resolution
            { "n", "<leader>mo", actions.conflict_choose("ours"), { desc = "Merge: choose OURS" } },
            { "n", "<leader>mt", actions.conflict_choose("theirs"), { desc = "Merge: choose THEIRS" } },
            { "n", "<leader>mb", actions.conflict_choose("base"), { desc = "Merge: choose BASE" } },
            { "n", "<leader>ma", actions.conflict_choose("all"), { desc = "Merge: choose ALL" } },
            { "n", "<leader>md", actions.conflict_choose("none"), { desc = "Merge: delete conflict" } },
            -- Whole file resolution
            { "n", "<leader>MO", actions.conflict_choose_all("ours"), { desc = "Merge: OURS (file)" } },
            { "n", "<leader>MT", actions.conflict_choose_all("theirs"), { desc = "Merge: THEIRS (file)" } },
            { "n", "<leader>MB", actions.conflict_choose_all("base"), { desc = "Merge: BASE (file)" } },
            { "n", "<leader>MA", actions.conflict_choose_all("all"), { desc = "Merge: ALL (file)" } },
            { "n", "<leader>MD", actions.conflict_choose_all("none"), { desc = "Merge: delete all conflicts" } },
            -- Layout
            { "n", "<leader>mx", actions.cycle_layout, { desc = "Merge: cycle layout" } },
          },
          diff3 = {
            { "n", "g?", show_merge_help, { desc = "Show merge help" } },
            { "n", "]x", actions.next_conflict, { desc = "Next conflict" } },
            { "n", "[x", actions.prev_conflict, { desc = "Previous conflict" } },
            { "n", "<leader>mo", actions.conflict_choose("ours"), { desc = "Merge: choose OURS" } },
            { "n", "<leader>mt", actions.conflict_choose("theirs"), { desc = "Merge: choose THEIRS" } },
            { "n", "<leader>mb", actions.conflict_choose("base"), { desc = "Merge: choose BASE" } },
            { "n", "<leader>ma", actions.conflict_choose("all"), { desc = "Merge: choose ALL" } },
            { "n", "<leader>md", actions.conflict_choose("none"), { desc = "Merge: delete conflict" } },
            { "n", "<leader>MO", actions.conflict_choose_all("ours"), { desc = "Merge: OURS (file)" } },
            { "n", "<leader>MT", actions.conflict_choose_all("theirs"), { desc = "Merge: THEIRS (file)" } },
            { "n", "<leader>MB", actions.conflict_choose_all("base"), { desc = "Merge: BASE (file)" } },
            { "n", "<leader>MA", actions.conflict_choose_all("all"), { desc = "Merge: ALL (file)" } },
            { "n", "<leader>MD", actions.conflict_choose_all("none"), { desc = "Merge: delete all conflicts" } },
            { "n", "<leader>mx", actions.cycle_layout, { desc = "Merge: cycle layout" } },
          },
          diff4 = {
            { "n", "g?", show_merge_help, { desc = "Show merge help" } },
            { "n", "]x", actions.next_conflict, { desc = "Next conflict" } },
            { "n", "[x", actions.prev_conflict, { desc = "Previous conflict" } },
            { "n", "<leader>mo", actions.conflict_choose("ours"), { desc = "Merge: choose OURS" } },
            { "n", "<leader>mt", actions.conflict_choose("theirs"), { desc = "Merge: choose THEIRS" } },
            { "n", "<leader>mb", actions.conflict_choose("base"), { desc = "Merge: choose BASE" } },
            { "n", "<leader>ma", actions.conflict_choose("all"), { desc = "Merge: choose ALL" } },
            { "n", "<leader>md", actions.conflict_choose("none"), { desc = "Merge: delete conflict" } },
            { "n", "<leader>MO", actions.conflict_choose_all("ours"), { desc = "Merge: OURS (file)" } },
            { "n", "<leader>MT", actions.conflict_choose_all("theirs"), { desc = "Merge: THEIRS (file)" } },
            { "n", "<leader>MB", actions.conflict_choose_all("base"), { desc = "Merge: BASE (file)" } },
            { "n", "<leader>MA", actions.conflict_choose_all("all"), { desc = "Merge: ALL (file)" } },
            { "n", "<leader>MD", actions.conflict_choose_all("none"), { desc = "Merge: delete all conflicts" } },
            { "n", "<leader>mx", actions.cycle_layout, { desc = "Merge: cycle layout" } },
          },
          file_panel = {
            { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
            { "n", "g?", show_merge_help, { desc = "Show merge help" } },
          },
          file_history_panel = {
            { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
            { "n", "g?", show_merge_help, { desc = "Show merge help" } },
          },
        },
      }
    end,
  },
}
