# Upstream tools in the Agent template

This guest-only installation adds Codex, Nous Research Hermes Agent,
OpenClaw and signal-cli to the owned Debian Agent TemplateVM. Shared program
files live under `/opt/qubes-hud-agent`, which dependent AppVMs inherit from
the template. They are not installed in AppVM-private `/usr/local` or a shared
template user's home. No gateway, daemon, account, credential or login session
is initialized by the installation.

Dom0 remains offline. Debian packages continue to use native UpdatesProxy;
upstream downloads execute inside the guest using the installation's scoped
proxy environment. Ordinary user shells do not inherit that install proxy.
These upstream components are separate from APT: normal Debian updates alone
do not update their `/opt` installations.

The selected releases are Codex 0.155.0, Hermes Agent 0.21.3 (tag
`v2026.9.14`), OpenClaw and `@openclaw/signal` 2026.9.4, signal-cli 0.14.8,
and Node 24.21.0 with npm 11.19.0. Hermes uses Debian's Python 3.13 with
uv 0.12.16, setuptools 83.0.0 and wheel 0.48.0. Normal CLI and Signal
dependencies are installed; optional Hermes browser downloads and its separate
TUI are not bundled. No automatic upstream updater is installed.

## Version and update ownership

`versions.json` records upstream releases, runtime versions, artifact locations,
integrity metadata and npm lifecycle-script decisions. Salt generates
`package.json` from its `npm.dependencies` and `npm.allowScripts` fields;
only `files/package-lock.json` is committed. That npm lock and Hermes's
upstream `uv.lock` at its pinned source commit record dependency sets. Pins
define a reviewed deployment revision; they are not permanent package holds.
Update the pins and locks, then apply Salt to publish the next revision.

OpenClaw and its official Signal plugin use the same release cohort. The
published npm packages are used directly; this formula does not maintain an
OpenClaw fork or build its desktop companion. Node is installed from its
official release archive. The selected Node archive's SHA256 was checked
against its signed checksum list, verified with release key
`5BE8A3F6C8A5C01D106C0AD820B1A390B168D356`. Normal deployment verifies the
pinned archive hash; repeat the upstream signature check before accepting a
new runtime. Signal's published archive and extracted binary are hash-pinned;
this does not claim verification of its separate release signature.

To prepare an update:

1. Review the projects' release notes and compatibility requirements. Update
   the selected releases and integrity metadata in `versions.json`, including
   Node when required. Keep OpenClaw and `@openclaw/signal` compatible.
2. In an isolated guest working directory, generate a temporary `package.json`
   from the changed central npm fields and refresh `files/package-lock.json`
   using the selected Node/npm runtime, as shown below. Commit the updated
   central pins and lock. Do not resolve a floating `latest` tag during normal
   Salt deployment.
3. For Hermes, review the new upstream release commit and its `uv.lock`, then
   update the source, uv and build-tool pins together. The installation uses
   `uv sync --frozen --no-dev --extra all --no-install-project`, followed by
   the separately pinned build tools and a no-dependencies, no-build-isolation
   project install. A lock mismatch must fail rather than resolve new versions
   during deployment. Do not use `hermes update` to maintain this shared tree:
   its moving-source update flow is separate from the reviewed Salt revision.
4. Validate the candidate in a disposable guest with no account data. The
   native npm install uses `npm ci`, which requires the committed manifest and
   lock to agree. Review the manifest's explicit `allowScripts` decisions when
   updating dependencies; this npm project setting belongs in `package.json`,
   not an `--allow-scripts` command-line option. OpenClaw needs its package-local
   postinstall, and the native Koffi/tree-sitter bindings need their installation
   checks. The pinned protobufjs and Google GenAI hooks are also explicitly
   accounted for; do not replace that list with a blanket approval.
5. Sync the reviewed repository and dry-run/apply the family to the owned
   Agent template using the commands in [the family guide](../README.md).
   Shared Base changes require applying all three family targets. Confirm the
   template is halted afterward, then restart dependent AppVMs normally so
   they receive the new root snapshot.

For step 2, run this inside an isolated guest checkout, from the repository
root. First install and verify the Node version selected in `versions.json`;
set `agent_node_bin` to that runtime if it is not the current stable link.
The proxy variables apply only to this npm invocation.

```sh
set -eu
agent_source="$PWD/salt/qubes_gui/templates/family/agent-upstream"
agent_lock_work=$(mktemp -d)
agent_node_bin=/opt/qubes-hud-agent/node/bin
python3 - "$agent_source/versions.json" "$agent_lock_work/package.json" <<'PY'
import json, pathlib, sys
pins = json.loads(pathlib.Path(sys.argv[1]).read_text())
manifest = {"name": "qubes-hud-agent-tools", "version": "1.0.0", "private": True,
            "dependencies": pins["npm"]["dependencies"],
            "allowScripts": pins["npm"]["allowScripts"]}
pathlib.Path(sys.argv[2]).write_text(json.dumps(manifest, indent=2) + "\n")
PY
cp -- "$agent_source/files/package-lock.json" "$agent_lock_work/package-lock.json"
(
  cd "$agent_lock_work"
  env PATH="$agent_node_bin:$PATH" \
    HTTP_PROXY=http://127.0.0.1:8082 HTTPS_PROXY=http://127.0.0.1:8082 \
    NODE_USE_ENV_PROXY=1 \
    "$agent_node_bin/npm" install --package-lock-only --ignore-scripts --no-audit --no-fund
)
cp -- "$agent_lock_work/package-lock.json" "$agent_source/files/package-lock.json"
```

Review the lock diff, native CLI checks and `npm audit --omit=dev` results
before committing it; run the audit inside the guest with the same proxy
environment. This command
does not run dependency lifecycle scripts; the later candidate `npm ci` must
exercise the reviewed scripts and verify the native dependencies.

Keep Debian system updates on their normal schedule. Review upstream tool
releases regularly and apply security fixes promptly; check the four tools
and Node at least monthly. In particular, signal-cli tracks a changing server
protocol: its upstream warns that releases older than three months may stop
working. Do not leave that pin indefinitely unchanged.

The root-owned installation is updated through Salt. Running a self-updater
inside an AppVM is not a persistent template update. User data remains in the
user's private home; back it up before tool upgrades that migrate formats.
After an OpenClaw update, run its documented Doctor/migration workflow as the
owning AppVM user before restarting a configured gateway. Reverting program
files alone does not reverse a user-data migration.

Versioned directories retain the prior program revisions. To revert a tool
revision, restore the previous reviewed pins and npm lock, then reapply Salt
and restart dependent AppVMs. Review and remove inactive old directories only
after no dependent AppVM is using them; the formula does not automatically
delete them or user data.

The shared PATH configuration is loaded by native login-shell and Xsession
hooks. Graphical terminals and Qubes application launches inherit it after
the next session starts. Headless RPC commands do not necessarily read shell
profiles: use an absolute installed path or a login shell for those commands.
No system `/usr/bin/node` is replaced.

## OpenClaw and Signal setup

The fresh-home OpenClaw configuration only points at the shared Signal plugin
and marks it disabled. It contains no account, gateway or authentication
settings. It is supplied through `/etc/skel`; existing AppVM configurations
are preserved. Qubes can initialize an AppVM from an existing template home
rather than `/etc/skel`; use the configuration fragment below when that home
has no OpenClaw plugin entry. Merely installing the plugin package does not enable a Signal
account or start signal-cli.

An existing user can select the shared plugin through OpenClaw's native
configuration interface, preserving their other load paths and settings:

```json
{
  "plugins": {
    "load": {
      "paths": ["/opt/qubes-hud-agent/npm/node_modules/@openclaw/signal"]
    },
    "entries": {"signal": {"enabled": false}}
  }
}
```

This is a configuration fragment to merge, not a replacement for an existing
file. `openclaw plugins list` inspects discovery; it does not prove a running
gateway loaded the plugin. Perform onboarding and any Signal linking or
registration later as the user in an AppVM. For example, the native
`signal-cli link -n OpenClaw` flow links an existing Signal installation;
`openclaw channels add` guides channel configuration. Enable the Signal plugin
only when choosing to configure and use it. No account actions belong in the
shared TemplateVM.

Native Signal integration uses signal-cli's HTTP JSON-RPC and event stream;
Docker and a separate REST bridge are unnecessary. Signal keys remain in the
user's normal `~/.local/share/signal-cli` directory, and OpenClaw retains its
normal private `~/.openclaw` configuration/state.

## Upstream references

- [OpenClaw installation](https://docs.openclaw.ai/install)
- [OpenClaw updates and read-only package installations](https://docs.openclaw.ai/install/updating/update-methods)
- [OpenClaw plugin configuration](https://docs.openclaw.ai/plugins/manage-plugins)
- [OpenClaw Signal integration](https://docs.openclaw.ai/channels/signal)
- [Node release verification](https://github.com/nodejs/node#verifying-binaries)
- [signal-cli releases and update requirements](https://github.com/AsamK/signal-cli#readme)
