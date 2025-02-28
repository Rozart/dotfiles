return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        separator_style = "thick",
        show_buffer_close_icons = false,
        indicator = {
          style = "none",
        },
        offsets = {
          {
            filetype = "snacks_layout_box",
            separator = true,
          },
        },
      },
      highlights = {
        fill = { bg = "#343136" },
        background = { bg = "#343136" },
        modified = { bg = "#343136" },
        diagnostic = { bg = "#343136" },
        error = { bg = "#343136" },
        error_diagnostic = { bg = "#343136" },
        warning = { bg = "#343136" },
        warning_diagnostic = { bg = "#343136" },
        info = { bg = "#343136" },
        info_diagnostic = { bg = "#343136" },
        hint = { bg = "#343136" },
        hint_diagnostic = { bg = "#343136" },
        close_button = { bg = "#343136" },
        buffer = { bg = "#343136" },
      },
    },
  },
}
