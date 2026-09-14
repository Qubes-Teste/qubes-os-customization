# Project handoff

Read this document before working on the repository. It summarizes the design
and current implementation so future work does not accidentally undo the
security, portability, or visual decisions already made. The detailed user
documentation remains authoritative for individual states and commands:

- `README.md`
- `salt/qubes_gui/hud/README.md`
- `salt/qubes_gui/guest_hud/README.md`

Always verify the current worktree and history. The prior published baseline is
`f1a1403` (`Align HUD scrollbars and retain five workspace buttons`),
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
13. The user then reported an empty Xen pane, pointer freezing during selection
    and missing two-axis scrollbars. The stock Xterm view is superseded by the
    shared GTK/VTE viewer described in the final section, retaining native log
    readers and the preference to minimize custom code.
14. Cyan scrollbar separators and five persistent i3bar workspace buttons were
    accepted without creating unused native workspaces.
15. The user requested a scheduled green display-output filter covering all
    qubes and accepted altered label colors. Native systemd scheduling and
    existing X11 color-matrix controls implement it without new packages.

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
From 21:00 to 08:00 by default, the user-configurable output night light maps
the whole display to green monochrome, including Qubes label colors. The
underlying palettes remain unchanged and normal output colors return by day.

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


## Scrollable terminal viewers and recent Xen output (2026-09-12)

The user reported three problems with the native Xterm trial: HUD Xen Logs
was empty, selecting text appeared to freeze the mouse until button release,
and there were no vertical/horizontal sliders for reading the monitor tables.
This section supersedes the preceding Xterm-viewer behavior. The general
preference for less non-Salt code remains: the replacement shares the existing
HUD frontend and a small VTE body, while the custom Python log reader stays
removed. No custom binary, source build or additional package is introduced.

### Diagnosis and chosen behavior

Read-only inspection found the Xen reader alive as uid1000, with its source
FD at EOF18244. The file's last modification was September6 at10:09CEST; it
had received no new output after the native follow-only viewer opened.
Nothing was written to the Xen log to test the viewer. A short recent tail
now avoids a blank view when the hypervisor is quiet.

The installed Xterm397 and Xfce Terminal1.1.4 expose vertical scrollbars only.
Xfce's per-tab read-only mode also has no documented startup switch. Neither
supplies the requested horizontal viewport/slider through configuration.
The final Xterm input resources, stock resources, focused/unfocused windows
and a narrow real xentop all passed isolated held-button pointer-motion
checks, including official Picom plus hud-glow. The reported freeze was not
reproduced: do not claim a proven Xterm/XAllowEvents root cause or a verified
fix for every live Xorg/input-driver condition. The replacement returns to
the GTK/VTE selection behavior, with dedicated drag/copy checks.

`hud-bindings` again supplies the shared window, classes/roles, styling and
instance handling for all six HUD views. New `hud_terminal.py` supplies only
the shared terminal body and fixed native-command lifecycle. The former
`hud_logs.py` and `hud_monitor.py` stay retired. Monitors run the same native
top, xentop and systemd-cgtop commands; dom0 logging retains its unprivileged
rsyslog configuration and source filters. The stock Xfce interactive terminal,
official Manager, Bindings and eight-pane layout remain in place.

All five read-only viewers have visible bottom and right scrollbars. Monitor
canvases are at least1280px wide and960px tall: their sliders pan the current
live table, not historical top snapshots. The native program still controls
which rows it displays in that terminal canvas. Monitor scrollback is disabled.
Logs have a1280px wide canvas sized to visible height and600rows of native
history. Their right scrollbar is explicitly bound to VTE's vertical history
adjustment, outside the horizontal viewport so it remains visible while
panning. A plain GtkViewport vertical adjustment would pan content rather
than expose VTE history, so these two cases intentionally differ.

VTE input is disabled before spawning; drag-and-drop input is unset. Selection,
Ctrl+Shift+C and Ctrl+Insert copying, focus and both scrollbars remain enabled.
Font8 and the cyan palette remain local to the viewer. Native log escaping
prevents control sequences from being interpreted as terminal commands.
There is no interactive shell fallback. Normal close uses the existing
pidfd/GPid cleanup and native VTE child watch; TERM gets up to2seconds so dom0
rsyslog can save its156offset records (previously measured~929ms), followed
by a bounded KILL fallback. No Python callback executes after fork.

### Xen native reader and safety limits

Xen uses a fixed stock Bash pipeline: `tail -c65536 -F` on the hypervisor log,
then `LC_ALL=C cat -vT`. It displays up to64KiB of existing data, which can
begin partway through a record, and follows new bytes, replacement and
truncation. A trusted banner explains the recent-output/following behavior.
Xen's original recorded timestamps remain; the extra rsyslog timestamp/source
prefix and cursor state are removed. Each launch loads the recent tail.

The pipeline is a fixed literal, without user-supplied commands or paths.
Bash uses noprofile/norc and `-p` to ignore startup environment hooks/imported
functions; this does not change its uid. Both tail and cat start through
stock setpriv parent-death signaling so even a quiet reader terminates after
its shell exits. All programs remain the unprivileged desktop user.
Native cat escapes every byte except printable ASCII and LF, including tabs,
ESC, C1, malformed encodings, Unicode/bidi and terminal commands. It streams
bounded buffers, with no new per-line limit; VTE retains bounded history.
Dom0 retains its2KiB record/512FD/direct-queue policy. Both native followers
still follow matching symlinks; the old custom no-follow guarantee is not
restored. No guest sources, permissions, ACLs, groups or system logger settings
are changed, and no copied log archive is written.

Salt installs and validates the new root0644 VTE body before the frontend,
checks native programs/libraries and the dom0 configuration, and supplies
five shared desktop launchers retaining native flock. The checked shared
frontend also retains per-view instance locks. It removes the owned legacy
Xterm resource and Xen rsyslog configuration only after replacements validate.
User-tmpfiles now creates only the dom0 cursor directory and five native
locks; an existing Xen cursor directory is guarded and left until normal
runtime cleanup. Rollback removes launchers/frontend before the module and
leaves running applications/runtime state untouched. No i3 config or layout
algorithm change is needed because existing class/instance matching accepts
the GTK panes. Future startup remains workspace1; live migration targets2.

### Validation and integration

Native Xen fixtures verified the exact64KiB initial bound, immediate partial
records, append/rename/recreate/truncate behavior, all256byte values, and
termination of both children after shell TERM or KILL. A separate proof
confirmed uid1000 throughout and ignored BASH_ENV/exported functions.
Evidence: `/tmp/qubes-hud-xen-64k-_7mthksw/results.json` and
`/tmp/qubes-hud-bash-p-proof-h90kfrwm/results.json`. Xterm pointer investigations
are under `/tmp/qubes-hud-xterm-pointer-test/`; no live pointer/clipboard or
real log contents were used in those tests. The repository's37unit tests
pass, including display-free runtime and terminal input/spawn boundaries.
All five final viewers passed private official-i3 tests: actual held-button
pointer motion, short text selection and Ctrl+Shift+C, input/paste/API/drop
blocking, native slider dragging, and normal child cleanup. Monitor canvases
provided213columns/59rows at1280x960. Both log panes kept their right history
bar visible while panning horizontally, preserved the visible line across
append/pruning and resumed following at the bottom. Xentop redraws can erase
an active selection when they change the selected text; no pause feature or
monitor-control code was added. This is separate from pointer movement.
Evidence: `/tmp/qubes-hud-vte-scroll-test/summary.json` (module hashd6a4f482,
frontend989dee28). All private displays/processes were stopped.

Installed default Salt renders passed61apply/51rollback states, with
install/refresh/remove all resolving to qubes_dom0_update.269migration,
ownership and dependency-order fixtures passed. Native desktop loading,
UID1001rendering and user-tmpfiles checks passed, preserving active lock
inodes and existing legacy Xen runtime data. Evidence:
`/tmp/hud-scrollable-terminals-{installed-salt-render,salt-fixtures,native-validation}.json`.
The tested reverse migration retained all eight outer frames, protected three
client identities/interiors, workspace1 and focus on a replaced Xen pane.
It captured and verified each old Xterm/native-child/flock tree and waited
for all old processes to exit before launching its successor. GTK client
interiors are2px wider/taller than Xterm due to native border accounting;
outer geometry is identical. Evidence:
`/tmp/qubes-hud-scrollbars-deploy/replacement-results.json`. All private
migration processes/displays were stopped.

Live formula sync, default dry-run and apply passed61states. Ten changes
installed the238-line shared body, restored frontend dispatch, updated the
five desktop entries/tmpfiles, and removed the old Xterm resource/Xen config.
All installed source bytes, owners/modes and retired-file absence were
verified. Repeat apply passed61states with zero changes; rollback dry-run
passed51states, with no rollback executed. Final audit scanned61deployment
files and found no new package, external module, build, compiled artifact or
default direct-network request. The opt-in maintainer direct-DNF branch is
unchanged.37repository tests and whitespace checks passed.

The final reviewed runner replaced the five live Xterms on workspace2.
All eight outer rectangles, Bindings/interactive-terminal/Manager processes
and client interiors, workspace1 signature and prior Code-window focus are
unchanged. Live GTK PIDs are top898507, xentop898537, cgtop898567,
dom0898600 and xen898632. All native children run as uid1000, launcher logs
are empty, and every replaced Xterm/flock/native child exited. Xen's native
tail and cat each emitted18244bytes from the existing quiet hypervisor log;
only counters were inspected, without saving log content. Dom0 has its expected
rsyslog child; Xen has only Bash/tail/cat. The Bindings window remains its
existing process and uses the updated common frontend at its next launch.
No i3, compositor, screen lock, display manager or qube was restarted/reloaded.
Future startup still targets workspace1. Evidence is under
`/tmp/qubes-hud-scrollbars-deploy/`, including live-validation.json.
The physical pointer symptom remains for user verification; isolated pointer
motion and copying passed on the replacement. Native monitor redraws can
still erase text selection, as documented above.

## Cyan scrollbar separators (2026-09-12)

The shared GTK viewer inherited pale Adwaita separator borders on its bottom
and right scrollbars, plus a gray background and border image at the monitor
pane's bottom-right scrollbar junction. The existing `hud-bindings` CSS now
sets those separator borders to dim cyan `#116b86` and the junction to black
without its border image. These rules are scoped to `.shortcut-window` and
change no widget dimensions, terminal behavior or dependencies.

Private native GTK rendering isolated the painted pixels: 448 monitor
separator pixels and 219 log separator pixels changed from gray to dim cyan;
the monitor's remaining 24 gray junction pixels became black. No other client
pixels or widget rectangles changed. Normal, hover, active, disabled and
backdrop checks found no remaining pale neutral pixels in either body type.
Evidence: `/tmp/qubes-hud-scrollbar-css-test/verified.json`.

GTK retained cached user CSS after file replacement and native theme
notifications. The live update therefore uses the reviewed temporary
GTK-to-GTK replacement runner for the five read-only panes. Its private test
preserved all eight outer/client rectangles, the other three client identities,
workspace 1 and focus, and verified old native children and locks exited
before launching replacements. No runtime reload watcher was added.

## Five default workspace buttons (2026-09-12)

The HUD bar now uses official i3bar's `workspace_command` protocol, introduced
in i3 4.23 and available in the installed official 4.25.1 package. Buttons 1–5
remain visible even when their native workspaces do not exist. Selecting one
creates a normal i3 workspace; empty, hidden workspaces are still removed by
i3. Future startup continues to place only the HUD dashboard on workspace 1,
without starting windows on 2–5 or relocating the current workspace 2 preview.
This is not a blanket restriction on where other dom0 applications may open.

The existing `hud-workspace` gains a small, separate `--buttons` mode. It merges
missing numbered buttons with real `get_workspaces` results, preserving actual
IDs, names, focus, visibility, urgency, outputs and workspaces outside 1–5.
Missing buttons contain only name/number and use i3bar's primary-output fallback.
An official `i3-msg` subscriber delivers workspace/output changes; its initial
tick establishes subscription before the first snapshot, so startup cannot
miss a change. There is no periodic polling, layout mutation, extra executable
asset, package or custom binary. The layout-startup mode and display-free
`--check` behavior remain intact. SIGTERM, closed-bar writes and subscriber EOF
clean up the owned child. Existing Qubes status/tray programs are unchanged.

Static config alone cannot retain accurate focus/urgency for absent buttons.
A one-shot JSON command is also unsuitable: i3bar replaces the buttons with an
error when its provider exits, including success status. The shared helper is
therefore the bounded custom-code addition required for the requested behavior.

### Integration and live activation

The exact frontend CSS (SHA-256 `39a5dc10...`) passed native parsing and rendered
identically to the pixel-verified candidate in all five style states for both
body types. Evidence: `/tmp/qubes-hud-scrollbar-css-test/repo-verified.json`.
The workspace addition adds 55 net source lines to the existing helper (248 total).
All 43 repository tests passed, including six workspace state/lifecycle checks;
display-free validation and official i3 config validation also passed.

Private official i3/i3bar tests showed buttons 1–5 without creating workspaces,
native click-to-create empty workspace 5, its removal on leaving, retained
focus/urgency, named and additional workspaces, and correct real assignments
across two outputs. Missing buttons also displayed with no explicit primary
output. The exact captured live-to-installed config reload preserved both
workspace trees, all eight HUD clients, focus and the i3 process. Ordinary
reload ran no startup command, including `exec_always`; the existing wallpaper
comment saying otherwise is inaccurate. All private processes were stopped.
Evidence: `/tmp/qubes-hud-workspace-buttons-test/{results,reload-results,native-cleanup}.json`.

Formula sync, default dry-run and apply passed 61 states, changing only the
shared frontend, workspace helper and saved i3 config. Installed bytes and
ownership/modes match the repository. Repeat apply passed with zero changes;
rollback dry-run passed 51 states, without executing rollback.
The deployment audit covered all 61 deployment files, including 14 shebang
entrypoints, with no new package, module, binary, build or default network
path. Default install/refresh/remove still resolve to `qubes_dom0_update`.

The five live read-only panes were refreshed before reloading i3. All eight
outer/client rectangles, the three other client identities, workspace 1 and
focus were preserved; launcher logs were empty and native readers resumed.
Their new PIDs are top908227, xentop908257, cgtop908290, dom0908322 and xen908354.
The guarded live i3 reload then enabled the five buttons while retaining the
same i3/i3bar processes, both workspace trees, all client identities/geometry
and focus. The bar's provider is PID908814 with native subscriber908815.
The current HUD preview stays on workspace 2; future login starts it only on 1.
Evidence: `/tmp/qubes-hud-cyan-scrollbars-deploy/`, especially
`installed-validation.json`, `live-validation.json` and `reload-validation.json`.

## Scheduled display-wide green night light (2026-09-12)

The user superseded the initial HUD-accent-only choice with a display-output
filter covering every application in every qube, and explicitly accepted
changes to displayed Qubes label colors. Default local hours are 21:00–08:00,
adjustable through the new **HUD Night Light** Rofi menu or `hud-night-light
--hours START END`. Manual `--mode day`, `night` and `auto` are available.
The marked user-owned 0644 `~/.config/qubes-hud/night-light.ini` lives in an
owned 0700 directory and uses Salt `replace: false` to retain user choices.

Night applies a green monochrome matrix at the graphics output: red and blue
rows are zero, while fixed Rec.709 weights combine all input channels into
green. It composes with the original output matrix instead of discarding it.
Day restores that original matrix only while the current matrix still matches
the helper's saved night or original transform and the connector/EDID identity
matches. Records remain after restoration so a cached Xorg value cannot hide
a failed DRM restore from later retries; external changes release ownership.
Night adopts an external reset/calibration as the new baseline. Disconnected
outputs retain records for later restoration; temporarily unreadable matrices
retain their records and report an error. Original values are persisted before
the first hardware write; failed writes therefore retain restoration data.
Private 0600 runtime state and locks are bounded, owner/type/mode/link checked,
and shared by equivalent `:0` and `:0.0` display names. No root display access.

`hud-night-light` is a standard-library controller; `hud_output.py` binds the
already installed libX11/libXrandr using ctypes. No system binary is patched,
compiled or pinned, and no package or third-party Python dependency is added. Direct native
RandR calls avoid an actual CLI incompatibility: xrandr 1.5.2 accepts 18 raw
CTM words while 1.5.3 uses nine floating-point coefficients. The adapter bounds
property reads, uses native longs for Xlib format-32 data, catches X errors,
refuses absent/malformed CTM properties and verifies exact property readback.
There is no theme, guest application, i3, Picom or glow-helper modification.

Salt installs three native systemd user units (oneshot apply, minute calendar
timer, oneshot restore) and a desktop launcher. There is no enabled global
target or additional daemon. HUD autostart imports DISPLAY/XAUTHORITY and
starts the timer and first apply; Salt apply only installs/validates and
reloads an existing user manager. `--start` activates an already open session.
The timer reacts to clock/timezone changes; elapsed calendar events catch up
after resume. Hotplug or output-reset correction occurs at the next minute,
normally within 61 seconds, rather than synchronously with the display event.
Night and subsequent day reassert the saved transform on each tick, even with
matching property readback, because Xorg can retain the property after a failed
DRM write. It
does not recompute from the filtered value or rewrite unchanged runtime state.
`--stop` stops timer/apply and restores connected saved outputs. Rollback
orders this before deleting the controller, preferences or units, then reloads
the user manager. Marked files, owner/group/mode, link and directory guards
apply to every new path; the user directory and runtime records are retained.

### Hardware limits and validation

Every active output must expose a working XRandR CTM property. An unsupported
active output refuses night activation before new writes. The reference Intel
i915/modesetting HDMI-1 output exposes the property and accepted CTM writes.
Other graphics drivers require verification. Xorg may log a DRM CTM failure
while still accepting its X property: exit status/readback alone is not proof
of physical output. Screenshots capture before this stage and cannot prove
the visible effect. The filter sets RGB channels; no optical measurement or
medical effect is claimed. Boot/login screens before this user's HUD startup
are outside the session filter's scope.

Private Xvfb tests exercised native writes, unsigned values, malformed/missing
properties, actual X errors, EDID changes, exact restoration and cleanup.
A detached temporary preview restorer recovered the original matrix after
20.006 seconds. The live 20-second preview restored the exact original CTM;
the complete normalized i3 tree/workspaces/focus, i3/Picom/glow process
identities and compositor selection owner were unchanged. No new Xorg CTM
driver errors appeared. The preview/watchdog is maintainer-only temporary
test code, not a deployed recovery service. Evidence:
`/tmp/qubes-hud-output-test/` and `/tmp/qubes-hud-ctm-preview-6xl7mpkg/`.

Default installed-Salt render passes 71 apply / 60 rollback states and retains
`qubes_dom0_update` for install, refresh and removal. All 441 Salt safety and
ordering fixtures pass, including modified-file refusals, partial installs,
preserved hours and restore-before-removal. Native unit validation, headless
runtime binding and shell syntax checks pass. Deployment audit covers 68
files and 15 shebang entrypoints with no new dependencies, compiled assets,
source builds or default direct-network path. Evidence:
`/tmp/hud-night-light-{installed-salt-render,salt-fixtures,regression-salt-fixtures,entrypoint-audit}.json`.

### Installed-controller and kernel verification

All 79 repository tests pass, including cached-property/hardware-write failure
simulations for both scheduled phases, retained calibration, output identity
changes, malformed state, FIFO refusal without blocking, native service
ordering and menu settings. The exact Rofi prompts also passed private Xvfb
tests for cancellation, selection indices and accepting prefilled hours.

Formula sync and default dry-run/apply pass all 71 states. A final controller
update was applied, then repeat apply passed with zero changes. Installed
source hashes and root ownership/modes match; preferences remain user-owned.
Rollback dry-run passes 60 states without executing the rollback. No package
was installed or removed. Existing workspace trees, all client identities and
geometry, focus, compositor selection and i3/Picom/glow processes are unchanged.

The installed controller then ran a second 20-second preview with an automatic
detached return to the original schedule. A temporary read-only libdrm probe
queried active i915 CRTC 88 directly: its kernel CTM contained exactly the
requested nine coefficients (zero red/blue rows, green weights 913110047,
3071760610 and 310096639 in S31.32). This verifies the kernel received the
transform beyond Xorg's cached property. The native `--stop` restore service
returned the kernel CTM to blob 0 (identity). Automatic 21:00–08:00 scheduling
then resumed successfully; the current daytime desktop has normal colors.
No optical measurement, suspend/reboot or physical hotplug test was performed.
The read-only kernel probe and temporary preview runner are not deployment
dependencies. Evidence: `/tmp/qubes-hud-night-light-deploy/`, especially
`installed-validation.json`, `controller-green-kernel.json`,
`controller-restored.json`, Salt JSON results and `tests.log`.

## Optional AppVM workspace preset (2026-09-12)

The user authorized trying the community qube-specific-workspace idea,
accepted starting the entire application group whenever its qube starts,
requested boot startup on workspace 2, and delegated the test-qube choice.
A new green `hud-test` AppVM was created from the installed
`debian-13-xfce` template, with native `sys-firewall` networking. No existing
qube or template was repurposed. The preset is Firefox on the left (40%),
two Xfce terminals stacked in the middle (30%), and Thunar on the right (30%).

The community guide targets Xfce and adds workspace-management scripts.
This implementation instead uses the existing official i3 binary's native
assignment/layout mechanisms and Qubes' standard guest XDG autostart. Four
Salt-owned 0644 `.desktop` files in the AppVM user's persistent
`~/.config/autostart` invoke the installed programs directly. Firefox uses
`--class HudQubeBrowser --new-window about:blank`; the terminals use
`--disable-server --class=HudQubeTermTop` and `HudQubeTermBottom`; files use
Thunar. There is no guest runtime helper, new package, language module,
compiled asset, template modification or source build. The selected template
already supplies Firefox 140.15.0esr, Xfce Terminal and Thunar.

The existing `hud-workspace` grows from 248 to 364 lines and gains `--qube`
and `--prepare` modes. A root-owned optional
`/etc/qubes-hud/qube-workspace.json` selects the name and fixed workspace 2.
The helper validates its name/schema, root-owned parent/file modes, regular
inode and link count, and uses the existing private runtime lock and native
i3 IPC. Layout matching uses the Qubes GUI daemon's trusted `qube-name:`
prefix on WM_CLASS, with exact per-application suffixes; titles do not
establish qube identity. Native placeholders receive matching new clients.
Already-open matching clients can be adopted without closing or relaunching
them. Both adoption and placeholder cleanup match the original placeholder's
XID plus container ID atomically, so a late real client cannot be swapped or
closed by stale cleanup. Layout discovery is restricted to direct children
of the target workspace: i3's output-content container is also type `con`
and can otherwise mimic a three-column layout when three workspaces exist.

The root-owned optional i3 include assigns the qube's windows to numeric
workspace 2 and invokes `--prepare` when its windows appear. Startup also
prepares slots before normal GUI autostart. This handles boot-before-login
and later Manager starts without an additional resident event daemon or
fixed sleep. Numeric matching includes renamed workspaces such as `2: mail`;
unrelated occupancy is refused before layout mutation. Separate qube marks
cannot collide with dom0 HUD pane names. Marked layouts preserve user
rearrangements, and repeated manual launches focus their actual workspace
with i3's auto-back-and-forth disabled for that command.

The root desktop file `qubes-hud-qube-workspace.desktop` supplies **Start
workspace** under the selected qube in the standard Applications menu and
HUD launcher. It runs the dom0 helper, which uses native
`qvm-start --skip-if-running`; it does not repeat guest application commands.
Qubes Manager itself remains unmodified: its ordinary Start launches the
guest and therefore its app group, while its Start action remains disabled
for running qubes. Closing a pane does not refill its old slot; restarting
the qube launches the complete group again. This first preset supports one
AppVM and workspace 2, not arbitrary profiles or disposable-session recovery.

### Deployment and rollback

The separately applied `qubes_gui.hud.qube` state is a no-op when its name
pillar is absent; a normal HUD install creates no AppVM. The documented
three phases create/tag a new AppVM with `ready: false`, configure its guest
autostart through native Qubes Salt, then publish the dom0 profile/i3/menu
and enable native boot `autostart` with `ready: true`. The final phase checks
the installed helper's new command support and validates the i3 snippet.
Existing targets require the ownership tag, AppVM class and exact configured
template. Unsupported/missing apps, unsafe parents, unowned files and changed
owned files are refused. Guest private-home configuration is intentionally
separate from the existing template-only `guest_hud` theme state.

The stock Qubes Salt `qvm.prefs` provider was found to call `setattr()` even
in test mode: its reported preview actually toggled this test qube's boot
property. All new preference states therefore render descriptive native
`test.nop` previews when `opts.test` is true, with matching requisites;
real applies still use native `qvm.prefs`. This covers create preferences,
final boot enablement and rollback disablement. It is an explicit workaround
for the installed provider, not a custom replacement for Qubes' package or
VM-management tooling. Normal deployment uses no direct dom0 network path.

`qube-rollback.sls` shares the same state logic. Run it first in the selected
guest, then dom0, using the same name/template pillar. It removes only exact
owned autostart/preset/menu files and disables the preset's boot startup;
the AppVM, private data, tag and live windows remain. Main HUD rollback
refuses while any optional preset asset remains, avoiding a dead launcher
or guest autostart referring to a removed layout helper. Main HUD install
also refuses a foreign or unsafe optional i3 include. The README and pillar
example document this opt-in deployment and rollback order.

### Validation and live trial

All 87 repository tests pass. Native private i3 tests verify new-client
swallowing, existing-client adoption, concurrent late arrivals, repeated
launches, renamed workspace handling, closing/reopening clients and actual
`for_window` preparation. Tests with three populated workspaces (1, 2, 5)
verify that only the target's direct layout is selected and other workspaces
retain structure, geometry and focus. The regression also fails against the
previous broad search. Private sessions and generated Python caches were
cleaned up. Evidence: `/tmp/qubes-hud-qube-layout-test/`, including
`three-workspaces-results.json`.

Native default Salt rendering retains 71 main apply and 60 main rollback
states when no optional profile is present; both optional states default to
one no-op. Package install/refresh/remove still resolve to
`qubes_dom0_update`. Targeted Salt fixtures cover ownership, invalid names
and booleans, readiness, guest rollback without installed applications and
all preview/apply requisite branches. No new deployment dependency or fetch
entrypoint was added.

Live creation passed six states, guest setup passed six, and final dom0
configuration passed ten. The 71-state HUD update changed only its existing
workspace helper, startup helper and i3 config; the layout-discovery fix
subsequently changed only the workspace helper. A normal test-qube restart
launched all four guest apps via XDG autostart. Their correct live classes,
positions and retained IDs are recorded in
`/tmp/hud-qube-deploy/live-validation.json`; three actual desktop-launcher
invocations preserved all four clients and the layout. Workspace 1's dom0
dashboard and workspace 5's existing windows retained their exact structure
and geometry. No full-machine reboot was performed during this task.

Final repeat apply passed all 81 combined dom0 HUD/preset states and all six
guest states with zero changes. The corrected native ready and rollback
previews passed ten and four states respectively while preserving the
test qube's complete preference output byte-for-byte, including
`autostart=True`. Guest rollback preview passed four states. Main HUD rollback
preview correctly returned only the explicit preset-active refusal and
changed nothing. Installed helpers match the committed assets. Evidence is
under `/tmp/hud-qube-deploy/`, especially `native-preview-validation.json`,
`repeat-validation.json`, `main-rollback-guard.json` and the final
`live-validation.json`. The earlier boot-property observation is retained
separately in `live-validation-before-preview-fix.json`.

The screen locked and DPMS turned the monitor off during verification.
Read-only inspection confirmed all four client/frame windows are mapped,
Picom retains its compositor selection, and the captured solid `#030b12`
surface is i3lock above those frames. The lock, input and display power state
were left intact. Workspace 2 is selected behind the lock and ready for the
user's normal unlock; there was no compositor restart or screenshot repair.

## Optional native Firefox cyan page colors (2026-09-13)

The user requested that ordinary Firefox render most content cyan on black,
with a toggle. The separate `qubes_gui.guest_hud.firefox` state supplies
eight editable defaults through the stock browser's restricted preference
loader. It adds no extension, package, custom binary, AutoConfig script,
runtime helper, profile file or enterprise-policy merge. This remains an
opt-in state; ordinary guest-theme installation and template provisioning do
not implicitly enable it. Tor Browser's separate installation is untouched.

The owned file is `/usr/lib/firefox-esr/defaults/pref/qubes-hud.js` for
Debian-family templates and `/usr/lib64/firefox/defaults/pref/qubes-hud.js`
for Fedora's ordinary x86-64 Firefox layout. Native GRE preference loading
reads that directory even when the application uses `omni.ja`. Debian's
older `/etc/firefox-esr/*.js` mechanism is deliberately avoided: its current
ESR package has a reported loading regression. Application-local defaults
also avoid the broader `/etc/firefox` scope used by some Firefox forks.
Relevant upstream references are Mozilla's
[preference-file format](https://firefox-source-docs.mozilla.org/modules/libpref/index.html#preference-values),
[Contrast Control](https://support.mozilla.org/en-US/kb/firefox-contrast-control),
and [Debian's ESR loading report](https://bugs.debian.org/1121823).

`browser.display.document_color_use=2` selects Firefox's native Custom
Contrast Control. Text is `#19d3ff` on `#000000`, unvisited links `#7ae9ff`,
visited links `#1493b3`, and active links `#b3f3ff`. The two remaining defaults
request dark page appearance and supply the native system-dark-theme hint.
No `.dark` palette duplicates are needed: ESR 140's explicit forced-color
mode selects its ordinary preference palette. This recolors text, backgrounds
and links; images, video, canvas pixels and `forced-color-adjust: none`
elements retain their colors. Firefox chrome and internal pages have their
own behavior, and existing explicitly selected browser themes can override
the dark hint. No maintained browser CSS selectors are introduced.

On the installed Firefox 140 ESR, **Settings → General → Contrast Control →
Off / Custom** is the native live toggle. Off writes color-use `1`; Custom
writes `2`. These defaults are unlocked: existing user or policy values win,
and user toggle choices survive Salt reapplies. Installing/removing the file
requires a Firefox process restart; the toggle itself takes effect live.
Rollback removes only the exact owned drop-in and preserves user choices,
which may therefore remain effective after removal.

Normal deployment targets a selected TemplateVM with Firefox already
installed, then shuts it down to commit its root. Dependent qubes inherit
changes on their next start and are never restarted by this state. An
explicit `qubes_gui:guest_hud:firefox:preview_qube` matching QubesDB `/name`
allows the same file in an already-running AppVM's ephemeral root. This
preview is not a substitute for template deployment and does not write
`/home`, `/rw` or `/usr/local`. Both paths and their matching
`firefox-rollback` commands are documented in the guest-theme README.

Apply and rollback share guards for Qubes type/name, supported OS, real
root-owned 0755 parents, a regular root:root 0644 destination with one link,
bounded exact contents, and absence of package ownership. Apply additionally
requires the installed Firefox package and its owned `channel-prefs.js`.
No shared directories are created or removed. The first native preview
exposed that Salt's `pkg.owner` leaves retcode 1 for an unowned Debian path,
which the Qubes SSH wrapper promotes to a render exception. Fixed-argument
native `dpkg-query`/`rpm` queries now use `cmd.run_all` with
`python_shell=False`, `ignore_retcode=True` and explicit result validation.
The queries are read-only package-database operations, not package fetches.

### Validation

Native rendering with default settings correctly refuses dom0 for both new
states. All 200 bounded Debian/Fedora apply/rollback guard fixtures pass.
An audit of 73 deployment files and 15 executable entrypoints found no new
dependency, download, build, binary or generated cache. Native dom0 package
install/refresh/remove still resolve to `qubes_dom0_update`; the existing
explicit direct-DNF maintainer override remains separate and opt-in.
Evidence: `/tmp/hud-firefox-salt-check-tibt4tzj/results.json`. Fedora paths
were rendered and checked with fixtures, not visually tested in a live
Fedora TemplateVM.

Actual stock Firefox 140.15.0esr in the already-running `hud-test` passed
five isolated headless rendering phases: baseline, installed system defaults,
native Off preference, native Custom preference, and fresh profile after
Salt rollback. A local HTML fixture proved exact black backgrounds,
`#19d3ff` text and `#7ae9ff` links. Off and post-rollback screenshots matched
baseline byte-for-byte; Custom matched system defaults byte-for-byte.
Raster images, canvas and CSS opt-out regions retained their original pixels
in every phase. This proves preference behavior, not a live click on the
Settings control. That control's mapping was checked in the installed ESR
source. All ten original Firefox processes survived every phase, and every
owned headless process, temporary guest profile and fixture was removed.
Test inputs used only local files and temporary test profiles, with proxy
settings blocking browser background HTTP/HTTPS. Evidence and screenshots
remain under `/tmp/qubes-hud-firefox-colors/`, including `summary.json` and
`cleanup.json`. No existing user profile was edited.

The native Qubes Salt dry runs planned exactly one preference file in each
of `hud-test` (explicit preview pillar) and `debian-13-xfce` (normal template
scope). Template apply succeeded and repeat apply reported zero changes;
the template is halted again. This persistent root change will reach its
other dependent qubes at their next normal start. No dependent qube,
ordinary browser session, service VM, compositor or window manager was
restarted during the initial installation. The user's existing Firefox
process retained its earlier settings until the separately authorized restart
below. Firefox's `about:profiles` → **Restart normally** provides the native
session-restoring route. Initial source inspection suggested that it would
preserve the startup class argument; actual installed-package behavior below
supersedes that inference. The live preview avoids requiring a whole-qube
restart just to see the new defaults.

After rollback testing, the explicit live `hud-test` preview was reapplied;
its repeat apply also reported zero changes. Its installed preference file
matches the repository byte-for-byte. Native apply/preview/rollback evidence
is under `/tmp/hud-firefox-deploy/`. The final state is an installed template
default plus the same ephemeral preview in the running test qube, with the
user's active browser initially awaiting its normal restart.

### Live browser activation (2026-09-13)

The user explicitly requested restarting the current Firefox on workspace 2.
The native About Profiles **Restart normally** control replaced main PID 916
with 12283 and restored the existing search tab. The live page visibly renders
cyan text and links on black; the screenshot is
`/tmp/hud-firefox-activation/active-page-final.png`. No browser profile
configuration or additional package was changed.

The installed Debian browser's native restart dropped `--class HudQubeBrowser`:
its new trusted dom0 class is `hud-test:firefox-esr`. It stayed on workspace 2,
but i3 rebalanced the three columns after the old client disappeared. Native
i3 commands restored the browser's existing preset mark and 40% width; the
two terminal and file-manager columns returned to 30% each. This is a known
manual-browser-restart layout caveat, not a change to the persistent preset.
A normal future qube start still invokes the committed XDG autostart command
with its custom class. The activation evidence is under
`/tmp/hud-firefox-activation/`; the earlier claim of restart-class preservation
was source-based and should not be repeated as tested behavior.
Final independent verification retained all 15 other client identities and
their exact frame/client geometry, and restored Firefox's original geometry.
The installed eight-default file remained unchanged. Evidence:
`/tmp/hud-firefox-activation/independent-validation.json`. Only this handoff
changed in the repository; the previously audited deployment entrypoints,
dependencies and Salt states are unchanged.

## Optional stock-rendered font trials (2026-09-13)

The user selected four font trials in this order: Xolonium, Induction,
Neuropol, Johnny Fever. The shared `qubes_gui.hud.font` state and its
`font-rollback` alias are opt-in and no-op without an explicit family. Leave
each trial visible for the user to judge before selecting the next; no
automatic cycling or final favorite has been requested. Ordinary HUD Noto
configuration remains intact and is resolved through the optional selector.

The repository contains unchanged official Xolonium 4.3 Regular/Bold OTFs
under SIL OFL 1.1 and the three requested Typodermic OTFs from their individual
CC0 archives. Xolonium is openly licensed rather than public domain, and its
license permits bundling. Original license/declaration files and provenance
record upstream archive URLs, SHA-256 values and exact asset bytes. Johnny
Fever's external filename uses a hyphen for the existing Salt sync path
policy; its internal name and font bytes are unchanged. Git attributes retain
the exact upstream font/license bytes, including the original CRLF license,
across checkouts. Acquisition used
HTTPS inside existing sys-net, followed by selective transfer. No deployment
download, source build, conversion, package or runtime helper was added.

Assets are staged by normal Qubes Salt `file.managed` transfer under the
marked `/usr/share/qubes-hud-font-trial/<family-slug>` directory, outside
Fontconfig's ordinary font directories. Native `file.file_exists` and
`file.check_hash` checks form a runtime SHA-256 gate. Only after that gate
passes does `/etc/fonts/conf.d/99-qubes-hud-font.conf` register the selected
family's directory and strongly prepend its name to ordinary font requests.
Symbol/emoji/icon requests and missing-character fallback remain available.
The stock Fontconfig, FreeType, Pango, GTK, Qt, VTE, browser and i3 binaries
render the fonts and retain their normal package updates. Hashes pin the
supplied font bytes; they do not constitute a security audit of font data.

All four fixed manifests and selectors are admitted for switching. Root and
family directories, markers, font/license files and selector have bounded
ownership, type, mode, link, content and SHA-256 guards. Unknown entries or
modified files refuse the state. Existing verified assets use `replace:false`;
apply also refuses a partially missing currently registered family so
unverified replacements cannot become visible through its previous selector.
Rollback accepts missing assets, removes the owned selector, browser default
and installed fonts, runs native `fc-cache --force`, and retains the marked
root and empty family directories. Unrelated fonts and user browser choices
are preserved. Omitting the pillar does not undo an installed selection.
The optional font state is independent of main HUD removal; use its rollback
when returning to the original font selection.

The same state supports Qubes 4.3 dom0 and Debian-family/Fedora TemplateVMs.
An exact `preview_qube` name permits an AppVM's ephemeral root; normal template
installation is the persistent guest route. Guests with ordinary distribution
Firefox installed receive a separate guarded `qubes-hud-font.js` with the
editable `browser.display.use_document_fonts=0` default. The cyan color file,
profiles and Tor Browser installation are unchanged. Native Firefox Settings
can re-enable page fonts, and existing user choices win. Disabling page fonts
can affect web icon fonts; images and text drawn as pixels cannot be changed
by font selection.

These are proportional display faces. VTE retains its fixed cell grid, so
spacing can widen and fewer columns fit. Applications cache fonts: a new
login refreshes dom0, and an application restart refreshes its own selection.
Salt never restarts applications or qubes. Immediate managed-viewer refreshes
are maintenance actions, not new deployed runtime code; interactive terminal
sessions are preserved until the user normally reopens them.

### Validation

Actual native testing resolved three Salt portability details: stock dom0's
`/` is mode 0555; Qubes Salt SSH does not support the ad-hoc render-time transfer
used by `cp.cache_file`; and `cmd.run` states already supply `python_shell`.
The final state admits 0555 or 0755 only for `/`, uses normal bundled source
transfer with the runtime hash gate, and executes a fixed cache command with
no duplicate keyword. It does not rely on Salt's configured cache hash, which
is MD5 here. Fresh `test=True` cannot hash files that have only been planned,
so its gate is an explicit descriptive no-op; real apply checks the hashes
before permitting the selector. Native execution proved that a bad hash or
missing staged file blocks selector installation. No Internet access from
dom0 is required.

Private native Fontconfig/Pango tests selected Xolonium Regular and Bold for
ordinary requests while retaining symbols and missing-glyph fallback. Fresh
VTE uses stable 12×13-pixel cells at the existing 8-point request. Long-lived
VTE kept its old 10-pixel width even after Xfce's native Fontconfig timestamp
notification; managed viewers need replacement for a reliable immediate
preview. In ordinary Firefox, a local four-row fixture rendered identical
pixels for generic, explicit installed, embedded other-font and embedded
Xolonium cases with the one preference. Extra language-family preferences
proved unnecessary. All original browser processes survived these tests;
temporary profiles/displays were cleaned up. Evidence is under
`/tmp/qubes-hud-font-trial-test/`, including `summary.json` and
`firefox-pixel-proof.json`.

Native i3 tests proved replacement through explicitly matched placeholders
and container swaps, including unequal column widths, preserving client order
and outer geometry. Immediate dashboard refresh uses that maintenance
technique for managed viewers and Qube Manager while preserving interactive
terminals and unrelated windows. Temporary scripts and evidence are under
`/tmp/hud-font-trial/`; none are deployment inputs. The superseded initial
font-installation directory was rolled back and its empty owned marker/root
removed before the final directory scheme was installed.

### Live Xolonium trial

Final native apply passed eight dom0 states and nine states in the exact
`hud-test` AppVM preview. Both repeat applies passed with zero changes.
Rollback previews passed eleven and twelve states respectively and changed
nothing. Actual runtime-gate tests include eight isolated successful/failed
hash and preview cases under `/tmp/hud-font-gate-native-artjpd4q/`; native
final default/family renders and UpdateVM provider evidence are under
`/tmp/hud-font-native-render-ozi7w5yh/`. The deployment entrypoint audit found
no new dependencies, network fetch, build or runtime helper. The sole guest
installation remains the ephemeral preview; no template has adopted a final
font choice yet.

Stock i3 was restarted to refresh frame/bar font caches. Seven managed dom0
viewer/Manager processes were replaced and load the selected OTF files.
Their XIDs can be reused by X11; process replacement and actual font mappings
were verified independently. One transient geometry check ran before i3bar
finished mapping; after the bar settled, all original outer geometry was
restored. The exact eight-pane dashboard group retained its structure and
its `qubes-hud-workspace` mark was restored. Interactive terminal sessions
and unrelated applications were preserved. Their cached fonts can remain
until those application processes are normally restarted.

The screen locked during preparation. Lock processes remained intact through
the i3 restart and initial managed-viewer refresh; the screen was later
unlocked normally, with no unlock, password entry or lock termination by the
agent. After unlock, Firefox's native About Profiles Restart normally control
replaced main PID 12283 with 21023 and restored the original Google search tab.
The two trial About Profiles tabs were closed. The replacement browser landed
inside the terminal column, so native i3 commands moved it back to the left,
restored its preset mark and 40% width, and returned the terminal/file columns
to 30% each. This is the previously documented native browser-restart class
and layout caveat, not a persistent layout change.

Independent verification passed all fourteen original outer frames, six
protected XIDs, available protected process identities, complete layout
structure/marks, installed file hashes/permissions, native font selection in
dom0 and hud-test, and actual Xolonium mappings in all seven refreshed dom0
processes plus Firefox. Titlebars changed from 22 to 18 pixels, giving clients
four more pixels of height within unchanged outer frames. Evidence is
`/tmp/hud-font-trial/independent-validation.json`. Actual screenshots
`bindings-xolonium-final.png` and `firefox-xolonium-loaded.png` show the selected
face; the latter captures the completed cyan/black Google results page.
Final focus is workspace 1 HUD Bindings. Xolonium remains selected; Induction,
Neuropol and Johnny Fever are committed candidates awaiting successive trials.

### Induction trial and faster switching (2026-09-13)

After a reboot, hud-test correctly lost its ephemeral Xolonium font files and
Firefox font default. Native font matching and the running Thunar/Firefox
process mappings confirmed a return to Noto. The user then chose to try the
next font before deciding on persistent guest installation or a monospace
terminal exception. **Induction was selected for this trial (subsequently rejected below).** No TemplateVM font
selection or terminal exception was added; hud-test remains a temporary
AppVM preview and will lose this root change at its next restart.

The shared state now stages all four committed families and their licenses
on the first selected apply. Only the chosen directory is registered with
Fontconfig. Later switches change the single `family` pillar, reuse the
verified local assets, and update the selector/cache; no formula sync is
needed unless repository inputs changed. All nine font/license paths must
pass the existing runtime SHA-256 gate before selection. There is still no
new runtime helper, package, network fetch or source build. Application
refresh remains separate because live programs can retain font caches.

Jinja guard checks now use native `file.lstat` type/mode fields and reuse
metadata already read. Exact type, special-mode-bit, owner, link-count,
size, content and hash checks remain equivalent. Root mode 0555 or 0755 is
still allowed only for `/`; other directories require 0755 and files 0644.
Previously generated selectors remain byte-identical and accepted. A
partially missing active family still refuses apply; rollback still accepts
missing assets. Full-catalog file-function calls fall from 109 to 39, reducing
Qubes Salt SSH render overhead. Independent review passed 99 old/new render
comparisons and eight actual native metadata cases; 20 native renders cover
all four choices, default no-op and rollback. Evidence is under
`/tmp/hud-font-prestage-render-b7zvop7t/`,
`/tmp/hud-font-catalog-audit-tk5rwoj6/` and
`/tmp/hud-font-catalog-audit-f39i8g71/`.

Actual all-family installation passed 17 dom0 and 18 hud-test states. Repeat
applies passed with zero changes. The default dom0 preview remains a single
no-op. Rollback previews passed eleven dom0 and twelve guest states without
removing files. Live Salt evidence is `/tmp/hud-font-reboot/salt-summary.json`.
The deployment audit covered 87 files and 15 script entrypoints with
no new dependencies or deployment network/build commands. Native package
install, refresh and removal still resolve to `qubes_dom0_update`; provider
evidence is `/tmp/hud-font-final-provider-6ucw5qsr/results.json`.

Stock i3 was restarted to refresh frame/bar fonts, then the seven managed
dom0 viewers/Manager were replaced using native matched placeholders and
container swaps. Interactive terminals and unrelated applications were
preserved. Firefox's native About Profiles restart replaced PID 918 with
5763; its original Google results tab was retained, and the browser's preset
mark and 40/30/30 column proportions were restored. Thunar's existing single
`/home/user` window required a normal application restart to discard its
cached Noto rendering; its folder, preset mark and outer frame were retained.
Refreshing the guest XSettings daemon alone had not refreshed Thunar. No
profile font preference, template, user terminal command or persistent
workspace configuration was changed for activation.

Screenshots in `/tmp/hud-font-reboot/` include `bindings-induction.png`,
`thunar-induction.png` and `firefox-induction-page.png`; each visibly renders
Induction, including the existing browser page. Native process mappings
provide a separate check of the loaded OTF. Temporary maintenance scripts in
that directory are not deployment inputs.

Induction has especially wide glyphs. Private native VTE measurement gives
18x14-pixel cells at the existing 8-point request, versus Xolonium's 12x13;
at 10 points the widths are 22 versus 15 pixels. VTE uses the widest ASCII
glyph for its fixed grid, and its stock cell-width scale has a minimum of
1.0. This is inherent proportional-font spacing, not an extra configured
tracking value. No spacing workaround was applied while comparing the
requested fonts. Evidence: `/tmp/hud-font-spacing-check/induction-comparison.json`.
Neuropol and Johnny Fever remain ready for later user-requested trials.

Final independent validation preserved all fourteen original outer frames,
ordered workspace structure/proportions, both preset group marks, and the five
protected original XIDs (four interactive terminals and Code). All seven
refreshed dom0 processes plus Firefox and Thunar map Induction. Both targets'
nine catalog files match pinned hashes, sizes and root:root 0644 metadata;
directories remain root:root 0755, and ordinary native font requests select
Induction. Evidence: `/tmp/hud-font-reboot/independent-validation.json`.
Final focus is workspace 1 HUD Bindings; workspace 2 retains the test apps.

### Neuropol trial (2026-09-13)

The user rejected Induction as unreadable and requested the next candidate.
**Neuropol was selected** in dom0 and the running hud-test preview. The user
subsequently kept it as a top candidate and requested Johnny Fever below. The unchanged shared state passed all 17 dom0 and
18 guest states, changing only the selector and native font cache on each
target. No assets were reinstalled, and no dependency, runtime code, template
font selection or terminal spacing exception was added.

The seven managed dom0 viewers/Manager were refreshed with the existing
maintenance procedure after stock i3's font-cache restart. Thunar's single
home-folder window was normally restarted, retaining its frame and mark.
Firefox's interface adopted Neuropol through the guest XSettings refresh,
but the existing page used a fallback font even after reload. Its native
About Profiles restart completed before the agent's guarded click (the old
XID had already disappeared), replacing PID 5763 with 11245. The browser
then rendered the original page in Neuropol. Its 40/30/30 layout and mark
were restored; only the temporary About Profiles tab was closed.

Independent verification preserved all fourteen original outer frames,
ordered layouts/proportions, both workspace root marks, four qube leaf marks
and the five protected interactive-terminal/Code XIDs. All seven refreshed
dom0 processes plus Firefox and Thunar map Neuropol, and native font matching
selects it in both targets. Evidence and screenshots are under
`/tmp/hud-font-neuropol/`, including `independent-validation.json`,
`bindings-neuropol.png`, `thunar-neuropol.png` and `firefox-neuropol.png`.
Unchanged default apply/rollback renders and UpdateVM providers were verified
in `/tmp/hud-neuropol-default-audit-xpobstfa/results.json`; deployment paths
match the preceding audited commit. Final focus is workspace 1 HUD Bindings.
The guest font selection remains ephemeral until a final font is chosen.

### Johnny Fever trial (2026-09-13)

The user retained **Neuropol as a top candidate** and requested the last font.
**Johnny Fever was selected** in dom0 and the running hud-test preview.
Induction remains rejected; no final favorite or template-wide installation
has been requested. All four committed candidates remain available locally.

The unchanged shared state passed 17 dom0 and 18 guest states, changing only
the selector and native cache. The seven managed dom0 viewers/Manager and
Thunar were refreshed using the existing maintenance procedure. Firefox's
native restart completed before the agent's guarded click, replacing PID
11245 with 13037. Its existing Woxikon page visibly renders Johnny Fever;
the original two tabs remain and the temporary About Profiles tab is gone.
Thunar remains in its original home-folder view, now PID 12990. The browser's
40/30/30 layout and marks were restored after its native restart.

Independent validation preserved all fourteen outer frames, ordered workspace
layouts/proportions, both root marks, four qube leaf marks and five protected
interactive-terminal/Code XIDs. All nine refreshed applications map the
committed Johnny-Fever.otf, and native matching selects Johnny Fever in both
targets. Evidence and screenshots are in `/tmp/hud-font-johnny-fever/`,
including `independent-validation.json`, `bindings-johnny-fever.png`,
`thunar-johnny-fever.png` and `firefox-johnny-fever.png`. Deployment files are
unchanged from `099b964`; their matching hashes retain the preceding native
default-render and UpdateVM-provider evidence, recorded in
`/tmp/hud-font-johnny-fever-preflight.json`. No runtime code, dependency or
terminal spacing exception changed. Final focus is workspace 1 HUD Bindings;
the guest selection remains ephemeral while the user compares candidates.


### Google Fonts candidates and Zen Dots trial (2026-09-14)

The user liked Johnny Fever's appearance but found its uppercase-only design
impractical, and requested Zen Dots, Orbitron (Google), then Wallpoet.
Neuropol remains a top candidate; Induction remains rejected. The shared
font catalog now includes these three additional families, retaining all
four earlier choices and their exact selector/asset declarations. The only
state change is the family/asset manifest expansion; no runtime helper,
package, framework or font conversion was added.

The original Google Fonts TTFs, copyright/OFL notices and catalog metadata
are committed under `files/fonts/google-fonts/`. Acquisition pinned official
repository commit `809e4d8b8d7e9364a914909bb777679606c178b8`, downloaded only
allowlisted files through HTTPS in existing sys-net, and checked Git blob
identities plus SHA-256 on transfer. Dom0 made no network request. Provenance
records source URLs, exact sizes/hashes and the commit. Orbitron's external
filename is `Orbitron-Variable.ttf` to satisfy the existing sync path policy;
its variable font bytes and internal name remain unchanged. Git attributes
preserve original TTF, metadata and licence bytes, including upstream trailing
spaces in OFL notices. Normal target deployment downloads nothing.

All three contain visibly distinct lowercase glyphs. Native Pango/FreeType
checks confirmed ASCII and German umlauts/sharp-s coverage; capital sharp-s
is present in Zen Dots and uses fallback in Orbitron/Wallpoet. Orbitron's
actual variable weight coordinates 400/700/900 were selected correctly.
Zen Dots and Wallpoet supply Regular only; ordinary bold synthesis remains
the stock renderer's behavior. Evidence is `/tmp/hud-google-font-check/`.

The first selected apply now stages fifteen font/licence files across seven
families, registering only the chosen directory after the runtime hash gate.
Native validation passed 32 default/family apply/rollback render variants;
independent review confirmed every asset pin, all thirty ordered existence
and hash checks, and byte-identical prior selectors. The deployment audit
covered 97 files and 15 script entrypoints with no new package declarations,
network/build commands, external Python modules, ELF programs or caches.
Native package providers still resolve to `qubes_dom0_update`. Evidence is
`/tmp/hud-google-fonts-native-i1owar_l/results.json` and
`/tmp/hud-font-catalog-audit-9z98k58_/google-fonts-results.json`.

**Zen Dots was selected for this trial, followed by Orbitron and Wallpoet below.** Actual applies passed 26 dom0 and
27 hud-test states; each staged the three added families and selected Zen
Dots. Repeat applies passed with zero changes. The seven managed dom0
viewers/Manager were refreshed after stock i3's font-cache restart, and
Thunar's single home-folder window was normally restarted (PID 17901),
retaining its frame and mark. The guest selection remains an ephemeral
preview; no TemplateVM font choice or terminal spacing exception was added.

The screen locked before Firefox's normal restart, initially leaving main
PID 13037 and trusted XID 77595338 running with an updated interface but
unverified page content. The user was asked to unlock normally; no unlock
attempt, lock termination or input injection was performed. The initial
`thunar-zen-dots.png` captures the lock and is not visual font evidence.
`partial-validation.json` records that temporary incomplete stage.

The user later unlocked and Firefox had already restarted to PID 20314 /
XID 77595431. Its existing Wikipedia page now visibly renders Zen Dots.
Native i3 commands restored its 40/30/30 layout and preset mark; only the
temporary About Profiles tab was closed. Final read-only verification
preserved all fourteen frames/layouts, five protected XIDs, both root marks
and four qube leaf marks. All seven refreshed dom0 processes plus Firefox
and Thunar map ZenDots-Regular.ttf. Evidence is
`/tmp/hud-font-zen-dots/independent-validation.json`; final screenshots are
`firefox-zen-dots-settled.png`, `thunar-zen-dots-unlocked.png` and
`top-zen-dots.png`. The 26/27-state repeats passed with zero changes.

The user asked where to judge terminal letter spacing. All five read-only
VTE panes (HUD top, xentop, systemd-cgtop, dom0 logs and Xen logs) were
refreshed and independently confirmed to load Zen Dots. Interactive terminal
sessions were preserved and can retain earlier cached font metrics. Final
focus was placed on workspace 1 HUD top for the spacing comparison. Orbitron
and Wallpoet remain the next trials; Neuropol stays on the shortlist.

### Orbitron and Wallpoet trials (2026-09-14)

The user requested the remaining original fonts before considering a
monospace derivative. Orbitron was selected in dom0 and the ephemeral
hud-test preview, and the seven managed dom0 windows plus Thunar were
refreshed. The user then requested stopping Orbitron before the planned
Firefox restart. **Wallpoet is now the current selection.** No font outlines,
terminal spacing configuration, runtime helper or package dependency changed.
Neuropol remains a shortlisted candidate; no final TemplateVM font selection
has been made.

Both switches used the unchanged bundled font state. Each passed 26 dom0 and
27 guest states, changing only the selector and native font cache. After the
Wallpoet apply, stock i3 and the seven managed dom0 applications were refreshed.
Thunar was normally restarted in its original home-folder view (PID 24271).
Firefox's native Restart normally control replaced PID 20314 with 24312;
its original Wikipedia page visibly renders Wallpoet. The original page and
blank New Tab remain; only the temporary About Profiles tab was closed.
The browser's preset mark and 40/30/30 layout were restored.

Independent validation preserved all fourteen outer frames, ordered layouts,
five protected interactive-terminal/Code XIDs, both root marks and all four
qube leaf marks against both the Wallpoet and original pre-Orbitron snapshots.
All seven refreshed dom0 processes plus Firefox and Thunar map Wallpoet, and
native font matching selects it in both targets. Evidence and screenshots are
under `/tmp/hud-font-wallpoet/`, including `independent-validation.json`,
`top-wallpoet.png`, `bindings-wallpoet.png`, `thunar-wallpoet.png` and
`firefox-wallpoet-page.png`. Final focus is workspace 1 HUD top. Interactive
terminal processes remain intact and may retain earlier cached font metrics.
The guest font installation remains an ephemeral AppVM preview.

Native VTE measurements at 96 DPI and Regular 8 points give cell widths of
8 pixels for Johnny Fever, 13 for Zen Dots, 13 for Orbitron and 10 for Wallpoet.
Median lowercase advances are 6, 8, 7 and 8 pixels respectively. Wallpoet's
approximately two pixels of spare cell width around a typical lowercase
letter are comparable to Johnny Fever; Orbitron remains relatively spread
out. This measures native fixed-grid rendering, not modified fonts or a
tracking adjustment. Measurements at 10 points and private terminal specimens
are recorded in `/tmp/hud-font-spacing-check/four-font-comparison.json` and
`spacing-*-8pt.png`. The private display was cleaned up.

Two native maintenance caveats were observed and resolved. Stock Qube Manager
startup raced deletion of Salt's temporary management disposable during the
Orbitron refresh; relaunching it after guest Salt completed succeeded. Finish
guest Salt before refreshing Manager. After the Wallpoet i3 restart, hidden
workspaces briefly retained geometry without the bar's reserved space;
visiting each existing workspace recalculated their original frames before
viewer replacement. Native restarts also required restoring the two exact
workspace group marks. These are maintenance actions, not deployed helpers.

The deployment audit covered 97 files and 15 script entrypoints with no new
dependencies, network/build commands or generated caches. Default font apply
and rollback remain no-ops; dom0 package install, refresh and removal still
resolve to `qubes_dom0_update`. Synced font states match the repository.
Evidence is `/tmp/hud-orbitron-deployment-audit-k35bkj9c/results.json`.
