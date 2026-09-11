# Project handoff

Read this document before working on the repository. It summarizes the design
and current implementation so future work does not accidentally undo the
security, portability, or visual decisions already made. The detailed user
documentation remains authoritative for individual states and commands:

- `README.md`
- `salt/qubes_gui/hud/README.md`
- `salt/qubes_gui/guest_hud/README.md`

Always verify the current worktree and history. The prior published baseline is
`a049bff` (`Use shared read-only terminals for dom0 and Xen logs`),
which includes the accepted official i3/glow changes, HUD Bindings, host logs,
Manager and the terminal layout, and these project instructions. The latest integration and validation are recorded at
the end of this document.

## Goal and non-negotiable constraints

This is a portable Qubes OS 4.3 desktop customization managed through Qubes
Salt. The target is a normal Qubes machine whose dom0 has no direct Internet
access. A configured networked UpdateVM and normal TemplateVM UpdatesProxy are
allowed and expected for missing signed system packages.

The complete dependency and offline policy is in `AGENTS.md`. In particular:

- never require direct dom0 networking for normal deployment;
- use the UpdateVM-backed Salt package path by default;
- use only packages in stock, signed Qubes/Fedora/Debian repositories;
- do not add pip, npm, Cargo, Conda, third-party repository, or similar
  deployment dependencies;
- use the Python already shipped by Qubes and its standard library only;
- do not perform a source build or network fetch during target deployment;
- keep all persistent behavior in committed Salt states and assets, not in
  one-off live edits.

The existing explicit `auto` and `direct-dom0` package-transport choices are
development overrides. They must never become necessary or the documented
default. Both `qubes_gui.i3` and `qubes_gui.hud` currently default to
`qubes-updatevm`.

## How the current result was reached

The visual work was developed and checked iteratively on the current Qubes
machine:

1. The base i3 formula and separate black/cyan HUD session were made
   reproducible in Salt, while packaged i3 and Xfce stayed available.
2. Rounded glass, cyan glow, tiled mouse behavior, trusted label-color lines,
   and the trusted close control were added through configuration plus a
   separately deployed, pinned i3 build.
3. GTK, terminal, Rofi, Dunst, and guest-template palettes were aligned to the
   main `#19d3ff` foreground.
4. The first icon pass exposed icons that stayed white and strokes that looked
   too heavy. The solution was a generated single-color theme based on Breeze
   Dark's thinner monochrome and symbolic geometry rather than a collection of
   unrelated hand-drawn replacements.
5. NetworkManager and Tor/Sdwdate indicators still bypassed ordinary icon-theme
   handling because they arrive as guest-owned XEmbed pixels. Qubes tray mode,
   targeted regular icon names, package-owned Whonix status assets, and opaque
   black canvases were handled explicitly.
6. Tor Control Panel remained gray because it is Qt and GTK CSS does not define
   a Qt widget palette. A narrowly scoped `qt5ct` palette was added for the
   Sdwdate service tree and the standalone Tor launcher without changing every
   Qt application or writing AppVM homes.
7. The final changes were moved into dom0 and guest Salt states, supplied with
   strict rollback/ownership handling, audited for reproducibility, committed
   as `b79a78d`, and pushed. The default package transport was changed from
   route-detected `auto` to explicit `qubes-updatevm` for offline dom0 targets.
8. On 2026-09-06, the user chose to retire the custom i3 artifact and its label
   line. The HUD now uses official Qubes i3, with the complete title colored by
   Qubes label. The custom close control was retired with the binary.
9. On 2026-09-07, the user accepted the external glow helper with rounded
   corners and requested it as the default, retiring the preview/fallback
   workflow. The portable HUD now includes that helper as Python source.
10. On 2026-09-11, the user requested Salt/GitHub promotion of the selected
    keyboard-aware HUD Bindings card window. Future HUD logins place it on
    workspace 1; the current workspace 2 preview is preserved during migration.
11. The same day, shared dom0/Xen log panes were added, followed by a central
    block with four terminal panes above Qubes Manager. The complete layout
    starts on workspace 1 at future HUD logins; live previews use workspace 2.
12. The user then requested minimizing additional non-Salt code. The five
    Python log/monitor terminals were replaced with stock Xterm and native
    programs configured by Salt; rsyslog replaces the custom log reader.
    Earlier VTE/reader sections below are historical, superseded by the final
    native-terminal section.

## Repository and deployment architecture

The repository is the source of truth. `scripts/sync-salt-formula.sh` copies
the four formula trees into `/srv/user_salt/qubes_gui`, records hashes in a
sync manifest, removes only unchanged stale managed files, and refuses unsafe
or locally modified targets.

The normal order is:

1. Run `./scripts/sync-salt-formula.sh` in dom0.
2. Apply `qubes_gui.i3` to install and configure the supported Qubes i3 base.
3. Apply `qubes_gui.hud` to install the separate HUD session and dom0 theme.
4. Apply `qubes_gui.guest_hud` to each selected halted TemplateVM.
5. Shut down the TemplateVM and restart its dependent qubes when convenient.
6. Log out and enter **Qubes HUD (i3)** to activate dom0 session or binary
   changes.

`scripts/provision-hud-template.sh SOURCE TARGET` provides the two-phase new
template workflow. `qubes_gui.templates.hud` first clones and tags a target;
the wrapper then applies `qubes_gui.guest_hud` inside it and verifies that the
result ends halted. Source and target names are runtime policy and are not
hardcoded in the formula.

Rollback states are provided at `qubes_gui.i3.rollback`,
`qubes_gui.hud.rollback`, and `qubes_gui.guest_hud.rollback`. They use strict
ownership records and are intended to preserve unrelated user or package
content.

## Implemented desktop behavior

The HUD is an additional login session. It retains packaged i3 and Xfce as
fallbacks and does not restart LightDM or the currently running window manager
when Salt is applied.

The visual language is exact black plus focused cyan `#19d3ff`, with distinct
semantic muted, selection, warning, urgent, and Qubes trust-label colors. The
session includes the black background, compact top bar, 32-pixel inner gaps,
rounded translucent windows, blur, a strong cyan outer halo, an inner rim,
Rofi, Dunst, and matching GTK/terminal styling.

The inner cyan rim is applied after Picom's `default_post_processing()`.
Picom 12.4 synthesizes curved border pixels from the original texture edge;
applying lighting first allowed that step to repaint an unlit arc over the
glow. The shader now lights the finished rounded border while preserving its
premultiplied alpha, 70% window opacity, and antialiased corner coverage. The
outer halo is now rendered separately by `hud-glow`, with a 34-pixel extent
and equal brightness at equal distances from straight and rounded edges. Application corners now use a 12-pixel
radius because official i3 puts title text closer to the left edge; the previous
16-pixel curve clipped the opening bracket. Rofi and Dunst retain 16 pixels.
The cyan effect follows Picom's color processing; the shipped config uses no inversion,
dimming, or reduced maximum brightness.

The HUD session directly executes the official Qubes `/usr/bin/i3`. Its
`client.* <label>` palettes color the entire title, including the trusted
`[qube-name]` descriptor. For example, a green-labeled sys-firewall window has
a green `[sys-firewall] user - Thunar` title. The frame stays dark/cyan. Gray
and black labels use readable neutral shades, and dom0 uses white. The eight
standard Qubes labels are supported; arbitrary custom label RGB properties
from the retired patch are not rendered by the official i3 palette mechanism.

The official Qubes renderer combines the descriptor and application title
as plain text. It cannot color only the descriptor independently through
`title_format` markup: the markup appears literally. The configuration
therefore colors the complete title. The shader protects saturated label
colors and neutral title text from its cyan rim.

The Qubes label property is consumed and painted by the official i3 in dom0.
The previous custom line and close button are removed; `Alt+F4` closes windows.
Titlebar dragging, tiled-edge resize, and Shift plus center-drop swapping are
upstream i3 features and remain enabled through configuration. Fullscreen or
otherwise undecorated windows do not show the titlebar.

The HUD ships no customized compiled binary or source-build workflow. The old
`files/i3-hud` artifact and `source/i3-hud/` tree are removed from the working
formula; their provenance remains in Git history through `b79a78d`. Application
requires Qubes OS 4.3 x86_64, an intact root-owned `/usr/bin/i3` matching the
installed i3 RPM's SHA-256 file digest, and `i3-settings-qubes` exactly
`1.14-1.fc41`. There is no i3 version pin. The settings guard remains because
the committed config and autostart integration derive from that version.
The installed official i3 checks candidate configuration with `i3 -C`.

The legacy `/usr/local/libexec/qubes-hud/i3` pathname is maintained as a small,
hash-pinned shell launcher containing `exec /usr/bin/i3 "$@"`. This lets a
still-running old custom i3 use its native restart command without losing its
original executable path. Fresh installs also receive this compatibility
launcher; new XSessions execute `/usr/bin/i3` directly. Migration accepts only
the exact known legacy artifact or launcher, an exact known adjacent owner
record, and expected root ownership and modes. The owner record is written
first; both known file/record combinations are accepted to recover an
interrupted migration. Unknown or modified content is refused.

Salt does not restart the running window manager. A normal logout/login
activates the official executable; after a successful apply, `i3-msg restart`
can also replace it in place. Isolated tests verified that this preserves the
process ID, supervising parent, clients, geometry, layout, marks, and focus.
Rollback retains the verified legacy pathname and record while `/proc` shows
an old custom executable still running, including a replaced `(deleted)` inode,
to preserve that process's restart path. A subsequent rollback can remove the
retained files after the old process exits or restarts into official i3.

## Thin cyan icon implementation

`manage-cyan-icon-theme` deterministically generates
`/usr/share/icons/Qubes-HUD-Cyan` from the distribution's installed KDE Breeze
Dark theme. It prefers thin symbolic geometry, fixes generic monochrome paint
to `#19d3ff`, creates targeted aliases, writes provenance and a complete
ownership manifest, and safely updates or removes only a validated tree.

The generated theme covers generic actions, status, devices, places, MIME
types, emblems, small categories, notifications, and selected neutral Qubes
tray concepts. It deliberately excludes application-icon directories and
inherits from Adwaita, hicolor, and Breeze Dark. Consequently, application
logos and Qubes VM class, label, security, and warning icons preserve their
identity and security meaning.

Icon themes can affect only icons requested by name. Absolute icon paths,
application-drawn pixels, web content, thumbnails, `_NET_WM_ICON` title-bar
images, and arbitrary client tray images normally bypass the theme. Do not
describe those exclusions as bugs or recolor trust-significant Qubes icons
without an explicit design and security decision.

The generated icon tree is approximately 70 MiB in every root filesystem where
it is installed. Breeze artwork retains its upstream LGPL/CC-BY-SA licensing;
the installed Breeze package contains the authoritative notices.

## NetworkManager and guest tray behavior

Guest-owned legacy XEmbed tray surfaces do not reliably preserve alpha. They
were observed turning transparent pixels into light gray `#f0f0f0` before
dom0 received them. For that reason, the targeted regular NetworkManager
wired, disconnected, Wi-Fi strength, and secure variants are intentionally
rendered on an exact-black canvas.

`manage-trayicon-mode` sets the GuiVM-wide Qubes feature
`gui-default-trayicon-mode` to `border1`. This preserves the guest's source
pixels while retaining a one-pixel trusted VM-label border. A per-qube
`gui-trayicon-mode` remains higher priority. The manager records the exact
previous global value, detects drift, and restores that value—or removes an
originally absent feature—during rollback.

The state never restarts active `qubes-guid` connections, networking qubes, or
anonymity qubes. The tray mode is adopted the next time each qube establishes
its GUI connection.

## Guest and Whonix implementation

`qubes_gui.guest_hud` writes only persistent TemplateVM root paths. It never
writes AppVM or TemplateVM home directories, `/rw`, or private volumes. It
supports Debian-family and Fedora TemplateVMs and refuses dom0, AppVMs,
StandaloneVMs, and unsupported systems.

It installs the GTK 2/3/4 theme, Xfce/XSettings and dconf policy, terminal
palette, fonts, and the same generated cyan icon theme. System locks ensure
that old per-user toolkit theme selections do not hide the HUD; rollback
removes the locks so earlier choices become effective again.

For Debian-family templates that already contain Whonix PyQt5 applications:

- `qt5ct` is installed conditionally only when `python3-pyqt5` and Sdwdate or
  Tor Control Panel are already present;
- the black/cyan Qt palette is scoped to `sdwdate-gui.service` and the
  standalone Tor Control Panel launcher rather than the entire session;
- `manage-sdwdate-tray-icons` replaces only six package-owned Sdwdate/Tor
  status PNGs with deterministic thin icons on black canvases;
- normal/busy states are cyan, Tor warning is amber, and stopped/error is
  pink-red;
- `manage-tor-control-panel-launcher` wraps only the package's launcher and
  forwards all arguments to its diverted original.

Both Whonix managers use `dpkg-divert`, package ownership and hash validation,
transaction records, and explicit installing/removing phases. A foreign
diversion or modified managed file causes a refusal instead of an overwrite.
The scoped Qt configuration avoids `qt5ct` creating a stale copy in an AppVM
private home.

Template changes become visible only after the TemplateVM shuts down and its
dependent AppVMs/DispVMs restart. This includes `sys-whonix`, Sdwdate, and Tor
Control Panel. Plan those restarts rather than interrupting live network or
anonymity qubes during a Salt apply.

## Current dependency ceiling

Do not add to these lists without the explicit approval and documentation
required by `AGENTS.md`.

Dom0 i3 state:

- `i3`
- `i3-settings-qubes`
- `j4-dmenu-desktop`
- `dmenu`
- `dunst`
- `pulseaudio-utils`
- `xss-lock`

Dom0 HUD state:

- `rofi`
- `feh`
- `picom`
- `breeze-icon-theme`

Debian-family guest state:

- `dconf-cli`
- `fonts-noto-core`
- `fonts-noto-mono`
- `kf6-breeze-icon-theme`
- conditional `qt5ct` only for the narrow Whonix case described above

Fedora guest state:

- `dconf`
- `google-noto-sans-vf-fonts`
- `google-noto-sans-mono-vf-fonts`
- `breeze-icon-theme`

The four Python managers import only standard-library modules. They may call
existing system tools for their specific jobs, such as `qvm-features`,
`gtk-update-icon-cache`, `dpkg-query`, and `dpkg-divert`; they do not download
or install Python modules. The separate `hud-glow` renderer also uses only
Python standard-library modules; ctypes loads libX11.so.6, libXrender.so.1, and
libXfixes.so.3, already dependencies of the stock desktop. Its Salt runtime
check verifies those libraries and required symbols without opening X11.

## Portability limits and machine-local policy

The project supports Qubes OS 4.3 x86_64. The base i3 state requests current
packages from the configured official repositories, and the HUD validates the
installed i3 executable against its own RPM metadata without a version pin.
The `i3-settings-qubes` version guard remains as described above: a future
settings package update can require auditing the committed config/autostart
integration before a fresh HUD apply will proceed. No custom binary rebuild
is needed on the target or on a maintainer machine.

The cyan theme is deterministic for a particular installed Breeze source
tree, but the Breeze package itself is supplied by each distribution and is
not byte-pinned here. Different supported distribution or Breeze versions can
produce different underlying glyph bytes while retaining the same selection,
thin-line, and color policy. The manager records the local source signature so
an update is rebuilt and validated rather than silently treated as identical.

The guest state also requires `/etc/dconf/profile/user` to be a regular file
whose active lines include `system-db:local`. It refuses rather than inventing
an unfamiliar dconf profile. Package paths, systemd units, and plugin paths
used by the narrow Whonix integration are validated against the installed
packages and may need a deliberate update when Whonix changes them.

Qube names, template assignments, and dependency topology remain local policy.
The clone wrapper does not reassign `sys-net`, `sys-whonix`, AppVMs, or
DispVMs. Identify every actual backing template and target it explicitly.
Desktop user/group can be set through pillar, and keyboard layout is inherited
from the target machine's saved Xfce or system X11 configuration; no locale or
keyboard language should be hardcoded.

## Safety model

Salt states check destinations with `lstat` before mutation. Managed text
files carry recognizable owner markers. Binary ownership is proven through
adjacent records. The generated icon theme has a manifest covering path,
inode type, mode, owner, hash, and symlink target. Unknown paths, symlinks,
non-regular files, foreign diversions, marker loss, modified managed content,
or ownership drift cause the state or rollback to refuse.

The Python managers use staged writes, atomic replacement, fsync where needed,
and resumable transaction/removal records. Preserve this refusal-first model.
Do not simplify it into unconditional copying or recursive deletion. Rollback
must remove only content whose ownership and integrity the project can prove.

## Current development-machine state

The active `/srv/user_salt/qubes_gui` copy was synced from the repository on
2026-09-11 for HUD Bindings integration, preserving the accepted official i3
and rounded-glow defaults. No running i3 configuration was reloaded: the new
workspace 1 assignment is for the next HUD login. Following the earlier
September 7 unlock-associated crash, Picom and the glow helper had been
restored as PIDs 229591 and 229594. Promotion and diagnostic evidence follow
below. The next paragraphs describe the preceding official i3 migration.

On 2026-09-06, default i3/HUD renders confirmed the
`*_qubes_updatevm` package identifiers; the installed Salt loader resolves
package installation and refresh to Qubes' `qubes_dom0_update` provider.
The retired compiled i3 asset was removed from the managed Salt fileserver.

The live HUD dry-run passed all 37 states, proposing exactly six file changes:
the title palette, Picom rounding, window shader, XSession, legacy ownership
record, and compatibility launcher. The actual apply passed all 37 states;
a repeated apply passed with zero changes. The rollback dry-run also passed
32 states and correctly retained the legacy executable/record while the old
custom process was still running.

The active window manager was then migrated with native `i3-msg restart`.
PID 3455 and its LightDM supervising parent 3053 were retained, while
`/proc/3455/exe` changed to the official `/usr/bin/i3`. After i3bar recreated
its dock, all four application windows retained their original geometry,
layout percentages, marks, and focus. Picom PID 3547 was reinitialized with
`SIGUSR1` to load the final radius/shader. A live screenshot confirmed the
whole `[sys-firewall] user - Thunar` title in green, white dom0 titles, intact
opening brackets, and the absence of the custom line/close control.
LightDM and service qubes were not restarted. No packages were installed.

The already-installed dom0 and `sys-whonix` icon/tray managers were compared
with the committed sources during the preceding glow work and passed their
live integrity checks. The current visual state is represented in Salt,
including the official session migration and corrected inner rim.

## Earlier corner and glow previews (2026-09-06)

The user compared square corners and a roughly 30% smaller native Picom glow,
reducing the old radius from 48 to 34. Neither native configuration equalized
the brightness around corners. Those session-only trials were superseded by
the accepted rounded external helper on 2026-09-07. Their temporary evidence
is historical; normal login now uses the managed helper configuration below.

## Compositor crash after official i3 migration

After the first successful migration capture, Picom PID 3547 aborted at
20:06:43 on 2026-09-06. The next user turn reported that the desktop looked
substantially different. Inspection found no running compositor, explaining
the loss of rounded corners, transparency, blur, and glow; official i3 itself
remained running.

The recorded backtrace and installed executable identify an assertion in
Picom 12.4 `ev_unmap_notify()`, `src/event.c:475`: an unmap event referred to an
unknown window despite the window tree being marked consistent. This is an
X11 event-bookkeeping assertion, not a shader compilation or GLX rendering
failure. A connection to the preceding i3 restart/reinitialization is
plausible but not proven. Do not claim a confirmed upstream fix or change
shader/backend settings without supporting evidence.

A fresh official Picom instance was started with the unchanged managed config
and a temporary diagnostic log at `/tmp/qubes-hud-picom-recovery.log`. PID
89861 restored the rounded glass and glow in a new live capture. Normal login
already starts a fresh compositor through the committed autostart helper;
no new package, source build, or persistent configuration change was needed
for this recovery. Observe stability; a successful startup alone does not
prove the assertion cannot recur.

The user has also asked for the previous visual character, an evenly bright
outer halo, and a label-colored close X while keeping official i3. Official
i3 has no configurable close-button decoration or drawing hook. A separate
overlay helper could keep the official binaries, but would still introduce
custom trusted dom0 UI code. The user has since authorized an external glow
helper, now the accepted default described below; the close-button helper
remains unimplemented.
The installed Picom window-shader hook affects window contents; its shadow
render command does not use that hook, so it cannot directly equalize the
existing external Gaussian halo.

## Validation already performed

For feature commit `b79a78d`, the following checks passed using stock tools:

- `git diff --check`;
- Python AST/compile checks for all four managers;
- confirmation that every Python import is from the standard library;
- shell syntax checks for deployment and Xsession helpers;
- XML and GTK/Qt INI parsing checks;
- Rofi configuration validation;
- GTK 3 and GTK 4 CSS loading with fatal warnings enabled;
- Salt rendering for dom0 i3/HUD init and rollback states;
- confirmation that default rendered dom0 package states use
  `qubes-updatevm`, not direct DNF;
- the cyan theme manager's isolated install/check/validate/remove cycle;
- live dom0 cyan-theme and tray-mode integrity/rollback checks;
- byte comparison and successful cyan, Sdwdate, and Tor manager checks in the
  running `sys-whonix` qube;
- verification that deployment scripts contain no pip, curl, wget, clone, or
  source-build path.

The active Salt tree was audited against the repository during the visual
work, and persistent visual changes were confirmed to exist in the formula
rather than only on the live machine. The subsequent package-transport default
was synced and revalidated during the rounded-border correction described above.

## Official i3 migration validation (2026-09-06)

- Official Qubes i3 configuration validation and shell syntax checks pass.
- Forty-two isolated Salt render cases cover clean targets, legacy and wrapper
  files, interrupted owner/file transitions, missing records, unknown bytes,
  wrong ownership/modes, symlinks, official RPM digest drift, requisites, and
  the default UpdateVM package path. Actual installed Salt also renders both
  changed HUD states from the repository successfully.
- An isolated Xvfb session started the exact retired custom binary with three
  clients and a mixed layout. Atomic replacement with the compatibility
  launcher followed by native restart retained the same PID, parent, clients,
  geometry, percentages, marks, and focus while `/proc/PID/exe` became
  `/usr/bin/i3`. A second restart also succeeded.
- The rollback process guard was exercised with a running temporary ELF, its
  replaced `(deleted)` inode, and its exit: it retained, retained, then allowed
  removing the legacy pathname, respectively.
- An independent deployment audit found no new packages, language
  dependencies, direct-network entrypoints, or source-build path. The retired
  binary and its build workflow are removed. Installed Salt uses atomic
  replacement for `file.managed`, as exercised by the restart test.
- Official i3 with stock Picom GLX reproduces literal title markup and colors
  the complete plain title with the configured label. At application radius
  16, the first bracket loses solid pixels; radius 12 preserves both solid and
  antialiased bracket coverage with the current Noto Sans Mono 9 configuration.
  Centering the title does not solve long-title clipping, so it is not used.
- The final shader preserves all 100 sampled solid title pixels across green,
  gray, black, blue, and purple exactly against a default-shader render at
  matching opacity. The title guard protects both low-chroma purple and
  neutral labels while the dark frame retains its cyan rim. All isolated
  Xvfb/i3/Picom test processes were stopped.

## Remaining customization and update audit (2026-09-06)

The user asked whether Qt or other components still use custom builds. A scan
of all 61 current working-tree files found no shipped ELF/PE executables,
shared libraries, object archives, RPMs, or DEBs. Salt and deployment scripts
contain no source-build, compiler, language-package-index, injected-library,
or package-manager hold path. This describes the working tree after retiring
i3; the removed artifact remains in Git history and the deletion is not yet
committed or pushed.

Live dom0 RPM verification passed for all 33 installed Qt/PyQt/GTK packages
selected by the audit and for qubes-manager, qubes-desktop-linux-menu, Rofi,
Dunst, and Picom. The selected toolkit RPM headers identify Fedora packages
signed with the Fedora 41 key. Qubes Manager and the application menu loaded
only package-owned Qt/GTK files. All five installed HUD executable helpers
are scripts matching the formula, including the legacy i3 forwarding launcher.
No custom Qt/GTK library or theme-plugin binary is supplied by this project.

There is still maintained custom code: the Picom GLSL shader, Python managers,
keyboard helper, session environment hooks, and Qubes-derived autostart script.
The copied i3 config/autostart do not automatically inherit upstream fixes.
The exact i3-settings-qubes1.14-1.fc41 guard refuses a new HUD apply after a
settings-package update until reviewed; it does not block the package manager
from installing updates. Treat reviewing those copied scripts/configuration
as a continuing maintenance obligation, even though the i3 executable itself
uses normal package updates.

Qt customization selects the installed GTK platform adapter in dom0 and
uses the distribution's qt5ct plugin plus a palette in the narrow Whonix case.
The Whonix integration also diverts the Tor Control Panel launcher to a
managed shell wrapper that invokes the packaged original, and substitutes six
Sdwdate/Tor PNG icons. These are package-file overrides rather than rebuilt
Qt, Tor, or Sdwdate programs. They and the generated icon theme still need
compatibility checks on later applies when upstream packages/assets change.

A read-only audit inside already-running sys-whonix passed dpkg verification
for seven relevant Qt5/PyQt5/qt5ct/Sdwdate/Tor Control Panel packages; none was
held. Eight helpers/config/hooks matched the repository, including root owner
and mode checks. The seven project diversions contain six PNGs and the launcher;
their originals match current package file hashes, managed replacements match
their records, and record versions match current installed versions. The qt5ct
shared plugin is package-owned. No guest was started, restarted, or modified
for this audit. Other halted templates were not started or inspected live.

## Known caveat: guest Salt render time

A multi-template `state.show_sls` and a Debian guest `state.sls ... test=True`
were interrupted after producing no result for more than three minutes. Qubes
had reached the temporary management qubes and the execution was spending time
in the many remote Jinja `file.*` and `cmd.retcode` safety probes, including
validation and hashing of the generated Breeze-derived theme. Guest operations
can therefore appear idle for several minutes. All qubes started by those
tests were returned to their prior halted state.

This is currently considered Salt-SSH round-trip amplification, not evidence
of a syntax or live-state failure: the same guest managers were already
deployed, byte-identical to the repository, and passed their live checks in
`sys-whonix`. Nevertheless, future work should treat render performance as a
real maintainability issue. If optimizing it, batch read-only preflight checks
without weakening collision detection, ownership proof, or rollback safety.
Do not leave temporary management qubes or TemplateVMs running after an
interrupted test.

## Activation and testing reminders

- Render and dry-run before apply; repeat successful applies to check
  idempotence.
- Do not restart LightDM from an active dom0 session. Log out normally to load
  a new HUD session. A validated native `i3-msg restart` can switch an existing
  HUD process to the official binary in place after compatibility migration.
- `i3-msg reload` reloads configuration but does not replace the running i3
  executable.
- Apply guest changes only to intended TemplateVMs. Shut the template down
  afterward and restart dependents deliberately.
- A guest render or dry-run can start a previously halted TemplateVM. Check the
  target and temporary management-qube states afterward, especially following
  interruption.
- Never restart `sys-net`, `sys-firewall`, `sys-whonix`, or another critical
  service qube merely to make a visual test take effect. Plan activation with
  the user or defer it to the next reboot.
- Do not treat an icon remaining multicolored as automatically wrong. First
  determine whether it is an application logo, trusted Qubes indicator,
  absolute path, `_NET_WM_ICON`, or other client-owned pixel source.
- Before committing, inspect `git status`, preserve unrelated user changes,
  audit dependencies and network calls, and update this handoff when the
  architecture or known risks change.

The previously user-confirmed state was that the thin icon style looked good,
NetworkManager and Tor/Sdwdate tray backgrounds matched, the Tor Control Panel
used the dark palette, and `sys-whonix` used the new style.
An inner-rim defect was reproduced and corrected on 2026-09-06.
Stock Picom 12.4 GLX renders on isolated Xvfb showed
the dark curved border gaining the cyan rim, with unchanged outer halo,
interior, center, and saturated test colors. Live captures confirmed the same
correction on dom0. The isolated test processes were stopped afterward; no
validation tooling or deployment dependencies were installed.

The user subsequently clarified that the outer halo remains darker around
rounded corners. For the original Gaussian shadow, at equal outside
distances of 2/8/16/24 pixels, an isolated 45-degree corner measured approximately
63/60/57/56 percent of a straight edge's intensity. Stock Picom's Gaussian
area blur causes this difference; the inner-rim shader fix does not change it.
A separate Picom build with a distance-based halo was proposed and prototyped
only under `/tmp`. No additional build packages were approved or installed,
and no customized Picom binary was built or deployed.

The user subsequently chose the official Qubes i3 build to avoid distributing
custom dom0 machine code. The custom label line and close control are retired,
and complete label-colored titles replace their trust-color cue. After
reviewing the security-update maintenance burden, the user explicitly declined
a custom Picom build on 2026-09-06. Keep the packaged compositor; do not resume
the prototype or install its build dependencies without new user direction.
The outer halo intensity difference is addressed by the separate helper below.
A separate custom close-button helper has not been approved or implemented.

## Default rounded external glow (2026-09-07)

The user accepted the rounded helper appearance and requested it as the
portable default, with the temporary preview and recovery machinery removed.
Source now lives in `salt/qubes_gui/hud/files/hud-glow` and `glow_pixels.py`;
standard-library tests live in `tests/test_glow_pixels.py`. The experiment's
supervisor, native-shadow fallback, and preview commands are retired. This
change does not include a custom i3/Picom binary or the discussed close X.

`glow_pixels.py` creates native-endian premultiplied ARGB32 pixels whose alpha
depends only on positive distance from a rounded rectangle. Pixels inside the
window body have zero alpha. The HUD helper defaults are radius 12, extent 34, peak 0.35,
matching the accepted trial and its straight-edge brightness. Picom uses the
same application radius 12, 70% opacity, existing glass shader and blur, with
native application shadows disabled. A dedicated `QubesHudGlow` class rule
leaves glow surfaces unrounded, unblurred, unfaded and fully opaque at the
window level, preserving their pixel alpha. Rofi and Dunst retain native Picom
shadows and radius 16; those popup shadows now use the smaller extent 34.

`hud-glow` uses Python standard-library ctypes and the stock libX11/libXrender/
libXfixes libraries. Their RPM signatures, integrity and baseline desktop
dependency provenance were checked; no packages or Python modules were added.
It uses public X11 managed-window properties/events and parent/frame queries,
without i3 IPC or private i3 data. Each eligible visible application gets one
ARGB surface immediately below its own root frame. An empty input shape is
set before mapping; only the helper's own surfaces are moved, painted,
restacked or destroyed. Application geometry, focus, labels and input handling
are preserved. A per-display X11 selection prevents duplicate helpers.

Per-surface pixels are limited to 64 MiB and aggregate visible surfaces to
128 MiB before compositor copies. Invalid geometry is skipped and exceeding
the aggregate allocation limit stops the helper. Radius is clamped to frame
dimensions. Hidden, fullscreen and destroyed clients lose their glow. The
helper exits when the compositor disappears. Very large resize uploads remain
a performance limit. This is custom trusted dom0 code requiring maintenance
and compatibility testing despite retaining official system binaries.

Salt installs root-owned `hud-glow` (0755) and `glow_pixels.py` (0644) with managed
markers, collision guards and AST checks. A no-DISPLAY `hud-glow --check`
validates all required runtime libraries and symbols before Salt installs the
Picom configuration or autostart hook. Normal HUD login starts official Picom
with the explicit managed config, then the Python helper, then normal Qubes
XDG autostart. There is no preview supervisor, automatic restart, or automatic
switch to native application shadows. General HUD rollback removes the owned
helper files and startup hook without restarting the live desktop.

Original isolated Xvfb tests used official i3/Picom on display `:91`, with
artifacts under `/tmp/qubes-hud-glow-helper-test`. Square and radius 12 renders
matched straight-edge brightness at distances 2/8/16/24 pixels. Across four
edges and twenty corner angles, corner samples differed by less than one
8-bit blue code. Seventeen lifecycle checks covered overlap, focus restacking,
actual click-through to the lower application, movement/resizing, workspaces,
fullscreen, scratchpad, unmap/remap, destruction and helper SIGKILL cleanup.
An interior region more than 16 pixels from the frame remained identical;
existing background blur samples the new halo near the edge, producing small
expected differences there. Event-driven wakeups plus one-second reconciliation
used approximately 0.4% of one CPU with four idle clients, and about 21 ms for
movement/workspace changes in the isolated test.

The first live helper trial ran overnight, but stock Picom 12.4 aborted on
2026-09-07 at 12:17:49 CEST in `ev_unmap_notify`, `src/event.c:475`, following
an unmap for unknown window `0x02a00004`. Logs and the coredump confirm the
same assertion seen before the helper existed; its trigger remains unproven.
The experimental supervisor restored native shadows, explaining the user's
report that the display looked unchanged. Reactivating the same tested helper
restored the accepted appearance; the subsequent radius 12 trial was also
accepted. The stock Picom assertion remains an outstanding stability issue;
promotion to the default does not claim to fix it.

The promotion preserves the rendering and event loop. Ten standard-library
tests pass, including equal-distance corner brightness, transparent body,
premultiplication, symmetry, falloff, allocation limits, and runtime-check
behavior (root/no DISPLAY, no X11 calls, missing-library/symbol rejection).

Promotion validation and deployment completed on 2026-09-07:

- The final managed config and no-argument helper produced a PNG identical
  to the accepted radius-12 isolated render. The extracted normal autostart
  launch block, display-free runtime check, input transparency, geometry/focus,
  movement, workspace hide/restore, and close cleanup passed. Evidence:
  `/tmp/qubes-hud-glow-helper-test/promoted-default/normal-startup-results.json`.
  Under Xvfb, daemonized Picom first rendered an existing static fixture after
  its first damage event; foreground Picom rendered immediately. Normal login
  starts applications after the compositor. All isolated processes were stopped.
- Installed Salt rendered 40 HUD init and 34 rollback states with default
  pillar; 36 isolated ownership/inode/mode/marker cases and all requisite checks
  passed. The native loader resolves package installation, refresh and removal
  to `qubes_dom0_update`. Evidence: `/tmp/hud-glow-installed-salt-render.json`
  and `/tmp/hud-glow-salt-fixtures.json`.
- Formula sync succeeded. The live dry-run passed 40 states; apply passed all
  40, changing only the two new Python assets, Picom config and autostart hook.
  A repeated apply passed all 40 with zero changes. General HUD rollback dry-run
  passed 34 states, including removal of both new owned assets. Results are
  `/tmp/qubes-hud-default-{dryrun,apply,idempotence,rollback-dryrun}.json`.
- The temporary supervisor was stopped and its compositor replaced with
  official Picom PID 192757 using the installed config. Installed `hud-glow`
  PID 192758 runs with no options, the same defaults used on normal login.
  Official i3 remains PID 3455; the complete i3 tree was unchanged. Four mapped
  glow surfaces are directly below their correct frames, match the previous
  geometry, and have empty input shapes. Both startup logs are empty. Evidence:
  `/tmp/qubes-hud-default-live-mcv1p715/{activation,validation}.json`.
- The live screen was already locked before this switch, so its before/after
  captures show the lock screen, not a new visual confirmation of the desktop.
  The lock was left intact. Visual equivalence is established by the isolated
  render and the user's preceding acceptance of the same renderer/defaults.
- `experiments/glow-helper/` source and its supervisor/fallback workflow were
  removed after promotion. Historical temporary test artifacts are unnecessary
  for deployment. No new packages, network requests, custom builds, i3/LightDM
  restarts or qube restarts occurred. The deployment-entrypoint audit found no
  added network, build or language-package path; default dom0 transport remains
  UpdateVM-backed.

## Unlock-associated compositor crash investigation (2026-09-07)

The user reported both glow and transparency gone after locking/display power
saving. Neither Picom PID 192757 nor helper PID 192758 was still running.
The helper's log reports `Compositor disappeared; removing glow`; the coredump
confirms that official Picom 12.4-1.fc41 aborted at 18:53:48 with the same
`ev_handle` stack location as the earlier `ev_unmap_notify` assertion. This
explains the simultaneous loss of transparency, blur, rounding and external
glow. The helper's exit followed compositor loss.

Journal timestamps strongly associate all three recent crashes with unlocking:

- September 6, 20:06:43: successful `unix_chkpwd` authentication at .270,
  Picom abort at .288 (18 ms later), before the glow helper existed.
- September 7, 12:17:49: authentication at .897, abort at .900 (3 ms later).
- September 7, 18:53:48: authentication at .716, abort at .719 (3 ms later).

There is no corresponding suspend/resume event in the inspected interval.
Display power management is enabled with 600-second timeouts, but physical
DPMS transitions were not reproduced; do not claim that power saving itself
causes the crash. The correlation identifies a longstanding lock/unlock
interaction involving stock Picom, rather than a glow-specific render defect.
The exact event sequence behind the window-tree inconsistency remains unknown.

The unmodified local Picom 12.4 `src/event.c:462–478` checks its window tree
before applying any rendering/backend rules and asserts on an unknown unmap
while the tree is considered consistent. Its asynchronous initial tree-import
code is a possible area of investigation, not a confirmed cause. No supported
configuration workaround was found; changing blur, vsync, damage handling or
window exclusions was not justified by this evidence.

Both effects were restored while the desktop was unlocked by starting official
Picom with the existing installed config and then the installed no-argument
helper. Picom PID 229591 and helper PID 229594 are active, the complete i3 tree
is unchanged, both logs are empty, and a live screenshot confirms the accepted
rounded halo, glass and title colors. Evidence is in
`/tmp/qubes-hud-compositor-loss-dfeiqmit/`, including the crash journal,
before/after trees, process logs and `restored.png`. RPM verification passed
for Picom and i3lock. No installed configuration, dependency, package, lock or
power policy was changed; no recovery supervisor was reintroduced.

Isolated tests on Xvfb with stock Picom and the helper did not reproduce the
crash through ordinary or preexisting fullscreen override-redirect lock
surfaces, nested children, or repeated map/unmap/destroy cycles. The actual
packaged i3lock was also tested on the private display, both before and after
compositor startup, by unmapping only its identified test surface and stopping
the test process. No passwords or real authentication were used, and the live
locker was not touched. Starting Picom while a locker is already mapped is
therefore not established as sufficient to cause the crash. True authenticated
unlock and the physical Xorg/DPMS environment remain the reproduction gap.
The bounded report at
`/tmp/qubes-hud-glow-helper-test/lock-lifecycle/summary.json` records six
synthetic cases (43 cycles) and six actual-i3lock cases without a crash. Xvfb
does not provide DPMS. All owned test processes were stopped and the private
display socket removed. No deployment states or assets changed in this
investigation; the preceding default render/apply validation remains applicable.
The restored appearance is not a permanent fix for the underlying crash.

## Temporary workspace 2 layout test (2026-09-09)

The user requested a layout trial on workspace 2 while keeping workspace 1
unchanged, and accepted four new temporary dom0 terminals as the first test.
Workspace 2 did not previously exist. No persistent startup configuration or
Salt assets were changed; this trial does not yet launch applications at login.

Native i3 `append_layout` loaded a vertical split with two equal-height rows.
The top row has C, D and A in three equal-percentage horizontal slots; B spans
the full bottom row. Each placeholder matches only class `QubesHudLayoutTest`
and the exact role `qubes-hud-layout-test-A`, `-B`, `-C` or `-D`. Four separate
`xfce4-terminal --disable-server` processes filled those slots. Existing
terminal processes and windows were not reused or moved. The installed i3
and terminal support this without new packages or custom binaries.

Before live activation, an isolated i3 test with actual terminals launched
out of order verified matching, positions and preservation of workspace 1.
Its evidence is `/tmp/qubes-hud-layout-isolated/results.json`; all isolated
processes were stopped and the private X display socket removed.

Live evidence, candidate JSON, runner, process IDs and before/after i3 trees
are in `/tmp/qubes-hud-layout-test-kdmzxafa/`. The workspace 1 tree retained
all window IDs, nested containers, geometry, percentages, borders, marks,
application fullscreen states and focus ordering. Only normal workspace
visibility/focus state changed while visiting workspace 2. The test initially
focused A; workspace 1 was selected again by the subsequent read-only check.
`desktop-after-test.png` therefore shows workspace 1, not the test layout.

Live rectangles (x, y, width, height) are C=(44,74,584,465),
D=(660,74,600,465), A=(1292,74,584,465), and B=(44,571,1832,465).
Native i3 inner-gap accounting gives the middle top frame 16 more visible
pixels despite equal one-third allocations; the two rows have equal heights.
The terminals remain on workspace 2 for evaluation, accessible with Super+2;
Super+1 returns to the original workspace. They are ordinary closable windows.
No compositor, window-manager, LightDM or qube restarts occurred, and no
deployment entrypoints or dependencies changed. Persistent app selection,
layout proportions and login startup remain future choices after this trial.

## Temporary graphical shortcut references on workspace 2 (2026-09-09)

The user confirmed the four-terminal layout worked, then requested a full-height
left-hand Qubes/i3 shortcut reference. It must be an ordinary framed, focusable
dom0 application with the normal `[dom0]` header and label styling, not a
terminal. The user asked to compare several formats on workspace 2 before
choosing. Three temporary graphical windows are now running there, ordered
left to right: `Shortcuts - Table`, `Shortcuts - Cards`, `Shortcuts - Search`.
All support filtering and scrolling. Their 45 shortcut/mouse entries in eight
sections reflect the installed HUD i3 bindings, the active German keyboard,
and Qubes clipboard defaults. In particular the physical lock binding is
shown as Super+Shift+O and the directional letter keys as J/K/L/Ö. The entries
are reference text and do not execute the described commands.

The prototype sources, shared `shortcuts.json`, content provenance, layout,
runner, process records and validation are in
`/tmp/qubes-hud-shortcut-options/`. These files are temporary comparison
artifacts, not deployment inputs or a new startup requirement. At this stage
no GUI format had been selected; the later choice is recorded below.

- `gui.py` supplies the table and cards using Python's standard-library
  `ctypes` with the existing GTK3/GLib/GObject C libraries. It imports no Python
  GUI modules and creates normal decorated GTK top-level windows. Installed
  `gtk3 3.24.43-2.fc41` and `glib2 2.82.5-1.fc41` belong to the stock desktop
  dependency set; Fedora signatures and RPM integrity checks passed. No
  package, Python module, runtime or compiled binary was added.
- `search.py` and `search.rasi` use the already-declared official Rofi 1.7.8
  in `-normal-window -dmenu` mode. A separate private PID file leaves the
  ordinary launcher available. Acceptance bindings are disabled and output
  discarded. The wrapper verifies its newly launched child PID and executable
  before setting only that child's class, role and title. This distinguishes
  the normal reference window from the existing Picom Rofi-popup rule.
  Initial class `Rofi` and exact title `rofi - Shortcuts` fill its i3 slot
  before renaming to class `QubesHudShortcutsSearch`.
- Official i3 supplies all three frames and dom0 headers; no Qubes identity
  properties or replacement title bars are fabricated. GTK classes are
  `QubesHudShortcutsTable` and `QubesHudShortcutsCards`.

A new three-column group occupies 65% of workspace 2 on the left. The original
four-terminal subtree remains intact on the right, including its window and
container IDs and C/D/A-over-B structure. The references' frame rectangles
are Table=(44,74,362,962), Cards=(438,74,379,962), and
Search=(849,74,379,962). Their XIDs are respectively 85983235, 88080387 and
92274702. GTK PIDs are 512724 and 512730; wrapper PID 512736 owns Rofi PID
512737. They are ordinary closable applications, not autostart services.

Isolated tests verified readability at 340–344px widths, searching, scrolling,
normal focus and close behavior, real i3 headers, and the absence of global
Rofi keyboard/pointer grabs. The append/swap/resize procedure preserved the
original terminal subtree in an isolated i3 test before live use. Evidence is
in `/tmp/qubes-hud-shortcut-gtk-test/` and
`/tmp/qubes-hud-rofi-reference/final-results.json`; all owned isolated
processes were stopped and their private X display sockets removed.

Live `validation.json` confirms all three slots filled, normal 3px frames,
the 65% left group, preservation of the four original terminals, and unchanged
workspace 1 window IDs, nested layout, geometry, borders, marks and focus
ordering. Workspace 2 is selected. The screen had locked during preparation,
so `live-workspace2.png` captures the lock surface rather than the new desktop;
do not treat it as live visual proof. The lock and power policy were left
intact. Visual validation used the isolated renders; the user can inspect the
live comparison after unlocking, with Super+2 (Super+1 returns to workspace 1).

No Salt assets, startup configuration, deployment dependencies, network paths,
compositor or window-manager settings changed for this comparison. No
compositor, i3, LightDM or qube restarts occurred. The deployment audit found
the eight relevant Salt files still identical to their deployed copies, and
scripts/default pillar unchanged. Default transport remains UpdateVM-backed;
the preceding installed Salt render/provider evidence remains applicable.
The outstanding unlock-associated Picom crash remains a separate unresolved
issue. A chosen reference format and final layout would need committed Salt
assets and deployment validation before becoming persistent.

## Selected card reference and cyan text (2026-09-10)

The user selected the second, grouped-card `Quick reference` format, requested
the headline `HUD Bindings`, and specified cyan shades instead of white text.
The card prototype now uses `HUD Bindings` for both its content headline and
application title. Headings use `#19d3ff`, key combinations `#57dfff`,
descriptions `#32bdd8`, and hints/footer softer saturated cyan shades. Entry
text, selected text, cursor, icons, menu labels and tooltips also have explicit
cyan colors. GTK3's named `placeholder_text_color` is defined because entry
foreground alone does not color its placeholder. These are application-local
styles; official i3 still draws the trusted `[dom0]` title in the normal dom0
label color, consistently with the other windows.

Only the chosen card reference remains, full height at the left of workspace
2 with a 25% allocation (frame 44,74,426,962). The table and Rofi previews were
closed normally. The four temporary terminals retain their original subtree
on the remaining 75% at right, and workspace 1 is unchanged. The updated
reference is PID 607101, XID 81788931, container 110144761296992, class
`QubesHudShortcutsCards`. No technical preview mark is displayed in its title.

Updated source remains `/tmp/qubes-hud-shortcut-options/gui.py`; activation,
before/after trees, process information and validation are under its
`chosen-cards/` subdirectory. Installed GTK3 accepted the CSS without warnings,
the live application log is empty, and the unlocked desktop capture confirms
the cyan card content and full-height left placement. The 45 reference entries
and filtering behavior are unchanged. No new tests or packages were needed
for this text/style adjustment.

This remains the workspace 2 design trial. Choosing the format has not enabled
login startup or installed the reference through Salt. No deployment assets,
dependencies, transport defaults, compositor or window-manager configuration
changed; prior default Salt render/provider checks remain applicable. The
selected format still needs repository assets and Salt integration when the
user proceeds from this layout trial to persistent startup.

## Keyboard-aware HUD reference (2026-09-10)

The user requested that the selected card reference follow the currently
chosen English or German keyboard, and that actual shortcut combinations use
the headline's highlight cyan. All 45 key labels now use exactly `#19d3ff`.
The subtitle names the active keyboard, and the panel updates in place within
approximately one second of a layout, variant or active XKB group change.
Search text is retained and its matching rows are recalculated for the new
legends. Interface descriptions remain in English.

The temporary `keyboard_layout.py` beside `gui.py` uses standard-library
ctypes and the existing `libX11.so.6`. Each snapshot reads XKB group/rules and
a fresh keyboard map, avoiding stale translations after a map replacement.
It translates unshifted physical key legends, ignores held modifiers/Caps
Lock, and retains explicit Shift in shortcut text. It does not observe key
events, grab input, change the keyboard, or run subprocesses. Supported layout
codes are `us`, `gb` and `de`; actual configured variants are read from the
map. Unknown/unsupported layouts show an explicit unavailable state rather
than retaining German labels.

`shortcuts.json` now annotates 29 physical-binding rows with keycode templates,
including compound shortcuts and resize-mode keys. For standard layouts,
keycode 47 displays `Ö` in German and `;` in English. Descriptions no longer
assume German. Qubes/application clipboard shortcuts remain symbolic. The
two scratchpad rows additionally resolve i3's `minus` symbol in the first
configured group, then display that physical key's active-group legend. This
handles `us,de` with German active (`ß`) and `de,us` with English active (`/`).
Unqualified i3 bindings apply across groups while symbolic bindings translate
in the first group, as documented in the
[official i3 guide](https://i3wm.org/docs/userguide.html#keybindings).
No actual HUD keybinding was changed.

Private-display backend checks covered US, UK, German, variants, both active
groups, map replacement on one connection, and unsupported layouts. An
integrated GTK check verified the same window across DE/US/group changes,
the retained `Ö` search with 3→0→3 matches, empty logs and normal close.
Computed GTK colors for the headline and every key label were exactly
RGB(25,211,255). A follow-up backend check verified both scratchpad group
orders; all dynamic templates, including unavailable symbol handling, parsed
successfully. Evidence is in `/tmp/qubes-hud-keyboard-test/` and
`/tmp/qubes-hud-bindings-layout-test/`; all isolated processes were stopped.

The updated live reference is PID 608794, XID 81788931, container
110144761296992. It retains the 426×962 left frame on workspace 2. The final
activation/validation, empty application log and unlocked screenshot are in
`/tmp/qubes-hud-shortcut-options/layout-aware/`. Workspace 1 and every other
window's geometry/borders/fullscreen state were unchanged. The live keyboard
remains German; English switching was tested only on the private display.

This remains the workspace 2 prototype with no Salt/autostart promotion. No
packages, modules, compiled binaries, network deployment paths or system
configuration were added. All nine Salt/Jinja files still match deployed
copies, and deployment scripts/default pillar are unchanged. No Salt state
was affected, so the preceding default UpdateVM render/provider validation
remains applicable. No compositor, i3, LightDM or qube restart was performed.

## Salt promotion and publication (2026-09-11)

The user authorized adding HUD Bindings to the Salt stack and publishing the
accepted rice to GitHub. They specifically requested workspace **1** after
reboot and for future logins, while leaving the currently occupied workspace
1 alone. This supersedes the temporary workspace 2 startup proposal.

The permanent card implementation is now in
`salt/qubes_gui/hud/files/hud-bindings`, `bindings_keyboard.py`, and
`bindings.json`, installed under `/usr/local/libexec/qubes-hud/`. The retired
table/Rofi comparison paths are not deployment inputs. The application title,
headline, cyan colors, 45 entries, filtering and live EN/DE keyboard behavior
are preserved. The new managed class is `QubesHudBindings` with instance/role
`qubes-hud-bindings`.

The normal HUD autostart helper runs `hud-bindings --background` once at login.
Native i3 rules assign it to workspace 1 and avoid changing focus from another
workspace. It fills an empty workspace; when normal applications open there,
its containing horizontal split gives it a quarter allocation. This is native
i3 insertion/resizing, not a layout reconstruction daemon. Existing complex
layouts retain their ordinary insertion behavior. None of the four temporary
layout-test terminals is autostarted. `qubes-hud-bindings.desktop` supplies a
launcher entry, visible for the session's actual lowercase `i3` desktop name
and the uppercase alias. A first manual launch focuses its own XID through a
bounded public i3 IPC request after mapping; a repeated manual launch focuses
the existing reference. Background invocations preserve focus.

A private per-user/display flock in `XDG_RUNTIME_DIR` prevents duplicates.
The directory and lock file must have the expected owner, private modes and
regular inode type; linked lock files are refused. Closing the app or failing
window initialization releases the lock. No additional process supervises it.
GTK/GDK/GLib/GObject and X11 are the stock desktop libraries; only standard
Python modules and the adjacent project keyboard module are imported. No
package, module download, custom compiled binary or system-library change
was introduced.

Salt installs the helper as root 0755, the keyboard module/data/desktop entry
as root 0644, with owner markers and inode/UID/GID/mode collision guards.
Staged Python uses AST validation; staged JSON runs the helper's schema and
template checks. `hud-bindings --check` resolves all required library symbols
and reads the data without opening a display, creating locks or running i3.
Startup and launcher installation depend on successful validation. Rollback
removes the owned startup hook, launcher, application and support files in
dependency order without stopping live desktop processes.

Validation used stock installed tools:

- All 23 repository unit tests passed (13 bindings, 10 glow), including
  malformed data, bounded reads/templates, missing runtime symbols, no native
  calls during headless checks, private-lock refusal and duplicate behavior.
- 102 isolated Salt ownership/partial-install/requisite cases passed.
  Installed Salt rendered 45 init and 38 rollback states; package install,
  refresh and removal still resolve to `qubes_dom0_update`. Evidence is in
  `/tmp/hud-bindings-{salt-fixtures,installed-salt-render}.json`.
- Private official-i3 tests confirmed background workspace-1 assignment,
  preserved existing-workspace focus, normal 3px framing, quarter width as
  neighbors arrive, first/repeated manual focus, duplicate prevention,
  close/reopen, DE/EN switching and exact `#19d3ff` heading/key colors. Evidence
  is in `/tmp/qubes-hud-bindings-promoted-test/`. All test displays/processes
  were stopped. The desktop entry's visibility was also checked through the
  installed GDesktopAppInfo implementation in the real session environment.
- Final sync, dry-run and apply passed all 45 states; the repeated final apply
  passed all 45 with zero changes. Rollback dry-run passed 38. The initial
  integration added four assets and updated the autostart/i3 files; the final
  pass refined only the helper and launcher. Full logs are under
  `/tmp/qubes-hud-bindings-deploy/`.

No running i3 config was reloaded and no compositor, LightDM or qube was
restarted. Two Qube Manager windows closed during the Salt validation interval,
so its whole before/after tree snapshots are not claimed identical; Salt made
only the recorded file changes. A fresh baseline was used for live reference
replacement afterward. The installed helper replaced only the old reference
on workspace 2, preserving its 426×962 frame at (44,74) and every other window's
geometry; the complete workspace 1 signature matched. Its PID is 773889,
XID 67108867, container 110144761320256. Evidence is
`/tmp/qubes-hud-bindings-deploy/live/validation.json`. Future workspace-1
startup takes effect when the saved i3 configuration is loaded at the next
HUD login/reboot. The current preview intentionally remains on workspace 2.

The publication includes the previously accepted, uncommitted official-i3
migration and rounded-glow implementation so the remote formula matches the
installed rice. It removes the old compiled i3 artifact and maintainer build
tree, retaining their provenance in Git history. The existing upstream Picom
unlock crash caveat is unchanged; this change does not claim to fix it.
No credentials or test screenshots are included in the repository.
The maintainer GitHub transport uses the existing SSH key/known-host trust and
a temporary `core.sshCommand` ProxyCommand through already-running `sys-net`
and its stock `socat`. DNS/TCP occur in that qube, with strict host-key checking;
dom0 does not make a direct network connection. This is only a publication
transport and is not called by any deployment state or script. No SSH
configuration, credential or package was added or changed.


## Shared HUD log panes (2026-09-11)

The user requested two full-height log panes to the right of HUD Bindings,
using its normal framed dom0 window and cyan styling. The far-right pane is
Xen; the middle pane is dom0, including host-recorded Qubes activity. They
explicitly requested short, auditable, shared source and bounded recent
history, excluding journals or other logs from inside guest qubes.

`hud-bindings` remains the shared executable and now accepts
`--view bindings|dom0|xen`. Window creation, CSS, framing, per-view/display
singleton locking, focus and lifecycle are shared. The bindings content and
keyboard behavior remain in their original builder/module/data. Both log
panes use one GtkTextView builder and the adjacent standard-library-only
`hud_logs.py` reader. All content is literal text; no markup or terminal
controls are interpreted. Control/bidi characters are visibly escaped and
malformed UTF-8 replaced. No new binaries, Python modules or packages are used.

Each text buffer retains at most 600 complete lines and 262144 characters;
long source lines and each update are capped. It follows while at the bottom,
preserves a visible text mark when scrolling back, and resumes at the bottom.
Pruning can expire the oldest viewed text; this is recent scrollback, not a
full archive. No log copy is written to disk. Sources are interleaved as read,
without pretending their independent clocks/history form an exact total order.

The dom0 reader runs fixed stock `journalctl --boot --lines=80 --follow
--no-pager --output=short-iso --quiet`, including accessible system and user
journals from dom0. It also follows the fixed Xen hotplug/domain-builder paths
and strictly named `guid.*.log`, `qrexec.*.log`, `qubesdb.*.log` files under
`/var/log/qubes`. File histories can predate the current boot. New files,
inode replacement and truncation are checked; source count, directory scans,
read bytes, partial lines and output are bounded. Closing the pane reaps its
journal process and closes file descriptors. Missing/unreadable sources,
limits and journal exit are visible in the footer instead of silent failure.

The Xen reader follows only `/var/log/xen/console/hypervisor.log`: stock
xenconsoled already timestamps and records this genuine hypervisor console.
It is the only below-dom0 log stream found on this system. `xl dmesg` exposes
the same source and is not combined a second time or cleared. Guest console
files (`guest-*.log`), guest journals, update logs and management-VM execution
logs are deliberately outside both allowlists. Xen daemon and hotplug
messages run in dom0 and belong in the dom0 pane. Quiet Xen output is normal.

The current desktop user's existing wheel/qubes access suffices for the
journal and included files. No GUI or reader runs as root, no sudo command is
used, and no ACL/group/security-policy changes are made. Root-private libvirt
per-domain detail files remain inaccessible and are identified in the footer;
accessible libvirt/toolstack journal messages are still included. Journalctl supplies only records accessible to the desktop user; reduced
permissions on another machine can limit coverage. This is
custom trusted dom0 source using stock libraries, not a new official Qubes app.

Salt adds the root0644 log module with ownership/marker/inode/mode guards and
AST checks, plus HUD Dom0 Logs and HUD Xen Logs desktop launchers. The module
is installed before shared-helper/data/runtime checks; `--check` does not
open logs or a display. Rollback removes startup/launchers before the shared
helper/modules without stopping active desktop processes. Native i3 assigns
all three types to workspace 1 at future logins, placing Bindings left at 25%
and Xen at right as they arrive. Remaining widths use normal i3 allocation;
existing manually nested layouts are not reconstructed by a daemon.
Autostart invokes the same helper for each view with `--background`.
The four old layout-test terminals are not made persistent.

Validation used only installed tools:

- All 34 repository unittest cases passed, including ten new log tests for
  allowlists, append/truncate/replacement/new files, fair bounded reads,
  malformed/control text, source limits, huge error lists, nonregular and
  symlink refusal, journal failure/exit and child cleanup. Runtime validation,
  i3 config validation, shell syntax and `git diff --check` passed.
- Actual stock GTK tests exercised initial tail-follow, scroll pause/resume,
  preserving the visible line through append/pruning, both buffer limits,
  literal markup, read-only text and normal close cleanup. The bindings pane
  retained its same-window DE/EN updates and all 45 bright-cyan key labels.
  All six application arrival orders produced Bindings/dom0/Xen order,
  full-height panes, a quarter-width Bindings pane and preserved the existing
  other workspace's tree/focus. Remaining native i3 fractions vary by arrival
  order. Evidence is under `/tmp/qubes-hud-logs-test/`; private test displays
  and owned processes were stopped.
- Seventy isolated Salt ownership/partial-install/requisite cases passed.
  Installed Salt rendered 48 init and 41 rollback states; package install,
  refresh and removal still resolve to `qubes_dom0_update`. No deployment
  entrypoint adds a direct-network, guest-access, build or package path.
  Evidence: `/tmp/hud-logs-{salt-fixtures,installed-salt-render}.json`.
- Formula sync, live dry-run and apply passed all 48 states. Exactly six
  files changed: the new reader and two launchers, shared GUI, autostart and
  saved i3 config. A repeated apply passed with zero changes; rollback
  dry-run passed all 41 states. All nine relevant installed assets match the
  repository. No running i3 config reload or desktop/qube restart occurred.
  Deployment results are under `/tmp/qubes-hud-logs-deploy/`.
- A bounded unprivileged reader smoke test found 156 matching readable dom0
  files plus the live journal, and the single Xen hypervisor file. The file
  cap is 256, above current usage; no matching file was omitted by the cap.
  Only counters/source status were saved, not log contents. Libvirt's private
  detail files remain unreadable as described above.

Live activation completed with the installed helper:

- The four exact `QubesHudLayoutTest` A/B/C/D windows were rechecked for their
  original XIDs/roles/PIDs and a sole sleeping foreground bash with no jobs.
  They closed normally only after both log panes filled their exact new slots.
  A private matching-layout test had verified this procedure and refusal when
  an extra window or a busy terminal was present.
- The existing HUD Bindings process/window was retained, including its
  426x962 frame at (44,74), its left containing subtree, and focus. It uses the
  updated shared source on its next launch. The new installed dom0 pane is
  PID784852/XID88080387, frame (502,74,679,962); Xen is PID784853/XID90177539,
  frame (1213,74,663,962). Both run as uid1000 and have empty application-error
  logs. Their readers hold the expected source descriptors.
- The complete fresh workspace 1 signature was unchanged. Workspace 2 now
  contains exactly the three HUD windows in the requested order. Future
  startup remains workspace 1; the running i3 config was not reloaded.
- Evidence is `/tmp/qubes-hud-logs-deploy/live/validation.json`, with before/
  after trees and process records. The screen was locked during final capture
  checking, so no live log screenshot was taken and the lock was left intact.
  The isolated synthetic render established the shared appearance; actual
  live visual acceptance remains for the user after unlocking.

The log-pane source, Salt integration, documentation and tests were committed
and published as `dec2ba1`. No raw log contents or test screenshots are
included in the repository. The existing Picom unlock-crash caveat remains
unrelated and unchanged.


## Complete dom0 workspace: Manager and four terminals (2026-09-11)

The user requested a central block between Bindings and the two journals:
four terminals across its upper half, with Qubes Manager below. Bindings and
both log panes remain full-height. Native i3 allocations are 18% / 50% / 16% /
16%; the upper and lower central halves each receive 50%, with four equal
upper slots. At 1920x1080 with the current gaps, measured frame widths are
294px for Bindings, 205px for each upper terminal, 916px for Manager, 271px
for dom0 logs and 255px for Xen. Manager's 910px client exceeds its actual
863px minimum width. Other resolutions naturally change those visible widths.

The top row, left to right, is an ordinary interactive stock Xfce terminal,
standard dom0 `top --secure-mode`, `xentop --delay=2 --full-name`, and
`systemd-cgtop --delay=2 --depth=2`. No `qvm-top` or `qubes-top` is installed.
An optional clarification about “Qubes top” received no answer before
implementation, so standard dom0 top is the stated assumption. Xen domain
usage is available in the adjacent xentop pane. Existing system accounting
and desktop-user permissions determine visible metrics; neither is changed.
The first terminal and the official Qubes Manager remain interactive.

`hud-bindings` now also accepts `--view top|xentop|cgtop`. All six custom panes
share its framing, cyan CSS, singleton locking, focus and lifecycle. The
adjacent `hud_monitor.py` builds all three monitor bodies with ctypes calls
to stock GTK3/VTE/Pango. VTE is already required by the installed stock Xfce
terminal. No package, Python module, runtime, custom binary, source build or
permission change is added. Monitor executables and Manager/Xfce launchers
match their installed official RPM digests; xentop/cgtop were verified to
work as uid1000 without sudo. Custom code remains trusted dom0 source subject
to review, while the executables and libraries retain normal signed updates.

Monitor commands use fixed argument arrays and no shell. Native VTE input is
disabled before spawn, with drag destinations removed, hyperlinks/sixel/bell
disabled, all ANSI colors mapped to cyan shades, font Noto Sans Mono 8 and
200 scrollback lines. Selection/copy/focus/scroll remain available. A native
viewport preserves at least 1280px of terminal width inside the narrow pane;
horizontal scrolling reveals intact native tables. Fullscreen reveals more
columns and larger windows expand the terminal. VTE's native PTY spawn/watch
handles child lifecycle without a Python post-fork callback. Cleanup uses a
pidfd where available, bounded termination and native GLib reaping. There is
no interactive shell fallback after failure or exit.

New `hud-workspace` embeds the eight-slot i3 JSON and launches fixed programs
through public IPC, then exits. It uses a private per-display lock, exact
classes/roles for HUD panes and the official Qt `-name qubes-hud-manager`
instance argument for Manager. Manager's class is translated, so matching it
would be unreliable. All swallow rules require normal windows. i3 ignores
split-container marks in appended JSON; the helper therefore locates the
unique new group by all eight leaf marks and explicitly marks it via IPC.
Real i3 placeholders have XIDs before they contain applications; completion
checks actual app properties, and old-pane migration only closes verified
empty placeholder containers after swapping. The original three panes retain
their XIDs, processes, buffers and search state.

Default startup is workspace 1. Empty targets or the previous three-pane HUD
can be assembled; foreign windows, duplicate/fullscreen panes or HUD apps
elsewhere cause a no-op. The completed layout's parent mark prevents repeat
startup from rearranging the user's windows. Prior focus is restored. The
helper is not a layout daemon and does not rebuild a partially failed layout
automatically. A visible startup error leaves the partial layout inspectable;
normal Qubes XDG startup still continues. The saved i3 configuration assigns
all HUD types and the dedicated Manager instance to workspace 1, without the
previous arrival-order edge/resize rules. Explicit live preview uses
`hud-workspace --workspace 2`; no live i3 reload is needed.

Salt now guards/installs the root0644 monitor module and root0755 workspace
helper, validates AST/runtime before autostart, and removes startup before
these owned assets on rollback. Default package transport remains the native
UpdateVM provider, with no deployment fetch/build/new dependency. Installed
Salt rendered 51 init and 43 rollback states, and 46 isolated ownership and
ordering cases passed. The existing 34 tests plus eight new workspace tests
all pass. Display-free runtime checks, i3 configuration validation, shell
syntax and whitespace checks pass with installed tooling.

Private real-i3/GTK tests verified empty workspace 1 startup and migration of
the existing wrapped three-pane workspace 2, with all eight actual clients in
the requested geometry. Other-workspace tree/focus and all three retained
HUD XIDs/PIDs were unchanged; repeated startup was an exact no-op and foreign
occupancy was refused before mutation. Actual typing, clipboard/primary
paste, direct VTE input/paste APIs and drops could not control monitors;
selection/copy, focus, resizing and horizontal scrollbar dragging worked.
Normal close stopped and reaped each monitor child. All private displays,
apps and journal children were cleaned up. Evidence is under
`/tmp/qubes-hud-manager-layout-test/`, `/tmp/qubes-hud-monitor-test/`,
`/tmp/qubes-hud-logs-test/workspace-{empty,reuse}/`, and
`/tmp/hud-workspace-{salt-fixtures,installed-salt-render}.json`.

Live integration completed using the installed source:

- Formula sync, dry-run and apply passed all 51 states. Five files changed:
  monitor module, workspace helper, shared frontend, autostart and saved i3
  configuration. Repeat apply passed with zero changes; rollback dry-run
  passed all 43 states. Installed file hashes/ownership/modes match the source.
- The installed `hud-workspace --workspace 2` completed successfully. All
  eight frames match the measured geometry above. The complete workspace 1
  structure, window IDs and geometry were unchanged, prior focus was restored,
  and the running i3 configuration was unchanged. No i3, compositor, desktop,
  display manager or qube restart was performed.
- Bindings PID773889/XID67108867, dom0 PID784852/XID88080387 and Xen
  PID784853/XID90177539 were retained. New terminal PID801414/XID23068675,
  top PID801411/XID79691779, xentop PID801412/XID73400323, cgtop
  PID801413/XID75497475 and Manager PID801415/XID81788935 run as uid1000.
  Each monitor has exactly its expected running unprivileged child process.
- The custom panes and Manager emitted no application errors. Stock
  xfce4-terminal reported only that SESSION_MANAGER is unset in this i3
  session; its normal interactive terminal opened successfully. No session
  manager was added to suppress this harmless warning.
- Evidence is under `/tmp/qubes-hud-workspace-deploy/`, including before/after
  trees, validation, process identities, Salt output and installed hashes.
  No private log contents, screenshots or temporary test assets are committed.
  Live visual acceptance remains with the user; Super+2 opens the preview.

The same complete workspace starts on workspace 1 at the next HUD login.
Publication uses the previously authorized GitHub SSH transport through
sys-net, with strict host verification and no direct dom0 network route.


## Read-only terminal log panes (2026-09-11)

The user changed the two right-side dom0/Xen log panes to read-only terminals
and explicitly requested copying from every read-only terminal. All five now
use `hud_monitor.build`: the same VTE widget, cyan terminal palette/font,
disabled input/paste/drop handling, selection and Ctrl+Shift+C copying. The
three top-row monitors already supported copying and retain their existing
fixed commands and wide horizontally scrollable canvas. The two log panes
wrap at their actual window width and expose VTE's native vertical scrollback
adjustment directly through GtkScrolledWindow. Their window classes, roles,
titles and layout positions are unchanged.

The original `LogFeed` reader and source allowlists are unchanged, including
unprivileged journal/file access, rotation/truncation/new-file handling,
source limits and bounded per-poll/line work. Logs do not spawn a terminal
shell or a PTY command: the existing reader feeds the shared VTE display.
`log_bytes()` applies the reader's existing literal-text sanitizer to each
LF-delimited line before supplying trusted CR/LF separators. ESC, C0/C1,
OSC/CSI, clipboard/title controls and bidi characters are visibly escaped;
raw log bytes cannot send commands to VTE. Source/error status stays in the
small literal GTK footer. Native VTE keeps 600 scrollback rows plus the
visible screen, replacing the old GtkTextView's separate 600-line/256KiB
buffer cap. Soft wraps count as terminal rows, so retained original records
vary with width. This is short recent history, not an archive.

The separate GtkTextView builder, its manual pruning/scroll code, CSS and
unused ctypes structures/bindings were removed from `hud-bindings`. This
reduces the total shared GUI/terminal source. There are no new assets,
packages, compiled binaries, Python modules or elevated permissions. Existing
Salt requisites install both reader/terminal modules before GUI validation
and remove them after the GUI on rollback; no Salt-state or startup/layout
change is required. Default native Salt renders still contain 51 init and
43 rollback states, with install/refresh/remove resolving to
`qubes_dom0_update`. All deployment entrypoints remain unchanged and no
network/build/dependency path was introduced. Evidence for the default render
is `/tmp/hud-log-terminals-installed-salt-render.json`.


Validation for the terminal conversion used only installed tooling:

- All 47 repository tests pass. Five new terminal tests cover literal control
  escaping, OSC52/title/screen sequences, Unicode/surrogates, no log PTY spawn,
  reader cleanup and invalid mode refusal. Runtime and whitespace checks pass.
- All five modes passed actual mouse selection and Ctrl+Shift+C copying in
  the shared frontend with official i3 on a private X display. q/Ctrl+C,
  direct VTE feed/paste APIs, clipboard/primary paste, Ctrl+Shift+V and middle
  click could not control monitors or alter the synthetic log buffer; GTK
  reports no drop destinations. Normal close reaped each monitor child and
  closed each log reader. No real log contents or live clipboard were used.
  Evidence: `/tmp/qubes-hud-five-terminal-test/summary.json`.
- Both log modes passed native tail-follow/resume and actual visible-line
  preservation while paused through pruning (the same line stayed visible
  as 400, 500 and 700 source lines accumulated). Scrollback and oversized
  wrapped feeds remained bounded. Native readback showed terminal-control
  payloads literally, without changing clipboard/title/screen state. Evidence:
  `/tmp/qubes-hud-terminal-log-test/history-results.json`.
- The shared GUI plus terminal module now totals 643 lines (406 + 237), down
  from 736 (531 + 205). All private test displays and their owned children
  were stopped. Startup, workspace layout and existing monitor commands are
  unchanged.


Deployment and live activation completed:

- Final formula sync/dry-run/apply passed all 51 states, changing only
  `hud-bindings` and `hud_monitor.py`. Repeat apply passed with zero changes;
  rollback dry-run passed all 43 states. Both installed sources and the
  unchanged reader/workspace helper match the repository and expected
  root ownership/modes. Evidence: `/tmp/qubes-hud-log-terminals-deploy/`.
- A private test of the exact replacement procedure verified all eight
  rectangles, six retained app identities, workspace 1 and focus, including
  focus on a log being replaced. The live procedure then replaced only the
  two verified log clients with the installed shared helper, using temporary
  exact-class/role placeholders. All eight frame/client rectangles, the six
  other XIDs/PIDs, the completed layout group and workspace 1 were preserved;
  previous focus was restored. No i3/compositor/qube restart or reload occurred.
- Live dom0 is now PID813493/XID88080387; Xen is PID813520/XID90177539. Both
  run as uid1000, load stock VTE and emit no application errors. The old log
  processes exited. Dom0 owns only its expected journalctl child; Xen has
  no child command. Existing top/xentop/cgtop processes remain running with
  their already-enabled Ctrl+Shift+C behavior. Log history reloads from the
  existing bounded reader tails; the previous GTK text buffers are retired.
- Live evidence is `/tmp/qubes-hud-log-terminals-deploy/live/validation.json`;
  temporary replacement evidence is
  `/tmp/qubes-hud-terminal-log-test/replacement-results.json`. Temporary
  activation/test scripts and private log content are not deployment assets
  and are not committed. Future workspace-1 startup uses the new terminals
  through the same existing Salt-managed helpers and launchers.


## Stock terminals and log followers (2026-09-11)

The user approved trying native programs instead of the custom Python
terminal/log implementation, and set the general rule that less additional
non-Salt code is better. This preference is now explicit in `AGENTS.md`.
This section supersedes the previous GTK/VTE terminal and custom log-reader
behavior. Bindings, the interactive Xfce terminal, official Manager, existing
i3 layout and glow remain. Future login startup still targets workspace 1;
live evaluation remains on workspace 2 without moving workspace 1.

### Implementation and baseline dependencies

The five read-only windows use stock Xterm. One shared Jinja desktop template
renders their class/instance/title and fixed native command. A scoped
`XENVIRONMENT` file supplies cyan text, black background, Noto Sans Mono 8,
600 scrollback rows and replacement input translations. Selection and
Ctrl+Shift+C / Ctrl+Insert copying work; key input, paste, mouse reporting and
terminal menu actions do not reach the child. Window/title/font/color/termcap
operations are denied, including OSC52 clipboard reads/writes. The ordinary
first terminal remains interactive. These are interface restrictions, not a
sandbox against the desktop user changing their own configuration.

Monitors directly run the existing top/xentop/systemd-cgtop commands through
stock `setpriv --pdeathsig TERM`. Each log pane instead runs its own
unprivileged foreground rsyslog with a small committed native configuration.
No system rsyslog service or global logging configuration is enabled/changed.
Rsyslog treats HUP as reload, so its launcher uses stock
`setsid --fork --wait` before setpriv: closing Xterm stops the waiting parent,
which sends TERM through the parent-death mechanism and lets rsyslog save
its cursors and exit. Direct setpriv alone was rejected because Xterm could
wait indefinitely for rsyslog after HUP.

Native flock provides one terminal per user/view. A duplicate launch exits
quietly rather than focusing an existing pane. User-tmpfiles supplies 0700
runtime/state directories and five 0600 lock files under
`/run/user/UID/qubes-hud-terminals`. Salt prepares them only if the user's
runtime exists; the HUD login hook also runs the native tmpfiles command.
Repeated creation preserves lock inodes. Rollback removes persistent owned
assets but leaves live processes and their runtime metadata alone.

No package was installed or added to the Salt package ceiling. The signed
Qubes 4.3 `qubes-release` package's `/usr/share/qubes/qubes-comps.xml` selects
Xterm through base-x and rsyslog through standard, both included by the Qubes
Xfce environment. Installed libcomps parses Xterm's untyped packagereq as
mandatory, including for base-x with nodefaults. Stock util-linux supplies
flock/setpriv/setsid, GTK supplies gtk-launch, and systemd supplies tmpfiles.
These baseline program requirements are now checked before enabling launchers;
a stripped installation missing them fails validation. Tested native versions
are Xterm 397 and rsyslog 8.2312.0 on Fedora 41 dom0. No source build, downloaded
asset, language package or Python module is required on another machine.

`hud_logs.py` (282 lines) and `hud_monitor.py` (237 lines) are retired. Their
managed installed files are removed only after the native replacements and
bindings-only frontend validate. `hud-bindings` no longer imports them or
accepts non-bindings views. All five native panes have desktop launchers.
The existing small `hud-workspace` helper still guards and assembles public
i3 JSON/IPC, now matching native terminal class+instance and launching those
desktop entries. Bindings and the glow remain custom Python where stock
configuration does not provide the accepted behavior. No new terminal/log
runtime script replaces the removed modules.

### Log coverage and changed behavior

Dom0 rsyslog combines accessible local journals and the same guid/qrexec/
qubesdb files, xen-hotplug and optional domain-builder log. Exact output path
filters retain the selected host services. Xen follows only hypervisor.log;
it does not separately invoke or clear xl dmesg. No guest command is run and
no guest console/journal is selected. All readers run as uid1000 here, with
no sudo, permission or group changes. Native rsyslog diagnostics replace the
custom source/omissions footer; protected libvirt detail logs remain unread.

A fresh reader begins with new records, without the former recent tail.
Journal following starts fresh on each launch. Native file offsets saved on
graceful close persist within the login runtime, so reopening resumes records
written since closing; logout/reboot removes the offsets. No copied log
archive is stored. Quiet Xen output can therefore be empty at startup.
Native imfile handles append, new-file first records, copytruncate and
rename/recreate. Records/lines are limited to 2 KiB, process descriptors to
512, and the message queue is direct; the former Python source-count and
per-poll limits no longer apply. Full source sets may exceed the native FD
limit (current dom0 reader used 333 FDs, roughly two per selected file).

Control and all non-ASCII bytes display as visible escapes, including German
text, malformed encodings, bidi characters and terminal sequences. Native
imfile follows matching symlinks, unlike the former O_NOFOLLOW reader. The
current 155 selected Qubes daemon files, xen-hotplug, hypervisor log and their
parents were verified regular/readable with no symlinks; domain-builder is
absent. A future dom0-created matching symlink can change the opened target.
These tradeoffs were presented as an optional preference question; proceeding
with stock programs follows the user's explicit preference for less custom
code. Do not claim preservation of the old Unicode/no-follow guarantees.

Rsyslog's backtick `echo $HUD_LOG_STATE` notation is its built-in environment
expansion, not a shell command. The exact 8.2312 source implementation calls
getenv and accepts only that syntax. An isolated test with literal shell
metacharacters confirmed no execution; arbitrary backtick commands fail.
The scoped state directories hold only file-offset metadata.

Native Xterm follows the actual pane width. At the current 1920px layout,
205px top panes show about 25 columns: tables can wrap or be clipped. The
former wide VTE canvas/horizontal scrollbar is removed. Super+F expands a
pane for usable full tables. Wheel and Shift+PageUp/PageDown scroll recent
history; scrolling back pauses following until the bottom is reached.

### Validation

Before live activation, isolated tests verified the final native resource
file, zero input/paste/mouse-reporting bytes, selection/copy, OSC52 denial,
unchanged clipboard/title/geometry and normal native child cleanup. Rsyslog
fixtures checked file lifecycle, exact output filters, long-line bounds,
raw-message preservation and environment expansion. Production configurations
were run unprivileged with stdout/stderr discarded; descriptor inspection
found only selected host sources and accessible journals, with no guest log
FDs. Their shutdowns completed normally, including saving 156 dom0 file
cursors. No actual log contents or live clipboard contents are committed.

Salt fixtures passed 249 safety/ordering cases; installed native renders
contained 60 apply and 50 rollback states. Native package install, refresh
and removal providers resolve to qubes_dom0_update. Generated desktop files
were accepted by installed GDesktopAppInfo, configurations by rsyslog -N1,
and runtime files by native user-tmpfiles. The custom-code regression suite
now contains 32 tests, including exact native terminal class/instance matching.

Evidence is under `/tmp/qubes-hud-xterm-test/`,
`/tmp/qubes-hud-rsyslog-candidate-rbyjkcb1/`,
`/tmp/qubes-hud-rsyslog-env-proof-s6cj9h47/`,
`/tmp/qubes-hud-native-production-smoke-o5w2usig/`, and
`/tmp/hud-native-terminals-{salt-fixtures,installed-salt-render,native-validation}.json`.
The final private official-i3 startup test placed all eight real clients,
preserved workspace 1/focus, and verified repeated layout/desktop launches as
no-ops with five held flock locks. Selection/copy and child cleanup passed
with the exact final resources. A separate private migration replaced all five
old Python panes while preserving eight outer frames, the other three clients
and focus. Native Xterm interiors are 2px smaller in each dimension due to
native border accounting; this does not change the layout's frame geometry.
Evidence: `/tmp/qubes-hud-native-workspace-test/results.json` and
`/tmp/qubes-hud-native-terminals-test/replacement-results.json`.

Live deployment synced the committed-source assets through the existing local
Salt workflow. Default dry-run and apply passed all 60 states; rollback dry-run
passed 50 states. No package changes occurred. Installed source bytes, root
ownership/modes and removal of the two retired modules were verified.
The first repeat apply found that Jinja blank lines inside the runtime guard's
folded YAML string produced shell syntax errors before `&&`, unnecessarily
rerunning native tmpfiles. Its harmless repeat setup preserved runtime inodes;
the guard was corrected to a single joined native-test expression.

The reviewed temporary migration runner then replaced only the five old
Python read-only panes on live workspace 2. All eight outer rectangles and
the three retained clients' identities/interiors are unchanged. The complete
workspace 1 signature and prior Code-window focus were restored. Current
native Xterm PIDs are top832690, xentop832720, cgtop832764, dom0832789 and
xen832815. Their children are stock top/xentop/cgtop or setsid/rsyslogd, all
uid1000. Native launcher diagnostics are empty; all replaced Python processes
and their former monitor/journal children stopped. No i3, compositor, display
manager, screen lock or qube was restarted. Startup remains workspace 1 at
future HUD logins. Live evidence is under
`/tmp/qubes-hud-native-terminals-deploy/`; captures contain process/layout
metadata, not terminal contents.


After the runtime guard correction, the final default apply passed all 60
states with **zero changes** while the five native panes remained active.
All five native locks remained held. Final default state renders and the
50-state rollback dry-run passed, with no rollback executed. The deployment
entrypoint audit covered 62 files, including extensionless helpers, and found
no new direct-network path, build, binary, package or language dependency.
The unchanged explicit maintainer direct-dom0 override remains opt-in.
The 32 custom-code tests and final whitespace checks passed. No further desktop
restart is required to evaluate these panes on workspace 2.
