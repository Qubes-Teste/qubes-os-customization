# Debian template family

This opt-in formula creates Debian 13 x86_64 TemplateVMs on Qubes 4.3. It uses
native Qubes cloning, Salt includes and signed Debian packages through the
normal TemplateVM UpdatesProxy. Agent also uses Microsoft's signed APT
repository for VS Code and pinned upstream sources for its agent tools;
downloads stay inside the guest through that proxy. It adds no dom0 package,
repository, source build or runtime helper. The installed `debian-13-xfce`
source remains intact.

## Profiles and inheritance

`base.sls` is included by both `agent.sls` and `trader.sls`. All profiles also
include the existing guest HUD, bundled Zen Dots/White Rabbit fonts, Mousepad
defaults and ordinary Firefox page colors when Firefox is already installed.

- **Base:** `pass`; purge packages from the LibreOffice and Thunderbird source
  families, including UNO and OpenSymbol, and their registered configuration
  residues and dependencies made unused by that removal. Hide Xfce's generic
  Mail Reader launcher without removing Xfce.
- **Agent:** Base plus `git-all`, `git-lfs`, `gh`, search/JSON/file/archive
  tools, SSH/rsync, process diagnostics, tmux, SQLite, build-essential,
  pkg-config and shellcheck, plus VS Code, Codex, Hermes Agent, OpenClaw with its
  disabled Signal plugin, and native signal-cli. Debian packages are listed in
  `agent.sls`; upstream versions and updates are described below.
- **Trader:** Base plus Debian's Electrum, using the existing native Qt HUD
  palette through its standard desktop launcher.

The guest-only upstream state installs Codex 0.155.0, Nous Research's Hermes
Agent 0.21.3, OpenClaw and its Signal plugin 2026.9.4, and signal-cli 0.14.8.
Node 24.21.0 and a pinned Python environment support them under
`/opt/qubes-hud-agent`; private AppVM homes retain accounts and configuration.
Normal CLI and Signal dependencies are included. Optional Hermes browser
downloads and its separate TUI are not bundled or started. See the
[upstream guide](agent-upstream/README.md) for the exact pins, lockfile
maintenance, first-use configuration and update procedure.

`git-all` deliberately includes Debian's Git GUI, documentation, mail, SVN,
CVS and MediaWiki integrations. APT recommendations are disabled for these
profile packages. Shared libraries needed by other applications and existing
user profiles/documents are preserved. Two read-only APT simulations compare
pre-existing unused packages with those made unused by the application purge;
only the latter are added to the explicit purge list. A third simulation checks
that this final explicit list causes exactly those removals, with no installs
or configuration actions. There is no blanket
`autoremove`, and later Base package additions are installed after this cleanup.
No password store, agent credentials, Signal account or Electrum wallet is
initialized inside a shared template.

Edit `base.sls` for common policy, then reapply the family to all targets.
Agent and Trader are sibling profiles. Their initial native clones come from
Base, but Qubes clones do not track later changes: the Salt includes provide
the repeatable inheritance. Changing only the Base VM by hand does not update
its siblings.

Electrum's desktop launcher selects the shared root-owned qt5ct Fusion palette
without redirecting its wallet/data directory. Command-line invocations do not
inherit that launcher environment. An explicit user-selected Electrum dark
theme can override the palette; status and QR colors remain application-owned.

## Visual Studio Code

Agent includes `qubes_gui.templates.family.agent-vscode`. Microsoft's native
`code` package is installed through its signed APT repository using the guest
UpdatesProxy. No Code version pin or package hold is added: normal Qubes/APT
updates provide new releases. Repository preferences permit only `code` from
Microsoft. A debconf setting prevents the package from creating a duplicate,
unmanaged repository entry.

The committed, repository-scoped signing key comes from
[Microsoft's official key](https://packages.microsoft.com/keys/microsoft.asc):
fingerprint `BC528686B50D79E339D3721CEB3E94ADBE1229CF`, SHA256
`2fa9c05d591a1582a9aba276272478c262e95ad00acf60eaee1644d93941e3c6`.
Its signature on the actual Code repository `InRelease` was verified before
accepting the key. APT verifies repository signatures during normal updates;
the key is not added to a global trusted-key pool.

Two JSON files under the package's built-in extension directory provide the
HUD theme and editable defaults, inherited by dependent AppVMs. This is
data-only: no JavaScript, custom CSS, binary patch, Marketplace download or
account setup. The native dark high-contrast theme supports black selected
text on cyan; editor and integrated-terminal defaults use White Rabbit with
monospace fallback, while the existing Fontconfig rules give the interface
Zen Dots. Existing user/workspace settings override these defaults. VS Code's
titlebar preference is preserved; the Qubes outer frame remains managed by
dom0. Restart Code normally after adopting an updated template root.

## Home folders

The native system `xdg-user-dirs` configuration disables automatic creation.
`/etc/skel/.config/user-dirs.dirs` maps all eight standard locations to `$HOME`
for newly initialized private homes. Existing empty standard folders in these
owned templates and their skel are removed with `rmdir`; nonempty folders are
retained and reported. Existing AppVM private homes are not edited, and their
files and location preferences are preserved.

## Apply and validate

Default pillar policy, shown in `salt/pillar.example.sls`:

```yaml
qubes_gui:
  templates:
    family:
      source: debian-13-xfce
      names:
        base: debian-13-hud-base
        agent: debian-13-hud-agent
        trader: debian-13-hud-trader
```

Sync the repository, then inspect the dom0 phase:

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl state.sls qubes_gui.templates.family saltenv=user test=True
```

A fresh dry run describes the clones without creating them. Guest validation
requires those guests to exist. To create and configure the whole family:

```sh
sudo qubesctl --targets=debian-13-hud-base,debian-13-hud-agent,debian-13-hud-trader \
  state.sls qubes_gui.templates.family saltenv=user
```

Native `qubesctl` completes the dom0 phase before discovering the target VMs.
For a separate guest dry run on first install, run the dom0 command without
`test=True` to create the clones, then:

```sh
sudo qubesctl --skip-dom0 \
  --targets=debian-13-hud-base,debian-13-hud-agent,debian-13-hud-trader \
  state.sls qubes_gui.templates.family saltenv=user test=True
```

Inspect that result before the normal full apply. Use the same guest dry run
before later updates. Substitute all three target names if pillar overrides
are used. Existing TemplateVMs must be halted before the dom0 phase; the state
does not shut them down. Qubes management normally returns initially halted
guests to halted; verify their state after an interrupted or failed operation.
Running AppVMs are never restarted by this formula. Restart them normally to
receive updated template roots.

For an upstream-tool-only update, the same command can target just
`debian-13-hud-agent`; shared Base changes require all three targets. APT does
not update the pinned `/opt` applications. Review their upstream releases,
update `agent-upstream/versions.json` and the npm lock when needed, then apply
Salt. No scheduled upstream updater or permanent package hold is installed.

## Identity and recovery

The source and target names must be distinct valid Qubes names. A required
clone source must be a halted TemplateVM. Existing targets must be halted
TemplateVMs tagged `hud-template-family-managed`, with matching
`vm-config.qubes-hud-family-name`, `-role` and `-source` features. Guest states
also verify the actual QubesDB identity and native dom0-supplied pillar.
Unknown targets, mismatched source policy and unsafe managed paths are refused.

The native clone command refuses a concurrent name collision before assigning
ownership. If creation is interrupted between cloning and recording identity,
the resulting unowned VM is deliberately refused on retry. Inspect it and
choose fresh target names or explicitly remove only that confirmed unused
partial clone before retrying; the formula never adopts or deletes it itself.

Creation sets menus without Mail Reader/LibreOffice and includes Mousepad;
Trader additionally lists Electrum and Agent lists VS Code. Later applies
preserve other menu choices and add Code to Agent's existing explicit lists;
absent lists keep their normal Qubes inheritance/fallback behavior.
Reapply the family after package upgrades: an upgrade can replace the package
launchers whose Mail Reader visibility and Electrum environment are configured
here. Native menu-sync hooks republish those settings when Salt changes them.

The source template is the recovery baseline. There is no automatic rollback
that removes new templates, reinstalls purged applications or deletes private
data. To retire a family, first identify its dependent qubes and preserve
their data, then change their templates or remove the unused family through
normal Qubes administration. Removing only the visual theme uses the existing
guest HUD rollback and does not undo the Base package/home policy or remove
VS Code and its separate built-in theme. In Trader,
first restore the Electrum package launcher before removing its Qt palette;
the family's launcher setting is reapplied by the next family apply.
