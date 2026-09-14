# Bundled font trials

These are unchanged font files supplied by their authors. They are data for
the distribution's existing Fontconfig/FreeType stack, not custom application
binaries. Salt stages the bundled files from this repository and registers
only the selected family or proportional/monospace pair after a native
SHA-256 check of all staged font and notice files. It makes no font download
or source build on the target machine.

| Trial order | Family | License | Source |
| --- | --- | --- | --- |
| 1 | Xolonium 4.3, Regular and Bold | SIL Open Font License 1.1 | [Severin Meyer](https://sev.dev/fonts/xolonium/) |
| 2 | Induction, Regular | CC0 1.0 | [Typodermic public-domain collection](https://typodermicfonts.com/public-domain/) |
| 3 | Neuropol, Regular | CC0 1.0 | Same publisher collection |
| 4 | Johnny Fever, Regular | CC0 1.0 | Same publisher collection |
| 5 | Zen Dots, Regular | SIL Open Font License 1.1 | [Google Fonts: Zen Dots](https://github.com/google/fonts/tree/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/zendots) |
| 6 | Orbitron, variable weight 400–900 | SIL Open Font License 1.1 | [Google Fonts: Orbitron](https://github.com/google/fonts/tree/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/orbitron) |
| 7 | Wallpoet, Regular | SIL Open Font License 1.1 | [Google Fonts: Wallpoet](https://github.com/google/fonts/tree/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/wallpoet) |
| 8 | White Rabbit, Regular | Author's MIT-style licence | [Matthew Welch](https://squaregear.net/fonts/whitrabt.html) |

Xolonium is openly licensed rather than public domain. Its license permits
bundling with this project; its copyright and complete license are retained.
The Typodermic archives each include the same `read-this.html`, which expressly
dedicates the included fonts to CC0. That guide and the official CC0 legal
text are retained under `typodermic-cc0/`.

The three Google Fonts families retain their original copyright/OFL notices
and catalog metadata under `google-fonts/`. Orbitron's external filename is
`Orbitron-Variable.ttf` because brackets in the upstream filename are excluded
by the existing Salt sync path policy. Its variable font bytes and internal
name are unchanged; stock rendering supplies the requested weight.

White Rabbit retains the original `whitrabt.ttf`, `license.txt` and
`whitrabt.txt` from the author's HTTPS download. The archive's licence grants
use, modification and redistribution, including commercial use, with the
copyright and permission notices retained. It agrees with the author's
[current licence page](https://squaregear.net/fonts/license.html). The readme
explicitly makes contacting the author optional. Older mirrors' descriptions
are not the licence for these downloaded files.

Each collection's `PROVENANCE.json` records the upstream archive or pinned
repository commit, source URLs, exact file hashes and acquisition details.
The files were fetched in a networked maintainer qube and selectively transferred to
this repository; none were compiled, converted, subsetted or renamed
internally. Hashes pin the reviewed bytes; they do not establish a security
audit of the font files. Font parsing remains the responsibility of the stock,
security-updated rendering libraries.

The first seven display faces are proportional. Terminals still use their
normal fixed cell grid, so spacing can look wider than with the original
monospace face.
White Rabbit is monospace and supplies basic Latin characters, with distinct
uppercase and lowercase forms. Existing distribution fonts remain available
for missing characters, including German accents and box drawing.
