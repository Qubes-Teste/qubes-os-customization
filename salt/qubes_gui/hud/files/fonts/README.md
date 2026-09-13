# Bundled font trials

These are unchanged font files supplied by their authors. They are data for
the distribution's existing Fontconfig/FreeType stack, not custom application
binaries. Salt installs the selected files from this repository and makes no
font download or source build on the target machine.

| Trial order | Family | License | Source |
| --- | --- | --- | --- |
| 1 | Xolonium 4.3, Regular and Bold | SIL Open Font License 1.1 | [Severin Meyer](https://sev.dev/fonts/xolonium/) |
| 2 | Induction, Regular | CC0 1.0 | [Typodermic public-domain collection](https://typodermicfonts.com/public-domain/) |
| 3 | Neuropol, Regular | CC0 1.0 | Same publisher collection |
| 4 | Johnny Fever, Regular | CC0 1.0 | Same publisher collection |

Xolonium is openly licensed rather than public domain. Its license permits
bundling with this project; its copyright and complete license are retained.
The Typodermic archives each include the same `read-this.html`, which expressly
dedicates the included fonts to CC0. That guide and the official CC0 legal
text are retained under `typodermic-cc0/`.

Each subdirectory's `PROVENANCE.json` records the upstream archive URL and
SHA-256, the exact distributed file hashes, and acquisition details. The files
were fetched in a networked maintainer qube and selectively transferred to
this repository; none were compiled, converted, subsetted or renamed
internally. Hashes pin the reviewed bytes; they do not establish a security
audit of the font files. Font parsing remains the responsibility of the stock,
security-updated rendering libraries.

These display faces are proportional. Terminals still use their normal fixed
cell grid, so spacing can look wider than with the original monospace face.
Existing distribution fonts remain available for missing characters.
