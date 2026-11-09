# Rex Picker

A native AppKit fuzzy picker for Rex machines, sessions, and tabs. No third-party dependencies.

## Use

Press **Ctrl+A, then F** in Rex to open its native **Go to Anything** picker. This shortcut does not launch the companion app.

The companion app remains available for numbered-tab navigation. Its standalone search can still be opened with **Open Rex Picker** from the terminal icon in the menu bar.

- Type a subsequence: `dvst` matches `dev-station`.
- Combine terms: `dvst logs` searches machine and tab context together.
- Use Up/Down and Enter to switch. Escape dismisses.
- Double-click a destination to switch.
- Select Refresh Destinations from the menu bar to refresh manually. Opening the picker also refreshes.

Press **Ctrl+A, then '** for a numbered preview of available tabs across machines and sessions.

- The list shows each tab’s number, title, session, and machine.
- Press **1–9** to switch immediately.
- Reach tab 10 and above with arrows, name search, double-click, or a pasted number followed by Enter.
- Filtering does not renumber the tabs. Numbers follow local-first configured host/session/tab order, not fuzzy ranking.
- The list waits for discovery to finish before enabling numeric selection.
- User-defined tab names take priority; unnamed tabs show the focused terminal’s title when available.

Both modes read Rex’s active custom theme and light/dark appearance preferences when opened. Background, foreground, selection, and selected text follow Rex rather than the macOS accent color. Built-in or unresolvable themes fall back to system colors.

Machines with sessions activate one of this Mac's attached sessions, falling back to the first listed session. A machine with no sessions remains unavailable; the picker never creates sessions. A host must already have a connection from this Mac's Rex client. Open that host in Rex first if the picker says it cannot find this Mac.

Rex Remote Control must allow client actions. The picker reports refusals; it does not change Rex's permission settings.

## Build and install

Requires macOS 15 or newer, Swift 6, existing Xcode or Command Line Tools, and an installed Rex CLI.

Chezmoi tracks the source under `dot_local/share/rex-picker`, deploys it to `~/.local/share/rex-picker`, and links `~/Dev/rex-picker` there. On Rex-enabled Macs, `run_onchange_after_zz-build-rex-picker.sh.tmpl` rebuilds the app when its Swift sources, manifest, bundle metadata, build script, or launcher module change. It reloads an already-running Rex server's configuration without starting or restarting a server. Other hosts receive neither the sources nor the development link.

Edit through `chezmoi edit ~/.local/share/rex-picker/<file>`, then apply. Edits made directly through the development link affect the deployed copy; import those edits with `chezmoi re-add ~/.local/share/rex-picker` before applying again. The Lua launcher has one source of truth at `dot_config/rex/fuzzy-picker.lua` in the chezmoi repository.

For a manual build:

```sh
swift test
sh build-app.sh
open "$HOME/Applications/Rex Picker.app"
```

The build script stages and verifies an ad-hoc signed app before replacing the managed bundle in `~/Applications`. Build or signing failures leave the installed app unchanged. It refuses to replace an unrelated bundle or a symlink. It never stops a running picker; quit and reopen the picker after rebuilding to load the new executable. It does not register a login item. The numbered-tab shortcut starts the app when needed; it remains in the menu bar until quit.

Chezmoi also deploys `~/.config/rex/fuzzy-picker.lua`. The managed `keys.lua` loads this launcher when the companion app is installed; otherwise it loads `tab-number` for the number-entry dialog. The two modules are mutually exclusive. For a manual installation, obtain the launcher from the chezmoi repository and use the same installed-app check to choose between `require("fuzzy-picker")` and `require("tab-number")`, then run `rex config reload`. Ctrl+A then F and W remain Rex's native Go to Anything picker in either case. The numbered-tab shortcut runs on the home server hosting that configuration, so install this integration on the Mac's local home server, not on a shared remote home server.

`REX_PICKER_CLI` can override the CLI path when launching the executable directly. The default resolves Rex's current bundled server binary rather than a version-specific location.

## Verification

```sh
swift test
lua rex/test-picker.lua "$HOME/.config/rex/fuzzy-picker.lua" installed
lua rex/test-picker.lua "$HOME/.config/rex/fuzzy-picker.lua" absent
"$HOME/Applications/Rex Picker.app/Contents/MacOS/RexPicker" --diagnose
```

Diagnostics list every destination and explain unavailable hosts without changing sessions.

For an isolated native render:

```sh
REX_PICKER_QUERY="dvst" REX_PICKER_RENDER="/tmp/rex-picker.png" .build/debug/RexPicker
```

This launches a temporary picker instance, renders its own view after three seconds, prints visibility, match count, theme, and mode, and exits. Add `REX_PICKER_MODE=tabs` for numbered mode or `REX_PICKER_APPEARANCE=dark` to render Rex’s dark palette without changing Rex’s preferences. No Accessibility permission is needed for the app's own view. It does not test OS-delivered keyboard events.

## Structure

- `PickerCore` owns fuzzy ranking, Rex JSON models, destination discovery, and client activation.
- `PickerWindow` owns native controls and appearance tokens; `RexAppearance` reads Rex’s theme preferences.
- `AppDelegate` owns menu-bar lifecycle, incremental refresh, and keyboard navigation.

The picker uses the public Rex CLI. It resolves this Mac's client separately on each host and uses its full client ID. It never falls back to another Mac's connection. Discovery runs away from the main thread; hosts load independently and failures remain visible.
