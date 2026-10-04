# AI CLI installation policy

`run_after_zz-install-ai-tools.sh.tmpl` installs missing tools on every Mac and Linux hosts marked `is_dev_station`, `is_docker_host`, or `is_media_host`. Those flags identify `roz-dev-station`, `roz-docker-host`, and `roz-media-host` in the chezmoi config template. Other Linux hosts and Windows render an empty script.

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

Sources:

- https://pi.dev/install.sh and the installed Pi README/CLI documentation.
- https://claude.ai/install.sh and https://code.claude.com/docs/en/setup.
- https://github.com/backnotprop/plannotator/releases/tag/v0.27.25.
- https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/.
