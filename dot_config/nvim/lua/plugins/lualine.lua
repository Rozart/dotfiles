local function git_user()
  -- Get the directory of the current file
  local cwd = vim.fn.expand("%:p:h")
  -- Check if the current file is inside a Git repository by looking for a .git directory
  local git_dir = vim.fn.finddir(".git", cwd .. ";")
  if git_dir == "" then
    return ""
  end

  local function get_git_value(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then
      return ""
    end
    local value = handle:read("*a") or ""
    handle:close()
    return value:gsub("\n", "")
  end

  local username = get_git_value("git -C " .. cwd .. " config user.name")
  local email = get_git_value("git -C " .. cwd .. " config user.email")

  if username == "" and email == "" then
    return ""
  end

  return username .. " <" .. email .. ">"
end

return {
  {
    "SmiteshP/nvim-navic",
    opts = {
      separator = "  ",
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections.lualine_b = {
        { git_user },
        "branch",
      }
      opts.sections.lualine_c = {
        LazyVim.lualine.root_dir(),
        {
          "diagnostics",
          symbols = {
            error = LazyVim.config.icons.diagnostics.Error,
            warn = LazyVim.config.icons.diagnostics.Warn,
            info = LazyVim.config.icons.diagnostics.Info,
            hint = LazyVim.config.icons.diagnostics.Hint,
          },
        },
        { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
        {
          LazyVim.lualine.pretty_path({
            length = 0,
            directory_hl = "Italic",
            filename_hl = "Bold",
          }),
        },
      }
      table.insert(opts.sections.lualine_c, { "navic", color_correction = "dynamic" })
      return opts
    end,
  },
}
