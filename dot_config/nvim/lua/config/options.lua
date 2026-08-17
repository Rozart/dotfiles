-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_picker = "snacks"
vim.opt.swapfile = false
vim.opt.spelllang = { "en", "pl" }
vim.o.termguicolors = true
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
vim.opt.title = true
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 0
vim.g.ai_cmp = false

vim.opt.updatetime = 200
vim.opt.synmaxcol = 300
vim.opt.maxmempattern = 5000
vim.opt.shortmess:append("c")
vim.opt.iskeyword:remove("_")

-- ============================================================================
-- Clipboard
-- ============================================================================
-- MUST live in this file, not init.lua. LazyVim snapshots `clipboard` into its
-- internal lazy_clipboard right after loading this file, blanks the option for
-- startup speed, then restores the snapshot on the VeryLazy event. Anything set
-- after `require("config.lazy")` in init.lua is therefore reverted once the UI
-- attaches, and plain `y` silently stops reaching the system clipboard.
-- LazyVim's own default is `clipboard = ""` under SSH (it assumes bare OSC 52),
-- so the assignment below is what gets snapshotted and restored.
--
-- Remote sessions: copy/paste via the ssh-forwarded clipboard tunnels
-- (~/.ssh/config RemoteForward + launchd pbcopy/pbpaste servers on the Mac,
-- ports 2490/2489). Deterministic — no OSC 52 size limits or per-hop escape
-- handling. Never OSC 52 paste — its queries can't reach the real clipboard
-- through tmux and block nvim waiting for a reply.
--
-- Copies go through ~/.local/bin/clip-copy, shared with fish's pbcopy and
-- tmux's copy-command. It waits for the server's ack before deciding the copy
-- landed, which is why nvim no longer needs its own OSC 52 fallback here: nc
-- exits 0 even against a dead pbcopy-server (the remote sshd accepts first),
-- so nc's status could never drive that decision.
-- Local sessions: no override, nvim autodetects pbcopy/pbpaste.
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  local function tunnel_copy(lines, regtype)
    local data = table.concat(lines, "\n")
    if regtype == "V" then
      data = data .. "\n"
    end
    vim.fn.system(vim.env.HOME .. "/.local/bin/clip-copy", data)
  end
  local function tunnel_paste()
    local out = vim.fn.systemlist("nc -N -w 1 127.0.0.1 2489")
    if vim.v.shell_error == 0 and #out > 0 then
      return out
    end
    -- tunnel absent: fall back to the unnamed register so p still works
    return vim.fn.getreg('"', 1, true)
  end
  vim.g.clipboard = {
    name = "ssh-tunnel",
    copy = { ["+"] = tunnel_copy, ["*"] = tunnel_copy },
    paste = { ["+"] = tunnel_paste, ["*"] = tunnel_paste },
  }
end

vim.opt.clipboard = "unnamedplus"

-- ============================================================================
-- Python specific settings
-- ============================================================================
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"
-- vim.o.tabstop = 4
-- vim.o.shiftwidth = 4
