local M = {}

local context_manager = require("plenary.context_manager")
local open = context_manager.open
local with = context_manager.with

local config = {
  dailies_dir = vim.fn.expand("~/Documents/Rozart-Second-Brain/data/00_dailies"),
}

function M.get_current_daily_note_path()
  local date = os.date("%Y-%m-%d")
  return string.format("%s/%s.md", config.dailies_dir, date)
end

function M.find_md_header(name, file_path)
  local ripgrep_cmd = string.format("rg --vimgrep '^## %s' %s", name, file_path)
  return vim.fn.systemlist(ripgrep_cmd)
end

function M.add_todo_for_header(name, content, file_path)
  local header = M.find_md_header(name, file_path)
  if #header == 0 then
    print("Header not found")
    return
  end

  -- Extract line number correctly
  local line_number = string.match(header[1], ":(%d+):")
  if not line_number then
    print("Failed to parse line number")
    return
  end

  local todo = string.format("- [ ] %s", content)

  local found_section = false
  local last_section_entry_index = tonumber(line_number)

  -- [TODO] Modify to simplify
  local file_content = with(open(file_path, "r"), function(file)
    local lines = {}
    local curr_line_number = 0
    local found_last_section_entry = false

    for line in file:lines() do
      curr_line_number = curr_line_number + 1
      table.insert(lines, line)

      if not found_last_section_entry then
        if curr_line_number == tonumber(line_number) then
          found_section = true
        elseif found_section then
          if line:match("- %[.%] .+") then
            last_section_entry_index = curr_line_number
          elseif line:match("^## .+") then
            found_last_section_entry = true
          end
        end
      end
    end

    return lines
  end)

  if found_section then
    table.insert(file_content, last_section_entry_index + 1, todo)
  end

  with(open(file_path, "w"), function(file)
    for _, line in ipairs(file_content) do
      file:write(line .. "\n")
    end
  end)

  local buf_exists = vim.fn.bufnr(file_path)
  if buf_exists ~= -1 then
    vim.cmd("checktime")
  end
end

function M.open_todo_input()
  local Snacks = require("snacks")

  Snacks.input({
    prompt = "Add TODO for today",
  }, function(value)
    if not value or value == "" then
      return
    end

    local file_path = M.get_current_daily_note_path()
    M.add_todo_for_header("Todos", value, file_path)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("AddTodo", M.open_todo_input, {})
end

return M
