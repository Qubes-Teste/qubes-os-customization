# Trusted Qubes HUD i3 patches

This directory contains the complete provenance and build recipe for the
separate `i3-hud` executable deployed by the HUD Salt state. It does not replace
Fedora's `/usr/bin/i3`; the `qubes-hud` login session explicitly launches the
separate binary, so the packaged Qubes i3 session remains a fallback.

The trusted-label patch keeps the frame in the dark navy/cyan HUD palette and
draws a thin, rounded Qubes label-color line in every normal decoration. The
line begins after the rendered title, fades from 4% label intensity there to 100% at the
right, and carries a restrained two-layer halo in the same trusted color. Its
geometry is recalculated from the current decoration after every resize. A
minimum segment is reserved so a long application title cannot hide the trust
cue. The line is painted by i3 in dom0 from gui-daemon's trusted
`_QUBES_LABEL_COLOR` property. It is not an application overlay and cannot be
painted by AppVM content. The existing `[qube-name]` prefix is retained.
The trusted decoration also gives that prefix a 10-logical-pixel left inset so
Picom's rounded window corner cannot clip its first glyph.

Normally decorated application windows also have a compact close button in the
same validated Qubes label color as the line, including its canonical fallback.
The button uses a dedicated 26-logical-pixel region at the far right. The label
line, including its halo, ends before that region, so the two trusted controls
cannot overlap as the window is resized. Pressing and releasing the primary
mouse button on the same close control requests a normal application close;
`Alt+F4` is the keyboard fallback. A fullscreen or `BS_NONE` window has no
decoration and therefore no button.

For compatibility with older gui-daemon versions, a strictly parsed legacy
label index selects a built-in canonical color. `BS_PIXEL` windows retain a
label-colored whole-border cue. A real trusted-user fullscreen or `BS_NONE`
window has no decoration and therefore no label line. Qubes' default gui-daemon
policy rejects untrusted fullscreen requests, and the HUD config forces normal
decorations for managed application windows.

## Build

Build on the Fedora 41 dom0 development environment after installing i3's
build requirements. The script downloads directly over HTTPS, verifies both
pinned upstream inputs and both local patches, applies the official Qubes
patch, the trusted-label HUD patch, and then the close-button patch, and uses
Fedora's hardening flags:

```bash
./source/i3-hud/build.sh
```

The default output is `salt/qubes_gui/hud/files/i3-hud`. The Salt state checks
its SHA-256 digest and refuses to use it unless the installed Qubes i3 package
is the exact audited base version. `SOURCE-MANIFEST` records all pinned inputs.
