return {
  {
    "b0o/incline.nvim",
    event = "VeryLazy",
    config = function()
      local helpers = require("incline.helpers")
      local devicons = require("nvim-web-devicons")
      local active_fg = "#e3e1e4"
      local inactive_fg = "#848089"
      local active_bg = "#605d68"
      local inactive_bg = "#37343a"

      require("incline").setup({
        window = {
          padding = 0,
          margin = { horizontal = 0 },
        },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          if filename == "" then
            filename = "[No Name]"
          end
          local ft_icon, ft_color = devicons.get_icon_color(filename)
          local modified = vim.bo[props.buf].modified

          local win_id = vim.fn.bufwinid(props.buf)
          local is_active = win_id == vim.api.nvim_get_current_win()

          return {
            ft_icon and { " ", ft_icon, "  ", guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or "",
            " ",
            { filename, gui = modified and "italic" or "" },
            " ",
            guifg = is_active and active_fg or inactive_fg,
            guibg = is_active and active_bg or inactive_bg,
          }
        end,
      })
    end,
  },
}
