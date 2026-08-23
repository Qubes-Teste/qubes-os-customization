# Trusted Qubes HUD i3 patch

This directory contains the complete provenance and build recipe for the
separate `i3-hud` executable deployed by the HUD Salt state. It does not replace
Fedora's `/usr/bin/i3`; the `qubes-hud` login session explicitly launches the
separate binary, so the packaged Qubes i3 session remains a fallback.

The patch keeps the frame in the dark navy/cyan HUD palette and draws a compact
Qubes label-color rectangle at the top right of every normal decoration. The
rectangle is painted by i3 in dom0 from gui-daemon's trusted
`_QUBES_LABEL_COLOR` property. It is not an application overlay and cannot be
painted by AppVM content. The existing `[qube-name]` prefix is retained.

For compatibility with older gui-daemon versions, a strictly parsed legacy
label index selects a built-in canonical color. `BS_PIXEL` windows retain a
label-colored whole-border cue. A real trusted-user fullscreen or `BS_NONE`
window has no decoration and therefore no badge. Qubes' default gui-daemon
policy rejects untrusted fullscreen requests, and the HUD config forces normal
decorations for managed application windows.

## Build

Build on the Fedora 41 dom0 development environment after installing i3's
build requirements. The script downloads directly over HTTPS, verifies both
pinned upstream inputs, applies the official Qubes patch and then the HUD patch,
and uses Fedora's hardening flags:

```bash
./source/i3-hud/build.sh
```

The default output is `salt/qubes_gui/hud/files/i3-hud`. The Salt state checks
its SHA-256 digest and refuses to use it unless the installed Qubes i3 package
is the exact audited base version. `SOURCE-MANIFEST` records all pinned inputs.
