# Qubes OS customization

Portable Qubes OS 4.3 desktop customization, managed with Salt from dom0.

## Tiling window manager

The first formula installs Qubes' patched i3 session and its Qubes-specific
settings. It deliberately keeps Xfce installed as a fallback.

The formula:

- refuses to run outside Qubes 4.3 dom0;
- installs `i3` and `i3-settings-qubes` from signed repositories;
- automatically uses direct DNF when dom0 has a direct IPv4 default route;
- otherwise uses Qubes' native Salt package provider and UpdateVM path;
- manages a deterministic user config without running `i3-config-wizard`;
- uses the Windows-logo key (`Mod4`) as the i3 modifier;
- makes i3 the default for the next LightDM login without restarting the
  active graphical session;
- leaves the Xfce session and all Xfce packages intact.

### Install the formula

From this repository in dom0:

```sh
./scripts/sync-salt-formula.sh
```

Render and dry-run it before applying:

```sh
sudo qubesctl state.show_sls qubes_gui.i3 saltenv=user
sudo qubesctl state.sls qubes_gui.i3 saltenv=user test=True
```

Apply it:

```sh
sudo qubesctl state.sls qubes_gui.i3 saltenv=user
```

Run the same apply command again to verify idempotence. It should report zero
changes.

Log out only after the state succeeds. LightDM should select i3 by default;
Xfce remains available from the session chooser.

Useful initial bindings:

- `Windows-logo key+Enter`: terminal in the focused qube
- `Windows-logo key+D`: application launcher
- `Windows-logo key+Shift+D`: Qubes application menu
- `Windows-logo key+Shift+E`: exit i3 and return to LightDM

### Roll back to Xfce

The rollback state changes only the next LightDM default. It does not remove
i3 or delete user configuration:

```sh
sudo qubesctl state.sls qubes_gui.i3.rollback saltenv=user
```

Then log out and select Xfce if LightDM has remembered another per-user choice.

### Configuration

Defaults are defined in `salt/qubes_gui/i3/init.sls`. The supported pillar
keys are shown in `salt/pillar.example.sls`. The package transport defaults to
`auto`; use a pillar override only when route-based detection is inappropriate.

## HUD desktop shell

The `qubes_gui.hud` state adds the black/cyan shell shown by the visual
references under `style_guide/`. It installs an exactly black background,
30-pixel top bar, 32-pixel inner gaps, sharp frames with a maximum-intensity
48-pixel cyan glow, a translucent Rofi launcher, translucent Dunst
notifications, and glossy dom0 GTK chrome. On the current 598-mm-wide
reference display, the gap is approximately 10 mm; its physical size varies
with display DPI. The HUD deliberately does not style AppVM application
content or web pages.

Tiled windows can be dragged directly by their title bars. Drop near the top,
bottom, left, or right edge of another window to choose its tiled position;
drag a shared border to resize the neighboring tiles. Hold Shift before
starting the drag, then drop onto the center to swap the two windows.

In the HUD session, `Ctrl+Alt+T` always opens an `xfce4-terminal` in dom0. The
standard Windows-logo-key plus Enter binding remains context-sensitive and
opens a terminal in the currently focused qube.

Qubes label colors remain visible as compact rectangles in the upper-right of
normal window decorations. They are painted by a pinned, hardened i3 binary in
dom0 from gui-daemon's trusted label-color property; AppVM content cannot paint
or reposition them. The Qubes frame and label rectangle stay fully opaque;
Picom adds only an external glow to VM windows. The packaged `/usr/bin/i3`, its
login session, and Xfce all remain available as fallbacks.

At HUD startup, the keyboard helper first restores the desktop user's saved
Xfce layout, variant, model, and keyboard options and otherwise falls back to
the machine's complete system X11 tuple. No language is hardcoded in the
portable state, so this machine uses its saved German layout while another
machine keeps its own configured layout.

On another Qubes 4.3 machine, apply the base state first and then the HUD:

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl state.sls qubes_gui.i3 saltenv=user
sudo qubesctl state.sls qubes_gui.hud saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud saltenv=user
sudo qubesctl state.sls qubes_gui.hud saltenv=user
```

The second HUD apply should report zero changes. Log out and choose
**Qubes HUD (i3)**; the state never restarts the active desktop or LightDM.

The custom binary is accepted only on the exact audited Qubes/Fedora i3 base
and is verified by SHA-256 before use. Its complete source patch, pinned input
hashes, build recipe, license, and reproducibility notes are under
`source/i3-hud/`. See `salt/qubes_gui/hud/README.md` for collision handling and
the exact platform pins.

To return to packaged i3:

```sh
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user
```

Real user-triggered fullscreen has no window-manager decoration and therefore
no corner badge. Qubes' default gui-daemon policy rejects untrusted AppVM
fullscreen requests; override-redirect windows keep gui-daemon's protected
label border.
