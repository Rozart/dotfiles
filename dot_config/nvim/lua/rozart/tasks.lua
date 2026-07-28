local M = {}

local config = {
  vaults = {}, -- list of backends, built in setup()
  display = "split", -- "split" (right sidebar) or "float" (centered overlay)
  width = 50,
}

local state = { win = nil, buf = nil, line_meta = {}, filter = nil, undo = {} }

-- Fixed estimate steps — mirrors ESTIMATES in wiki-app task-core (types.ts);
-- the vault-api rejects anything else on POST /tasks.
M.ESTIMATES = { "15m", "30m", "1h", "2h", "4h", "1d" }

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
      for _, tag in ipairs(task.parsed.tags) do
        set[tag] = true
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

-- ── Pure layer ──────────────────────────────────────────────────────────────
-- Mirrors wiki-app libs/shared/task-core (parse.ts / daily.ts / score.ts),
-- which itself was ported from an earlier version of this file. Token grammar:
--   - [<state>] text @assignee @@author #p1 ➕ created 📅 due ⏱ est 🛫 started ❌ cancelled #tags 📄 [[doc]]

-- Pure: parse a raw task line into the full token record.
function M.parse(text, today)
  text = text:gsub("\239\184\143", "") -- strip U+FE0F so ⏱️ parses like ⏱
  local indent = #text:match("^(%s*)")
  local box = text:match("^%s*%- %[(.)%]")
  -- 📄 [[slug]] is stripped first so the slug never leaks into #tags
  local doc = text:match("📄%s*%[%[([a-z0-9%-]+)%]%]")
  if doc then
    text = text:gsub("📄%s*%[%[[a-z0-9%-]+%]%]", "")
  end
  local important = text:match("#p1%f[%W]") ~= nil
  local due = text:match("📅%s*(%d%d%d%d%-%d%d%-%d%d)")
  local author = text:match("@@([%w_%-]+)")
  -- Lua has no lookbehind: drop @@author before matching @assignee
  local assignee = text:gsub("@@[%w_%-]+", " "):match("@([%w_%-]+)")
  local tags = {}
  for tag in text:gmatch("#([%w_/%-]+)") do
    tag = tag:lower()
    if tag ~= "p1" then
      tags[#tags + 1] = tag
    end
  end
  return {
    state = box,
    important = important,
    due = due,
    urgent = due ~= nil and due <= today,
    done = text:find("✅", 1, true) ~= nil, -- done keys off ✅, not [x]
    done_date = text:match("✅%s*(%d%d%d%d%-%d%d%-%d%d)"),
    in_progress = box == "/",
    cancelled = text:find("❌", 1, true) ~= nil or box == "-",
    cancelled_date = text:match("❌%s*(%d%d%d%d%-%d%d%-%d%d)"),
    started_date = text:match("🛫%s*(%d%d%d%d%-%d%d%-%d%d)"),
    created = text:match("➕%s*(%d%d%d%d%-%d%d%-%d%d)"),
    estimate = text:match("⏱%s*(%d+[mhd])"),
    assignee = assignee,
    author = author,
    tags = tags,
    doc = doc,
    indent = indent,
  }
end

-- Pure: build a task line body in the canonical wiki-app token order
-- (formatTaskLine, daily.ts). `opts.created` is required.
function M.format_task_line(text, opts)
  local parts = { (text:gsub("^%s+", ""):gsub("%s+$", "")) }
  if opts.assignee then
    parts[#parts + 1] = "@" .. opts.assignee
  end
  if opts.author then
    parts[#parts + 1] = "@@" .. opts.author
  end
  if opts.important then
    parts[#parts + 1] = "#p1"
  end
  parts[#parts + 1] = "➕ " .. assert(opts.created, "created date required")
  if opts.due then
    parts[#parts + 1] = "📅 " .. opts.due
  end
  if opts.estimate then
    parts[#parts + 1] = "⏱ " .. opts.estimate
  end
  if opts.started then
    parts[#parts + 1] = "🛫 " .. opts.started
  end
  if opts.cancelled then
    parts[#parts + 1] = "❌ " .. opts.cancelled
  end
  for _, t in ipairs(opts.tags or {}) do
    parts[#parts + 1] = "#" .. t
  end
  if opts.doc then
    parts[#parts + 1] = "📄 [[" .. opts.doc .. "]]"
  end
  return table.concat(parts, " ")
end

-- Pure: complete a task. Checkbox class covers [/] too — completing an
-- in-progress task must flip the box, or it wedges as done+in-progress
-- (the bug daily.ts markDone documents). Idempotent on ✅.
function M.mark_done(line, today)
  if line:find("✅", 1, true) then
    return line
  end
  local l = line:gsub("^(%s*%- %[)[ /](%])", "%1x%2", 1)
  return l .. " ✅ " .. today
end

-- Pure: [ ] → [/] and stamp 🛫 today; an existing 🛫 date is kept.
function M.mark_in_progress(line, today)
  local l = line:gsub("^(%s*%- %[) (%])", "%1/%2", 1)
  if l:find("🛫", 1, true) then
    return l
  end
  return l:gsub("%s+$", "") .. " 🛫 " .. today
end

-- Pure: [/] → [ ] and strip the 🛫 stamp (mirrors markTodo, daily.ts).
function M.mark_todo(line)
  local l = line:gsub("^(%s*%- %[)/(%])", "%1 %2", 1)
  return (l:gsub("%s*🛫%s*%d%d%d%d%-%d%d%-%d%d", "", 1))
end

-- ── Do-next score (port of score.ts — keep weights/tables in sync) ─────────

local WEIGHTS = { due = 0.4, important = 0.25, shortness = 0.2, age = 0.15 }
local AGE_CAP_DAYS = 14
local SHORTNESS = { ["15m"] = 1, ["30m"] = 0.85, ["1h"] = 0.65, ["2h"] = 0.4, ["4h"] = 0.2, ["1d"] = 0.1 }
local EST_MINUTES = { ["15m"] = 15, ["30m"] = 30, ["1h"] = 60, ["2h"] = 120, ["4h"] = 240, ["1d"] = 480 }

local function clamp(n, lo, hi)
  return math.min(hi, math.max(lo, n))
end

-- Whole days from ISO date a to b (b − a). hour=12 dodges DST edges.
local function days_between(a, b)
  local function t(d)
    local y, m, dd = d:match("(%d+)%-(%d+)%-(%d+)")
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })
  end
  return math.floor((t(b) - t(a)) / 86400 + 0.5)
end

-- Weighted sum of due/important/shortness/age factors, 0..1.
function M.task_score(p, today)
  local due_s = 0
  if p.due then
    local d = days_between(today, p.due)
    due_s = d <= 0 and 1 or clamp(1 - d / 14, 0.15, 1)
  end
  local short_s = p.estimate and (SHORTNESS[p.estimate] or 0.3) or 0.3
  local age_s = p.created and clamp(days_between(p.created, today) / AGE_CAP_DAYS, 0, 1) or 0
  return WEIGHTS.due * due_s
    + WEIGHTS.important * (p.important and 1 or 0)
    + WEIGHTS.shortness * short_s
    + WEIGHTS.age * age_s
end

-- table.sort predicate: true if a ranks before b. Score desc, then earlier
-- due, then older created (nulls last), then shorter estimate.
function M.compare_for_next(a, b, today)
  local sa, sb = M.task_score(a, today), M.task_score(b, today)
  if sa ~= sb then
    return sa > sb
  end
  local ad, bd = a.due or "9999-99-99", b.due or "9999-99-99"
  if ad ~= bd then
    return ad < bd
  end
  local ac, bc = a.created or "9999-99-99", b.created or "9999-99-99"
  if ac ~= bc then
    return ac < bc
  end
  local am = a.estimate and (EST_MINUTES[a.estimate] or math.huge) or math.huge
  local bm = b.estimate and (EST_MINUTES[b.estimate] or math.huge) or math.huge
  return am < bm
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

-- ── Backends ────────────────────────────────────────────────────────────────
-- A backend scans for open tasks and replaces single lines. Task records are
-- uniform: { backend, vault?, file, lnum, raw } — `raw` doubles as the
-- optimistic-concurrency guard (files: exact match; api: `expected`).

local function files_backend(spec)
  local b = { kind = "files", name = spec.name or "files" }
  b.dailies = vim.fn.expand(spec.path .. "/data/00_dailies")
  b.scan = function()
    local out = {}
    -- open ([ ]) and in-progress ([/]) checkbox lines
    local cmd = string.format("rg --vimgrep -e '^\\s*- \\[[ /]\\] ' %s", vim.fn.shellescape(b.dailies))
    for _, l in ipairs(vim.fn.systemlist(cmd)) do
      local file, lnum, _, text = l:match("^(.-):(%d+):(%d+):(.*)$")
      if file and lnum and text then
        out[#out + 1] = { backend = b, file = file, lnum = tonumber(lnum), raw = text }
      end
    end
    return out
  end
  b.set_line = function(task, new_raw)
    local lines = vim.fn.readfile(task.file)
    if lines[task.lnum] ~= task.raw then
      return false, "Task changed on disk — refresh (r) and retry"
    end
    lines[task.lnum] = new_raw
    vim.fn.writefile(lines, task.file)
    if vim.fn.bufnr(task.file) ~= -1 then
      vim.cmd("checktime")
    end
    return true
  end
  return b
end

local function api_call(b, method, path, body)
  local args = { "curl", "-sS", "--max-time", "5", "-X", method, "-H", "Content-Type: application/json" }
  if b.token then
    vim.list_extend(args, { "-H", "Authorization: Bearer " .. b.token })
  end
  if body then
    vim.list_extend(args, { "--data-binary", vim.json.encode(body) })
  end
  args[#args + 1] = b.url .. "/api" .. path
  local res = vim.system(args, { text = true }):wait()
  if res.code ~= 0 then
    return nil, "curl: " .. vim.trim(res.stderr or tostring(res.code))
  end
  local ok, decoded = pcall(vim.json.decode, res.stdout)
  if not ok then
    return nil, "bad response from " .. path
  end
  if type(decoded) == "table" then
    if decoded.ok == false then
      return nil, decoded.error or "server refused" -- stale line etc. (HTTP 200)
    end
    if type(decoded.statusCode) == "number" and decoded.statusCode >= 400 then
      return nil, tostring(decoded.message) -- NestJS error body (401 etc.)
    end
  end
  return decoded
end

local function api_backend(spec)
  local b = { kind = "api", name = spec.name or "api", url = spec.url:gsub("/+$", ""), token = spec.token }
  local vault_q = spec.vault or "all"
  b.scan = function()
    local eis, err = api_call(b, "GET", "/tasks/eisenhower?vault=" .. vault_q)
    if not eis then
      vim.notify(b.name .. ": " .. err, vim.log.levels.WARN)
      return {}
    end
    local out = {}
    for _, key in ipairs({ "do", "schedule", "delegate", "someday" }) do
      for _, row in ipairs(eis[key] or {}) do
        out[#out + 1] = { backend = b, vault = row.vault, file = row.file, lnum = row.line, raw = row.text }
        for _, sub in ipairs(row.subtasks or {}) do
          out[#out + 1] = { backend = b, vault = sub.vault, file = sub.file, lnum = sub.line, raw = sub.text }
        end
      end
    end
    return out
  end
  b.set_line = function(task, new_raw)
    -- /tasks/set replaces any checkbox line — one endpoint covers done,
    -- in-progress and undo; `expected` guards against stale rows.
    local _, err = api_call(b, "POST", "/tasks/set", {
      vault = task.vault,
      file = task.file,
      line = task.lnum,
      text = new_raw,
      expected = task.raw,
    })
    if err then
      return false, b.name .. ": " .. err
    end
    return true
  end
  return b
end

-- Configured backends (braindump.lua uses this for its vault picker).
function M.vaults()
  return config.vaults
end

-- POST /tasks — capture a new task on an api vault (braindump.lua).
function M.api_add(backend, body)
  local _, err = api_call(backend, "POST", "/tasks", body)
  if err then
    vim.notify(backend.name .. ": " .. err, vim.log.levels.WARN)
    return false
  end
  return true
end

-- ── Dashboard ───────────────────────────────────────────────────────────────

-- Scan all vaults for open tasks, grouped by quadrant, do-next order.
local function scan()
  local by_key = { ["do"] = {}, schedule = {}, delegate = {}, someday = {} }
  local today = os.date("%Y-%m-%d")
  for _, backend in ipairs(config.vaults) do
    for _, task in ipairs(backend.scan()) do
      local parsed = M.parse(task.raw, today)
      -- rg pre-filters state but api rows (and wedged "[/] ✅" lines) don't
      if not (parsed.done or parsed.cancelled) then
        task.parsed = parsed
        table.insert(by_key[M.bucket(parsed)], task)
      end
    end
  end
  for _, tasks in pairs(by_key) do
    table.sort(tasks, function(a, b)
      return M.compare_for_next(a.parsed, b.parsed, today)
    end)
  end
  return by_key
end

-- Build buffer lines + line_meta from scanned groups.
local function render_lines(by_key)
  local title = state.filter and ("# Task Dashboard — #" .. state.filter) or "# Task Dashboard"
  local lines =
    { title, "`<CR>` jump · `x` done · `s` start/stop · `u` undo · `a` add · `f` filter · `r` refresh · `q` close", "" }
  local meta = {}
  for _, q in ipairs(QUADRANTS) do
    table.insert(lines, q.header)
    local shown = 0
    for _, task in ipairs(by_key[q.key]) do
      if task_matches(task.raw, state.filter) then
        table.insert(lines, task.raw)
        meta[#lines] = task
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
  local task = current_meta()
  if not task then
    return
  end
  if task.backend.kind ~= "files" then
    vim.notify("Remote task (" .. (task.vault or task.backend.name) .. ") — no local file to jump to", vim.log.levels.INFO)
    return
  end
  if config.display == "float" then
    M.close() -- dismiss the overlay; edit lands in the window beneath it
  else
    vim.cmd("wincmd p")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(task.file))
  vim.api.nvim_win_set_cursor(0, { task.lnum, 0 })
end

-- Apply a pure line-mutation to the task under the cursor via its backend.
local function mutate(task, fn)
  local new_raw = fn(task.raw, os.date("%Y-%m-%d"))
  if new_raw == task.raw then
    return
  end
  local ok, err = task.backend.set_line(task, new_raw)
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
    redraw()
    return
  end
  table.insert(state.undo, { task = task, prev = task.raw, new = new_raw })
  redraw()
end

function M.toggle_done()
  local task = current_meta()
  if task then
    mutate(task, M.mark_done)
  end
end

function M.toggle_progress()
  local task = current_meta()
  if not task then
    return
  end
  mutate(task, task.parsed.in_progress and M.mark_todo or M.mark_in_progress)
end

-- Revert the most recent mutation (works across backends via set_line).
function M.undo()
  local entry = table.remove(state.undo)
  if not entry then
    vim.notify("Nothing to undo", vim.log.levels.INFO)
    return
  end
  local t = entry.task
  local target = { backend = t.backend, vault = t.vault, file = t.file, lnum = t.lnum, raw = entry.new }
  local ok, err = target.backend.set_line(target, entry.prev)
  if not ok then
    vim.notify("Cannot undo: " .. err, vim.log.levels.WARN)
    return
  end
  vim.notify("Restored: " .. entry.prev:gsub("^%s*%- %[.%]%s*", ""), vim.log.levels.INFO)
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
  map("s", M.toggle_progress)
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

-- Self-check for the pure parse/format/mutate/score logic. Run headless:
--   nvim --headless -c "lua require('rozart.tasks')._test(); print('ok')" -c q
function M._test()
  local T = "2026-07-04"
  local function b(text)
    return M.bucket(M.parse(text, T))
  end
  assert(b("- [ ] Do it #p1 📅 2026-07-01") == "do", "overdue #p1 -> do")
  assert(b("- [ ] Plan it #p1 📅 2026-12-01") == "schedule", "future #p1 -> schedule")
  assert(b("- [ ] Plan it #p1") == "schedule", "no-due #p1 -> schedule")
  assert(b("- [ ] Quick #work 📅 2026-07-04") == "delegate", "due-today no-p1 -> delegate")
  assert(b("- [ ] Later #work 📅 2026-12-01") == "someday", "future no-p1 -> someday")
  assert(b("- [ ] Idea #work") == "someday", "no-due no-p1 -> someday")
  assert(M.parse("x #p10 y", T).important == false, "#p10 is not #p1")
  assert(M.parse("x #p1 #p1 y", T).important == true, "duplicate #p1 still important")
  assert(task_matches("Foo #work #p1", "work") == true, "filter matches tag")
  assert(task_matches("Foo #WORK", "work") == true, "filter is case-insensitive")
  assert(task_matches("Foo #workflow", "work") == false, "filter is word-boundary, not prefix")
  assert(task_matches("Foo #work", nil) == true, "nil filter matches all")

  -- format → parse round trip, every field
  local line = M.format_task_line("Fix login", {
    assignee = "roz",
    author = "roz",
    important = true,
    due = "2026-08-01",
    estimate = "30m",
    tags = { "work", "auth" },
    created = "2026-07-01",
    doc = "fix-login",
  })
  assert(
    line == "Fix login @roz @@roz #p1 ➕ 2026-07-01 📅 2026-08-01 ⏱ 30m #work #auth 📄 [[fix-login]]",
    "canonical token order"
  )
  local p = M.parse("- [/] " .. line .. " 🛫 2026-07-02", T)
  assert(p.state == "/" and p.in_progress, "in-progress state")
  assert(p.assignee == "roz" and p.author == "roz", "assignee/author split")
  assert(p.important and p.due == "2026-08-01" and p.estimate == "30m", "flags")
  assert(p.created == "2026-07-01" and p.started_date == "2026-07-02", "dates")
  assert(#p.tags == 2 and p.tags[1] == "work" and p.tags[2] == "auth", "tags exclude p1 and doc slug")
  assert(p.doc == "fix-login", "doc slug")
  assert(not p.done and not p.cancelled, "open task")
  assert(M.parse("- [ ] x ⏱️ 1h", T).estimate == "1h", "U+FE0F variant of ⏱ parses")
  assert(M.parse("- [x] x ✅ 2026-07-03", T).done and M.parse("- [x] x ✅ 2026-07-03", T).done_date == "2026-07-03", "done + date")
  assert(M.parse("- [-] x", T).cancelled, "[-] box is cancelled even without ❌")
  assert(M.parse("  - [ ] sub", T).indent == 2, "indent from leading whitespace")

  -- mutations mirror daily.ts
  assert(M.mark_done("- [ ] a", T) == "- [x] a ✅ " .. T, "mark_done stamps ✅")
  assert(M.mark_done("- [x] a ✅ 2026-07-01", T) == "- [x] a ✅ 2026-07-01", "mark_done idempotent on ✅")
  assert(M.mark_done("- [/] a 🛫 2026-07-01", T) == "- [x] a 🛫 2026-07-01 ✅ " .. T, "mark_done unwedges [/]")
  assert(M.mark_in_progress("- [ ] a", T) == "- [/] a 🛫 " .. T, "mark_in_progress stamps 🛫")
  assert(M.mark_in_progress("- [/] a 🛫 2026-07-01", T) == "- [/] a 🛫 2026-07-01", "existing 🛫 date kept")
  assert(M.mark_todo("- [/] a 🛫 2026-07-01 📅 2026-08-01") == "- [ ] a 📅 2026-08-01", "mark_todo strips 🛫")

  -- score port (fixtures mirror score.test.ts)
  assert(days_between("2026-07-01", "2026-07-04") == 3, "days_between")
  local TS = "2026-07-10"
  local a = M.parse("- [ ] Fix login #p1 ➕ 2026-07-05 📅 2026-07-01 ⏱ 30m", TS)
  local c = M.parse("- [ ] Refactor ➕ 2026-07-09 📅 2026-08-30 ⏱ 4h", TS)
  assert(M.task_score(a, TS) > M.task_score(c, TS), "overdue #p1 30m outranks future no-p1 4h")
  assert(M.compare_for_next(a, c, TS) == true and M.compare_for_next(c, a, TS) == false, "predicate direction")
  assert(M.compare_for_next(a, a, TS) == false, "strict weak order (a,a) = false")
  -- both overdue → dueScore 1 for each → equal score → earlier due wins
  local e1 = M.parse("- [ ] x 📅 2026-06-01", TS)
  local e2 = M.parse("- [ ] y 📅 2026-07-01", TS)
  assert(M.task_score(e1, TS) == M.task_score(e2, TS), "overdue dues score identically")
  assert(M.compare_for_next(e1, e2, TS) == true, "equal-score tie: earlier due first")
  -- both past AGE_CAP_DAYS → ageScore capped at 1 → equal score → older created wins
  local c1 = M.parse("- [ ] x ➕ 2026-06-01", TS)
  local c2 = M.parse("- [ ] y ➕ 2026-06-20", TS)
  assert(M.compare_for_next(c1, c2, TS) == true, "equal-score tie: older created first")
  return true
end

function M.setup(opts)
  opts = opts or {}
  if opts.width then
    config.width = opts.width
  end
  if opts.display then
    config.display = opts.display
  end
  local specs = opts.vaults
  if not specs and opts.obsidian_base then
    specs = { { name = "obsidian", path = opts.obsidian_base } } -- back-compat
  end
  config.vaults = {}
  for _, spec in ipairs(specs or {}) do
    config.vaults[#config.vaults + 1] = spec.url and api_backend(spec) or files_backend(spec)
  end
  vim.api.nvim_create_user_command("TaskDashboard", M.toggle, {})
end

return M
