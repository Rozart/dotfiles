# Rex SSH agent forwarding

```sh
python3 .tests/test-rex-ssh-agent.py -v
python3 .tests/test-rex.py -v
```

Each Mac's existing SSH tunnels forward its 1Password agent to a distinct raw
socket under `/run/user/1000/rex-ssh-agent/` on all six Linux hosts. The
`docker-host` tunnel also forwards the other Mac's raw agent back to a private
local socket. This makes Docker the bridge for cross-Mac authentication without
adding inbound SSH services or copying private keys. Rex's Mac-to-Mac terminal
connections continue using their existing Tailscale HTTPS endpoints.

The tunnel launcher checks ownership, directory permissions, and socket type
before replacing its own listeners. It leaves the other Mac's reverse listener
alone. Tunnel authentication stays pinned to the originating Mac's 1Password
agent, independent of pane routing. LaunchAgent bootstrap retries cover
asynchronous completion of `launchctl bootout`.

## Pane ownership and failure behavior

A supervised router runs on each host, using systemd on Linux and a LaunchAgent
on each Mac. A Lua watcher reads Rex's pane ownership and client identities.
Remote Tailscale clients map through their node identity; Unix-socket clients
map through allowlisted app labels under the same user account. CLI clients and
unknown owners do not authorize signing.

Each pane has a 0600 agent socket at
`~/.local/state/rex/ssh-agent/b-<block-uuid>.sock`, inside a 0700 directory. Its
path stays constant when ownership changes. The router chooses only the owning
Mac and never falls back to the other Mac. Detachment retains the last
positively observed Mac. An unobserved ownership transition, unknown owner,
watcher restart, or observation gap discards that history rather than guessing.
A detached pane without trusted history must be controlled again to authorize
requests. Periodic snapshots reconcile pane lifecycle; owner events re-read
current ownership rather than blindly replaying stale owners.

Owner changes revoke existing relay connections. A generation check prevents a
slow connection attempt from restoring an old route. A five-second watcher
health lease gates admission and active forwarding, checked at most every
250 ms. Watcher EOF invalidates routes immediately. Cleanup of removed sockets
runs outside routing locks. In-flight operations can fail during ownership
changes or router restart; the router never retries a signature on another Mac.
1Password still controls unlocking and approval on the selected device.

The former global `/run/user/1000/rex-ssh-agent/agent.sock` is removed. Unscoped
requests fail. Cross-Mac authentication depends on `docker-host`; authentication
using a host's own Mac agent and Linux hosts' direct Mac tunnels does not.

## Shells, SSH, and Git signing

Fish startup and managed Bash/Zsh hooks derive `SSH_AUTH_SOCK` from `REX_BLOCK`.
Missing or invalid pane scope selects a nonexistent deny socket, not a local
fallback. Existing shells and agents retain their previous environment; perform
this one-time Fish refresh, then relaunch agents:

```fish
source ~/.config/fish/functions/refresh_ssh_agent.fish
refresh_ssh_agent
```

For Bash or Zsh:

```sh
. "$HOME/.config/rex/ssh-agent.sh"
```

New terminals configure themselves. For direct Rex `--shell=none` commands, run
the command through the deployed `~/.local/bin/rex-agent-exec` wrapper, using its
absolute path on the target host. A newly created unowned pane remains denied
until a recognized Rex app claims it. The systemd drop-in provides only an
unrouted deny path; it cannot derive a pane-specific environment for native
processes. No Rex server restart is required for the shell hooks or wrapper.

The first SSH `Match exec` branch makes Rex use `SSH_AUTH_SOCK` instead of the
Mac's hardcoded local IdentityAgent. Outside Rex, existing SSH behavior stays
unchanged. Git uses `rex-ssh-sign`: in Rex it validates and normalizes arguments,
requires public-key files for signing, and forces `ssh-keygen -U` agent-only
signing. Outside Rex it preserves the installed 1Password signing helper, or
native ssh-keygen when that helper is absent. Git verification remains local.

## Deployment and checks

Deploy Linux routers before updating the Mac routers and bridge tunnels. The
standalone setup hook restarts only the router, not Rex. Linux's raw socket
runtime directory survives router restarts. Both Macs need their updated tunnel
launcher, router, shell hooks, SSH config, and Git signing helper. Generated
live target deployments do not update another machine's chezmoi source; sync the
committed source before its next full apply.

The live rollout saved target contents and modes on each host under
`~/.local/state/rex/agent-rollout-20261109T183609Z/backup.json`. It left all eight
Rex server instances running and removed its temporary verification sessions.

Unit tests use fixture sockets and do not request real signatures. They cover
strict owner selection, source changes, revocation, detached history, unavailable
agents, unknown clients, health expiry, nonblocking cleanup, public-key-only
signing, SSH overrides, shell scope, listener cleanup, and template rendering.
Live checks separately verified both Mac-to-Mac directions with real agent and
Git signatures, rejection while the chosen bridge source was unavailable even
with the other agent available, reconnection, and routed shells on all six Linux
hosts. App Remote Control was used only for test navigation; it is not required
for normal routing, and its disabled setting on roz-laptop stayed unchanged.

# Rex native agent status

```sh
python3 .tests/test-rex-agent-status.py
python3 .tests/rex-agent-status.py --manifest /tmp/rex-agent-status-$(date +%s).json
```

The unit tests exercise the loopback-only provider fixture and ensure received
states belong to the expected application and blocking reason. The explicit
live runner starts the installed Claude/Codex interactive CLIs with temporary
homes, placeholder authentication, and a local model fixture. It verifies
working, completion, fatal-error, and permission-blocked reports through Rex's
terminal API without real model calls or granting permission requests.

Pi uses its installed lifecycle reporter and formatter with injected events,
including nested blocking dialogs and cancellation. This is not a full Pi TUI
model run. A manifest records owned session IDs and pending creation labels;
cleanup attempts all remaining IDs and never reports an uncertain create as
cleaned. Control commands clear inherited Rex targets and pin a verified local
Unix-socket endpoint. The runner does not select tabs, alter app preferences, install
hooks, restart services, or deploy remotely. It is not part of unattended test
discovery. See `ai-cli-configs/docs/rex-status.md` for native detection details
and the separate read-only live Pi observation.

# Rex Picker provisioning

```sh
python3 ~/.local/share/chezmoi/.tests/test-rex-picker.py -v
cd ~/.local/share/rex-picker && swift test
```

Chezmoi deploys the native picker source and the `~/Dev/rex-picker` development
link only on Rex-enabled Macs. The onchange hook hashes the manifest, bundle
metadata, build script, Lua launcher, and Swift source paths and contents.
It builds and verifies an ad-hoc signed `~/Applications/Rex Picker.app`, then
reloads a reachable local Rex server with autostart disabled. Inherited Rex
target variables are cleared. It does not install developer tools, stop the
picker, start or restart servers, register a login item, or change permissions.
A running picker must be quit and reopened to use a new executable.

The Python suite uses temporary homes and stubbed build/signing commands. It
covers platform/hostname gates, source-change detection, scoped deployment,
build/signing failures, unmanaged-path refusal, replacement rollback, and
compiler preflight. It makes no network requests or live app changes.
Generated `.build` and `.swiftpm` directories stay outside chezmoi management.
The canonical Lua launcher remains in `dot_config/rex/fuzzy-picker.lua`.

# SketchyBar window geometry

SketchyBar uses the native menu-bar row on ordinary desktops. The macOS setup
script selects menu-bar auto-hide in fullscreen only, and `notch.sh` reads
`NSMenu.menuBarHeight` to fit the bar inside that row. With shared Spaces,
macOS reserves that row only on the main display. AeroSpace adds 10 pixels on
that display and keeps the 42-pixel allowance elsewhere. The palette forces
an opaque bar background so the native menu bar cannot show through.

`sticky=off` keeps SketchyBar out of the separate overlay Space that caused the
background to cover its items during native fullscreen transitions.
`show_in_fullscreen=off` leaves native fullscreen window controls unobstructed.
AeroSpace's Alt+F keeps the menu-bar row and SketchyBar visible.

```sh
python3 ~/.local/share/chezmoi/.tests/test-sketchybar.py
```

Tests run the real Zsh config and geometry helper with stubbed application
commands. They cover fullscreen settings, startup sizing, notch reset, invalid
geometry, per-monitor top gaps, opaque themed backgrounds, and macOS-only
setup rendering. They do not alter live
application settings. Native fullscreen transitions and window controls require
manual desktop checks.

# Clipboard tunnel agents

```sh
python3 ~/.local/share/chezmoi/.tests/test-clipboard-agents.py
```

Tests render the Mac setup script and stub `launchctl`. They verify that missing
agents can be loaded, bootstrap failures stop the script with a nonzero status,
and missing socat prevents any reload. Linux and Windows render no script.
The tests do not change running services or clipboard contents.

# AI CLI installation policy

`run_after_zz-install-ai-tools.sh.tmpl` installs missing tools on every Mac and on Linux hosts with the `homelab` role: `roz-dev-station`, `roz-docker-host`, and `roz-media-host`. Roles live in `[fleet.roles]` in `.chezmoidata.toml`, keyed by rex host label, and `.chezmoitemplates/host-roles` resolves them from `.chezmoi.hostname` on every apply. Other Linux hosts and Windows render an empty script.

The `zz-` name places the installer after the existing package bootstrap. Scripts that render only whitespace do not run, according to chezmoi's script documentation.

## Ownership and versions

| Tool | Fresh installation | Explicit updates |
|---|---|---|
| Pi | Official managed installer, current stable release | `update-all` Pi section uses `pi update --self --no-approve` |
| Claude on Mac | Homebrew `claude-code` stable cask | Existing `update-all` brew section |
| Native Claude on Linux | Official installer with `stable` | `update-all` Claude section uses `claude update` |
| Plannotator | Verified release 0.27.25 binary | Remains pinned; coordinate a future CLI/plugin upgrade |

New Pi and Claude major versions are permitted during fresh installation and explicit updates. `chezmoi apply` does not upgrade existing installations. An existing Plannotator version mismatch fails visibly without replacing it.

Pi's installer needs Node.js and npm. The script uses the existing mise configuration from HOME when mise is available; otherwise it requires Node.js and npm already on PATH. It does not introduce a second Node version policy or install a second Claude copy on a Mac.

Plannotator downloads include SHA256 sidecars. If GitHub CLI is present, signed provenance must verify against the reviewed source commit and GitHub-hosted runners before installation. An attestation error stops installation. Without GitHub CLI, the script reports that only the checksum was verified. Unsupported architectures fail explicitly.

The shared Claude settings in `ai-cli-configs` set `DISABLE_AUTOUPDATER=1` and `autoUpdatesChannel: stable`. Claude's documentation says this disables background checks while preserving manual `claude update`. Restore the shared profile through Stow on a fresh machine to apply that policy. No credentials or login state are provisioned.

Claude plugin declarations remain in `ai-cli-configs`, not chezmoi. This installer provisions binaries; it does not install Pi extension packages, enable extra skills, or alter plugin pins. The currently enabled Plannotator plugin is pinned to 0.27.25 separately.

## Validation

Run from any directory:

```sh
python3 ~/.local/share/chezmoi/.tests/test-ai-tools.py
```

Tests use real chezmoi rendering and Bash with temporary homes and stubbed installers. They cover host selection, fresh installs, reruns, existing-version preservation, checksum and provenance failures, mise routing, and Homebrew/native update ownership. They make no network calls or actual package changes.

`.tests` is ignored by chezmoi, so test assets are not deployed to HOME.

## Plannotator theme synchronization

The `theme` function updates Plannotator's machine-local config through
`~/.config/plannotator/sync-theme.py`. It maps the selected palette family and
light/dark mode to built-in Plannotator themes. Sonokai Shusia uses Monokai Pro;
Sonokai Hikari uses Gruvbox Light. These are approximations, not exact colors.
Reopen or reload Plannotator after switching.

The helper preserves unrelated settings and the unselected theme half, honors
`PLANNOTATOR_DATA_DIR`, writes private files atomically, and refuses to replace
malformed JSON. Do not add `~/.plannotator/config.json` as a managed chezmoi file;
Plannotator writes its own settings there.

```sh
python3 ~/.local/share/chezmoi/.tests/test-plannotator-theme.py
```

The test runs the real Fish theme function in a temporary HOME with external app
commands stubbed. It covers all eight theme mappings and does not change live
application themes. The approval/archive adapters and their tests live in
`ai-cli-configs`; see that repository's `docs/plannotator.md`.

## Pi theme synchronization

The shared `theme` function also runs `~/.config/pi/sync-theme.py` with the
selected Claude theme JSON. It generates `~/.pi/agent/themes/claude-system.json`
and selects `claude-system` while preserving unrelated Pi settings. Explicit
Claude overrides retain their hex values; inherited roles use terminal ANSI
colors. Pi tool-state panels reuse Claude diff fills. Native Pi diffs keep
colored text rather than Claude's word-level background highlighting.

Both generated files remain machine-local. Select `claude-system` through
Pi's `/settings` once in an already-running session; Pi then hot-reloads the
active theme file after future shared theme switches.

```sh
python3 ~/.local/share/chezmoi/.tests/test-pi-theme.py
python3 ~/.local/share/chezmoi/.tests/test-plannotator-theme.py
```

Tests cover all eight palettes, exact overrides, preserved settings, check-only
preflight, invalid-input safety, and the real Fish integration in a temporary HOME.

Sources:

- https://pi.dev/install.sh and the installed Pi README/CLI documentation.
- https://claude.ai/install.sh and https://code.claude.com/docs/en/setup.
- https://github.com/backnotprop/plannotator/releases/tag/v0.27.25.
- https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/.

## Rex alongside tmux

```sh
python3 ~/.local/share/chezmoi/.tests/test-rex.py -v
python3 ~/.local/share/chezmoi/.tests/test-rex-client-hosts.py -v
```

Requires Python 3.11+, chezmoi, and Rex. Twenty-one tests cover host/platform/account
gates, both Macs' hostnames and aliases, case variants, Mac-only appearance files,
per-HOME launch-agent paths, dedicated
SSH settings, a HOME-relative native-registration guide, Lua loading and the
host-picker binding, the real scoped apply for hostname `laptop`, current-directory
actions against an isolated real server, checksum failures, unsupported architectures,
unmanaged binaries, active-session restart refusal, selective apply parent creation,
Linux/Mac reapplication safety, root-server exclusion, and the root-only Proxmox
account bootstrap. Mac installer cases cover fresh installation, existing-version
preservation in user/system application directories, conflicting paths, checksum
and signature failures, wrong builds, unsupported macOS, download failures, and
bundled-CLI fallback when Rex is absent from PATH.

Tests use temporary homes and mocked activation commands, except for a dedicated
Rex server on its own temporary socket. They do not restart the normal Rex server,
change running tunnel agents, or touch tmux. Both installer fixtures make no network
requests or actual app/service changes. Deployment and compatibility notes live in the homelab repo's
`infra/rex/README.md`.

Eleven additional native-host tests verify that the build-1853 seeder adds missing
socket entries while preserving existing names, IDs, locators, unknown fields,
and unrelated preferences. They cover idempotency, fresh preferences, malformed
or unknown formats, unreviewed builds, unreachable sockets, name conflicts,
concurrent native edits, write-failure backups, and paths containing spaces.
The tests mock all native preference and server calls; they do not edit app state.
The native synchronization script runs on each approved Mac apply, adding missing
entries only. It does not remove saved hosts or restart the app. Existing builds
other than the reviewed 1853 are preserved, but native synchronization fails
visibly until their format is reviewed.

## Reciprocal Mac Rex access

```sh
python3 ~/.local/share/chezmoi/.tests/test-rex-mac-peers.py -v
```

Twenty tests cover both Macs and hostname aliases, self-exclusion, six unchanged
Linux declarations plus one HTTPS Mac peer, validated tailnet URLs, pinned real
host IDs, exact native-store preservation/backups, idempotency, offline peers
without blocking Linux registration, permanent conflicts, owner-only policy,
tagged-node refusal, local-socket-only policy narrowing, and disabled/login/
approval/HTTPS-pending states without starting, renaming, or restarting nodes.
The old eleven native-host tests continue to cover the Unix-socket path.

Each Mac uses Rex's saved built-in Tailscale setting for inbound sharing and
one-time browser enrollment. The CLI's tailscale-on operation is runtime-only.
Outgoing HTTPS also needs the standalone Tailscale client connected for macOS
DNS/routing. A real reverse probe initially failed on .ts.net DNS while that
client was offline, then reached the existing server after it connected.

Native registration adds only the other Mac, preserving the original six Linux
records. Offline peers are reported as pending. The node must be untagged and
restricted to its enrolling Tailscale user; a broader running local policy is
only narrowed through the supported Unix-socket API. Disabled sharing is never
automatically re-enabled. These tests stub all native writes and network calls.

## Rex full appearance profile

```sh
python3 ~/.local/share/chezmoi/.tests/test-rex-appearance.py -v
```

Seventeen isolated tests cover the captured 36-setting profile and two exact
custom themes, strict preference allowlisting, app identity/build guards,
missing-font refusal, typed writes/readback, exact private backups, fresh
preferences, additive custom-theme merging, unknown-field preservation,
concurrent changes, write failures, check-only behavior, and running-GUI
deferral. Unchanged applies create no backup and make no native writes, even
with Rex open. These tests mock preference writes, font lookup, and process
checks; a separate live read-only check verifies CoreText detects Pragmasevka
and rejects a nonexistent font rather than accepting fallback.

`run_after_sync-rex-appearance.sh.tmpl` reuses app discovery without starting a
Rex server. It runs only on approved Macs; Linux excludes its profile and helper.
A changed apply reports pending while the GUI is running. Quit only the GUI
manually, reapply the appearance targets, and reopen Rex normally. Never stop a
server or kill sessions to apply an appearance profile. The helper does not
install fonts, launch or restart apps, enable Remote Control, change hosts, or
connect this profile to the shared Fish `theme` command.
