# Qubes HUD Salt state

This state installs the HUD as a separate `qubes-hud` XSession. It does not
replace `/usr/bin/i3`, remove the packaged i3 session, restart LightDM, or
reload the currently running i3 process. The selected session takes effect at
the next logout/login.

The custom i3 binary draws the Qubes label-color rectangle inside the trusted
window-manager decoration. Applications cannot paint or move that badge. The
normal window frame remains on the shared navy/cyan HUD palette.

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
- `qubes-hud.desktop`
- `qubes-hud-wallpaper.png`
- `qubes-hud.rasi`
- `dunstrc`
- `gtk-3.css`
- `gtk-4.css`

The `qubes-hud.rasi` source is installed as `~/.config/rofi/config.rasi`, so
the standard `rofi -show drun` binding loads it without an extra command-line
flag.

Except for binary assets, every managed source must contain a recognized text
ownership marker. Formula/session files use
`Managed by qubes-os-customization Salt formula`; the Rofi, Dunst, and GTK
assets use `Qubes HUD managed file. Owner: salt/qubes_gui/hud.`. Binary
ownership is recorded by adjacent `.owner` files created only after the
corresponding asset has been installed successfully.

## Collision safety

The state refuses as a whole when a destination is a symbolic link or an
existing destination lacks the ownership marker. This deliberately protects
an existing i3 config, Rofi theme, Dunst config, GTK CSS, LightDM override, or
XSession from silent adoption. For the i3 binary and wallpaper, a pre-existing
file is accepted only when its adjacent ownership record carries the marker.

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
Only the runtime packages `rofi` and `feh` are installed. Supported pillar
keys are `qubes_gui:hud:desktop_user`, `desktop_group`, and
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
the HUD XSession, wallpaper, and custom binary. It leaves `rofi`, `feh`, and
all packaged Qubes/i3 components installed. If an owned target has lost its
marker or become a symlink, rollback refuses before making changes.
