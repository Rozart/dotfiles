-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.o.encoding = "utf-8"
vim.o.fileencoding = "utf-8"

if vim.g.neovide then
  vim.o.guifont = "Pragmasevka Nerd Font:h11"
end

-- Remote sessions: copy/paste via the ssh-forwarded clipboard tunnels
-- (~/.ssh/config RemoteForward + launchd pbcopy/pbpaste servers on the Mac,
-- ports 2490/2489). Deterministic — no OSC 52 size limits or per-hop escape
-- handling. OSC 52 remains the copy fallback when no tunnel is up. Never OSC
-- 52 paste — its queries can't reach the real clipboard through tmux and
-- block nvim waiting for a reply.
-- Local sessions: no override, nvim autodetects pbcopy/pbpaste.
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function tunnel_copy(reg)
    local fallback = osc52.copy(reg)
    return function(lines, regtype)
      local data = table.concat(lines, "\n")
      if regtype == "V" then
        data = data .. "\n"
      end
      vim.fn.system("nc -N -w 1 127.0.0.1 2490", data)
      if vim.v.shell_error ~= 0 then
        fallback(lines, regtype)
      end
    end
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
    copy = { ["+"] = tunnel_copy("+"), ["*"] = tunnel_copy("*") },
    paste = { ["+"] = tunnel_paste, ["*"] = tunnel_paste },
  }
end

vim.opt.clipboard = "unnamedplus"
