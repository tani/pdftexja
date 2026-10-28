# pdftexja

Japanese typesetting for **pdfLaTeX in direct-PDF mode** (`\pdfoutput=1`).

`pdftexja` is the pdfTeX backend extracted from the [jlreq](https://github.com/tani/jlreq)
project and turned into a standalone package. It provides the Japanese
inter-character machinery (kanjiskip / xkanjiskip, JFM class metrics, kinsoku,
hanging punctuation, warichu, ruby, vertical writing) directly on pdfTeX
primitives, plus 12 document classes built on it.

- No Lua, no pTeX, no DVI: plain `pdflatex`.
- Horizontal (横組) and vertical (縦組) writing from the same source.
- Five built-in JFM presets (`standard`, `ujis`, `min`, `jis`, `ptexmin`),
  generated at build time from Lua sources in `data/`.
- Font assets are **never** committed: they are derived from the TeX Live
  installation by `make fonts`.
- `jlreq` uses this package through a small adapter; both share one gate suite.

> **Status**: v0.1. Every behaviour below is covered by the gate suites in
> `tests/` (12 foundation checks, 12 class pairs against LuaTeX-ja, and the
> 163-gate jlreq consumer suite). `PLAN.md` is the defect register: each entry
> carries measured evidence and a resolution.

## Requirements

| | |
|---|---|
| Engine | pdfTeX / pdfLaTeX with `\pdfoutput=1` (the package refuses to load otherwise) |
| LaTeX | LaTeX2e, `expl3`, `graphicx` |
| Japanese input | `cjk` + `bxcjkjatype` (loaded automatically per `fontset`) |
| Fonts | from TeX Live: IPAex (default, Type1 planes), IPA, or HaranoAji |
| Tools for building assets | `texlua`, `python3` (fontTools), `ttf2tfm` |

## Quick start

```latex
\documentclass{article}
\usepackage[direction=tate]{pdftexja}
\begin{document}
縦組の本文である。「括弧」と句読点、Latin と数字 123 を含む。
\end{document}
```

```sh
pdflatex sample.tex
```

Or use a bundled class directly:

```latex
\documentclass{pdfjarticle}   % pdfLaTeX + pdftexja, horizontal
\begin{document}
日本語の本文。
\end{document}
```

## Package options

All keys are also available through `\pdftexjasetup{...}`; keys marked
*preamble only* are rejected after `\begin{document}`.

| Key | Values | Default | Meaning |
|---|---|---|---|
| `direction` | `yoko`, `tate` | `yoko` | Writing direction |
| `fontset` | `ipaex-type1`, `ipa`, `haranoaji`, `custom` | `ipaex-type1` | Horizontal font axis |
| `fontprofile` | file name | — | Explicit vertical-glyph profile |
| `jfm` | `standard`, `ujis`, `min`, `jis`, `ptexmin`, or a `.def` name | `standard` | JFM class metrics |
| `open-bracket-pos` | `zenkaku_tentsuki`, `zenkakunibu_nibu`, `nibu_tentsuki` | `zenkaku_tentsuki` | Opening-bracket position class |
| `hanging-punctuation` | `true`, `false` | `true` | ぶら下げ |
| `math` | `true`, `false` | `true` | Japanese math integration |
| `math-capture` | `true`, `false` | `true` | Capture `$...$` for direction-correct math |
| `page-layout` | `physical`, `logical` | `physical` | Page-direction model for rotating output |
| `ja-scale` | factor | `1` | Multiplier on the class's Japanese glyph scale. `\Cjascale` is per class: `pdfjarticle`-family 0.962216, `pdfjs*` 0.924715, `pdfjspf` 0.903375 |
| `furniture-width` * | length | — | Furniture/trim width |
| `first-line-offset` * | length | — | First-line offset correction |
| `warichu-size`, `warichu-opening`, `warichu-closing` | — | — | 割注 parameters |
| `latin-family-matching` * | `true`, `false` | `true` | Latin family follows the Japanese family |
| `typewriter-ja-family` * | family name | — | Japanese family for `\ttfamily` |
| `bold-ja` * | `font`, `gothic-medium` | `font` | How Japanese bold is obtained |
| `ja-family-scope` * | `global`, `group` | `global` | Scope of Japanese family changes |

`*` = preamble only.

## Public API (selection)

The API is the contract `jlreq` and the bundled classes build on. All of it is
direction-aware: queries answer for the **current local** direction, not the
document direction.

| Command | Purpose |
|---|---|
| `\pdftexjaIfDirectionTF{yoko\|tate}{T}{F}` | Branch on the current local direction |
| `\pdftexjaIfPageDirectionTF{yoko\|tate}{T}{F}` | Branch on the page direction |
| `\pdftexjaBeginPageDirection{...}` / `\pdftexjaEndPageDirection` | Switch the page direction for a region |
| `\pdftexjaSetSpacing{<JA-JA>}{<JA-Latin>}` | Set kanjiskip / xkanjiskip providers |
| `\pdftexjaGetSpacing`, `\pdftexjaGetPairGlue` | Read the live spacing state |
| `\pdftexjaSetCharSpacing{<HEX>}{none\|pre\|post\|both}` | Per-scalar spacing permission (preamble only). Requires a JFM descriptor with `boundary_semantics=jfm` — `ujis`, `min`, `jis`, `ptexmin`; the `standard` preset keeps the JLReq boundary evaluator and rejects it with an explicit error |
| `\pdftexjaGetMetrics{<dir>}{\wd}{\ht}{\dp}` | JFM class-0 metrics (**`<w> <h> <d>` order**) |
| `\pdftexjaMeasureLinePosition{<current>}{<remaining>}`, `\pdftexjaIfPositionKnownTF{T}{F}` | Logical line position/remaining length from `\pdfsavepos` |
| `\pdftexjaSetCropStock` / `SetCropDrawing` / `SetPageAttributes` / `ClockwiseBox` | Crop, trim and rotation transport |
| `\warichu`, `\inlinenote` | 割注 / 行内注 (pdftexja-provided) |
| `\ruby{...}{...}` | ルビ — provided by the `ruby` package; pdftexja only adapts it (see `pdftexja-ruby.sty`) |

`\pdftexjaGetMetrics` deserves a warning: its argument order is `w h d`, not
`Cwd Cht Cdp`. Passing them in the wrong order compiles silently and produces a
wrong `\Cwd` (this exact mistake halved the tate line length in the bundled
classes before it was found — see `PLAN.md` R18).

## Bundled classes

| Horizontal | Vertical | Notes |
|---|---|---|
| `pdfjarticle` | `pdfjtarticle` | jlreq-style article |
| `pdfjreport` | `pdfjtreport` | report |
| `pdfjbook` | `pdfjtbook` | book |
| `pdfjsarticle` | — | jsclasses-style article |
| `pdfjsreport` | — | jsclasses-style report |
| `pdfjsbook` | — | jsclasses-style book |
| `pdfjspf` | — | spf (spf-style) |
| `pdfjskiyou` | — | kiyou (2-column journal) |
| `pdfjltxdoc` | — | ltxdoc for Japanese package documentation |

Each class is generated from `source/*.dtx` by `make classes` and ships with its
own `.clo` size files.

## JFM presets and fonts

- `make jfm` builds the five presets from `data/*.lua` into runtime `.def`
  payloads plus manifests. The payloads are the only JFM representation the
  runtime reads; the Lua sources are the single source of truth.
- `make fonts` derives the auxiliary vertical fonts, the HaranoAji horizontal
  conversion TTFs, encodings and profiles from the TeX Live installation.
  Nothing binary is stored in the repository.
- `make check-jfm` / `make check-fonts` verify that regeneration is
  deterministic (byte identical) and that every manifest entry exists.

## Build, install, uninstall

```sh
make                 # classes + jfm + fonts
make check           # check-jfm + check-fonts + check-uninstall
make install         # into $TEXMFHOME (override: make install PDFTEXJA_TEXMF=...)
make tds             # TDS bundle under ./tds (override: make tds TDS=...)
make uninstall       # removes only the paths it installed
make distclean
```

`make uninstall` is idempotent and leaves unrelated files alone; `make clean`
refuses an unsafe `TDS` value such as `/`.

## Tests

```sh
sh tests/run-tests.sh --texmf <staged-texmf>       # 12 foundation checks
sh tests/run-class-tests.sh --texmf <staged-texmf> # 12 class pairs vs LuaTeX-ja
sh tests/acceptance.sh --pdftexja . --jlreq ../jlreq
```

- **Foundation**: smoke documents in both directions plus contract gates
  (tiny JFM preset, UTF-8 dispatcher, tate `\begin{math}`, ruby, spacing).
- **Class parity**: each bundled class against its pinned LuaTeX-ja counterpart:
  class layout numbers (0.03 pt), extracted text, break positions, page extent
  (diagnostic), and the tate body-grid column pitch (0.05 pt).
- **Acceptance**: build → install + proofs → JFM canary → staged provenance →
  jlreq consumer suite (163 gates) → `make tds` payload check.

Every gate fails loudly with the measured numbers and the log path. Baselines
are never re-recorded automatically.

## Using with jlreq

`jlreq` detects the pdfTeX engine and inputs its adapter `jlreq-pdftex.def`,
which requires this package:

```latex
\documentclass[pdflatex]{jlreq}   % adapter loads pdftexja + jlreq's JFM
```

Install `pdftexja` first (or keep both in one TDS tree); the adapter aborts with
an explicit error if `pdftexja.sty` is missing.

## Known limitations (measured, not guessed)

1. **Latin metric source.** pdfTeX uses TFM widths, LuaTeX uses OTF widths. On
   mixed Latin/CJK lines a break can therefore fall one character earlier or
   later. The first divergence in a document is always on a line containing
   Latin text; pure-CJK lines are identical. The parity gates allow this
   ±1-cell band (`CELL_TOL`) and nothing more.
2. **Positional gating in vertical writing.** pdftexja rotates a horizontal
   galley while LuaTeX-ja typesets natively, so the two have no common absolute
   frame. Gated: text, glyph count, per-column character counts, and the
   page-1 body-grid column pitch on homogeneous pages. Whole-page painted
   extent is diagnostic only.
3. **Rotated ink origin.** Native vertical fonts place ink at
   `cell + height(glyph)`; the rotated/vertical path here places it at the cell
   origin (0.88 em offset plus per-glyph ink profile). Anchor comparisons are
   therefore bounded at 4.0 pt, while all cross-direction quantities and the
   note-column pitch are gated at 0.5 pt.

## License

BSD 2-Clause. See `LICENSE` (the extracted foundation code carries the jlreq
project copyright as well).
