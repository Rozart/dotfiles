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
    dependencies = { "folke/snacks.nvim" },
    opts = {
      recipe = { "default", { animate = false } },
      ncmode = "windows",
      fadelevel = 0.4, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
      basebg = "",
    },
    config = function(_, opts)
      require("vimade").setup(opts)
      vim.cmd("VimadeToggle")
    end,
  },
}
