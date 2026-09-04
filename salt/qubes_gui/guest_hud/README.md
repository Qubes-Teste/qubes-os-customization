# Qubes HUD guest-template theme

`qubes_gui.guest_hud` runs inside a Qubes TemplateVM. It installs the
application-facing part of the dom0 HUD as a named system theme and never
writes to `/home`, `/rw`, or an AppVM private volume.

The state supplies:

- GTK 2, GTK 3, and GTK 4 themes under `/usr/share/themes/Qubes-HUD`;
- the same black, glass-blue, cyan, text, and alert palette used by dom0;
- locked system Xfce/XSettings and dconf selections for existing and future
  AppVM homes;
- Adwaita icons with Noto Sans and Noto Sans Mono defaults;
- a matching Xfce Terminal palette when a user has no explicit terminal
  configuration;
- Qt 5 and Qt 6 GTK palette integration when the template already contains
  either generation's GTK 3 platform plugin.

The outer Qubes frame, rounded clipping, trusted label line, transparency,
blur, and glow remain in dom0. Installing a compositor or window manager in a
TemplateVM would not improve seamless guest windows and is intentionally out
of scope. Browser page content, Electron interfaces, and applications that
draw their own complete interface are also separate work.

## Safety and inheritance

The state verifies `/qubes-vm-type` and refuses dom0, AppVMs, StandaloneVMs,
and unsupported operating systems. Debian-family and Fedora TemplateVMs are
supported without encoding any Qube name or topology.

The selection policy lives under `/etc/qubes-hud`; it is deliberately not
placed under `/usr/local`, because Qubes gives each AppVM a private
`/usr/local` that does not track later TemplateVM changes.

All managed namespaces are unique and owner-marked. A symlink or non-directory
in any managed parent path, an unowned file, or a pre-existing unowned
`Qubes-HUD` directory makes the complete state fail before changing anything.
Rollback removes individual owned files only, and removes the empty theme or
configuration trees only when their ownership marker existed. It never
recursively deletes a directory and does not remove shared font or dconf
packages.

The Xfce and dconf theme choices are locked at system level so an existing
AppVM's saved toolkit theme cannot hide the HUD. The lock disappears on
rollback and the earlier user choice becomes effective again. A pre-existing
per-user Xfce Terminal palette is deliberately preserved.

Template root changes become visible only after the TemplateVM has shut down
and dependent AppVMs or DispVMs restart.

## Apply to an existing TemplateVM

Synchronize, render, and dry-run first:

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.show_sls qubes_gui.guest_hud saltenv=user
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud saltenv=user test=True
```

Apply it and repeat the command to verify zero further changes:

```sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud saltenv=user
sudo qvm-shutdown --wait debian-13-xfce
```

The final shutdown commits the TemplateVM root for newly started dependent
qubes. The example name is local policy, not part of the formula.

## Generate a themed TemplateVM

Provisioning is intentionally two-phase: Salt first clones an existing local
TemplateVM in dom0, then Salt applies `qubes_gui.guest_hud` inside the clone.
The target set for a Qubes Salt invocation is resolved before a new domain is
created, so a newly created TemplateVM cannot join that same first target set.

The wrapper performs both phases and reports success only after guest styling
succeeds:

```sh
./scripts/provision-hud-template.sh debian-13-xfce debian-13-hud
```

Source and target names are passed as pillar data. The dom0 state refuses to
adopt an existing target unless it already carries its
`hud-theme-managed` ownership tag.

## Roll back a TemplateVM

```sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.rollback saltenv=user test=True
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.rollback saltenv=user
```

Restart dependent qubes after either applying or rolling back.
