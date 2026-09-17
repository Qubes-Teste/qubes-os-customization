# Qubes HUD guest-template theme

`qubes_gui.guest_hud` runs inside a Qubes TemplateVM. It installs the
application-facing part of the dom0 HUD as a named system theme and never
writes to `/home`, `/rw`, or an AppVM private volume.

The state supplies:

- GTK 2, GTK 3, and GTK 4 themes under `/usr/share/themes/Qubes-HUD`;
- the same black, glass-blue, cyan, text, and alert palette used by dom0;
- locked system Xfce/XSettings and dconf selections for existing and future
  AppVM homes;
- the generated thin cyan-glyph `Qubes-HUD-Cyan` icon theme;
- bundled Zen Dots for interface text and White Rabbit for terminals, editors
  and other monospace text, with Noto fallback for missing characters;
- a matching Xfce Terminal palette when a user has no explicit terminal
  configuration;
- a native Mousepad cyan-on-black editor scheme, White Rabbit 10-point text,
  line numbers and status bar as editable defaults;
- a root-owned Qt 5 palette scoped to Whonix's Sdwdate service, its child Tor
  Control Panel, and the package's standalone Tor Control Panel launcher;
- thin Whonix Sdwdate/Tor tray status art on exact-black canvases, with cyan
  normal states, amber Tor warning, and pink-red stopped/error states.

Normal application and terminal text uses the same `#19d3ff` cyan as dom0's
focused window frame. White remains reserved for selection, urgent, and ANSI
white roles; muted and disabled text remains deliberately dimmer.
GTK selects `Qubes-HUD-Cyan`, which deterministically derives generic icons
from KDE Breeze Dark's thin monochrome and symbolic SVG geometry and fixes
their foreground paint to exact `#19d3ff`. It covers actions, small categories,
devices, emblems, MIME types, places, status icons, and thin notification
glyphs. The generated tree uses roughly 70 MiB in the TemplateVM root.

Application-icon directories are excluded and the theme inherits from
Adwaita, hicolor, and Breeze Dark. Application logos and Qubes VM class,
label, security, and Qubes-specific warning icons therefore keep their
identity and colors. Neutral Qubes tray concepts such as clipboard, domains,
disks, devices, and updates receive thin cyan aliases. Targeted regular
NetworkManager wired, disconnected, Wi-Fi signal, and secure status files use
cyan glyphs on exact-black canvases for reliable XEmbed rendering.

The outer Qubes frame, rounded clipping, label-colored window title, transparency,
blur, and glow remain in dom0. Installing a compositor or window manager in a
TemplateVM would not improve seamless guest windows and is intentionally out
of scope. Ordinary Firefox page colors have a separate opt-in state described
below. Electron palette customization and applications that draw their own
complete interface remain separate work; native font rules cover stock system
font requests, including VS Code's defaults. Absolute application
icon paths, thumbnails, tray images, `_NET_WM_ICON` title-bar images, and other
client-provided pixels likewise bypass freedesktop icon-theme lookup and are
not recolored by this test. The six package-owned images selected by Sdwdate's
tray-status code are the narrow exception: they are replaced with deterministic
thin artwork precomposed onto exact black while menu icons, branding, and Tor
Control Panel toolbar images remain upstream originals. The opaque canvas is
intentional because legacy 24-bit XEmbed source surfaces have no alpha and
were observed compositing transparent pixels onto a light-gray `#f0f0f0`
background before dom0 received them.

Debian templates install `kf6-breeze-icon-theme`; Fedora templates install
`breeze-icon-theme`. The generated artwork retains KDE Breeze's upstream
LGPL/CC-BY-SA licensing, with the installed package copyright and license files
as the authoritative notices.

Qt's GTK platform adapter supplies desktop integration such as fonts, icons,
and native dialogs, but it does not translate GTK CSS colors into a Qt widget
palette. The generic late-session hook therefore selects that adapter only
when it is already installed; this state does not install GTK adapters or
claim that they recolor Qt applications.

On a Debian-family template where `python3-pyqt5` and either `sdwdate-gui` or
`tor-control-panel` are already installed, the state installs `qt5ct` and
writes its 21-role HUD palette under `/etc/qubes-hud/xdg/qt5ct`. A root-owned
systemd user-service drop-in sets `QT_QPA_PLATFORMTHEME=qt5ct` and points
`XDG_CONFIG_HOME` at that system directory for `sdwdate-gui.service`. The
Sdwdate client launches Tor Control Panel as a child, so the tray-opened panel
inherits the palette. A package-safe wrapper applies those same two variables
when Tor Control Panel is launched independently from its desktop entry. Both
paths receive black `#02070c` window and field backgrounds with `#19d3ff`
text. Application-owned green, orange, red, yellow, and white status styles
still override the base palette and keep their meaning.

The scope is deliberate. `qt5ct` normally copies a system default into
`~/.config/qt5ct` on first use; directing only the service tree and standalone
Tor launcher to the already-existing root-owned file avoids that home write
and prevents a stale private-volume copy. The state does not set
`XDG_CONFIG_HOME` for the desktop session or other Qt applications.

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
The same rule protects `/usr/share/icons/Qubes-HUD-Cyan`: its deterministic
generator records every inode type, mode, owner, file hash, and symbolic-link
target in an ownership manifest. Update and rollback validate the tree;
rollback unlinks only the manifest-listed entries and removes directories only
after they are empty. Altered or unfamiliar content makes the state refuse;
only already-missing manifest entries from an interrupted removal are accepted
so that exact rollback can resume. Shared font, Breeze icon, `qt5ct`, and
dconf packages remain installed.

The Whonix exceptions use local `dpkg-divert` entries rather than overwriting
unrecoverable package content. One manager owns the six Sdwdate images; a
separate manager owns only the package's one-line Tor launcher and forwards
every argument to its diverted original. Both validate package ownership and
hashes before the first change, record original and generated hashes before
mutation, handle package upgrades or path retirement, and commit explicit
installing/removing phases for interruption-safe retry. Rollback restores the
current package originals and removes only manager-owned replacements. A
foreign diversion or modified managed file makes the state refuse.

The Xfce and dconf theme choices are locked at system level so an existing
AppVM's saved toolkit theme cannot hide the HUD. The lock disappears on
rollback and the earlier user choice becomes effective again. A pre-existing
per-user Xfce Terminal palette is deliberately preserved.

Mousepad uses the native `qubes-hud` GtkSourceView style scheme. It is installed
only into already-existing `/usr/share/gtksourceview-3.0/styles` and
`/usr/share/gtksourceview-4/styles` directories; Mousepad and GtkSourceView are
not added as dependencies. The scheme uses cyan text on black and a bright
cyan selection with black selected text. Its font, scheme, line-number and
status-bar settings are editable dconf defaults, without locks. Existing
saved Mousepad choices take precedence and remain intact across applies.
Choose the Qubes HUD scheme and White Rabbit font in Mousepad's preferences
to update an existing override. Rollback removes only the owned scheme files
and system defaults, leaving stock schemes, shared directories and user
preferences intact.

Template root changes become visible only after the TemplateVM has shut down
and dependent AppVMs or DispVMs restart. The state never restarts those
dependent qubes; they can pick up the change at their next planned start. This
restart is also when the Sdwdate service tree and standalone Tor launcher gain
their scoped Qt palette.

## Apply to an existing TemplateVM

The standard apply includes `qubes_gui.hud.font` and selects the fixed Zen
Dots/White Rabbit pair without a font pillar or separate command. Existing
Noto package prerequisites provide Unicode fallback before font activation.
The stock graphical template must already provide Fontconfig and
`/usr/bin/fc-cache`; bundled font installation adds no package or download.

For an installed ordinary distribution Firefox, the included font state also
sets an editable default to use system fonts for pages. Existing profile
choices take precedence. It does not write Tor Browser or browser profiles;
the optional page-color state below remains separate. Applications can keep
cached fonts until their next normal restart.

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

The included `qubes_gui.hud.font-rollback` removes the owned font selector,
bundled font files and ordinary Firefox font default. Distribution font
packages and user browser choices remain intact. Remove the optional Firefox
page-color state separately if desired.

Dependent qubes pick up either change at their next restart; the state does not
restart them automatically.

## Optional Firefox page colors

Apply `qubes_gui.guest_hud.firefox` separately to select cyan-on-black page
colors in an ordinary, already-installed distribution Firefox. It supports
Debian-family `firefox-esr` and Fedora's x86-64 `firefox` installation layout.
It does not install Firefox, change Tor Browser, merge enterprise policies,
write profile files, or add executable runtime code. The regular guest-theme
state and template-provisioning wrapper do not enable this option implicitly.

```sh
./scripts/sync-salt-formula.sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.firefox saltenv=user test=True
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.firefox saltenv=user
sudo qvm-shutdown --wait debian-13-xfce
```

Dependent qubes receive the template root on their next start. Native Firefox
loads the eight editable defaults in `defaults/pref/qubes-hud.js` below
`/usr/lib/firefox-esr` (Debian) or `/usr/lib64/firefox` (Fedora). This is
Firefox's restricted preference-file format, not AutoConfig JavaScript.
The state verifies the installed package, package-owned `channel-prefs.js`,
real root-owned parent directories and the exact owned drop-in. It refuses
unfamiliar, modified, linked or package-owned destination files. It neither
creates shared directories nor overwrites vendor configuration.

In Firefox 140 ESR, use **Settings → General → Contrast Control**:

- **Custom**: cyan `#19d3ff` text on black, with brighter cyan links and
  dimmer visited links.
- **Off**: allow website colors again, keeping the native dark appearance
  hint. This is the normal color rendering toggle.

These are default preferences, not locks. Existing profile values or
enterprise locks win, and a user's Off/Custom choice persists across Salt
reapplies. The dark appearance hint remains active when forced colors are
off. The switch changes page colors immediately; installing or removing the
system preference file requires Firefox to restart.
For a normal session-preserving restart, open `about:profiles` and choose
**Restart normally** when ready.

The native [Contrast Control](https://support.mozilla.org/en-US/kb/firefox-contrast-control)
mode recolors text, backgrounds and links, and may simplify shadows or
gradients. Images, video, canvas pixels and elements using
`forced-color-adjust: none` retain their colors. Firefox's own controls and
internal pages can differ from web content; this is not a display-wide color
filter. Browser controls get Firefox's native dark hint and toolkit colors,
without maintained `userChrome.css` selectors.

For a temporary preview in an **already-running** AppVM, supply its exact
QubesDB name explicitly; use `test=True` first:

```sh
sudo qubesctl --skip-dom0 --targets=hud-test \
  state.sls qubes_gui.guest_hud.firefox saltenv=user \
  'pillar={"qubes_gui":{"guest_hud":{"firefox":{"preview_qube":"hud-test"}}}}'
```

Restart Firefox to load the preview. This modifies only the AppVM's ephemeral
root and disappears when that qube restarts; a persistent installation must
also apply the normal TemplateVM state above. Neither path stops browsers
or dependent qubes automatically. Without the explicit matching preview name,
the state refuses AppVMs, as well as dom0 and unsupported platforms.

Rollback uses the same guards and removes only the exact owned drop-in:

```sh
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.firefox-rollback saltenv=user test=True
sudo qubesctl --skip-dom0 --targets=debian-13-xfce \
  state.sls qubes_gui.guest_hud.firefox-rollback saltenv=user
sudo qvm-shutdown --wait debian-13-xfce
```

For a live preview, use the AppVM target and its same `preview_qube` pillar.
Rollback preserves every profile preference, including choices made through
Firefox after installation. Such explicit choices can remain effective after
removal; use Firefox's own Off switch to disable recoloring. Main guest-theme
rollback is independent, so remove this optional state separately when desired.
