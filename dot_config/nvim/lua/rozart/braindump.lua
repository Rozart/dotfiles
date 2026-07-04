local M = {}

local Snacks = require("snacks")

local config = {
  obsidian_base = "~/Documents/obsidian/vault", -- Example path, override in setup()
  dailies_dir = nil, -- Will be set based on obsidian_base
  template_path = nil, -- Will be set based on obsidian_base
  header = {
    prefix = "##",
  },
  categories = {
    todos = {
      header = "Todos",
      prefix = "- [ ]",
      prefix_pattern = "- %[.%]",
    },
    braindump = {
      header = "Braindump",
      prefix = "- ",
      prefix_pattern = "- ",
    },
    journal = {
      header = "Journal",
      prefix = "- ",
      prefix_pattern = "- ",
    },
  },
}

function M.get_current_daily_note_path()
  local date = os.date("%Y-%m-%d")
  return string.format("%s/%s.md", config.dailies_dir, date)
end

function M.ensure_daily_exists(file_path)
  if vim.fn.filereadable(file_path) == 1 then
    return true
  end

  -- Read template
  if vim.fn.filereadable(config.template_path) ~= 1 then
    vim.notify("Template not found: " .. config.template_path, vim.log.levels.WARN)
    return false
  end

  local template_content = table.concat(vim.fn.readfile(config.template_path), "\n")

  -- Replace {{date}} placeholder with today's date
  local date = os.date("%Y-%m-%d")
  template_content = template_content:gsub("{{date}}", date)

  -- Write new daily file
  vim.fn.writefile(vim.split(template_content, "\n"), file_path)

  local filename = vim.fn.fnamemodify(file_path, ":t")
  vim.notify("✓ Created " .. filename, vim.log.levels.INFO)
  return true
end

function M.find_md_header(name, file_path)
  local ripgrep_cmd = string.format("rg --vimgrep '^## %s' %s", name, file_path)
  return vim.fn.systemlist(ripgrep_cmd)
end

function M.add_entry_for_header(name, prefix, prefix_pattern, header_prefix, content, file_path)
  -- Ensure daily note exists (create from template if needed)
  if not M.ensure_daily_exists(file_path) then
    vim.notify("Failed to create daily note", vim.log.levels.ERROR)
    return
  end

  local header = M.find_md_header(name, file_path)
  if #header == 0 then
    vim.notify("Header not found: " .. name, vim.log.levels.ERROR)
    return
  end

  -- Extract line number correctly
  local line_number = string.match(header[1], ":(%d+):")
  if not line_number then
    vim.notify("Failed to parse line number", vim.log.levels.ERROR)
    return
  end

  local new_entry = string.format("%s %s", prefix, content)

  local found_section = false
  local last_section_entry_index = tonumber(line_number)

  local file_content = vim.fn.readfile(file_path)
  local found_last_section_entry = false
  for curr_line_number, line in ipairs(file_content) do
    if not found_last_section_entry then
      if curr_line_number == tonumber(line_number) then
        found_section = true
      elseif found_section then
        if line:match(string.format("%s .+", prefix_pattern)) then
          last_section_entry_index = curr_line_number
        elseif line:match(string.format("%s .+", header_prefix)) then
          found_last_section_entry = true
        end
      end
    end
  end

  if found_section then
    table.insert(file_content, last_section_entry_index + 1, new_entry)
  end

  vim.fn.writefile(file_content, file_path)

  local buf_exists = vim.fn.bufnr(file_path)
  if buf_exists ~= -1 then
    vim.cmd("checktime")
  end

  -- Success notification
  local filename = vim.fn.fnamemodify(file_path, ":t")
  vim.notify("✓ Added to " .. filename, vim.log.levels.INFO)
end

function M.add_braindump_entry(content)
  if not content or content == "" then
    return
  end

  local file_path = M.get_current_daily_note_path()
  M.add_entry_for_header(
    config.categories.braindump.header,
    config.categories.braindump.prefix,
    config.categories.braindump.prefix_pattern,
    config.header.prefix,
    content,
    file_path
  )
end

function M.add_journal_entry(content)
  if not content or content == "" then
    return
  end

  local file_path = M.get_current_daily_note_path()
  M.add_entry_for_header(
    config.categories.journal.header,
    config.categories.journal.prefix,
    config.categories.journal.prefix_pattern,
    config.header.prefix,
    content,
    file_path
  )
end

function M.add_todos_entry(content)
  if not content or content == "" then
    return
  end

  local file_path = M.get_current_daily_note_path()
  M.add_entry_for_header(
    config.categories.todos.header,
    config.categories.todos.prefix,
    config.categories.todos.prefix_pattern,
    config.header.prefix,
    content,
    file_path
  )
end

local function format_date(time)
  return os.date("%Y-%m-%d", time)
end

local function ask_importance(cb)
  vim.ui.select({ "No", "Yes" }, {
    prompt = "Important? (#p1)",
  }, function(choice)
    if choice == nil then
      return
    end
    cb(choice == "Yes")
  end)
end

local function ask_due_date(cb)
  vim.ui.select({ "No due date", "Set due date" }, {
    prompt = "Due date?",
  }, function(choice)
    if choice == nil then
      return
    end
    if choice == "No due date" then
      cb(nil)
      return
    end
    local tomorrow = format_date(os.time() + 24 * 60 * 60)
    Snacks.input({
      prompt = "Due date (YYYY-MM-DD)",
      default = tomorrow,
    }, function(value)
      if not value or value == "" then
        cb(nil)
        return
      end
      cb(value)
    end)
  end)
end

function M.open_todo_input()
  Snacks.input({
    prompt = "Add TODO entry for today",
  }, function(value)
    if not value or value == "" then
      return
    end
    ask_importance(function(is_important)
      ask_due_date(function(due)
        local parts = { value }
        if is_important then
          table.insert(parts, "#p1")
        end
        table.insert(parts, "➕ " .. format_date(os.time()))
        if due then
          table.insert(parts, "📅 " .. due)
        end
        M.add_todos_entry(table.concat(parts, " "))
      end)
    end)
  end)
end

function M.open_braindump_input()
  Snacks.input({
    prompt = "Add Braindump entry for today",
  }, function(value)
    M.add_braindump_entry(value)
  end)
end

function M.open_journal_input()
  Snacks.input({
    prompt = "Add Journal entry for today",
  }, function(value)
    M.add_journal_entry(value)
  end)
end

function M.setup(opts)
  opts = opts or {}

  -- Override config with provided options
  if opts.obsidian_base then
    config.obsidian_base = opts.obsidian_base
  end

  -- Set derived paths from obsidian_base
  config.dailies_dir = vim.fn.expand(config.obsidian_base .. "/data/00_dailies")
  config.template_path = vim.fn.expand(config.obsidian_base .. "/data/99_templates/daily.md")

  vim.api.nvim_create_user_command("AddTodo", M.open_todo_input, {})
  vim.api.nvim_create_user_command("AddBraindump", M.open_braindump_input, {})
  vim.api.nvim_create_user_command("AddJournal", M.open_journal_input, {})
end

return M
