# Rex / tmux compatibility ledger

## Scope

The migration is incomplete. The approved plan is `rex-migration-plan.md`; the machine-readable inventory is `rex-parity-inventory.json`.

The inventory captures every binding printed by `tmux list-keys`, across prefix, root, copy-mode, copy-mode-vi, and move tables, plus the current managed Rex keymap and advertised actions. It does not prove tmux plugins are active or include all native/default Rex bindings. Regenerate with:

```sh
python3 .tests/update-rex-parity.py --client CLIENT_ID
```

Statuses are Matched, Accepted difference, Missing, Investigating, and Not applicable. Matched applies only to the scope named in its row. Overall inventory entries remain Investigating until all required host/lifecycle scenarios qualify. A configured action is not proof of matching behavior.

## Applied core pass

Prefix means Ctrl-a. Existing prefix-based h/j/k/l remains available.

| Keys | Behavior | Status and scope | Evidence |
|---|---|---|---|
| Arrows | Directional focus and edge wrap | Matched on Mac-local and dev-station fixtures | Live app observes focused-pane titles for all four directions |
| o | Next pane | Matched on Mac-local and dev-station fixtures | Live app observes pane change |
| ( / ) | Previous / next session | Matched on Mac-local and dev-station fixtures | Live app changes between two fixture sessions and back |
| ! | Break pane into a new tab | Matched on Mac-local and dev-station fixtures | Live app plus new window membership; original block/PID preserved |
| { / } | Swap with previous / next pane | Matched for tested local and dev-station layouts | Pure Lua wrap/floating/context tests, isolated server order/PID tests, actual app directional focus after swap |
| Ctrl-o / Alt-o | Rotate panes previous / next | Matched for tested local and dev-station layouts; large/slow/deadline cases pending | Inverse rotations preserve layout, focus, IDs and PIDs; live app focus confirms reordered positions |
| T | Rename pane | Investigating | Binding/action registration checked; interactive dialog and title-vs-label semantics not yet qualified |
| Ctrl-b | Send prefix through to the terminal | Investigating | Bound to pane.send_key ctrl+a; byte-level/nested-interaction checks pending |

Implementation: `dot_config/rex/keys.lua` and `dot_config/rex/panes.lua`. The pane module locates the invoking block's layer instead of trusting server active_window_id. It does not mix tiled/floating layers, start processes, read local helper paths, or execute remote shell commands. Session API calls retain Rex's selected-host routing.

The dev-station fixture runs the same pane module in a Mac-local CLI script, with Rex API calls routed to dev-station and native actions directed to that host's app connection. No Lua/helper/configuration files were installed remotely; only sleep processes were started in existing directories. This verifies real remote API and app behavior, not physical keyboard injection through the Mac configuration proxy.

Accepted native copy/search bindings:

| Keys | Native behavior |
|---|---|
| [ or PageUp | Scroll back one page, without entering a vi copy mode |
| / | Open native text search |
| y | Copy the current native terminal selection |
| ] | Paste the system clipboard |

Every key above still requires Ctrl-a. Bare vi motion/selection keys are not intercepted. Native selection, clipboard and search are an accepted difference; vi motions, rectangular-selection bindings, and tmux buffer history are not implemented. Interactive clipboard byte fidelity remains to be qualified separately.

Rex Picker.app now owns apostrophe when installed, by explicit user choice. The number dialog loads only when the app is absent. Isolated tests create/remove a fake installation marker and verify exactly one apostrophe binding in both states, including after reload. The concurrent picker implementation itself is not qualified by this migration.

Rotation uses multiple documented swaps. Returned API failures trigger inverse swaps, with explicit rollback-failed errors. This is not atomic: cancellation, the 30-second action limit, or concurrent layout changes can leave a partial rotation. Large/slow remote layouts remain Investigating; do not describe this as transaction-equivalent to tmux.

## Remaining workflow ledger

| Workflow / keys | Mechanism or boundary | Scope | Status |
|---|---|---|---|
| Ctrl-a prefix; double prefix | Existing forwarding plus Ctrl-b alias | Client / nested terminals | Investigating: native bytes, mode feedback, nesting qualification |
| h/j/k/l and arrows | Native pane.focus | Client / selected host | Matched for tested Mac-local and dev-station fixtures |
| Semicolon last pane; L last session | No history adapter established | Per-client focus | Missing |
| q pane numbers; m/M marks | No equivalent overlay/mark contract established | Client / selected layout | Missing |
| n/p; digits; apostrophe | Native app-wide tab actions | Client across hosts/sessions | Accepted difference for numbering scope; existing tab-number tests retained |
| Number entry / preview | Installed Rex Picker.app preferred; Mac-local dialog fallback has 25-second expiry | Mac client only | Accepted difference; no remote helper; picker UI implementation tracked separately |
| 0 | No substitute assigned under one-based indexing | Client | Missing; explicit decision required before repurposing |
| c, double quote, percent | Existing cwd-aware new tab/split actions | Selected host | Investigating: isolated local cwd checks pass; remote and edge cases pending |
| C new session; g host switch | Existing Rex extensions | Client | Accepted difference from tmux defaults |
| Comma, dollar, T rename | Native tab/session/pane dialogs | Client / selected host | Investigating: registration checked; complete interactive semantics pending |
| s/w trees and window finding | Native session switch / Go to Anything; concurrent optional fuzzy picker | Client | Investigating: separate pickers are not declared interchangeable |
| Ctrl-Space launcher | Currently session.switch | Client | Missing full tmux-fzf menu equivalence |
| Dot tab move | Native relative tab moves exist; absolute index prompt not implemented | Client / session order | Missing |
| Alt-n/Alt-p activity navigation | Activity actions exist; traversal contract unqualified | Client | Missing |
| z zoom; E balance | Native actions already bound | Selected layout | Investigating: focus/zoom/edge qualification pending |
| Space; Alt-1…7 presets | No preset-layout action found; move/split/ratio APIs exist | Selected layout | Missing; capability prototype needed |
| Marked-pane movement; join panes | Native movement and server move_block exist | Selected host | Missing workflow adapter |
| At-sign, Tab, Backtab, asterisk floating panes | Native floating actions exist | Selected host | Investigating: create/toggle/reuse semantics not yet qualified |
| Less-than / greater-than context menus | No compatibility menus implemented | Client | Missing |
| Ctrl/Alt arrows resizing | Existing native steps use percentages, not cells | Selected layout | Accepted difference: user chose Ctrl 1% / Alt 5% |
| x / ampersand closing | Native close actions already bound | Selected pane/tab | Investigating: confirmation, cancellation, last pane, running programs |
| Mouse focus/selection/resize/scroll | Native UI behavior | Client | Investigating: root-table snapshot is not a native-UI comparison |
| Shift-arrow viewport; Delete refresh | No substitute assigned | Client | Missing / tmux-specific decision pending |
| d / D / Ctrl-z | Detach / choose client / suspend | Client/server lifecycle | Investigating; do not map to destructive close |
| r reload | Native client.config.reload | Client/config server | Investigating: interactive acknowledgement/nesting pending |
| Question-mark key help; colon prompt | Native palette exists, not tmux command syntax; slash is now native search by choice | Client | Missing exact workflow; substitution decision pending |
| i / tilde / t | Info / messages / clock | Client | Missing / applicability decision pending |
| Left bracket / PageUp; vi copy mode | Native page-up binding, no vi mode | Client scrollback | Accepted difference |
| v / Ctrl-v / y; vi motions/search | Native selection; prefix y copies; prefix slash opens search | Client scrollback | Accepted difference: vi/rectangle bindings not implemented; native UI fidelity still Investigating |
| Right bracket / hash / equals / minus buffers | Prefix right bracket pastes system clipboard; no tmux buffer stack | Client | Accepted difference: buffer history/list/delete not implemented |
| Copycat pattern shortcuts | File/URL/git/number/hash/IP patterns beyond native text search | Client scrollback | Missing |
| Local/remote terminal and Neovim clipboard | Existing shared clip-copy / receiver / tunnel contract | Client plus remote host | Investigating: bytes, newlines, acknowledgement, OSC 52 fallback, privacy |
| Bare Ctrl-h/j/k/l; Ctrl-backslash | Existing editor plugin remains tmux-specific | Editor / terminal boundary | Missing Rex bridge; nested tmux precedence required |
| Editor modes, fzf, pi, shell Ctrl-h/Ctrl-j | Must preserve application input | Foreground process | Investigating; do not intercept broadly |
| Extra SSH hop | No bridge promised | Nested remote | Investigating; separate scope decision |
| Fuzzy menus | Installed tmux-fzf covers session/window/pane/command/keybinding/clipboard/process/copy-mode | Client / selected host | Missing complete menu equivalence |
| Scratchpad | Native floating panes are candidates | Ownership undecided | Missing; scope/reuse/focus decisions required |
| Ctrl-s collision | Installed scratchpad and Resurrect both default to Ctrl-s | Prefix namespace | Investigating; do not replicate collision |
| Reconnect to live processes | Distinct CLI calls retain isolated fixture state/processes | Running server | Partial evidence only; app/network recovery Investigating |
| App reopen, network loss, server restart, reboot | Must distinguish each recovery contract | Client and hosts | Investigating; real servers must not be restarted |
| Explicit/automatic layout restore | No Resurrect-style API established | Per host | Missing / native capability investigation |
| Neovim sessions and process restart | Unsaved buffers and command replay need explicit policies | Per host/editor | Investigating; no arbitrary process replay |
| Native agent lifecycle status | Claude 2.1.311, Codex 0.166.0, and Pi 1.5.0 already emit OSC 7501; no adapter added | Direct local Rex terminal | Matched for tested scopes: actual Claude/Codex TUI working/done/error/permission reports; Pi installed reporter/formatter with injected events plus a live working report |
| Subagent counts and tab aggregation | Native multi-record status exists; tmux count/priority contract remains separate | Per block, aggregated per tab | Investigating; no custom count adapter added |
| Unseen-completion acknowledgement | Native Rex activity acknowledgement versus tmux viewed clearing | Actual client focus | Investigating; exact parity unqualified, server active_window_id is insufficient |
| Focus clock | Reset on select; lazy initialization; 50/90-minute thresholds | Ownership undecided | Missing Rex adapter / presentation |
| Prefix/copy feedback, CPU/memory/network/temperature | Native/status capability and host attribution unresolved | Client vs selected host | Investigating; design gate before new UI |
| Terminal color/underlines/extended keys/Escape/hyperlinks/title/history | Must compare renderer behavior and settings | Local and remote | Investigating; no blind tmux-option translation |
| Host paths, executable availability, disconnection | Client-local helpers and selected-host workloads have different ownership | Client/host boundary | Existing regression coverage is partial; final qualification pending |

Native status checks: `python3 .tests/test-rex-agent-status.py` and the explicit `python3 .tests/rex-agent-status.py --manifest NEW_SCRATCH_MANIFEST.json`. Claude/Codex use isolated homes and a loopback model fixture; Pi's event injection is not a full TUI/model run. All received states must match the expected agent `app` and blocking `kind`. These checks do not verify tab pixels, activity settings, real remote versions, or exact unseen/count parity. `ai-cli-configs/docs/rex-status.md` records the native reporting paths and caveats. Existing tmux hooks remain unchanged.

Configured plugins are intended workflows, not proof of activation: the configured TPM loader is missing. No tmux repair is included.

## Verification and reproduction

Automated checks:

```sh
python3 .tests/test-rex.py
python3 .tests/test-rex-tab-number.py
python3 .tests/test-rex-core-fixture.py
python3 .tests/test-rex-parity.py
swiftc -typecheck .tests/rex-window-title.swift
```

Explicit live app check, never part of unattended test discovery:

```sh
python3 .tests/rex-core-app.py --client CLIENT_ID --restore-session SESSION_ID --restore-window WINDOW_ID --manifest NEW_SCRATCH_MANIFEST.json
```

The live check creates only owned local fixture sessions, observes actual window titles using a freshly discovered client PID rather than a stale window ID, checks PID preservation, restores selection, and attempts cleanup for every recorded session. Inspect the manifest if cleanup fails. It does not enable Remote Control or restart any app/server.

Initial live attempts exposed fixture-observer problems: process titles overrode OSC titles, long temp paths truncated window titles/session suffixes, and initial split focus needed explicit setup. All attempt sessions were cleaned. Short owned directories and explicit source focus corrected the observer; the subsequent full live check passed. These failed setup attempts were not counted as app verification.

The remote runner also accepts `--server dev-station --observer-pid LOCAL_APP_PID`. Its `--client` can be a unique app label so reconnects do not leave a stale client ID. Use restore session/window IDs from that same host; restore the prior Mac-host view separately afterward when appropriate.

The optional fuzzy-picker module and host/peer/appearance synchronization are concurrent work. Preserve them; registration counts may exceed the 59 core/fallback mappings. This migration did not implement or qualify that picker.

## Decision gate before the next phases

- Percentage resizing is accepted: keep Ctrl 1% / Alt 5%.
- Native selection/clipboard/search is accepted instead of vi copy mode and buffer history.
- Scratchpad ownership and Ctrl-s allocation remain unresolved.
- Owned dev-station sleep fixtures were approved and passed; no remote deployment was authorized.
- The new numbered-tab picker takes apostrophe when installed; keep the old dialog only as fallback.
- Extra SSH-hop requirements, recovery/restart policy, status ownership/presentation once capability evidence is available.

Do not label the whole migration complete until required workflows are Matched, explicitly Accepted difference, or explicitly Not applicable. No supported shortcut hides an unresolved workflow.
