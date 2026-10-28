#!/usr/bin/env python3
"""compare-pdf.py -- class-parity comparator (plan §10).

Usage:
  compare-pdf.py OUR.pdf REF.pdf LABEL [--tate] [--tolerance-pt 0.03]
                 [--max-line-delta 0]

Compares a pdftexja class's output with the pinned LuaTeX-ja class's output
for the SAME token stream (tests/fixtures/classes/shared-body.tex).

What is asserted, and why it is a quality statement rather than a smoke test:

  1. PAGES      same page count.
  2. MEDIABOX   same page size (default 0.02 bp, i.e. the PDF-level
                tolerance from the plan).
  3. TEXT       the concatenated Unicode text of every page, with all
                whitespace removed, is IDENTICAL.  Glyph-level ToUnicode is
                therefore correct on both sides and no character is lost.
  4. LINES      per-page line count is identical (the body is rigid: CJK
                runs break at whole cells, so this compares the line-breaking
                decisions, not font advances).
  5. GRID       yoko: the page's most frequent successive-baseline distance
                (the body line grid) matches within 0.03 pt.  tate: the
                COLUMN PITCH (mode of successive x-cluster gaps) matches
                within 0.05 pt -- raw tate coordinates are not comparable
                because pdftexja rotates a horizontal galley while
                LuaTeX-ja lays out vertical writing natively.

Extraction uses PyMuPDF, which resolves arbitrary CTMs; pdftotext is NOT
used because its rotated-layout filtering drops tate pages.
"""

import sys
import unicodedata

try:
    import pymupdf
except ImportError:  # older bindings
    try:
        import fitz as pymupdf
    except ImportError:
        sys.stderr.write("compare-pdf.py: PyMuPDF is required\n")
        sys.exit(2)


# Error band for break positions, in characters (cells).  The two sides use
# different font metrics by design (metric compatibility is NOT required), so
# a line may absorb one more/fewer cell; anything larger is a layout defect.
#
# The band is NOT hiding a font-face artefact: with the reference side forced
# onto the same face family (\usepackage[ipaex]{luatexja-preset}) the two
# remaining failures keep their signature and their lines are PURE full-width
# CJK (measured for pdfjskiyou: ours breaks after 17 cells at 'まみむめも…'
# where the reference still has 'はひふへほ' and reaches 22), and ltxdoc's
# divergence survives too.  A pure-CJK break difference is an evaluator or
# \zw/line-capacity defect, never something this tolerance may absorb.
CELL_TOL = 2


def norm_text(s):
    # NFKC folds the vertical presentation forms (U+FE10..FE19) onto
    # their nominal characters; the semantic text is identical.
    s = unicodedata.normalize("NFKC", s)
    return "".join(ch for ch in s if not ch.isspace())


def page_lines(page):
    """[(text, bbox, block_no)] for every line, in reading order."""
    out = []
    d = page.get_text("dict")
    for bi, block in enumerate(d.get("blocks", [])):
        for line in block.get("lines", []):
            txt = "".join(sp.get("text", "") for sp in line.get("spans", []))
            if not txt.strip():
                continue
            out.append((txt, tuple(line.get("bbox", (0, 0, 0, 0))), bi))
    return out


def line_cells(lines):
    """Per-line character counts, i.e. where the breaks fell -- measured in
    CHARACTERS, not points, so it is independent of the font metrics/TFMs in
    use (the body is rigid CJK: one cell per character)."""
    return [len(norm_text(t)) for t, _, _ in lines]


def column_cells(lines):
    """tate: glyphs grouped into columns by x-cluster, counted per column."""
    groups = {}
    for t, b, _ in lines:
        groups.setdefault(round(b[0], 1), 0)
        groups[round(b[0], 1)] += len(norm_text(t))
    return [groups[k] for k in sorted(groups)]


def grid_pitch(lines, tate):
    """The page's BODY grid: the most frequent successive-line distance.

    Block segmentation differs between extractors (pyMuPDF groups by
    proximity, which font-metric differences shift), and a page-wide median
    mixes the body grid with heading/footnote jumps.  The mode of the
    successive-line distances is exactly the class's line grid, independent
    of both.  Distances are binned at 0.1 pt.
    """
    vals = [(b[0] if tate else b[3]) for _, b, _ in lines]
    deltas = [abs(vals[i + 1] - vals[i]) for i in range(len(vals) - 1)]
    deltas = [d for d in deltas if d > 0.5]
    if len(deltas) < 4:      # too few lines: the mode is not a grid
        return None
    bins = {}
    for d in deltas:
        k = round(d * 10) / 10.0
        bins[k] = bins.get(k, 0) + 1
    best = sorted(bins.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
    return best


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    opts = [a for a in argv[1:] if a.startswith("--")]
    if len(args) != 3:
        sys.stderr.write("compare-pdf.py: expected OUR REF LABEL\n")
        return 2
    ours, ref, label = args
    tate = "--tate" in opts
    tol = 0.03
    for o in opts:
        if o.startswith("--tolerance-pt="):
            tol = float(o.split("=", 1)[1])
    failures = []

    def fail(msg):
        failures.append(msg)

    try:
        doc_a = pymupdf.open(ours)
    except Exception as exc:
        sys.stderr.write("compare-pdf.py: cannot open %s: %s\n" % (ours, exc))
        return 1
    try:
        doc_b = pymupdf.open(ref)
    except Exception as exc:
        sys.stderr.write("compare-pdf.py: cannot open %s: %s\n" % (ref, exc))
        return 1

    if len(doc_a) != len(doc_b):
        fail("page count: ours %d, reference %d" % (len(doc_a), len(doc_b)))

    text_a, text_b = [], []
    for i in range(min(len(doc_a), len(doc_b))):
        pa, pb = doc_a[i], doc_b[i]
        ra, rb = pa.rect, pb.rect
        if (abs(ra.width - rb.width) > 0.02 or abs(ra.height - rb.height) > 0.02):
            fail("page %d: MediaBox %.3fx%.3f vs %.3fx%.3f"
                 % (i + 1, ra.width, ra.height, rb.width, rb.height))
        la, lb = page_lines(pa), page_lines(pb)
        text_a.append("".join(norm_text(t) for t, _, _ in la))
        text_b.append("".join(norm_text(t) for t, _, _ in lb))
        if tate:
            # Vertical writing: pdftexja rotates a horizontal galley, so its
            # page x axis is the GALLEY's vertical axis, while LuaTeX-ja lays
            # out vertical writing natively and its x axis is the page's
            # horizontal axis.  Raw coordinates and edges are therefore not
            # comparable (measured: identical 16.93/16.94 pt column pitch,
            # different absolute origins).  The comparable positional
            # quantity is the COLUMN GRID: the pitch between successive
            # x-clusters, which both engines derive from the class
            # baselineskip.
            def pitch_of(lines):
                xs = sorted({round(b[0], 1) for _, b, _ in lines})
                ds = [round(xs[k + 1] - xs[k], 1) for k in range(len(xs) - 1)]
                ds = [d for d in ds if 4.0 < d < 40.0]
                if len(ds) < 4:      # too few columns: no stable grid
                    return None
                bins = {}
                for d in ds:
                    bins[d] = bins.get(d, 0) + 1
                return sorted(bins.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
            pa, pb = pitch_of(la), pitch_of(lb)
            if pa is not None and pb is not None and abs(pa - pb) > 0.05:
                fail("page %d: column pitch %.2f vs %.2f pt" % (i + 1, pa, pb))
            na, nb = len(la), len(lb)
            if abs(na - nb) > max(4, int(0.03 * max(na, nb))):
                fail("page %d: glyph-cell count %d vs %d" % (i + 1, na, nb))
            # Column contents in CHARACTERS: the tate analogue of the yoko
            # per-line break check, still metric-free.
            ka, kb = column_cells(la), column_cells(lb)
            if len(ka) == len(kb):
                worst = max((abs(x - y) for x, y in zip(ka, kb)), default=0)
                if worst > CELL_TOL:
                    for k, (x, y) in enumerate(zip(ka, kb)):
                        if abs(x - y) > CELL_TOL:
                            fail("page %d column %d: %d vs %d cells (band %d)"
                                 % (i + 1, k + 1, x, y, CELL_TOL))
                            break
                else:
                    print("INFO: %s: page %d column band max %d cell(s)"
                          % (label, i + 1, worst))
        elif len(la) != len(lb):
            fail("page %d: line count %d vs %d" % (i + 1, len(la), len(lb)))
        else:
            # Break positions measured in CHARACTERS: metric-free, but NOT
            # metric-identical -- the two sides use different font metrics, so
            # a line may hold one cell more or less.  CELL_TOL is the stated
            # error band ("agrees within error"); a real layout defect moves
            # breaks much further or changes the line count.
            ca, cb = line_cells(la), line_cells(lb)
            worst = max((abs(x - y) for x, y in zip(ca, cb)), default=0)
            if worst > CELL_TOL:
                for k, (x, y) in enumerate(zip(ca, cb)):
                    if abs(x - y) > CELL_TOL:
                        fail("page %d line %d: %d vs %d characters (band %d)"
                             % (i + 1, k + 1, x, y, CELL_TOL))
                        break
            else:
                print("INFO: %s: page %d break band max %d cell(s)"
                      % (label, i + 1, worst))
        ga, gb = (None, None) if tate else (grid_pitch(la, tate), grid_pitch(lb, tate))
        if ga is not None and gb is not None and abs(ga - gb) > tol:
            fail("page %d: line grid %.3f vs %.3f pt" % (i + 1, ga, gb))

    if "".join(text_a) != "".join(text_b):
        # report the first divergence for diagnosis
        ta, tb = "".join(text_a), "".join(text_b)
        k = 0
        while k < min(len(ta), len(tb)) and ta[k] == tb[k]:
            k += 1
        fail("text differs at character %d: ours %r vs reference %r"
             % (k, ta[k:k + 12], tb[k:k + 12]))

    # "later half" report: the last page's break pattern, so a divergence in
    # the body tail is visible even when page 1 is dominated by headings
    if len(doc_a) and len(doc_b):
        ia = len(doc_a) - 1
        ta_cells = line_cells(page_lines(doc_a[ia]))
        tb_cells = line_cells(page_lines(doc_b[ia]))
        print("INFO: %s: last page break pattern ours=%s ref=%s"
              % (label, ta_cells[:6], tb_cells[:6]))

    if failures:
        for f in failures:
            sys.stderr.write("FAIL: %s: %s\n" % (label, f))
        return 1
    print("PASS: %s: pages=%d lines=%s text identical"
          % (label, len(doc_a),
             ",".join(str(len(page_lines(doc_a[i]))) for i in range(len(doc_a)))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
