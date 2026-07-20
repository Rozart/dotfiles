return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
      fast_wrap = {
        check_comma = true,
      },
    },
    config = function(_, opts)
      require("nvim-autopairs").setup(opts)
    end,
  },
  {
    "nvim-mini/mini.pairs",
    enabled = false,
  },
  {
    "nvim-mini/mini.hipatterns",
    event = "BufRead",
    config = function()
      local hi = require("mini.hipatterns")

      -- ponytail: inline — only used here
      local function hsl_to_hex(h, s, l)
        h, s, l = h / 360, s / 100, l / 100
        if s == 0 then
          local v = math.floor(l * 255 + 0.5)
          return string.format("#%02x%02x%02x", v, v, v)
        end
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        local function hue(t)
          if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
          if t < 1 / 6 then return p + (q - p) * 6 * t end
          if t < 1 / 2 then return q end
          if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
          return p
        end
        return string.format(
          "#%02x%02x%02x",
          math.floor(hue(h + 1 / 3) * 255 + 0.5),
          math.floor(hue(h) * 255 + 0.5),
          math.floor(hue(h - 1 / 3) * 255 + 0.5)
        )
      end

      hi.setup({
        highlighters = {
          -- bare HSL channels in CSS custom properties: --name: 0 4% 14%;
          css_hsl_var = {
            pattern = "%-%-[%w_%-]+%s*:%s*()%d+%s+%d+%%%s+%d+%%()",
            group = function(_, _, data)
              local h, s, l = data.full_match:match("(%d+)%s+(%d+)%%%s+(%d+)%%")
              if not h then return nil end
              return hi.compute_hex_color_group(
                hsl_to_hex(tonumber(h), tonumber(s), tonumber(l)), "bg"
              )
            end,
          },
        },
      })
    end,
  },
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufRead",
    config = function()
      require("colorizer").setup({
        filetypes = { "*" },
        user_default_options = {
          names = false,   -- keep named colours (blue, red) off
          css_fn = true,   -- hsl(), rgb(), oklch()
          RRGGBBAA = true, -- #rrggbbaa 8-digit hex with alpha
          hwb = true,      -- hwb()
          lab = true,      -- lab()
          lch = true,      -- lch()
        },
      })
    end,
  },
}
