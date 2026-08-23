# Qubes HUD Salt state

This state installs the HUD as a separate `qubes-hud` XSession. It does not
replace `/usr/bin/i3`, remove the packaged i3 session, restart LightDM, or
reload the currently running i3 process. The selected session takes effect at
the next logout/login.

The custom i3 binary draws the Qubes label-color rectangle inside the trusted
window-manager decoration. Applications cannot paint or move that badge. The
normal window frame remains on the shared black/cyan HUD palette. Picom adds an
external cyan glow, but Qubes frames and label badges remain fully opaque.

The tiled layout uses a 32-pixel inner gap and permits direct title-bar drag
and drop. On the current 1920-pixel-wide, 598-mm display, that is approximately
10 mm; the physical distance varies on displays with a different DPI. Dropping
near a target edge selects a tiled position, shared borders resize with the
mouse, and holding Shift before starting a center-drop drag swaps two tiled
windows.

The root background is exactly black. Picom uses the GLX backend for shadows,
fades, and blur on the dom0 shell: i3bar, Rofi, and Dunst. The compositor rules
default every window to full opacity and finish with a defense-in-depth Qubes
property/class rule that forces compositor opacity to 1 and disables blur for
VM windows. The HUD launches Picom with its explicit owned config path, so a
higher-priority personal Picom config cannot replace these safety rules.
The cyan shadow uses Picom's maximum supported opacity and an intentionally
oversized 48-pixel radius, so adjacent blooms overlap across the inner gap.

## Pinned platform

Application is refused unless all of these checks pass:

- Qubes OS 4.3 dom0 on `x86_64`
- `i3` epoch/version/release/architecture exactly
  `1000:4.25.1-1.fc41.x86_64`
- `i3-settings-qubes` version-release exactly `1.14-1.fc41`
- the audited `files/i3-hud` SHA-256 is pinned in `init.sls`

Before publishing or applying a rebuilt binary, update `i3_hud_sha256` in
`init.sls` to the 64-character lowercase SHA-256 of `files/i3-hud`. The
deployed binary is installed as
`/usr/local/libexec/qubes-hud/i3`; its checksum is verified and it validates
the candidate i3 config with `i3 -C` before Salt replaces the user config.

## Files supplied by the formula

The state expects these sources under `qubes_gui/hud/files/`:

- `i3-hud`
- `i3-config`
- `apply-keyboard-layout`
- `hud-xdg-autostart`
- `picom.conf`
- `qubes-hud.desktop`
- `qubes-hud-wallpaper.png`
- `qubes-hud.rasi`
- `dunstrc`
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
`/usr/local/libexec/qubes-hud/picom.conf`, then runs the normal Qubes system and
user XDG autostart entries while filtering any bare `picom.desktop` entry. This
keeps the HUD session on its explicit config and prevents a second,
unconfigured Picom instance inside that session. Picom's packaged XDG entry is
left untouched for other desktop sessions.

Terminal shortcuts retain Qubes' context-sensitive behavior while adding an
unambiguous trusted path: `Ctrl+Alt+T` always starts `xfce4-terminal` locally
in dom0. The key with the Windows logo plus Enter keeps Qubes' standard
context-sensitive behavior and opens a terminal in the focused qube.

Except for binary assets, every managed source must contain a recognized text
ownership marker. Formula/session files use
`Managed by qubes-os-customization Salt formula`; the Rofi, Dunst, and GTK
assets use `Qubes HUD managed file. Owner: salt/qubes_gui/hud.`. Binary
ownership is recorded by adjacent `.owner` files created only after the
corresponding asset has been installed successfully.

## Collision safety

The state checks every destination with `lstat` and refuses as a whole when a
target is a symbolic link, directory, FIFO, device, socket, other non-regular
inode, or a regular file lacking the ownership marker. This deliberately
protects an existing i3 config, Rofi theme, Dunst config, GTK CSS, Picom
config, helper, LightDM override, or XSession from silent adoption. It also
ensures rollback can never recursively remove an unexpected directory. For
the i3 binary and wallpaper, a pre-existing regular file is accepted only
when its adjacent ownership record carries the marker.

If a collision is intentional, move or merge that file manually and run the
dry run again. There is no force-overwrite pillar.

## Apply

After syncing this repository to the dom0 user Salt fileserver, render and dry
run before applying. On a fresh machine, apply `qubes_gui.i3` first; the HUD
state intentionally refuses to install against a missing or different i3 base:

```sh
sudo qubesctl state.sls qubes_gui.i3 saltenv=user
sudo qubesctl state.show_sls qubes_gui.hud saltenv=user
sudo qubesctl state.sls qubes_gui.hud saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud saltenv=user
```

Package transport defaults to `auto`: a dom0 default IPv4 route selects direct
DNF, otherwise the normal Qubes UpdateVM-backed `pkg.installed` path is used.
Only the runtime packages `rofi`, `feh`, and `picom` are installed. If Picom
was absent, the state records that it owns the package so rollback can remove
it; a Picom package that predates the HUD is never claimed or removed.
Supported pillar keys are `qubes_gui:hud:desktop_user`, `desktop_group`, and
`package_transport` (`auto`, `direct-dom0`, or `qubes-updatevm`).

Log out normally and select **Qubes HUD (i3)** if LightDM does not select it
automatically. Do not restart LightDM from an active dom0 desktop session.

## Roll back

Dry run and apply the rollback state:

```sh
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user
```

Rollback selects the packaged `i3` session for the next login, restores the
include-only `~/.config/i3/config`, and removes only owner-marked HUD files,
the HUD XSession, wallpaper, helpers, Picom config, and custom binary. It
removes Picom only when the HUD's package-ownership record proves that the
formula installed it; otherwise Picom is left untouched. It leaves `rofi`,
`feh`, and all packaged Qubes/i3 components installed. If any target is no
longer an owner-marked regular file, rollback refuses before making changes.
