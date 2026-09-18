# Qubes OS customization

Portable Qubes OS 4.3 desktop customization, managed with Salt from dom0.

## Tiling window manager

The first formula installs Qubes' patched i3 session and its Qubes-specific
settings. It deliberately keeps Xfce installed as a fallback.

The formula:

- refuses to run outside Qubes 4.3 dom0;
- installs `i3` and `i3-settings-qubes` from signed repositories;
- keeps dom0 offline and uses Qubes' native Salt package provider and UpdateVM
  path by default;
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

The sync script verifies every formula entry point before touching the Salt
tree. It records hashes for copied files so later Git revisions remove only
stale files that are still byte-for-byte identical to the version it placed;
a locally modified stale file is preserved and makes the sync stop.

Dom0 deployment uses only files in this repository and software supplied by
the configured Qubes repositories. Dom0 remains offline: missing signed RPMs
are obtained through its UpdateVM. Dom0 Python helpers use its existing
interpreter and standard library; dom0 deployment does not install pip modules,
compile software or distribute a customized i3 binary. Inside guest qubes,
requested software may use upstream sources, language indexes and additional
runtimes under the separate guest policy in `AGENTS.md`.

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
- `Alt+F4`: close the focused window

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
`qubes-updatevm`, so a fresh deployment never assumes direct dom0 Internet.
`auto` and `direct-dom0` remain explicit development overrides.

## HUD desktop shell

The `qubes_gui.hud` state adds the black/cyan shell shown by the visual
references under `style_guide/`. It installs an exactly black background,
30-pixel top bar, 32-pixel inner gaps, 12-pixel rounded frames with a
34-pixel cyan glow with evenly lit corners, a translucent Rofi launcher, translucent
Dunst notifications, and glossy dom0 GTK chrome. On the current 598-mm-wide
reference display, the gap is approximately 10 mm; its physical size varies
with display DPI. The dom0 HUD toolkit theme does not style AppVM application
content or web pages. The guest-template state below adds the matching style;
the scheduled display filter described below covers every visible application.

Normal dom0 shell, toolkit, and terminal text uses the same `#19d3ff` cyan as
the focused outer frame. Semantic selection, muted, disabled, and urgent text
keeps distinct colors. GTK styling does not by itself recolor Qt widget
palettes; the narrowly scoped Whonix Qt exception is described below.
GTK, Rofi, and Dunst explicitly select the locally generated
`Qubes-HUD-Cyan` icon theme. It derives thin monochrome and symbolic geometry
from KDE Breeze Dark and fixes generic actions, status, devices, places, MIME
types, emblems, small categories, and notification glyph foregrounds to the
exact same `#19d3ff`. The generated tree occupies roughly 70 MiB on each root filesystem
where it is installed. It is built locally from the distribution's KDE Breeze
Dark package (`breeze-icon-theme` on Fedora and `kf6-breeze-icon-theme` on
Debian) and retains Breeze's upstream LGPL/CC-BY-SA licensing.

Application-icon directories are deliberately excluded. The theme inherits
from Adwaita, hicolor, and Breeze Dark, so application logos and Qubes VM
class, label, security, and Qubes-specific warning icons retain their original
identity and colors. Neutral Qubes tray concepts such as clipboard, domains,
disks, devices, and updates receive thin cyan aliases. Targeted regular
NetworkManager wired, disconnected, Wi-Fi signal, and secure status files use
thin cyan glyphs. Pixels supplied directly by an application remain outside
icon-theme lookup.

Guest XEmbed tray icons use Qubes' supported `border1` rendering mode in the
HUD. This keeps the guest's source pixels intact and retains a one-pixel
trusted VM-label border instead of recoloring the complete glyph to the VM
label. Legacy 24-bit XEmbed source surfaces have no alpha and were observed
compositing transparent icon pixels onto a light-gray `#f0f0f0` background
before dom0 received them, so the targeted regular NetworkManager states,
including secure variants, and Sdwdate/Tor tray glyphs are precomposed onto
exact black. Per-qube tray-mode
features still take precedence. Existing GUI daemon connections pick up the
GuiVM-wide default at their next start; the state does not restart running
networking or anonymity qubes.

Tiled windows can be dragged directly by their title bars. Drop near the top,
bottom, left, or right edge of another window to choose its tiled position;
drag a shared border to resize the neighboring tiles. Hold Shift before
starting the drag, then drop onto the center to swap the two windows.

In the HUD session, `Ctrl+Alt+T` always opens an `xfce4-terminal` in dom0. The
standard Windows-logo-key plus Enter binding remains context-sensitive and
opens a terminal in the currently focused qube.

The HUD uses the official Qubes-packaged `/usr/bin/i3`. Qubes label colors
appear in the complete window title, including its trusted `[qube-name]`
descriptor, while the frame stays on the black/cyan palette. For example,
`[sys-firewall] user - Thunar` is green for a green-labeled qube. Gray and
black labels use readable light and medium gray text against the dark
titlebar; dom0 uses white. The packaged renderer does not support coloring
only the descriptor separately from the application title.

The old custom label line and close button are retired. Use `Alt+F4` to close
a window. Picom intentionally composites each non-fullscreen window,
including its Qubes frame and title, at 30%
transparency (70% opacity) with background blur and an edge-weighted inner rim
that fades toward the center. A small Python helper draws the external cyan
halo with equal brightness at equal distances from rounded and straight edges.
Fullscreen windows remain opaque. Both i3 and Picom use official packages;
the helper needs no build or additional packages. The standard i3 login session
and Xfce remain available.

At HUD startup, the keyboard helper first restores the desktop user's saved
Xfce layout, variant, model, and keyboard options and otherwise falls back to
the machine's complete system X11 tuple. No language is hardcoded in the
portable state, so this machine uses its saved German layout while another
machine keeps its own configured layout.

HUD login also opens **HUD Bindings**, a normal framed dom0 reference window,
on workspace 1. Its searchable cards show 45 Qubes/i3 shortcuts, with the
headline and key combinations in highlight cyan. The key legends follow the
active English (US/UK) or German keyboard, including layout/group changes
while the window is open. Bindings sits left of a central block with four
terminals above Qubes Manager. The first terminal is interactive; the others
show read-only `top`, `xentop` and `systemd-cgtop`. Two full-height panes at
the right show **HUD Dom0 Logs** and **HUD Xen Logs** in read-only terminals.
They combine local host-service streams and the hypervisor console respectively, without
reading guest logs. Each retains 600 scrollback rows plus its visible screen
and pauses following while you scroll back. All five read-only terminals
support text selection and **Ctrl+Shift+C** copying. All panes can be reopened
from the HUD app launcher. Use **Super+F** to read wide monitor tables.

The bar always offers workspace buttons **1–5**, with the dom0 dashboard on 1
at login and no apps launched on 2–5. Empty workspaces are created when selected;
additional and named workspaces retain their normal buttons and status. This
uses official i3bar's workspace protocol (i3 4.23+) and an event-driven mode of
the existing helper, with no extra packages or compiled code.

The panel shows **RAM free** beside **Disk free**, using Xen's unallocated
host memory in GiB. RAM already assigned to qubes, including memory that could
later be reclaimed, is excluded. A small standard-library Python filter adds
this field to the stock Qubes status output using the existing `xl` command;
no package or permission change is needed.

The five read-only panes share a small GTK/VTE viewer with visible horizontal
and vertical scrollbars. Wide, tall monitor canvases let you pan through the
live tables; log panes retain short terminal history. The viewer reuses the
Bindings window code and runs native programs: rsyslog combines dom0 logs,
while tail and cat show the latest 64 KiB of the Xen console and follow new
events. No custom log reader, package or compiled binary is added. Control
and non-ASCII log bytes appear as visible escapes; see the
[log-reader details](salt/qubes_gui/hud/README.md#live-dom0-and-xen-logs).

The keyboard-aware reference, shared terminal viewer and guarded layout
startup use the existing system Python and desktop libraries. A small viewer
is necessary because the installed stock terminals lack horizontal scrolling.
Salt installs and validates the assets and removes owned files on rollback.
Applying Salt does not move current windows or reload i3; startup placement
takes effect at the next HUD login.

**HUD Night Light** applies a green monochrome filter to the display output
from **21:00 to 08:00** local time, including every qube, website, image and
Qubes label color. Open its application-launcher entry to change the hours
or choose Automatic, Day or Night. Day restores the saved output colors.
Day and Night stay selected across reboots; choose Automatic to resume the
daily schedule.
It uses a native systemd user timer and small Python/ctypes helpers with the
already installed X11 libraries; no package or custom binary is added.
Each active graphics output must expose XRandR's `CTM` property. The schedule
checks once per minute, including after resume and display changes; see the
[display-filter details](salt/qubes_gui/hud/README.md#display-wide-night-light).

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
For upgrades from the retired custom i3, Salt replaces the verified legacy
binary with a small shell launcher that executes `/usr/bin/i3` and forwards
all arguments. This preserves the running session's restart path. A normal
logout/login activates the official build; after a successful apply, a
deliberate `i3-msg restart` can also migrate the existing session in place.
The state validates the official executable against its installed RPM and
checks the candidate config with `/usr/bin/i3 -C`.
See `salt/qubes_gui/hud/README.md` for ownership checks and platform support.

To remove the HUD and return to the standard i3 session:

```sh
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud.rollback saltenv=user
```

Real user-triggered fullscreen has no window-manager titlebar.
Qubes' default gui-daemon policy rejects
untrusted AppVM fullscreen requests; override-redirect windows keep
gui-daemon's protected label border.

### Fonts and monospace text

The normal `qubes_gui.hud` and `qubes_gui.guest_hud` applies include **Zen Dots**
for proportional interface text and **White Rabbit** for terminals, editors
and other monospace text. No separate selection command or font pillar is
needed. These are the only bundled font families; their unchanged files,
licences and provenance are committed to this repository. Installation works
offline and adds no packages, compiled programs or runtime helpers. See the
[font sources and licences](salt/qubes_gui/hud/files/fonts/README.md).

Salt verifies the five font/notice files against pinned SHA-256 values before
activating the pair. Upgrades remove only verified files from earlier font
trials, after the final selector is installed, and remove their empty managed
directories. Modified or unknown content is refused. Remove obsolete trial
`family`/`monospace_family` settings from local pillar; the former explicit
Zen Dots/White Rabbit pair remains compatible.

To apply or check only the font configuration in dom0:

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl state.sls qubes_gui.hud.font saltenv=user test=True
sudo qubesctl state.sls qubes_gui.hud.font saltenv=user
```

For a persistent template font-only apply, add
`--skip-dom0 --targets=TEMPLATE` before `state.sls`, then shut down the template.
Its dependent qubes inherit the files on their next start. A temporary AppVM
preview is still possible with an exact `preview_qube` name under
`qubes_gui:hud:font`; normal template deployment needs no preview setting.
Stock graphical Qubes targets must already provide Fontconfig. The guest HUD's
existing Noto packages supply fallback glyphs; the standalone font state does
not install packages.

Native font rules cover the standard requests used by GTK/Qt interfaces,
i3, terminals and VS Code's interface, editor and integrated terminal. The
top status panel uses White Rabbit so clock digits have equal width and do
not shift neighboring status items. Window titles retain Zen Dots.

White Rabbit has distinct letter case and covers basic Latin; German accents and
other missing glyphs use installed monospace fallback fonts. Symbol and emoji
fonts remain available. Applications with unusual explicit font requests,
embedded fonts or text rendered as pixels can bypass these rules. Applications
may retain cached fonts until normally restarted; this includes VS Code.
Salt does not restart user applications, sessions or service qubes.

For installed ordinary guest Firefox, an editable default disables website
font choices so pages use the system selection. Existing user preferences
remain higher priority; Tor Browser and browser profiles are not modified.
Restore website fonts with **Settings → General → Fonts → Advanced → Allow
pages to choose their own fonts**. Disabling page fonts can affect web icons.

Both normal HUD rollbacks include font cleanup. The separate
`qubes_gui.hud.font-rollback` removes only the verified HUD selector, Firefox
default, bundled fonts, notices and empty family directories, preserving
system fonts and user choices. The empty root and ownership marker remain
for repeatable cleanup and reinstall. No font-selection pillar is required. A later
normal HUD apply installs the final pair again.

## HUD application theme in TemplateVMs

`qubes_gui.guest_hud` installs the application-facing HUD palette into a
TemplateVM's persistent root filesystem. It provides a named GTK 2/3/4 theme,
locked system Xfce and dconf defaults, matching fonts, the generated thin
`Qubes-HUD-Cyan` icon theme and terminal colors. On Debian-family templates
that already contain Whonix's PyQt5 applications, it installs `qt5ct` and
applies a root-owned black/cyan Qt palette to the Sdwdate user-service tree and
to the package's standalone Tor Control Panel launcher. The two narrow launch
scopes prevent `qt5ct` from creating a per-user configuration copy and do not
redirect `XDG_CONFIG_HOME` for the desktop session. Whonix's six
package-owned Sdwdate/Tor status tray images are replaced package-safely with
thin semantic glyphs on exact-black canvases: cyan for healthy/busy, amber for
Tor warning, and pink-red for stopped/error. It does not touch TemplateVM or
AppVM home directories.
The default application and terminal foreground is the focused-frame cyan
`#19d3ff` on every supported template family.

Icon themes affect icons requested by name. Other app-supplied pixels remain
outside that mechanism, including absolute Qubes application-menu icon paths,
web-page icons, thumbnails, and `_NET_WM_ICON` title-bar images. Those are left
untouched; the narrowly managed Sdwdate tray-status set is the exception.
The Tor launcher wrapper changes only toolkit environment selection and leaves
the package's icon and application content intact.
Trusted Qubes label colors remain unchanged.

Retrofit an existing TemplateVM with a dry run followed by an apply:

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud saltenv=user test=True
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud saltenv=user
```

The state never restarts dependent AppVMs or DispVMs. They see the template
root changes the next time they start; on a machine where this template backs
networking and management qubes, activate everything together at the next
reboot instead of interrupting the current session.

To generate a new themed TemplateVM, use the two-phase Salt wrapper:

```sh
./scripts/provision-hud-template.sh SOURCE_TEMPLATE TARGET_TEMPLATE
```

The source and target are runtime policy, so neither topology nor template
names are embedded in the formula. Salt clones and tags the target first and
then applies the guest state inside it; the wrapper succeeds only when both
phases succeed and the result is a halted TemplateVM. The clone phase refuses
to proceed while either the source or an already managed target is running;
it does not stop them implicitly. Halt either TemplateVM before retrying. Once
guest styling finishes, the wrapper cleanly shuts down the target and verifies
that it is a halted TemplateVM before reporting success.

The source argument is creation-time policy. If the target already carries
the `hud-theme-managed` tag, Salt converges that target in place and does not
re-clone it or claim that it came from the newly supplied source. Choose a new
target name when changing source templates. See
`salt/qubes_gui/guest_hud/README.md` for the exact scope, collision policy,
validation, and rollback.

### Debian Base, Agent and Trader templates

The separate `qubes_gui.templates.family` state creates three Debian 13
TemplateVMs and applies the common HUD, fonts and Firefox page defaults:

| Template | Salt inheritance | Applications |
| --- | --- | --- |
| `debian-13-hud-base` | Shared Base policy | `pass`; LibreOffice and Thunderbird purged |
| `debian-13-hud-agent` | Base + Agent | Complete Debian Git tool set and development CLI tools |
| `debian-13-hud-trader` | Base + Trader | Debian Electrum |

The Agent's upstream Codex, Hermes Agent, OpenClaw and signal-cli installation
is permitted by the guest-qube dependency policy but remains to be implemented;
the current Agent state supplies only its Debian CLI layer. See the
[family instructions](salt/qubes_gui/templates/family/README.md).

Agent and Trader independently include Base. Add shared packages to
[base.sls](salt/qubes_gui/templates/family/base.sls), then apply the family again
to update all three.
Qubes filesystem clones alone do not propagate later Base changes.

New private homes receive no automatic Desktop, Documents, Downloads, Music,
Pictures, Public, Templates or Videos folders; native XDG locations point to
the home directory. Only empty standard folders in the owned templates are
removed. Existing documents and AppVM homes are preserved.

With the default names and a halted `debian-13-xfce` source:

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl --targets=debian-13-hud-base,debian-13-hud-agent,debian-13-hud-trader \
  state.sls qubes_gui.templates.family saltenv=user
```

The source and all targets must be halted. Existing targets are accepted only
with the family's exact ownership, name, role and source records; names are
configurable in pillar. Dependent AppVMs receive updates on their next start.
The family is opt-in and is not created by an ordinary HUD theme apply.

### Optional Firefox page colors

The separate `qubes_gui.guest_hud.firefox` state gives ordinary Firefox cyan
text and links on black pages, with a native dark appearance hint. Toggle
page recoloring in **Settings → General → Contrast Control → Off / Custom**.
This uses eight editable Firefox preferences; no extension, custom binary,
package or runtime helper is added. Existing user choices take precedence,
and a toggle choice survives both Firefox restarts and Salt reapplies.

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.firefox saltenv=user test=True
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.firefox saltenv=user
sudo qvm-shutdown --wait debian-13-xfce
```

Selected TemplateVMs must already contain the distribution's Firefox package.
Dependent qubes inherit these defaults when they next start. Images, video,
canvas content and elements that explicitly opt out retain their colors.
Firefox controls receive a native dark appearance hint; existing theme choices
still take precedence.
Tor Browser's separate installation is not changed.

Use `qubes_gui.guest_hud.firefox-rollback` with the same target to remove the
owned preferences file, then shut down the template. See the
[guest theme instructions](salt/qubes_gui/guest_hud/README.md#optional-firefox-page-colors)
for a temporary preview in a running AppVM and rollback details.
