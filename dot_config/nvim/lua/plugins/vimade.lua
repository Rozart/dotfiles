local Snacks = require("snacks")

Snacks.toggle({
  name = "Vimade",
  get = function()
    return vim.g.vimade_running == 1
  end,
  set = function()
    vim.cmd("VimadeToggle")
  end,
}):map("<leader>uv")

Snacks.toggle({
  name = "Vimade Focus Mode",
  get = function()
    return vim.g.vimade_focus_active
  end,
  set = function()
    vim.cmd("VimadeFocus")
  end,
}):map("<leader>uV")

return {
  {
    "tadaa/vimade",
    event = "VeryLazy",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      recipe = { "default", { animate = false } },
      ncmode = "windows",
      fadelevel = 0.4, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
      -- Every colourscheme here is transparent, so Normal has no background for
      -- vimade to fade against. Resolved per window, so it tracks theme switches.
      basebg = function()
        local palette = require("config.palettes").get()
        return palette and palette.bg0 or nil
      end,
    },
    config = function(_, opts)
      require("vimade").setup(opts)
      vim.cmd("VimadeToggle")
    end,
  },
}
