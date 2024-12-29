-- lua/plugins/which-key.lua
return {
  "folke/which-key.nvim",
  opts = {
    icons = {
      rules = {
        { plugin = "copilot.lua", icon = " ", color = "orange" },
      },
    },
  },
}
