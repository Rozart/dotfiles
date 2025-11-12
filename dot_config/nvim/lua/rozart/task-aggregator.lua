local M = {}

-- Default configuration.
local config = {
  notes_dir = vim.fn.expand("~/notes"),
  tag_pattern = "^\\s*- \\[ \\]", -- Matches lines starting with "- [ ]" (with optional leading whitespace)
  debounce_ms = 500, -- Debounce delay (ms) for syncing changes
  window_style = "split", -- Options: "floating" or "split"
  filetype = "markdown", -- Use markdown for proper syntax highlighting
}

-- agg_meta holds metadata for each aggregated line:
-- Each entry: { file = source file, lnum = original line number, orig_text = original text }
local agg_meta = {}

-- Namespace for extmarks (virtual text).
local ns_id = vim.api.nvim_create_namespace("task_aggregator_ns")

------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------

local function run_cmd(cmd)
  return vim.fn.systemlist(cmd)
end

-- Ensure the given directory exists.
local function ensure_dir(dir)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

-- Get the current daily note path.
function M.get_current_daily_note_path()
  local daily_dir = config.notes_dir .. "/Daily"
  ensure_dir(daily_dir)
  local filename = os.date("%Y-%m-%d") .. ".md"
  return daily_dir .. "/" .. filename
end

-- Scan all Markdown files in notes_dir for lines matching tag_pattern.
local function scan_for_tasks()
  local cmd = string.format("rg --vimgrep '%s' %s", config.tag_pattern, config.notes_dir)
  local results = run_cmd(cmd)
  local lines = {}
  agg_meta = {} -- reset metadata
  for _, line in ipairs(results) do
    local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
    if file and lnum and text then
      table.insert(lines, text)
      table.insert(agg_meta, { file = file, lnum = tonumber(lnum), orig_text = text })
    end
  end
  return lines
end

-- Update virtual text for each aggregated line to show its source file.
local function update_virtual_text(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for i, meta in ipairs(agg_meta) do
    local shortname = vim.fn.fnamemodify(meta.file, ":t")
    local virt_text = string.format("[%s]", shortname)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
      virt_text = { { virt_text, "Comment" } },
      virt_text_pos = "eol", -- change to "eol" if you prefer
      hl_mode = "combine",
    })
  end
end

------------------------------------------------------------
-- Buffer and Sync Functions
------------------------------------------------------------

-- Opens the aggregation buffer according to the configured window style.
function M.open_aggregation_buffer()
  local lines = scan_for_tasks()
  local buf = vim.api.nvim_create_buf(true, true) -- scratch, unlisted buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = config.filetype -- Set filetype to "markdown"
  vim.api.nvim_buf_set_option(buf, "syntax", config.filetype) -- Force syntax highlighting
  local win
  vim.cmd("split")
  win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  update_virtual_text(buf)
  M.attach_sync_callback(buf)
end

-- Refresh the aggregation buffer.
function M.refresh_aggregation_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local lines = scan_for_tasks()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  update_virtual_text(buf)
end

------------------------------------------------------------
-- Debounce Utility (using vim.fn.timer_start)
------------------------------------------------------------

local function debounce(fn, delay)
  local timer_id = nil
  return function(...)
    local args = { ... }
    if timer_id then
      vim.fn.timer_stop(timer_id)
    end
    timer_id = vim.fn.timer_start(delay, function()
      fn(unpack(args))
      timer_id = nil
    end)
  end
end

------------------------------------------------------------
-- Syncing Functionality
------------------------------------------------------------

local function sync_changes(bufnr, _changedtick, firstline, lastline, new_lastline, _byte_count)
  local orig_count = lastline - firstline
  local new_count = new_lastline - firstline

  if new_count < orig_count then
    vim.notify("Deleting lines is not supported in the aggregation view", vim.log.levels.ERROR)
    local old_lines = vim.api.nvim_buf_get_lines(bufnr, firstline, lastline, false)
    vim.api.nvim_buf_set_lines(bufnr, firstline, new_lastline, false, old_lines)
    return
  end

  -- Process modifications on existing lines.
  for virt_line = firstline, firstline + orig_count - 1 do
    local new_text = vim.api.nvim_buf_get_lines(bufnr, virt_line, virt_line + 1, false)[1]
    local meta = agg_meta[virt_line + 1]
    if meta and new_text and new_text ~= meta.orig_text then
      local source_buf = vim.fn.bufnr(meta.file, true)
      if source_buf == -1 then
        vim.notify("Source file not found: " .. meta.file, vim.log.levels.WARN)
      else
        local source_line = vim.api.nvim_buf_get_lines(source_buf, meta.lnum - 1, meta.lnum, false)[1]
        if source_line ~= meta.orig_text then
          vim.notify(
            string.format("Conflict in %s at line %d. Source modified externally.", meta.file, meta.lnum),
            vim.log.levels.WARN
          )
        else
          vim.api.nvim_buf_set_lines(source_buf, meta.lnum - 1, meta.lnum, false, { new_text })
          meta.orig_text = new_text
        end
      end
    end
  end

  -- Process new lines as new tasks.
  if new_count > orig_count then
    local inserted = {}
    for i = firstline + orig_count, new_lastline - 1 do
      local new_text = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
      if new_text and #new_text > 0 then
        table.insert(inserted, new_text)
      end
    end
    if #inserted > 0 then
      local daily = M.get_current_daily_note_path()
      ensure_dir(vim.fn.fnamemodify(daily, ":h"))
      if vim.fn.filereadable(daily) == 0 then
        vim.fn.writefile({}, daily)
      end
      local daily_lines = vim.fn.readfile(daily)
      for _, task in ipairs(inserted) do
        table.insert(daily_lines, task)
        local new_meta = { file = daily, lnum = #daily_lines, orig_text = task }
        table.insert(agg_meta, new_meta)
      end
      vim.fn.writefile(daily_lines, daily)
    end
  end

  update_virtual_text(bufnr)
end

local debounced_sync = debounce(sync_changes, config.debounce_ms or 500)

function M.attach_sync_callback(bufnr)
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, bufnr, changedtick, firstline, lastline, new_lastline, byte_count)
      debounced_sync(bufnr, changedtick, firstline, lastline, new_lastline, byte_count)
    end,
  })
end

------------------------------------------------------------
-- Custom Commands
------------------------------------------------------------

-- Marks the task on the current line as completed (switches "- [ ]" to "- [x]").
function M.mark_current_task_completed()
  local bufnr = vim.api.nvim_get_current_buf()
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local line_text = vim.api.nvim_buf_get_lines(bufnr, cur_line - 1, cur_line, false)[1]

  if line_text:match("^%s*%- %[%s%]") then
    local new_text = line_text:gsub("^(%s*%- %[)%s(%])", "%1x%2")
    vim.api.nvim_buf_set_lines(bufnr, cur_line - 1, cur_line, false, { new_text })

    -- Retrieve metadata for the current line
    local meta = agg_meta[cur_line]
    if meta then
      local source_bufnr = vim.fn.bufnr(meta.file, true)
      local was_loaded = vim.api.nvim_buf_is_loaded(source_bufnr)

      -- Load the buffer if it's not already loaded
      if not was_loaded then
        vim.fn.bufload(source_bufnr)
      end

      -- Apply the change to the source buffer
      vim.api.nvim_buf_set_lines(source_bufnr, meta.lnum - 1, meta.lnum, false, { new_text })

      -- Save the changes to the source file
      vim.api.nvim_buf_call(source_bufnr, function()
        vim.cmd("write")
      end)

      -- Unload the buffer if it was not originally loaded
      if not was_loaded then
        vim.cmd("bdelete " .. source_bufnr)
      end
    else
      vim.notify("No metadata found for the current line", vim.log.levels.ERROR)
    end
  else
    vim.notify("Current line is not an open task", vim.log.levels.INFO)
  end
end

-- Jumps to the source file and line for the current task.
function M.jump_to_source()
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local meta = agg_meta[cur_line]
  if not meta then
    vim.notify("No metadata for the current line", vim.log.levels.WARN)
    return
  end
  vim.cmd("tabnew " .. vim.fn.fnameescape(meta.file))
  vim.api.nvim_win_set_cursor(0, { meta.lnum, 0 })
end

------------------------------------------------------------
-- Setup
------------------------------------------------------------

-- Setup function to merge user configuration and register commands.
function M.setup(user_config)
  if user_config then
    for k, v in pairs(user_config) do
      config[k] = v
    end
  end
  vim.api.nvim_create_user_command("TaskView", M.open_aggregation_buffer, {})
  vim.api.nvim_create_user_command("TaskRefresh", M.refresh_aggregation_buffer, {})
  vim.api.nvim_create_user_command("TaskComplete", M.mark_current_task_completed, {})
  vim.api.nvim_create_user_command("TaskJump", M.jump_to_source, {})
end

return M
