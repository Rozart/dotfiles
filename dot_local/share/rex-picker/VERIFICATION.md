# Verification

The development checks below were recorded on Rex Beta 0.1.0 (1853), with its bundled CLI at API revision 11. They describe earlier runs, including an earlier shortcut layout; their pass counts are historical rather than fresh validation of the current source.

## Current shortcut layout

Ctrl+A then F or W opens Rex's native Go to Anything picker. Ctrl+A then apostrophe loads the companion app's numbered-tab picker when installed, or the number-entry dialog when absent. The launcher and dialog modules are not loaded together. The earlier `open_fuzzy_picker` binding and concurrent dialog fallback described below have been superseded.

## Chezmoi provisioning

- The source now lives in the chezmoi repository at `dot_local/share/rex-picker` and deploys to `~/.local/share/rex-picker` on Rex-enabled Macs only.
- `~/Dev/rex-picker` links to the deployed source. The original project was preserved at `~/Dev/rex-picker.backup-20261109T121843Z`; 16 Swift and package metadata files matched before migration.
- `python3 ~/.local/share/chezmoi/.tests/test-rex-picker.py -v`: 11 provisioning tests passed, including real scoped file/link deployment in a temporary HOME and stubbed compiler, signing, replacement, rollback, local-only reload, and host-gate cases.
- The copied source passed all 18 Swift tests. The existing Rex provisioning suite passed 22 tests, and the tab-number fallback suite passed 8 tests. Both Lua launcher cases passed.
- A scoped live apply built the release app from the deployed source, verified its ad-hoc signature, and reloaded the reachable local Rex server with autostart disabled. A second apply skipped the unchanged build hook.
- The live Lua launcher and keys matched their chezmoi sources. The keymap retained both picker bindings with no diagnostics.
- With chezmoi 2.74.0, the destination-path directory target deployed recursively; selecting the source directory with `--source-path` selected only the directory entry in the scoped-deployment probe. Directory deployment therefore uses the destination path.
- No other Mac was changed. Physical shortcut delivery was not re-tested during provisioning.

## Passed

- `swift test`: 18 tests covering fuzzy subsequences, ranking, Unicode folding, multi-token context searches, destination identity, Rex JSON decoding, duplicate Unix endpoints, client selection safety, argument boundaries, simultaneous stdout/stderr drainage, error reporting, Rex theme selection and validation, stable numbering, immediate single-digit selection, and tab-title fallback.
- `sh build-app.sh`: release build and ad-hoc signed app bundle installed in `~/Applications/Rex Picker.app`.
- `RexPicker --diagnose`: local and dev-station machines, sessions, and tabs discovered; empty hosts and a host lacking this Mac's client reported explicitly.
- Local tab activation through `session.select` with session and window IDs, verified from a desktop screenshot.
- Remote tab activation on dev-station through this Mac's remote client ID, verified from a desktop screenshot.
- Native view renders reviewed in light and dark appearance, including an empty-result state.
- Native search notification handling narrowed `dvst prglrn` to one tab: `programium-learn` on dev-station.
- Direct calls to the field editor delegate's Up/Down handlers selected the expected rows.
- `rex config check` and `rex keymap --json`: Ctrl+A then F maps to `open_fuzzy_picker`; Ctrl+A then apostrophe resolves first to `open_numbered_tabs`, ahead of the unchanged dialog fallback. No reported keymap diagnostics.
- Lua launcher tests passed for installed-app and absent-app cases, including mode URLs, local execution in remote-session contexts, and launch errors.
- The existing chezmoi `test-rex-tab-number.py` suite passed all 8 fallback-dialog tests.
- Both launcher actions succeeded against the installed app. CoreGraphics window metadata confirmed the numbered picker was on-screen after a cold launch and that the same process changed to fuzzy-search mode through its URL handler.
- Light and dark view renders resolved the live Rex theme names as Sonokai Hikari and Sonokai Shusia. The numbered list showed 5 available tabs, with terminal titles used instead of generated names for unnamed tabs.
- The installed numbered window was captured and visually checked.
- `git diff --check` passed for the chezmoi checkout.

## Not verified

OS-delivered shortcut, Enter, and Escape events were not automated. System Events refused Accessibility access; no permission settings were changed. The picker itself does not need Accessibility permissions.

The read-only reviewer could not access the source directory under its directory policy. Compiler, unit, runtime, and visual checks ran directly instead.

## Deliberate boundaries

The launcher does not create sessions, pair devices, connect new hosts, change Remote Control settings, or choose a different Mac when this Mac is absent. An empty host cannot be activated until a session exists. A machine result selects an attached session or the first listed session; it does not claim to restore a server-wide most-recent session.

The shortcut integration assumes this Mac hosts its own Rex home configuration. Shared remote home-server launch routing is not implemented.

Numbers belong to this picker’s available-tab snapshot: local host first, then configured host/session/tab order. They stay fixed while filtering and activate destination IDs directly; the picker does not delegate its numbers to Rex’s native `client.tab.goto` indexing. Numbers 1–9 switch immediately; higher numbers use arrows, name search, double-click, or a pasted number followed by Enter. Discovery finishes before numbering is enabled.

Custom themes are read from Rex’s preferences on opening. If the selected theme is built-in or cannot be decoded, the picker falls back to system colors. The native search-field bezel retains its AppKit appearance; its text and text selection follow Rex’s palette.
