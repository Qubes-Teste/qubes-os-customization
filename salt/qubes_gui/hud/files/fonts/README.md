# Bundled HUD fonts

The HUD uses **Zen Dots** for proportional interface text and **White Rabbit**
for terminals, editors and other monospace text. Salt installs the unchanged
font files and their notices from this repository, verifies their pinned
SHA-256 hashes, then registers the pair with the existing Fontconfig/FreeType
stack. Deployment downloads no fonts and adds no packages or runtime helpers.

| Role | Family | License | Source |
| --- | --- | --- | --- |
| Proportional | Zen Dots, Regular | SIL Open Font License 1.1 | [Google Fonts: Zen Dots](https://github.com/google/fonts/tree/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/zendots) |
| Monospace | White Rabbit, Regular | Author's MIT-style licence | [Matthew Welch](https://squaregear.net/fonts/whitrabt.html) |

Zen Dots retains its original font, copyright/OFL notice and catalog metadata
under `google-fonts/zen-dots/`. Its licence permits bundling with this project;
the complete copyright and licence text accompany the installed font.

White Rabbit retains the original `whitrabt.ttf`, `license.txt` and
`whitrabt.txt` from the author's HTTPS download. The archive's licence grants
use, modification and redistribution, including commercial use, with the
copyright and permission notices retained. It agrees with the author's
[current licence page](https://squaregear.net/fonts/license.html). The readme
explicitly makes contacting the author optional. Older mirrors' descriptions
are not the licence for these downloaded files.

Each collection's `PROVENANCE.json` records the upstream archive or pinned
repository commit, source URLs, exact file hashes and acquisition details.
The files were fetched in a networked maintainer qube and selectively
transferred to this repository; neither font was compiled, converted,
subsetted or renamed. Hashes pin the reviewed bytes; they do not establish a
security audit of the font files. Font parsing remains the responsibility of
the stock, security-updated rendering libraries.

White Rabbit supplies basic Latin characters, with distinct uppercase and
lowercase forms. Existing distribution fonts supply missing characters,
including German accents and box drawing. Native terminal cell spacing,
symbol fonts and Unicode fallback remain in use.
