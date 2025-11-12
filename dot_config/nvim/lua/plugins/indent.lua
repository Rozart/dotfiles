return {
  {
    "nmac427/guess-indent.nvim",
    opts = {},
    config = function(_, opts)
      require("guess-indent").setup(opts)
    end,
  },
  {
    "saghen/blink.indent",
    opts = {
      static = {
        enabled = true,
      },
      scope = {
        highlights = {
          "RainbowLevel0",
          "RainbowLevel1",
          "RainbowLevel2",
          "RainbowLevel3",
          "RainbowLevel4",
          "RainbowLevel5",
          "RainbowLevel6",
          "RainbowLevel8",
          "RainbowLevel7",
        },
      },
    },
  },
}
