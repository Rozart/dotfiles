return {
  "nvim-mini/mini.icons",
  lazy = true,
  opts = {
    file = {
      [".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
      ["devcontainer.json"] = { glyph = "", hl = "MiniIconsAzure" },
    },
    filetype = {
      dotenv = { glyph = "", hl = "MiniIconsYellow" },
    },
  },
  specs = {
    { "nvim-tree/nvim-web-devicons", enabled = false, optional = true },
  },
  init = function()
    package.preload["nvim-web-devicons"] = function()
      require("mini.icons").mock_nvim_web_devicons()
      return package.loaded["nvim-web-devicons"]
    end
  end,
}
