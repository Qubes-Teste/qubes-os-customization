# Qubes HUD Salt state

This state installs the HUD as a separate `qubes-hud` XSession using the
official Qubes-packaged `/usr/bin/i3`. It does not remove the standard i3
session, restart LightDM, or reload the currently running i3 process. The selected session takes effect at
the next logout/login.

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

Native i3 rules assign the reference to workspace 1 without taking focus from
another workspace at startup. It fills the workspace while it is the only
window; as normal windows arrive, i3 allocates it a quarter of the available
horizontal split. The rules do not reconstruct existing layouts. Reopening
it after manually changing a layout uses normal i3 insertion behavior.
The layout trial's four terminal windows are not started automatically.

Launch **HUD Bindings** from the HUD application launcher, or run:

```sh
/usr/bin/python3 -B /usr/local/libexec/qubes-hud/hud-bindings
```

A per-user/display lock keeps one reference window open. Repeating the manual
launch focuses it; the login command's `--background` option leaves existing
focus alone. Closing the window releases the lock and it can be reopened.
The lock is a checked, owner-only file in the session's `XDG_RUNTIME_DIR`.

The application consists of `hud-bindings`, `bindings_keyboard.py` and
`bindings.json`, installed under `/usr/local/libexec/qubes-hud/`, plus
`/usr/share/applications/qubes-hud-bindings.desktop`. All are root-owned,
with marker/inode/owner/mode collision checks and corresponding rollback.
It uses only the existing Python standard library and stock GTK3/GLib/X11
shared libraries through ctypes. No packages or custom compiled binaries are
added. This is project-maintained dom0 source code, not an official Qubes app.

Salt validates Python syntax and staged JSON, then runs `hud-bindings --check`
without opening a display to verify the data and required library symbols.
Startup and the launcher depend on this check succeeding. Salt does not
reload the running i3 configuration or move existing windows. New assignment
and login behavior apply at the next HUD login/reboot.

## Supported platform and official packages

Application is refused unless all of these checks pass:

- Qubes OS 4.3 dom0 on `x86_64`
- the official Qubes `i3` package is installed, and `/usr/bin/i3` matches its
  installed RPM's file digest
- `i3-settings-qubes` version-release exactly `1.14-1.fc41`

The base state obtains i3 through Qubes' UpdateVM-backed package provider.
The HUD ships no compiled window manager and has no custom i3 build/version
pin. It validates the candidate config with `/usr/bin/i3 -C` before replacing
the user config. The settings package guard remains because the committed
configuration and autostart helper derive from that exact Qubes integration.

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
- `bindings.json`
- `qubes-hud-bindings.desktop`
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
once Picom succeeds, starts `hud-bindings --background`, then runs the normal
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
Supported pillar keys are `qubes_gui:hud:desktop_user`, `desktop_group`, and
`package_transport` (`auto`, `direct-dom0`, or `qubes-updatevm`).

Log out normally and select **Qubes HUD (i3)** if LightDM does not select it
automatically. Do not restart LightDM from an active dom0 desktop session.
Applying an updated state does not replace the i3 process already running in
an existing HUD session. Log out and back in to activate the official binary.
An `i3-msg reload` only reloads configuration and is insufficient; after
validation, `i3-msg restart` can deliberately restart i3 in place.

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
tree, and compatibility launcher. If the old custom i3 process is still
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
