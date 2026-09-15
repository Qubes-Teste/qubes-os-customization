# Qubes HUD Salt state

This state installs the HUD as a separate `qubes-hud` XSession using the
official Qubes-packaged `/usr/bin/i3`. It does not remove the standard i3
session, restart LightDM, or reload the currently running i3 process. The selected session takes effect at
the next logout/login.

The standard apply includes `qubes_gui.hud.font`: Zen Dots supplies interface
text and White Rabbit supplies terminals, editors and other monospace text.
The bundled pair needs no font pillar or separate apply. Native Fontconfig
rules cover the stock font requests used by the HUD and VS Code; existing
applications can retain cached fonts until their next normal restart.

The complete title, including the trusted `[qube-name]` descriptor, uses the
qube's label color through the official `client.* <label>` configuration.
The normal window frame remains on the shared black/cyan HUD palette.
Gray and black labels use light and medium gray text for readability; dom0
uses white. The eight standard Qubes labels are supported. The packaged
renderer cannot color just the descriptor independently of the application
title: it converts the combined title to plain text, so a `title_format`
markup span is displayed literally. The old custom line and close button are
retired; `Alt+F4` closes windows.
Normal shell and application text uses the focused-frame cyan `#19d3ff`.
Muted, disabled, selected, and urgent text retains separate semantic colors.
GTK, Rofi, and Dunst select the locally generated `Qubes-HUD-Cyan` theme. Its
generic glyphs use thin KDE Breeze Dark monochrome or symbolic geometry with
their foreground paint fixed to exact `#19d3ff`. It covers actions, small
categories, devices, emblems, MIME types, places, status icons, and custom thin
information and warning glyphs; the generated tree uses roughly 70 MiB.

Application-icon directories are intentionally not published by the theme.
Fallback inheritance through Adwaita, hicolor, and Breeze Dark preserves
application logos and Qubes VM class, label, security, and Qubes-specific
warning icons. Neutral Qubes tray concepts such as clipboard, domains, disks,
devices, and updates receive cyan aliases. Targeted regular NetworkManager
wired, disconnected, Wi-Fi signal, and secure status files use thin cyan
glyphs precomposed onto exact black for the legacy XEmbed path. Rofi prefers
the theme to raw window icons, while Dunst uses the thin themed information or
warning glyph only when a sender supplies no icon.

For guest-owned XEmbed tray windows, the state changes Qubes' GuiVM-wide
`gui-default-trayicon-mode` from its implicit full-label tint to the supported
`border1` mode. The source pixels therefore remain intact while Qubes retains
a one-pixel trusted VM-label border. Legacy 24-bit XEmbed source surfaces have
no alpha channel and were observed compositing transparent pixels onto a
light-gray `#f0f0f0` background before dom0 received them. The targeted
regular NetworkManager states, including secure variants, and Sdwdate/Tor
assets therefore carry their own exact-black canvas. A per-qube
`gui-trayicon-mode` remains a
higher-priority local policy. The state records the exact prior global feature
value before changing it and restores that value (or removes the feature when
it was originally absent) on rollback. Running `qubes-guid` processes are not
restarted; each qube adopts the setting the next time its GUI connection
starts.
The HUD glow helper draws the external cyan halo, while Picom adds an
edge-weighted inner rim that fades toward the center. Universal glass intentionally composites each
non-fullscreen application, including its Qubes frame and title, at 30%
transparency (70% opacity). Fullscreen windows remain fully opaque.

The tiled layout uses a 32-pixel inner gap and permits direct title-bar drag
and drop. On the current 1920-pixel-wide, 598-mm display, that is approximately
10 mm; the physical distance varies on displays with a different DPI. Dropping
near a target edge selects a tiled position, shared borders resize with the
mouse, and holding Shift before starting a center-drop drag swaps two tiled
windows. These mouse behaviors are supported by the official i3 build.

The root background is exactly black. Picom uses the GLX backend for shadows,
fades, and blur on the dom0 shell and all non-fullscreen application windows.
The baseline remains fully opaque, so docks, override-redirect surfaces, and
fullscreen applications do not inherit universal glass. A final Qubes
property/class rule retains the no-fade, always-composited policy without
overriding the non-fullscreen glass rule or its 12-pixel rounded corners. The
HUD launches Picom with its explicit owned config path, so a higher-priority
personal Picom config cannot replace these rules.
The external halo extends 34 pixels with a peak alpha of 0.35, so adjacent
glows overlap across the inner gap. Its brightness follows distance from the
rounded frame, keeping curved corners as bright as straight edges.
The inner cyan rim follows the same 12-pixel curve. Its shader applies lighting
after Picom synthesizes the rounded border; lighting before that step lets
Picom paint an unlit arc over the glow. The shader preserves Picom's processed
alpha, including window opacity and antialiased corner coverage.
Application rounding is reduced from 16 to 12 pixels to keep the opening
bracket of the trusted descriptor clear of official i3's smaller text inset.
Rofi and Dunst retain their 16-pixel radius.
Rofi and Dunst keep their native Picom shadows. No customized i3 or Picom
binary is deployed.

`hud-glow` and `glow_pixels.py` use the system Python standard library and
the stock desktop's libX11, libXrender, and libXfixes libraries through ctypes.
No additional packages or build steps are required. The helper places an
input-transparent surface immediately below each visible application frame
using public X11 properties and events. It follows window movement, stacking,
and workspace visibility without using i3 internals. Hidden, fullscreen, and
closed windows have no glow. This remains project-maintained dom0 code and
needs compatibility checks when the desktop stack changes.

## HUD Bindings reference

The HUD starts a regular, focusable `[dom0] HUD Bindings` window on workspace
1 at login. It uses the chosen card layout with 45 shortcut/mouse entries,
search and scrolling. Headings and key combinations use `#19d3ff`; descriptive
text, hints and controls use other cyan shades. Official i3 supplies the
trusted frame and dom0 title color.

The subtitle follows the active English (US/UK) or German keyboard. Physical
i3 keycode bindings are translated through the current XKB map and active
group once per second, without observing keystrokes or changing input state.
Shift remains explicit and Caps Lock does not alter labels. For example,
rightward focus is Super+Ö in German and Super+; in standard English.
The two scratchpad combinations also account for i3 resolving their `minus`
symbol in the first configured group when several layouts are present.
Search text survives keyboard changes, and matching entries update in place.
Unsupported layouts show unavailable physical-key labels. The descriptions
remain English and describe the shipped HUD configuration, not arbitrary
user-defined i3 bindings or independent guest keyboard settings.

The startup helper supplies native i3 slots on workspace 1: Bindings at left,
four terminals above Qubes Manager in the middle, then dom0 and Xen logs on the
right. Focus returns to the previously focused window. Repeated startup keeps
the existing arrangement; unrelated occupied workspaces are left alone.
Reopening an individual closed pane uses normal i3 insertion behavior.

Launch **HUD Bindings** from the HUD application launcher, or run:

```sh
/usr/bin/python3 -B /usr/local/libexec/qubes-hud/hud-bindings
```

A per-user/display lock keeps one Bindings window open. Repeating its manual
launch focuses it; the login command's `--background` option leaves existing
focus alone. Closing the window releases the lock and it can be reopened.
The lock is a checked, owner-only file in the session's `XDG_RUNTIME_DIR`.

`hud-bindings`, `bindings_keyboard.py` and `bindings.json` supply the reference.
The same frontend supplies the five read-only windows; `hud_terminal.py` adds
a shared GTK/VTE body around fixed native commands. `hud-workspace` prepares
the native i3 layout and launches the fixed applications. These helpers use
the existing Python interpreter, standard library and stock GTK3/GLib/X11,
VTE and Pango libraries through ctypes. No Python package or custom compiled
binary is added. The custom log reader remains retired. A small terminal
viewer is retained because installed Xterm and Xfce Terminal cannot supply
horizontal scrolling. These helpers are maintained by this project.

Salt validates Python syntax and staged JSON, then runs `hud-bindings --check`
without opening a display to verify the data, required symbols and native
command paths. `hud-workspace --check` validates its layout and launch commands.
Separate native checks validate the dom0 rsyslog configuration without reading
logs or opening windows. Files are root-owned, with marker/inode/owner/mode
collision checks and corresponding rollback. Startup depends on these checks
succeeding. Salt does not reload i3 or move existing windows; startup placement
takes effect at the next HUD login/reboot.

## Live dom0 and Xen logs

**HUD Dom0 Logs** and **HUD Xen Logs** are normal framed, focusable dom0
read-only terminals. Open them through the application launcher or run
`gtk-launch qubes-hud-dom0-logs` / `gtk-launch qubes-hud-xen-logs`.

The dom0 pane runs its own unprivileged foreground rsyslog. It combines new
accessible local system/user journal records with `/var/log/qubes/guid.*.log`,
`qrexec.*.log` and `qubesdb.*.log`, plus Xen's `xen-hotplug.log` and
`domain-builder-ng.log` when present. Journal records include dom0 kernel,
services, qubesd and other Qubes host activity. Each record has a timestamp
and source prefix. Sources interleave as received rather than being sorted
retrospectively into one exact timeline. The system rsyslog service and its
configuration remain untouched.

The Xen pane displays up to the last 64 KiB of
`/var/log/xen/console/hypervisor.log`, then follows new output with stock tail.
Stock cat renders controls and non-ASCII bytes visibly. The initial read may
begin partway through a line. Xen's own recorded timestamps remain intact;
there is no second generated timestamp/source prefix. A fixed banner explains
that recent Xen output is followed by new events. An empty file still shows
that banner. Stock xenconsoled records this single below-dom0 stream on the
development machine. `xl dmesg` exposes the same source and is not separately
added or cleared.

Neither pane connects to a guest or selects guest console/journal files,
update output or management-VM execution logs. Readers use the desktop user's
existing permissions: no sudo, root GUI, ACL or group changes. Protected
libvirt detail files remain unread; accessible service-journal messages are
still included. Native programs supply diagnostics instead of a custom
source-count/omissions footer. Tighter permissions can reduce coverage.

Dom0 initially follows new records without a recent tail. Its file readers
handle truncation, replacement and new matching files. On graceful close,
rsyslog saves small file-offset records under the private
`/run/user/UID/qubes-hud-terminals/dom0/` directory. Reopening during the same
login resumes those offsets, including records written while closed. Journal
following starts fresh each time. Xen loads its bounded recent tail on every
launch and follows truncation/replacement without saved offsets. No copied
log archive is stored. Both terminals retain 600 scrollback rows plus their
visible screen. The right slider scrolls history; returning to the bottom
resumes following. The bottom slider pans through the wide text canvas.

Controls and non-ASCII bytes, including Unicode, malformed encodings and
terminal escape sequences, display as visible escapes. Dom0 uses rsyslog's
escaping; Xen uses native `cat -vT` with the C locale. Both native followers
can follow matching symlinks, unlike the former custom O_NOFOLLOW reader.
Current selected host paths and their parents were checked and contain no
symlinks. A future matching dom0-created symlink would change the opened target.
Dom0 limits records to 2 KiB and descriptors to 512, with direct queue delivery;
larger source sets can exceed that descriptor limit. Xen limits the initial
read to 64 KiB and streams subsequent bytes with native buffers; it has no
additional per-line truncation. Terminal history remains bounded in both.

## Manager and terminal block

The complete workspace has these columns: Bindings (18%), a central block
(50%), dom0 logs (16%) and Xen logs (16%). In the central block, four equal
terminals fill the upper half; Qubes Manager fills the lower half. Native i3
gaps mean the visible frame widths differ slightly despite equal allocations.

The top row runs, left to right:

1. An ordinary interactive `xfce4-terminal` in the desktop user's home.
2. Dom0's standard `top --secure-mode`.
3. `xentop --delay=2 --full-name`.
4. `systemd-cgtop --delay=2 --depth=2`.

There is no separate `qvm-top`/`qubes-top` installed on the development machine;
the second pane therefore uses standard dom0 process top. The other monitors
show Xen domain usage and dom0 cgroup usage respectively. Cgroup metrics depend
on accounting already enabled by the system; the HUD does not enable any.
All commands run with the desktop user's existing permissions.

All five read-only panes share one GTK/VTE body and one Salt-rendered desktop
entry template. Mouse selection, **Ctrl+Shift+C** or **Ctrl+Insert** copying,
scrolling and focus remain available. VTE input is disabled before a command
starts; paste, mouse reporting and text drops cannot control the child.
Hyperlinks, sixel graphics and audible bells are disabled. Log bytes are
sanitized by native programs before entering VTE. There is no interactive
shell fallback when a command exits. The first Xfce terminal and Qubes Manager
remain interactive.

Each viewer uses Noto Sans Mono 8 and cyan shades on black. Both scrollbars
remain visible. Monitors draw on a canvas at least 1280px wide and 960px tall:
the bottom slider pans columns and the right slider pans rows of the current
live table. These monitor sliders do not replay historical top snapshots;
the native program still controls which rows it displays on that canvas.
Logs use a wide canvas sized to the visible height, with a separate right
slider connected to VTE's actual 600-row history. Its position remains visible
while horizontally panning. **Super+F** can still expand any pane.

Native `flock` keeps one launched terminal per user/view; duplicate desktop
launches exit quietly. The shared frontend also retains its checked per-view
instance lock. Normal close terminates and reaps the owned native command.
Dom0 rsyslog uses native parent-death signaling. Xen's fixed, noninteractive
Bash pipeline starts tail and cat with parent-death signaling, so both stop
even if the quiet reader's shell exits unexpectedly. Bash ignores startup
environment hooks; the pipeline runs entirely as the desktop user.
User-tmpfiles creates private runtime directories and locks at login. Salt
also prepares them for an already logged-in user; it neither starts a user
session nor removes active runtime objects on rollback.

In its default startup mode, `hud-workspace` embeds the layout, uses public i3
IPC, then exits. It launches
the official Manager with Qt's `-name qubes-hud-manager` instance argument;
matching does not depend on its translated class/title. It creates a layout
on an empty target or extends the previous three-pane HUD while retaining
those window IDs. Other windows, fullscreen panes, an existing complete HUD,
or HUD applications already open elsewhere prevent reconstruction. A private
per-display lock prevents concurrent launchers. It does not run a layout daemon.
An assembly failure is reported without preventing normal Qubes desktop
autostart from continuing.

Normal login uses workspace 1. To explicitly assemble a preview on a suitable
workspace 2 using the same installed source:

```sh
/usr/bin/python3 -B /usr/local/libexec/qubes-hud/hud-workspace --workspace 2
```

The bar always offers workspace buttons **1–5**. Official i3 removes empty
workspaces when they are no longer visible; clicking a retained button creates
that native workspace on demand. The HUD dashboard starts only on workspace 1;
no applications or placeholder windows are launched on 2–5. Existing workspaces,
including 6–10 and named workspaces, remain available with their real focus,
visibility, urgency and output assignments.

This uses the official i3bar `workspace_command` protocol, available in i3
**4.23 or newer**. The existing helper's small `--buttons` mode listens to native
`i3-msg` workspace/output events and adds missing buttons to i3's actual JSON.
Absent buttons use i3bar's primary-output fallback. It does not poll, move
windows or maintain empty workspaces. The initial tick event closes the
subscription startup race; bar shutdown terminates and reaps the subscriber.
Qubes status and tray handling remain with `qubes-i3status` and i3bar.
The bar uses White Rabbit through the shared monospace font rules, keeping
the clock's width constant as digits change. Window titles retain Zen Dots.
Other status fields can still resize when their character count changes.

Individual monitors can be reopened from the application launcher or with
`gtk-launch qubes-hud-top`, `gtk-launch qubes-hud-xentop` and
`gtk-launch qubes-hud-cgtop`. General HUD rollback removes owned launch/config
files and the startup hook without closing applications or restarting the
live desktop. Old managed `hud_logs.py`, `hud_monitor.py`, Xterm resources and the Xen
rsyslog configuration are removed only after their replacements validate.

## Display-wide night light

**HUD Night Light** switches the entire X11 display to green monochrome from
**21:00 to 08:00** in the system's local timezone. This acts on the graphics
output after applications are drawn, so it covers dom0, all qubes, fullscreen
applications, images and Qubes label colors. The user explicitly accepted the
label-color change. The red and blue output matrix rows are zero; all three
input channels contribute to green luminance. This is a green filter, rather
than the warm white-temperature adjustment commonly called night light.

Open **HUD Night Light** in the application launcher to select Automatic,
Day, Night or Change hours. Enter two 24-hour times, for example `21:00 08:00`.
The interval includes its start and excludes its end; equal times are refused.
Changing hours selects Automatic. The marked preferences file
`~/.config/qubes-hud/night-light.ini` is preserved by subsequent Salt applies.
Equivalent commands, run as the desktop user, are:

```sh
/usr/local/libexec/qubes-hud/hud-night-light --hours 21:00 08:00
/usr/local/libexec/qubes-hud/hud-night-light --mode night
/usr/local/libexec/qubes-hud/hud-night-light --mode auto
/usr/local/libexec/qubes-hud/hud-night-light --status
```

Salt installs a native systemd user oneshot service and timer; the HUD login
hook imports the local display environment and starts them. An existing
session can start them with `hud-night-light --start` at the full path above.
Apply itself does not activate the filter. Automatic checks run at each local
minute boundary and on clock/timezone changes. Calendar timers catch up after
resume; an output reset or newly connected monitor is corrected at the next
check, normally within 61 seconds. Both night and subsequent day checks reassert
the owned matrix even if Xorg's cached property already matches, so a cached
value does not prevent retries.
No compositor, window-manager or application
restart is involved. `--mode day` keeps normal colors; `--stop` stops the timer
and restores saved transforms for connected outputs. General HUD rollback
does the same before deleting the helper and service units.

The graphics driver must expose a working XRandR `CTM` color-matrix property
on every active output. Missing support causes night activation to fail with
an error, before any new matrices are written. This was tested on the reference
machine's Intel i915/modesetting HDMI output; support on other graphics drivers
must be verified. Query errors appear in the user service journal. X-property
readback alone cannot prove that a driver applied the physical output change,
and screenshots usually capture pixels before this transform.

`hud-night-light` handles the schedule, menu and restoration; `hud_output.py`
binds the existing `libX11.so.6` and `libXrandr.so.2` through standard-library
ctypes. The native API avoids the incompatible `xrandr --set CTM` command-line
formats in xrandr 1.5.2 and 1.5.3. Neither helper replaces a system binary or
requires a Python module or package. Native Salt configuration cannot itself
perform the output matrix conversion and exact restoration at session runtime.

Original matrices are saved before writes in a private per-display runtime
file, with output identity derived from the connector name and EDID hash.
Repeated checks do not accumulate the filter. A reset or external calibration
becomes the new baseline at night; daytime restoration leaves an externally
changed matrix alone. Disconnected outputs retain their saved record until
they can be restored, without applying it to a different identified monitor.
Day records remain available for retries until an external change releases
ownership or the private login runtime is removed.
The filter changes displayed RGB values; it does not measure a monitor's
physical light spectrum or promise a medical effect.

## Supported platform and official packages

Application is refused unless all of these checks pass:

- Qubes OS 4.3 dom0 on `x86_64`
- the official Qubes `i3` package is installed (4.23 or newer for the workspace
  protocol), and `/usr/bin/i3` matches its
  installed RPM's file digest
- `i3-settings-qubes` version-release exactly `1.14-1.fc41`

The base state obtains i3 through Qubes' UpdateVM-backed package provider.
The HUD ships no compiled window manager and has no custom i3 build/version
pin. It validates the candidate config with `/usr/bin/i3 -C` before replacing
the user config. The settings package guard remains because the committed
configuration and autostart helper derive from that exact Qubes integration.

VTE and GTK/Pango are already dependencies of the stock Xfce desktop terminal.
Rsyslog is selected by the supported Qubes 4.3 desktop's standard package group;
tail and cat come from coreutils, and the remaining launch utilities from
stock Bash, util-linux, GTK and systemd. No package is added to the formula's
install list. A stripped installation missing required tools/libraries fails
runtime validation. Package transport remains Qubes' native UpdateVM-backed
provider; normal dom0 deployment has no direct network calls.

For existing HUD installations, the legacy `/usr/local/libexec/qubes-hud/i3`
path becomes a small managed shell launcher that runs `/usr/bin/i3` with all
arguments forwarded. Its adjacent record and known content hashes distinguish
the retired artifact from the compatibility launcher and refuse unrelated or
modified files. The launcher keeps the active custom process's restart path
valid until it is reexecuted or the user logs out. New XSessions directly run
`/usr/bin/i3`.

## Files supplied by the formula

The state expects these sources under `qubes_gui/hud/files/`:

- `i3-official-compat`
- `i3-config`
- `apply-keyboard-layout`
- `hud-xdg-autostart`
- `hud-glow`
- `glow_pixels.py`
- `hud-bindings`
- `bindings_keyboard.py`
- `hud_terminal.py`
- `hud-terminal-tmpfiles.conf`
- `hud-dom0-logs.conf`
- `hud-workspace`
- `bindings.json`
- `qubes-hud-bindings.desktop`
- `qubes-hud-terminal.desktop` (shared template for five launchers)
- `picom.conf`
- `window-glass.glsl`
- `qubes-hud.desktop`
- `qubes-hud-wallpaper.png`
- `qubes-hud.rasi`
- `dunstrc`
- `terminalrc`
- `manage-cyan-icon-theme`
- `manage-trayicon-mode`
- `gtkrc-2.0`
- `gtk-settings.ini`
- `gtk-3.css`
- `gtk-4.css`

The `qubes-hud.rasi` source is installed as `~/.config/rofi/config.rasi`, so
the standard `rofi -show drun` binding loads it without an extra command-line
flag.

On each HUD login, `apply-keyboard-layout` first uses the desktop user's saved,
enabled Xfce keyboard layout, variant, optional model, and Group/Compose or
flat XKB options. If that preference is unavailable or incomplete, it applies
the machine's complete system X11 tuple from `localectl`. The helper never
hardcodes a country or language.

`hud-xdg-autostart` starts `/usr/bin/picom` synchronously with
`/usr/local/libexec/qubes-hud/picom.conf`, starts `hud-glow` in the background
once Picom succeeds, prepares native terminal runtime files, runs
`hud-workspace` to prepare workspace 1 and launch
its fixed applications, then runs the normal
Qubes system and user XDG autostart entries while filtering any bare
`picom.desktop` entry. This
keeps the HUD session on its explicit config and prevents a second,
unconfigured Picom instance inside that session. Picom's packaged XDG entry is
left untouched for other desktop sessions. There is no preview supervisor or
automatic switch back to native application shadows. Salt validates the glow
helper's installed runtime libraries without opening a display before enabling
the managed configuration and autostart hook.

Terminal shortcuts retain Qubes' context-sensitive behavior while adding an
unambiguous trusted path: `Ctrl+Alt+T` always starts `xfce4-terminal` locally
in dom0. The key with the Windows logo plus Enter keeps Qubes' standard
context-sensitive behavior and opens a terminal in the focused qube. Press
`Alt+F4` to close a window. Fullscreen windows have no
decoration, so use the keyboard shortcut there.

The state also owns the desktop user's Xfce Terminal profile so its normal and
uncolored bold text uses `#19d3ff`, plus GTK 2/3/4 settings that select
`Qubes-HUD-Cyan`. The HUD XSession selects Qt's GTK platform theme. Before
starting XDG applications, the managed autostart helper publishes that setting
to D-Bus and the systemd user manager as well. Native Qt tools launched
directly or by Qubes' resident application menu therefore use the adapter's
font, icon-theme, and native-dialog integration from the next login. The GTK
adapter does not translate GTK CSS colors into a Qt widget palette; Whonix's
narrowly scoped `qt5ct` handling is separate.

`manage-cyan-icon-theme` deterministically builds the theme from the installed
KDE Breeze Dark package, preferring the thinner symbolic peer for a regular
icon when one exists and exposing only Breeze directories documented as
monochrome. Fedora supplies that source through `breeze-icon-theme`. Breeze
artwork retains its upstream LGPL/CC-BY-SA licensing; the package's installed
copyright and license files are authoritative. The generated theme includes a
provenance note, owner marker, and manifest of inode types, modes, owners,
hashes, and symbolic-link targets.

`manage-trayicon-mode` applies only in dom0. It transactionally records the
previous Qubes GuiVM feature before setting the one-pixel tray border, refuses
external drift while owned, and restores the exact baseline on rollback.

An icon theme can only replace icons looked up by name. Absolute Qubes
application-menu icon paths, web content, thumbnails, client-provided tray
images, and `_NET_WM_ICON` title-bar pixels bypass it. They remain untouched;
the label-colored window titles also retain their security meaning.

Except for binary assets, every managed source must contain a recognized text
ownership marker. Formula/session files use
`Managed by qubes-os-customization Salt formula`; the Rofi, Dunst, Xfce
Terminal, and GTK assets, Picom config, and window shader use
`Qubes HUD managed file. Owner: salt/qubes_gui/hud.`. Binary ownership is
recorded by adjacent `.owner` files. The legacy i3 migration uses exact known
hashes and a resumable record transition for its shell replacement. The GTK icon-setting files
receive an ownership record only after all three have installed successfully.

## Collision safety

The state checks every destination with `lstat` and refuses as a whole when a
target is a symbolic link, directory, FIFO, device, socket, other non-regular
inode, or a regular file lacking the ownership marker. This deliberately
protects an existing i3 config, Rofi theme, Dunst config, Xfce Terminal profile,
GTK settings or CSS, Picom config, window shader, helper, LightDM override, or
XSession from silent adoption. It also ensures rollback can never recursively
remove an unexpected directory. The legacy i3 path and its record must match
the known hashes, contents, root ownership, and modes before migration or
removal. For the wallpaper, a pre-existing regular file is accepted only when
its adjacent ownership record carries the marker.

An existing `/usr/share/icons/Qubes-HUD-Cyan` is accepted only when its owner
marker and complete manifest validate. An update first validates the old tree
and builds its replacement separately. Rollback likewise checks the complete
tree before unlinking only manifest-listed entries and removing directories
once empty. Modified, added, ownership-changed, or type-changed content makes
it refuse; a manifest-listed item already missing during an interrupted
rollback is the sole exception, allowing that exact removal to resume.

For upgrade compatibility, rollback preserves an unfamiliar pre-existing GTK
icon settings file when the icon-setting ownership record has never been
created. Once this version has installed that record, the normal strict marker
checks apply to all three settings files.

If a collision is intentional, move or merge that file manually and run the
dry run again. There is no force-overwrite pillar.

## Apply

After syncing this repository to the dom0 user Salt fileserver, render and dry
run before applying. On a fresh machine, apply `qubes_gui.i3` first; the HUD
state intentionally refuses a missing or modified packaged i3 executable:

```sh
sudo qubesctl state.sls qubes_gui.i3 saltenv=user
sudo qubesctl state.show_sls qubes_gui.hud saltenv=user
sudo qubesctl state.sls qubes_gui.hud saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud saltenv=user
```

Package transport defaults to the normal Qubes UpdateVM-backed `pkg.installed`
path, so deployment never assumes direct dom0 Internet. `auto` remains an
explicit development override that selects direct DNF only when dom0 has a
default IPv4 route; `direct-dom0` is also available as an explicit override.
The runtime packages are `rofi`, `feh`, `picom`, and
`breeze-icon-theme`. If Picom was absent, the state records that it owns the
package so rollback can remove it; a Picom package that predates the HUD is
never claimed or removed. The shared Breeze package is retained on rollback,
like Rofi and Feh.
The bundled fonts add no package dependency or network fetch. The stock
graphical target must already provide Fontconfig and `/usr/bin/fc-cache`;
the font state verifies that prerequisite before changing its files.
Supported pillar keys are `qubes_gui:hud:desktop_user`, `desktop_group`, and
`package_transport` (`auto`, `direct-dom0`, or `qubes-updatevm`).

Log out normally and select **Qubes HUD (i3)** if LightDM does not select it
automatically. Do not restart LightDM from an active dom0 desktop session.
Applying an updated state does not replace the i3 process already running in
an existing HUD session. Log out and back in to activate the official binary.
An `i3-msg reload` only reloads configuration and is insufficient; after
validation, `i3-msg restart` can deliberately restart i3 in place.

## Optional qube workspace on workspace 2

`qubes_gui.hud.qube` creates a separate green AppVM from an already installed
Linux template. The first preset uses Firefox on the left (40%), two Xfce
terminals stacked in the middle (30%), and Thunar on the right (30%). Its
NetVM is `sys-firewall`. The template must already provide those programs;
this state installs no package and changes no template.

The approach follows the community's
[Qube-specific workspaces](https://forum.qubes-os.org/t/qube-specific-workspaces/28513)
idea using stock i3 layouts and
[Qubes' standard guest autostart](https://doc.qubes-os.org/en/latest/user/how-to-guides/how-to-install-software.html#autostarting-installed-applications).
It does not install the guide's Xfce scripts. Four native `.desktop` files in
the AppVM user's `~/.config/autostart` start the apps on each guest GUI session.
The existing dom0 `hud-workspace` helper supplies layout setup and repeated-click
focus. There is no new guest script, resident layout daemon or custom binary.

Provision in three phases so boot autostart is enabled only after guest setup.
First synchronize and apply the current HUD as above, then select a **new**
AppVM name and an installed template. For the tested Debian preset:

```sh
workspace_pillar='{"qubes_gui":{"hud":{"qube_workspace":{"name":"hud-test","template":"debian-13-xfce","ready":false}}}}'
sudo qubesctl state.sls qubes_gui.hud.qube saltenv=user pillar="$workspace_pillar" test=True
sudo qubesctl state.sls qubes_gui.hud.qube saltenv=user pillar="$workspace_pillar"
sudo qubesctl --skip-dom0 --targets=hud-test state.sls qubes_gui.hud.qube saltenv=user pillar="$workspace_pillar" test=True
sudo qubesctl --skip-dom0 --targets=hud-test state.sls qubes_gui.hud.qube saltenv=user pillar="$workspace_pillar"
workspace_ready='{"qubes_gui":{"hud":{"qube_workspace":{"name":"hud-test","template":"debian-13-xfce","ready":true}}}}'
sudo qubesctl state.sls qubes_gui.hud.qube saltenv=user pillar="$workspace_ready" test=True
sudo qubesctl state.sls qubes_gui.hud.qube saltenv=user pillar="$workspace_ready"
```

The optional state does nothing when `qube_workspace.name` is absent; a normal
HUD install creates no test qube. Existing targets are accepted only with the
`hud-workspace-managed` ownership tag and the matching AppVM/template identity.
All persistent settings are Salt-managed. Native Qubes transport works with
dom0 offline; guest provisioning uses the installed Qubes management machinery.

The qube starts at boot through its native `autostart` property; its windows
appear on workspace 2 when the HUD GUI session is available. The same app group
starts when Qubes Manager starts the qube, including when some other launcher
was the reason it started. **Start workspace**, listed under that qube in the
Applications menu and available in the HUD launcher, starts the qube or focuses
its existing group without starting another copy of any app. Manager's own
Start action remains disabled while a qube is running. Closing a pane does not
automatically reopen it; restart the qube to start the complete group again.

Placement uses the Qubes GUI daemon's trusted qube prefix on `WM_CLASS`, plus
distinct native application classes. The i3 rule also arranges windows that
arrived before layout preparation, so startup order is not a fixed-delay guess.
Existing marked layouts retain user rearrangements. An occupied workspace 2
containing unrelated windows is left intact and reported as a conflict.
Workspace 1's dom0 dashboard is unaffected.

For an immediate preview after provisioning, reload i3 configuration and start
the new qube after a clean shutdown if guest setup left it running. Do this
only when the test qube has no unsaved work:

```sh
i3-msg reload
qvm-shutdown --wait hud-test
/usr/local/libexec/qubes-hud/hud-workspace --qube
```

To remove this optional preset, use the same `workspace_pillar` from above:

```sh
sudo qubesctl --skip-dom0 --targets=hud-test state.sls qubes_gui.hud.qube-rollback saltenv=user pillar="$workspace_pillar" test=True
sudo qubesctl --skip-dom0 --targets=hud-test state.sls qubes_gui.hud.qube-rollback saltenv=user pillar="$workspace_pillar"
sudo qubesctl state.sls qubes_gui.hud.qube-rollback saltenv=user pillar="$workspace_pillar" test=True
sudo qubesctl state.sls qubes_gui.hud.qube-rollback saltenv=user pillar="$workspace_pillar"
i3-msg reload
```

This removes only the owned guest autostart and dom0 preset/menu files and
disables the preset's boot startup. It retains the AppVM, its private data,
ownership tag and currently open windows. Remove the optional preset before
the full HUD rollback below; that rollback refuses while preset assets remain.

## Roll back

Dry run and apply the rollback state:

```sh
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user
```

Rollback selects the packaged `i3` session for the next login, restores the
include-only `~/.config/i3/config`, and removes only owner-marked HUD files,
including the Xfce Terminal profile and GTK icon settings, plus the HUD
XSession, wallpaper, helpers, Picom config and shader, generated cyan icon
tree, and compatibility launcher. The included `qubes_gui.hud.font-rollback`
also removes the owned font selector and bundled font files, preserving
distribution fonts. If the old custom i3 process is still
running, rollback retains its verified launcher and record to keep its restart path
valid; a later rollback can remove them once that process has exited.
The icon manager validates the entire generated tree against its ownership
manifest before removing its listed entries. Rollback
removes Picom only when the HUD's package-ownership record proves that the
formula installed it; otherwise Picom is left untouched. It leaves `rofi`,
`feh`, `breeze-icon-theme`, and all packaged Qubes/i3 components installed. If
any existing target is no longer an owner-marked regular file, or the icon
tree no longer matches its manifest, rollback refuses before making changes.

The D-Bus activation environment cannot remove a published variable in place.
After rollback from an active HUD session, log out normally to clear
`QT_QPA_PLATFORMTHEME` and enter the restored packaged i3 session.
