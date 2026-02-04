return {
  {
    "axkirillov/hbac.nvim",
    event = "VeryLazy",
    opts = {
      autoclose = true,
      threshold = 5,
      close_buffers_with_windows = false,
    },
    keys = {
      {
        "<leader>bx",
        function()
          require("hbac").toggle_pin()
        end,
        desc = "Hbac toggle pin",
      },
      {
        "<leader>bX",
        function()
          require("hbac").close_unpinned()
        end,
        desc = "Hbac close unpinned",
      },
    },
  },
}
