local M = {}

local config = {
  dailies_dir = nil, -- set in setup() from obsidian_base
  display = "split", -- "split" (right sidebar) or "float" (centered overlay)
  width = 50,
}

local state = { win = nil, buf = nil, line_meta = {}, filter = nil, undo = {} }

-- Does a task line contain #<filter> (word-boundary, case-insensitive)?
local function task_matches(text, filter)
  if not filter then
    return true
  end
  return text:lower():match("#" .. filter:lower() .. "%f[%W]") ~= nil
end

-- Distinct tags present in the scanned tasks, sorted.
local function collect_tags(by_key)
  local set = {}
  for _, tasks in pairs(by_key) do
    for _, task in ipairs(tasks) do
      for tag in task.text:gmatch("#([%w_/%-]+)") do
        set[tag:lower()] = true
      end
    end
  end
  local list = {}
  for tag in pairs(set) do
    list[#list + 1] = tag
  end
  table.sort(list)
  return list
end

local QUADRANTS = {
  { key = "do", header = "## 🟥 Do — Important + Urgent" },
  { key = "schedule", header = "## 🟧 Schedule — Important, Not Urgent" },
  { key = "delegate", header = "## 🟨 Delegate / Quick — Urgent, Not Important" },
  { key = "someday", header = "## ⬜ Someday / Cull — Neither" },
}

-- Pure: parse a task's text into { important, due, urgent }.
function M.parse(text, today)
  local important = text:match("#p1%f[%W]") ~= nil
  local due = text:match("📅%s*(%d%d%d%d%-%d%d%-%d%d)")
  local urgent = due ~= nil and due <= today
  return { important = important, due = due, urgent = urgent }
end

-- Pure: bucket a parsed task into a quadrant key. Priority cascade so every
-- task lands somewhere (dashboard.md's literal queries drop not-important +
-- future-due; we route those to someday to match Eisenhower intent).
function M.bucket(parsed)
  if parsed.important and parsed.urgent then
    return "do"
  elseif parsed.important then
    return "schedule"
  elseif parsed.urgent then
    return "delegate"
  end
  return "someday"
end

-- Scan daily notes for open tasks, grouped by quadrant key.
local function scan()
  local by_key = { ["do"] = {}, schedule = {}, delegate = {}, someday = {} }
  local today = os.date("%Y-%m-%d")
  -- ripgrep for open checkbox lines (braindump.lua:62 idiom)
  local cmd = string.format("rg --vimgrep -e '^\\s*- \\[ \\] ' %s", vim.fn.shellescape(config.dailies_dir))
  for _, line in ipairs(vim.fn.systemlist(cmd)) do
    local file, lnum, _, text = line:match("^(.-):(%d+):(%d+):(.*)$")
    if file and lnum and text then
      local parsed = M.parse(text, today)
      local key = M.bucket(parsed)
      table.insert(by_key[key], { file = file, lnum = tonumber(lnum), text = text, due = parsed.due })
    end
  end
  -- due date first, undated last; stable-ish
  for _, tasks in pairs(by_key) do
    table.sort(tasks, function(a, b)
      return (a.due or "9999") < (b.due or "9999")
    end)
  end
  return by_key
end

-- Build buffer lines + line_meta from scanned groups.
local function render_lines(by_key)
  local title = state.filter and ("# Task Dashboard — #" .. state.filter) or "# Task Dashboard"
  local lines = { title, "`<CR>` jump · `x` done · `u` undo · `a` add · `f` filter · `r` refresh · `q` close", "" }
  local meta = {}
  for _, q in ipairs(QUADRANTS) do
    table.insert(lines, q.header)
    local shown = 0
    for _, task in ipairs(by_key[q.key]) do
      if task_matches(task.text, state.filter) then
        table.insert(lines, task.text)
        meta[#lines] = { file = task.file, lnum = task.lnum }
        shown = shown + 1
      end
    end
    if shown == 0 then
      table.insert(lines, "_none_")
    end
    table.insert(lines, "")
  end
  return lines, meta
end

local function redraw()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local lines, meta = render_lines(scan())
  state.line_meta = meta
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

function M.refresh()
  redraw()
end

local function current_meta()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return state.line_meta[lnum]
end

function M.jump_to_source()
  local meta = current_meta()
  if not meta then
    return
  end
  if config.display == "float" then
    M.close() -- dismiss the overlay; edit lands in the window beneath it
  else
    vim.cmd("wincmd p")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(meta.file))
  vim.api.nvim_win_set_cursor(0, { meta.lnum, 0 })
end

function M.toggle_done()
  local meta = current_meta()
  if not meta then
    return
  end
  local file_lines = vim.fn.readfile(meta.file)
  local line = file_lines[meta.lnum]
  if not line or not line:match("^%s*- %[ %]") then
    vim.notify("Not an open task on this line", vim.log.levels.WARN)
    return
  end
  local prev = line
  line = line:gsub("^(%s*- %[)%s(%])", "%1x%2", 1)
  if not line:match("✅") then
    line = line .. " ✅ " .. os.date("%Y-%m-%d")
  end
  file_lines[meta.lnum] = line
  vim.fn.writefile(file_lines, meta.file)
  if vim.fn.bufnr(meta.file) ~= -1 then
    vim.cmd("checktime")
  end
  -- Remember the mark-done so `u` can revert it (done tasks leave the view, so
  -- there is no cursor line to un-toggle otherwise).
  table.insert(state.undo, { file = meta.file, lnum = meta.lnum, prev = prev, done = line })
  redraw()
end

-- Revert the most recent mark-done.
function M.undo()
  local entry = table.remove(state.undo)
  if not entry then
    vim.notify("Nothing to undo", vim.log.levels.INFO)
    return
  end
  local file_lines = vim.fn.readfile(entry.file)
  if file_lines[entry.lnum] ~= entry.done then
    vim.notify("Task moved since completion — cannot undo automatically", vim.log.levels.WARN)
    return
  end
  file_lines[entry.lnum] = entry.prev
  vim.fn.writefile(file_lines, entry.file)
  if vim.fn.bufnr(entry.file) ~= -1 then
    vim.cmd("checktime")
  end
  vim.notify("Restored: " .. entry.prev:gsub("^%s*- %[.%]%s*", ""), vim.log.levels.INFO)
  redraw()
end

function M.add()
  require("rozart.braindump").open_todo_input()
  -- open_todo_input is async (Snacks.input); refresh once it has written.
  vim.defer_fn(redraw, 300)
end

function M.filter()
  local tags = collect_tags(scan())
  local choices = { "[all]" }
  vim.list_extend(choices, tags)
  vim.ui.select(choices, { prompt = "Filter tasks by tag" }, function(choice)
    if not choice then
      return
    end
    state.filter = (choice ~= "[all]") and choice or nil
    redraw()
  end)
end

local function open()
  local buf = vim.api.nvim_create_buf(false, true)
  if config.display == "float" then
    local width = math.min(config.width * 2, vim.o.columns - 8)
    local height = math.floor(vim.o.lines * 0.8)
    state.win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = "minimal",
      border = "rounded",
      title = " Tasks ",
      title_pos = "center",
    })
  else
    vim.cmd("vertical botright " .. config.width .. "vsplit")
    state.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.win, buf)
    vim.wo[state.win].winfixwidth = true
  end
  state.buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  -- Wrap long tasks into the visible width; indent continuation lines so they
  -- read as one task. Wrapping is display-only, so line_meta stays correct.
  vim.wo[state.win].wrap = true
  vim.wo[state.win].linebreak = true
  vim.wo[state.win].breakindent = true
  vim.wo[state.win].breakindentopt = "shift:2"

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
  end
  map("<CR>", M.jump_to_source)
  map("x", M.toggle_done)
  map("<Space>", M.toggle_done)
  map("u", M.undo)
  map("a", M.add)
  map("f", M.filter)
  map("r", M.refresh)
  map("q", M.close)
  map("<Esc>", M.close)

  redraw()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win, state.buf, state.line_meta = nil, nil, {}
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  else
    open()
  end
end

-- Self-check for the pure parse+bucket logic. Run headless:
--   nvim --headless -c "lua require('rozart.tasks')._test(); print('ok')" -c q
function M._test()
  local T = "2026-07-04"
  local function b(text)
    return M.bucket(M.parse(text, T))
  end
  assert(b("Do it #p1 📅 2026-07-01") == "do", "overdue #p1 -> do")
  assert(b("Plan it #p1 📅 2026-12-01") == "schedule", "future #p1 -> schedule")
  assert(b("Plan it #p1") == "schedule", "no-due #p1 -> schedule")
  assert(b("Quick #work 📅 2026-07-04") == "delegate", "due-today no-p1 -> delegate")
  assert(b("Later #work 📅 2026-12-01") == "someday", "future no-p1 -> someday")
  assert(b("Idea #work") == "someday", "no-due no-p1 -> someday")
  assert(M.parse("x #p10 y", T).important == false, "#p10 is not #p1")
  assert(M.parse("x #p1 #p1 y", T).important == true, "duplicate #p1 still important")
  assert(task_matches("Foo #work #p1", "work") == true, "filter matches tag")
  assert(task_matches("Foo #WORK", "work") == true, "filter is case-insensitive")
  assert(task_matches("Foo #workflow", "work") == false, "filter is word-boundary, not prefix")
  assert(task_matches("Foo #work", nil) == true, "nil filter matches all")
  return true
end

function M.setup(opts)
  opts = opts or {}
  local base = opts.obsidian_base or "~/Documents/obsidian/vault"
  config.dailies_dir = vim.fn.expand(base .. "/data/00_dailies")
  if opts.width then
    config.width = opts.width
  end
  if opts.display then
    config.display = opts.display
  end
  vim.api.nvim_create_user_command("TaskDashboard", M.toggle, {})
end

return M
