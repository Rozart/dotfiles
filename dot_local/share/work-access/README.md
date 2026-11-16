# Managed work access on macOS

## Status and boundaries

The chezmoi package stages a root-owned sing-box LaunchDaemon. Preparation and unprivileged checks do not activate it. Real privileged installation, cleanup, startup, failure behavior and reboot qualification remain separate acceptance steps.

Only `roz-mini-laptop` is opted in through `[work_access.hosts]`. Linux, the other Mac and unknown hosts ignore these assets. Removing a host from that table does not stop or uninstall an existing root service; deprovisioning is an explicit maintenance operation.

The official Tailscale client stays personal. The tool never switches profiles, changes exit-node selection, advertises routes, enables Tailscale SSH, changes the system proxy, or changes global/default DNS settings. It refuses manual installation/start unless the native client reports the configured personal tailnet and its node addresses do not collide with the selected work addresses.

Current work scope is the VPS only: one IPv4 /32 and one IPv6 /128. The two private DNS namespaces are broader than that address allowlist. Other work peers do not gain transparent routes merely because their names resolve.

## Ownership and updates

| Location | Purpose |
| --- | --- |
| `~/.local/share/work-access/` | User-owned desired configuration, management code and this guide. |
| `~/.local/bin/work-access` | User-invoked wrapper; never executed by launchd. |
| `/Library/Application Support/dev.rozart.work-access/releases/<hash>/` | Root-owned immutable binary/configuration releases. |
| `/Library/Application Support/dev.rozart.work-access/current` | Root-owned selection of one protected release. |
| `/Library/LaunchDaemons/dev.rozart.work-access.plist` | Root service definition. |
| `/var/db/dev.rozart.work-access/` | Root-private runtime state; node credentials are outside Git and releases. |
| `/var/log/dev.rozart.work-access/sing-box.log` | Restricted service output, potentially including enrollment URLs. |
| `/etc/resolver/<configured-suffix>` | Only the package's marked scoped DNS files. |

Chezmoi manages the desired files in the home directory. It does not implicitly install or restart the root service. `status` reports whether the staged release matches the installed selection.

The package pins the tested sing-box version and installed binary SHA-256 in `.chezmoidata.toml`. Installation checks that hash, takes and rechecks a private validation copy, checks required build features and system-only dynamic libraries, then copies and rechecks the executable in protected storage. Configuration files are snapshotted before validation so a concurrent chezmoi sync cannot replace the validated payload during installation. Launchd executes the protected copy, not a Homebrew symlink. An unrelated Homebrew upgrade therefore cannot silently replace the running root executable; it makes the next package check/install refuse until the new binary is qualified and the pin is deliberately updated.

There is no automatic privileged update hook and no blanket `brew bundle` invocation. The installed service uses native launchd supervision, not the user-owned Python manager. The manager uses macOS `/usr/bin/python3`; its syntax is compatible with the installed Python 3.9.

## Stage and inspect without stopping the pilot

```sh
chezmoi apply --include=files,dirs -- \
  "$HOME/.local/bin/work-access" \
  "$HOME/.local/share/work-access"

work-access check
work-access plan
work-access status
```

The apply targets only these files/directories and excludes scripts. It does not apply the Brewfile or unrelated configuration.

`check` validates configuration, plist scope and the pinned binary without starting sing-box. `plan` also checks native identity, personal/work IP collisions, existing private TUN routes, an already loaded service, running sing-box processes, DNS port occupancy and foreign scoped resolver files. An active pilot is an expected blocker, not a reason to stop it automatically. A clear plan does not prove credentials are enrolled or replace a maintenance-window approval.

Take a private, narrow baseline immediately before an approved cutover:

```sh
umask 077
work-access snapshot > "$HOME/.local/state/private-access-migration/managed-before.json"
```

This records native identity, selected exit-node ID and ordinary internet routing. It excludes node credentials and the complete peer map. `verify --baseline` compares this within the same network session; interface numbers can legitimately change after reboot or a native-client restart, so cross-reboot acceptance needs a fresh route review.

## Controlled first cutover

Do not execute this section until a local maintenance window, active TCP/UDP session impact and local rollback access have been confirmed. Review macOS ACLs on the protected parents and resulting files as well; owner/mode checks are not a complete ACL audit. Expect a brief interruption to work access. Keep personal, NAS and Rex acceptance checks available.

1. Confirm the existing pilot node belongs to the exact configured work login, `artur.rozalski@programium.dev`. This was established during the initial pilot, but the installer does not parse private state to revalidate the account. The displayed pilot node name is intentionally retained; no device rename or deletion is needed.
2. Review active TCP/UDP sessions. Stop only the foreground pilot with Ctrl-C in its own terminal. Wait for its cleanup message and verify that its marked resolver files were removed and its state ownership returned to the user. If that cleanup fails, use the pilot's existing guarded cleanup procedure rather than overwriting its files.
3. Run `work-access plan` again. Resolve blockers without killing unrelated sing-box processes or deleting foreign resolvers.
4. Install directly from a local terminal:

```sh
sudo "$HOME/.local/bin/work-access" install --confirm \
  --adopt-state "$HOME/.local/state/private-access-migration/work-pilot/tailscale"
```

Only that machine's dedicated pilot state is accepted. Official Tailscale or Rex node state must never be supplied. The installer rejects source aliases, symlinks, non-private files and hardlinks. It atomically moves the existing state on the same filesystem; it does not copy credentials. Cross-filesystem moves fail rather than falling back to a copy.

The original state path becomes a non-directory marker, so the old pilot cannot silently create a second identity there. Do not remove that marker or authenticate another pilot. Use `restore-pilot` to return the original state when needed.

Installation records its transaction before moving credentials. It installs only its marked DNS files and leaves the service disabled, including across reboot. It does not start a second process.

5. Start explicitly, then confirm that the work node's ID/IP still matches the existing pilot in an authorized work-side view. The filesystem move preserves its state; transport checks alone do not establish the embedded node's authenticated identity.

```sh
sudo "$HOME/.local/bin/work-access" start --confirm
work-access verify \
  --baseline "$HOME/.local/state/private-access-migration/managed-before.json"
rex --autostart=false --timeout 5s hosts check --json
```

`verify` refuses to count a foreground pilot as managed-service acceptance. It reads deployed metadata independently of staged files, so an incomplete desired-config sync cannot block the installed-service health check. Network preflights require a complete personal node identity and address list. Verification checks native identity/exit-node selection, exit-node availability, work IPv4/IPv6 gateways, ordinary internet routing, system DNS, normal HTTPS with certificate validation and no application proxy, and NAS TCP 445. Rex, authenticated UI actions and SSH host-key/authentication checks remain separate.

## Stop, failure and lifecycle acceptance

```sh
sudo "$HOME/.local/bin/work-access" stop --confirm
```

Stop disables this label across reboot, requests bootout of only this service and flushes the system DNS cache. It remains available if DNS/configuration health is damaged. It does not kill arbitrary processes.

Owned private resolvers stay installed while work access is off. That is an intentional DNS policy, not proof of complete fail-closed routing. Test both a fresh private DNS lookup and a connection with a cached/literal work address; the latter can fall back to native routing after a TUN disappears. Do not claim a packet-level fail-closed guarantee from startup collision checks or HTTPS failure alone.

Qualify these cases independently before accepting unattended operation:

- Work DNS and normal HTTPS succeed while the native personal/Mullvad settings, internet, home DNS, NAS and Rex remain usable.
- Normal stop and repeated start preserve identity and do not leave a duplicate process.
- Work shutdown prevents effective work access through both DNS and cached-address paths; inspect private DNS behavior rather than assuming timeout means no fallback.
- An authorized work peer cannot reach a loopback canary through the endpoint's ordinary application ingress.
- Unexpected child failure causes the expected launchd recovery without changing unrelated routes or DNS.
- Sleep/wake, Wi-Fi changes, hotspot/off-site use and reboot recover as expected. Check boot ordering with the native client and selected exit node; a successful manual start does not prove reboot behavior.
- Enrollment/key expiry produces a visible failure and an explicit recovery procedure, without automatic profile switching.

The enabled LaunchDaemon starts through launchd; the manager's manual-start preflight is not a continuous native-profile watcher. It never forces a user-selected profile back to personal. Verify the intended native-client startup behavior during reboot qualification.

Info-level logging preserves authentication prompts, which v1.14.4 emits at info level. Inspect restricted logs locally when needed, without publishing authentication URLs or credentials. Log rotation and disk use need an operational check; this package does not restart networking on a periodic timer to rotate stdout.

## Built-in peer API limitation

The application ingress rule rejects traffic entering through `ts-work`. A separate first DNS rule also rejects the peer-DNS handler, which supplies `Inbound = ts-work` in v1.14.4 (`endpoint.go:1064-1094`). Other unrecognized DNS namespaces are rejected; bootstrap uses an explicit underlay transport rather than those query rules. These are not blanket claims that all Tailscale built-in peer APIs are disabled, and authorized remote rejection tests remain required.

In sing-box v1.14.4, `protocol/tailscale/endpoint.go` registers Taildrop independently. `protocol/tailscale/taildrop.go:832-840` permits same-identity untagged peers or peers with the file-sharing-send capability, and requires the receiving node's file-sharing capability. `option/tailscale.go` exposes a directory setting but no Taildrop-disable setting. An empty directory option is not a disable switch.

Confirm the work node's file-sharing policy and this remaining exposure before production acceptance. The configured Taildrop storage is root-private and separate from executable releases, but that does not disable the API. Do not silently modify company-wide policy or describe ordinary ingress rejection as a Taildrop test.

Sources: [v1.14.4 endpoint](https://github.com/SagerNet/sing-box/blob/v1.14.4/protocol/tailscale/endpoint.go), [Taildrop](https://github.com/SagerNet/sing-box/blob/v1.14.4/protocol/tailscale/taildrop.go), [options](https://github.com/SagerNet/sing-box/blob/v1.14.4/option/tailscale.go). Launchd startup, KeepAlive, throttling and exit timeout follow this machine's installed `launchd.plist(5)` manual.

## Reapply, configuration rollback and pilot recovery

Updating staged home files does not restart anything. During a separately approved maintenance window, stop the service, check/plan the new files, run `install --confirm` without `--adopt-state`, then start and verify again. Reapplying identical files reuses the protected release and leaves the credential directory unchanged. DNS-suffix and node-name migrations require separate review.

For a same-binary configuration update with a previous protected release:

```sh
sudo "$HOME/.local/bin/work-access" stop --confirm
sudo "$HOME/.local/bin/work-access" rollback --confirm
sudo "$HOME/.local/bin/work-access" start --confirm
work-access verify
```

Rollback does not roll back node state or downgrade a different binary automatically. Cross-binary state compatibility must be qualified first.

For the initial cutover or an interrupted installation, restore the foreground pilot path:

```sh
sudo "$HOME/.local/bin/work-access" stop --confirm
work-access plan
sudo "$HOME/.local/bin/work-access" restore-pilot --confirm
```

If a complete service was never installed, `stop` can report that there is no owned installation. Inspect the recorded state and process status locally; do not treat that report as permission to remove files or bypass blockers.

`restore-pilot` requires the service and all sing-box processes to be stopped. It refuses changed resolvers, changed plist content, unexpected state in both locations or a changed original private parent. It removes only unchanged marked resolvers and its matching plist, returns the same state to the original private directory with the recorded owner, and leaves protected releases and logs for inspection. It does not delete a tailnet node or restore an old native profile.

After successful recovery, use the existing foreground pilot command if needed. Do not start it before credentials have returned. If a transaction remains incomplete, preserve `installation.json`, inspect the exact error locally and do not manually merge or duplicate credential directories.

No part of this package removes home routes, changes DNS on other hosts, replaces SSH aliases, moves the wake service, or provides control-plane-independent recovery. Those remain later milestones with separate cleanup approval.
