return {
  {
    "sainnhe/sonokai",
    config = function()
      vim.g.sonokai_enable_italic = 1
      vim.g.sonokai_disable_italic_comments = 1
      vim.g.sonokai_transparent_background = 1
      vim.g.sonokai_current_word = "high contrast background"
      vim.g.sonokai_diagnostic_virtual_text = "highlighted"
      vim.g.sonokai_menu_selection_background = "green"
      vim.g.sonokai_float_style = "dim"
      vim.g.sonokai_style = "shusia"
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "sonokai",
    },
  },
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    opts = {
      integrations = {
        blink_cmp = true,
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        snacks = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.groups.integrations.bufferline").get()
          end
        end,
      },
    },
  },
}
