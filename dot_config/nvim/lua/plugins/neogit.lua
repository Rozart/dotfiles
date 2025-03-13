return {
  {
    {
      "NeogitOrg/neogit",
      dependencies = {
        "nvim-lua/plenary.nvim", -- required
        "sindrets/diffview.nvim", -- optional - Diff integration
      },
      keys = {
        { "<leader>gg", "<cmd>Neogit<CR>", mode = { "n" }, desc = "Open Neogit (root)" },
        { "<leader>gG", "<cmd>Neogit cwd=<cwd><CR>", mode = { "n" }, desc = "Open Neogit (cwd)" },
      },
      opts = {
        integrations = {
          diffview = true,
        },
        graph_style = "kitty",
        kind = "split",
        auto_show_console = false,
        remember_settings = true,
        commit_editor = { kind = "split" },
        commit_select_view = { kind = "split" },
        log_view = { kind = "split" },
        rebase_editor = { kind = "split" },
        reflog_view = { kind = "split" },
        merge_editor = { kind = "split" },
        description_editor = { kind = "split" },
        tag_editor = { kind = "split" },
        preview_buffer = { kind = "split" },
        popup = { kind = "split" },
        auto_refresh = true,
        filewatcher = {
          interval = 1000,
          enabled = true,
        },
        commit_view = {
          kind = "split",
          verify_commit = vim.fn.executable("gpg") == 1,
        },
      },
    },
  },
}
