# Full tmux → Rex workflow migration plan

## Scope and current state

The user approved staged implementation with “Apply.” Current results and accepted differences live in `rex-parity.md`. The user subsequently accepted native selection/clipboard/search and percentage resizing, approved disposable dev-station sleep fixtures, and chose the installed Rex Picker.app over the number dialog, retaining the dialog as fallback.

Remote configuration deployment, tmux repair, restarts, settings changes, branches, and commits remain outside that approval.

The target covers core shortcuts, layouts, copy/search/buffers, clipboard transport, Neovim navigation, fuzzy launchers, scratchpad, persistence, and status automation. A familiar shortcut is not sufficient evidence of equivalent behavior.

### Evidence inspected

- `dot_config/tmux/tmux.conf.tmpl` and tmux key-table output.
- `dot_config/rex/keys.lua`, `tab-number.lua`, and `init.lua.tmpl`.
- Installed Rex client actions, server API descriptions, and terminal block methods/events.
- `dot_config/nvim/lua/plugins/tmux-navigator.lua`.
- Installed tmux-fzf, scratchpad, Copycat, and Resurrect defaults.
- `dot_local/bin/executable_agent-state`, `executable_focus-clock`, `executable_clip-copy`, and `.chezmoitemplates/tmuxline.tmux.conf`.
- Existing Rex tests and the banked OSC 52 clipboard note.

The configured TPM path, `~/.tmux/plugins/tpm/tpm`, is missing. Inspected plugins reside under `~/.config/tmux/plugins/`. Treat configured plugin workflows as intended behavior, not proof of current activation. Repairing tmux is outside this plan.

Rex advertises native pane/session navigation, tab reordering, pane movement, floating panes, clipboard actions, and search. The inspected action/API names do not establish vi copy mode, preset layout selection, or Resurrect-style restoration. Those remain capability investigations.

## Compatibility ledger

Create one ledger with these columns:

`tmux key/trigger | expected behavior | Rex mechanism | host/client scope | status | verification evidence`

Statuses:

- **Matched:** behavior and relevant keys pass tests.
- **Accepted difference:** the user explicitly chose a different behavior.
- **Missing:** not implemented.
- **Investigating:** capability or semantics remain unverified.
- **Not applicable:** explicitly excluded, with a recorded reason.

Inventory every baseline prefix/root/copy-mode key table and configured plugin workflow. Every item gets a status; no silent omissions. Existing automated test counts are not parity-coverage measurements.

## Preserve established choices

- [ ] Ctrl-a remains the prefix; nested applications can receive it.
- [ ] Number keys and the apostrophe prompt use native Rex app-wide tab numbering, including sessions/hosts. This intentionally differs from tmux session-relative windows.
- [ ] Number entry stays local to the Mac. Preserve the chosen native dialog and disclosed 25-second expiry unless requested otherwise.
- [ ] Preserve C for new session and g for host switching; record their differences from tmux defaults.
- [ ] Existing tmux, Neovim, clipboard, appearance, and host-sync behavior must not regress.
- [ ] No remote helper, dependency, tunnel, or service is installed without approval.

## Complete workflow checklist

Prefix below means Ctrl-a.

### 1. Core navigation, tabs, sessions, and utilities

- [ ] Prefix forwarding, nested prefixes, Escape handling, and prefix feedback.
- [ ] h/j/k/l focus: edge wrapping, floating panes, and zoom.
- [ ] Arrow focus aliases and o pane cycling.
- [ ] Semicolon previous-pane history, q pane identification, and m/M marked panes.
- [ ] n/p, digits, apostrophe selection, and numbering after close/reorder.
- [ ] Explicit behavior for 0 under one-based numbering; do not silently assign last-tab.
- [ ] Parenthesis session cycling and L previous-session behavior.
- [ ] s/w trees and f window finding. Select appropriate Rex pickers rather than treating them as interchangeable.
- [ ] New tabs/sessions and tab/session/pane renaming, including T.
- [ ] Dot window movement and Alt-n/Alt-p activity-based navigation.
- [ ] d detach, D choose client, and Ctrl-z suspend. Do not substitute destructive close actions.
- [ ] r reload; ? and / key help; colon command prompt; i information; tilde messages; t clock.

### 2. Pane operations, layouts, floating panes, and closing

- [ ] c, double quote, and percent preserve selected-pane cwd locally and remotely.
- [ ] z zoom and E balancing preserve focus.
- [ ] Space layout cycling and Alt-1…7 layouts, including mirrored layouts.
- [ ] Ctrl-o/Alt-o rotation, braces swapping, and marked-pane movement.
- [ ] Exclamation break-to-window and join/move-to-existing-window.
- [ ] At-sign float/tile; Tab/Backtab/asterisk floating-pane workflows.
- [ ] Less-than/greater-than context menus.
- [ ] Ctrl-arrow and Alt-arrow resizing: step size, repetition, nested splits, minimum sizes, and floating panes.
- [ ] x/ampersand close confirmation, cancel, last pane, and running-program warnings.
- [ ] Mouse selection, focus, divider dragging, scrolling, and floating-window behavior.
- [ ] Shift-arrow viewport adjustment and Delete refresh: classify explicitly rather than binding unrelated actions.

Rex resize amounts are percentages; tmux's configured steps are cells. Investigate a geometry-aware adapter through documented size/layout APIs, or request approval for percentage semantics.

Rex exposes splits, moves, swaps, and ratios, but no preset-layout action was found. Test layout prototypes on disposable layouts. Preserve processes and block IDs; never recreate terminals to imitate rearrangement.

### 3. Copy mode, search, buffers, and clipboard

- [ ] Left bracket and PageUp enter scrollback/copy workflows without typing into the running program.
- [ ] Vi motions, forward/backward search, next/previous match, v selection, Ctrl-v rectangles, y copy, and cancel.
- [ ] Right bracket paste, hash list buffers, equals choose buffer, and minus delete buffer.
- [ ] Copycat text, file, URL, git, number, hash, and IP search.
- [ ] Unicode, wrapped lines, long scrollback, rectangular selection, and trailing-newline fidelity.
- [ ] Local clipboard, remote terminal clipboard, and remote Neovim plus/star registers.
- [ ] Delivery acknowledgement, OSC 52 fallback, origin attribution, and notification privacy.
- [ ] Nested tmux and SSH-inside-Rex clipboard behavior.

Native copy/paste/find is not evidence of vi copy mode or a buffer stack. Investigate selection and cursor-control APIs first. If supported APIs cannot deliver exact behavior, present choices before implementing a substitute: native Rex selection, retaining tmux for that workflow, or upstream support.

Reuse the existing clipboard contract where appropriate. The banked OSC 52 note establishes that tmux answers paste queries from its own buffer; it does not establish Rex behavior. Test Rex independently. Do not assume Rex host tunnels contain clipboard forwards.

### 4. Neovim-aware navigation

- [ ] Bare Ctrl-h/j/k/l traverse editor splits, then cross an editor edge into Rex.
- [ ] Ctrl-backslash previous-focus behavior.
- [ ] Normal/insert/terminal/command-line modes, floating editor windows, and zoom.
- [ ] Preserve nested tmux precedence and its existing commands.
- [ ] Preserve input for fzf, pi, and other relevant foreground applications.
- [ ] Never steal shell Ctrl-h/Backspace or Ctrl-j/Enter.
- [ ] Direct Rex-hosted Neovim on Mac and remote hosts.
- [ ] An additional SSH hop is a separate decision, not implied support.

Start with direct Rex-hosted Neovim. Reuse the existing navigator contract if an appropriate backend seam exists. Validate edge detection and process-aware forwarding before choosing packaging.

### 5. Fuzzy launcher and scratchpad

- [ ] tmux-fzf menu categories: session, window, pane, command, keybinding, clipboard, process, and copy-mode actions; inspect optional custom menus separately.
- [ ] Decide what prefix Ctrl-Space opens. Rex currently opens a session switcher, not the full plugin launcher.
- [ ] Scratchpad create/show/hide/reuse, focus restoration, process survival, and cleanup.
- [ ] Choose scratchpad ownership explicitly: client-local/app-wide or host-local.
- [ ] Resolve prefix Ctrl-s: installed scratchpad and Resurrect defaults both claim it.

Prefer native pickers and floating-pane behavior where equivalent. A fresh shell on every invocation is not a reusable scratchpad. UI helpers must not inherit remote-host dependencies accidentally.

### 6. Persistence and recovery

- [ ] Distinguish reconnecting to live processes from saved-layout restoration and restarting programs.
- [ ] App/window close/reopen with a live server.
- [ ] Network loss and remote reconnect.
- [ ] Isolated server restart and host reboot behavior.
- [ ] Session/tab order, pane layout, labels, cwd, and scratchpad recovery.
- [ ] Explicit save/restore and automatic restore for Resurrect/Continuum intent.
- [ ] Vim/Neovim session files and unsaved-buffer expectations.
- [ ] Safe process restart policies; no blind replay of arbitrary commands.

Measure native Rex persistence before adding saved metadata. Test restarts only on owned disposable servers/processes. Do not restart the real Rex app/server or remote services during investigation.

### 7. Agent status, focus clock, and status display

- [ ] State remains owned per pane/block; multiple agents cannot clobber each other.
- [ ] Preserve wait > busy > idle > done priority, tool labels, and aggregate subagent counts.
- [ ] Preserve deferred completion, stale-count recovery, and exit cleanup.
- [ ] Viewing a tab acknowledges finished/idle agents but preserves busy/wait states.
- [ ] Verify actual client-visible focus events; server active_window_id alone is insufficient.
- [ ] Focus-clock reset on selection, initialization after reload, periodic updates, 50-/90-minute thresholds, and hour formatting.
- [ ] Decide clock ownership/restart behavior. Current timestamps live in tmux options, not a durable database.
- [ ] Prefix/copy feedback, host/session context, resource metrics, and theme-compatible presentation.
- [ ] Explicitly attribute resource information to the Mac or selected host.

Rex program_status events and native activity UI are candidates, not proven equivalents for unseen-completion badges. Trace lifecycle producers and focus events before choosing storage/UI. Preserve one lifecycle contract rather than inventing an incompatible second system.

Any new visible status UI goes through design before coding. Do not poll shell processes on every keypress or add dependencies without justification.

### 8. Terminal and host compatibility

- [ ] Truecolor, colored underlines, extended keys, Escape latency, and alternate-screen/scrollback behavior.
- [ ] Hyperlinks, mouse reporting, title/rename policy, and history limits.
- [ ] Host paths, cwd, executable availability, and disconnected-host errors.
- [ ] Local UI helpers never require Mac paths or executables remotely.
- [ ] Stable nesting with tmux and SSH.
- [ ] Existing appearance and host synchronization remain intact.

## Implementation sequence and exit criteria

| Phase | Work | Exit criterion |
|---|---|---|
| 0 | Finalize ledger; investigate copy mode, layouts, focus events, and persistence | Every baseline workflow is classified; capability boundaries and decisions are explicit |
| 1 | Core mappings and semantic corrections | Existing and new core behavior passes local/remote app checks; differences are disclosed |
| 2 | Copy/search/clipboard and Neovim integration | Byte fidelity and boundary navigation pass; ordinary application input is preserved |
| 3 | Fuzzy launcher and scratchpad | Approved menu coverage; toggles reuse processes and restore focus |
| 4 | Persistence and reconnect | Approved recovery cases pass on isolated fixtures without duplicate restore or unsafe replay |
| 5 | Agent/focus/status integration and qualification | State semantics and presentation pass; key reference and final compatibility ledger are complete |

Implement only after the relevant scope and substitution decisions are approved. Prefer native actions, then small adapters for demonstrated gaps. Keep mappings in keys.lua; split stateful workflows into small modules only when warranted.

## Verification contract

1. Capture a failing regression before changing each missing/mismatched behavior.
2. Test Lua routing/state without user sessions, then installed APIs on isolated servers.
3. Verify actual app-visible behavior, not only API success or server focus state.
4. Exercise Mac-local and remote-host contexts. Include remote-only session IDs so accidental local enumeration cannot pass.
5. Exercise nested tmux, direct remote Neovim, cancellation, reload, disconnection, and repeated/rapid input where relevant.
6. Discover client/window IDs each run; do not reuse stale app window IDs.
7. Use multiple sessions, indices above 9, and multiple hosts when scope matters.
8. Track fixture IDs, restore prior focus where feasible, and remove only owned resources.
9. Keep native-dialog smoke tests distinct from stubbed-dialog selection tests.
10. Normal keyboard use must not require Remote Control. App-driving automation may use it only when already enabled or explicitly approved.

Remote deployments and tests that start remote programs need scope approval. Preserve concurrent edits in .chezmoidata.toml, Rex host/peer templates, sync-client-hosts.py, and appearance files.

## Decisions before affected implementation phases

- Exact semantics versus native alternatives, per demonstrated gap.
- Cell-sized versus percentage resizing.
- Vi copy-mode/buffer fallback if supported APIs are insufficient.
- Scratchpad ownership and Ctrl-s allocation.
- Extra SSH-hop support in the first navigation release.
- Mandatory recovery cases and permitted command restarts.
- Status placement, clock ownership, metric host attribution, and unseen-completion acknowledgement.

Bring evidence and concrete options when each decision is actionable. Do not ask the user to guess capabilities or silently choose substitutions.

## Definition of completion

Every baseline workflow is Matched, explicitly Accepted difference, or explicitly Not applicable. No required workflow remains Missing or Investigating. All approved scenarios pass automated and app-visible checks. Publish a key reference and accepted-differences list. If a required workflow remains unsupported, report a partial migration rather than full tmux parity.
