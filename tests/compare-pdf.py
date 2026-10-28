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
                (the body line grid) matches within 0.03 pt.
  6. COLUMN     tate: the COLUMN PITCH, i.e. the distance between successive
     PITCH      body columns along x (the axis orthogonal to the text line),
                matches within 0.05 pt on every page whose body is
                homogeneous.  pdftexja ships a rotated horizontal galley and
                LuaTeX-ja lays out vertical writing natively, so page
                coordinates and edges are not comparable; the column pitch is
                comparable, because both engines derive it from the class's
                tate column glue, and it is measured here rather than derived
                from \baselineskip because that would assert the class's
                intent against itself.

                MEASUREMENT (see body_columns()/column_pitch()):
                  * per-glyph boxes from the text extractor; a tate glyph is
                    one "line" object, its bbox the character cell box;
                  * body glyphs are those whose box width equals the page's
                    modal box width (the body em).  Heading/title material is
                    set at a different size and therefore drops out -- that is
                    what keeps page-1 furniture from polluting the grid;
                  * a column is a distinct x0 of those body boxes carrying at
                    least BODY_MIN_CELLS characters (sub-cell ink splits and
                    lone heading glyphs fall below it);
                  * the pitch is the dominant (modal, 0.01 pt bins) successive
                    column distance inside COL_BAND.  A median over all gaps
                    is NOT used: it mixes the grid with indentation offsets
                    and column-group jumps, which is exactly how the old INFO
                    line reported jtbook page 1 as ours=16.90 ref=23.30 while
                    the real grids were 16.936 vs 16.936 pt (histogram in
                    PLAN.md R3).
                A page is homogeneous only when one em covers >=60% of the
                page's glyphs, >=4 body columns exist, >=4 in-band gaps exist
                and the modal gap holds >=1/3 of them; otherwise the page is
                reported as n/a with the reason.  A tate document must gate at
                least one page, so an unmeasurable body cannot silently escape
                the comparison.

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

# A tate column is a BODY column when it carries at least this many
# characters; smaller clusters are headings/furniture and are excluded from
# the column-grid measurement.
BODY_MIN_CELLS = 8

# --- tate column pitch (R14) -------------------------------------------------
# Tolerance on the measured column pitch, in points.  The extracted box
# coordinates are exact to the PDF's 1/1000 bp grid and both sides are measured
# with the same estimator, so the only residual is the 0.01 pt mode bin plus
# floating-point formatting: measured ours=16.9361 ref=16.9360 on jtbook page
# 1.  0.05 pt is 5x that residual and two orders below any layout defect (the
# estimator artefact this replaced read 6.4 pt apart).
COLUMN_PITCH_TOL = 0.05
# Plausible body column pitches: a tate grid is one column skip, 8-30 pt.
COL_BAND = (8.0, 30.0)
# A body column must carry at least this many characters (see BODY_MIN_CELLS)
# and there must be at least this many columns for a pitch to be defined.
PITCH_MIN_COLUMNS = 4
PITCH_MIN_GAPS = 4
# Homogeneity: one glyph size must cover this fraction of the page (a title
# page of display type is not a body page) ...
EM_FRACTION = 0.60
# ... and the modal gap must carry this share of the in-band gaps, otherwise
# the page has no dominant grid (mixed furniture).
PITCH_MODE_SHARE = 1.0 / 3.0
# A glyph box wider/narrower than the modal em by this much is not body text.
EM_TOL = 0.05
# Two reported column positions closer than this are the same column.
COLUMN_X_TOL = 0.001


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


def body_columns(lines):
    """tate: {column x0: body cells} for the page's body-size glyph boxes.

    In a vertical page every glyph is its own extractor "line", and its bbox
    is the character cell box: the full-width box at the body size is the
    MODAL box width on the page, while heading/title material is set at
    another size and drops out of the filter.  x0 of that box is the column
    position, identical for every glyph of a column (measured: 58 consecutive
    glyphs of one ltjtbook column all report x0=306.88).
    """
    widths = {}
    for _, b, _ in lines:
        w = round(b[2] - b[0], 2)
        widths[w] = widths.get(w, 0) + 1
    if not widths:
        return None, None, "no text"
    em, n_em = sorted(widths.items(), key=lambda kv: (-kv[1], kv[0]))[0]
    if n_em < EM_FRACTION * len(lines):
        return None, em, "%d/%d glyphs at the em (%.2f pt)" % (
            n_em, len(lines), em)
    cols = {}
    for t, b, _ in lines:
        if abs((b[2] - b[0]) - em) <= EM_TOL:
            k = round(b[0], 4)
            cols[k] = cols.get(k, 0) + len(norm_text(t))
    # One column can report x0 values a ten-thousandth apart (measured on the
    # reference side: 306.8809 for 45 glyphs, 306.8810 for 8).  Merge positions
    # closer than COLUMN_X_TOL, keeping the cell-weighted mean, so a column is
    # one lattice point on both sides without quantising the pitch.
    merged = []
    for x, n in sorted(cols.items()):
        if merged and x - merged[-1][2] <= COLUMN_X_TOL:
            m = merged[-1]
            m[0] += x * n
            m[1] += n
            m[2] = x
        else:
            merged.append([x * n, n, x])
    return {round(s / n, 4): n for s, n, _ in merged}, em, None


def column_pitch(lines):
    """(pitch, detail): the page's dominant tate body column pitch.

    Returns (None, reason) when the page is not a homogeneous body page, so
    the caller can report why a page was not gated instead of inventing a
    number.  detail always starts with the measurement context.
    """
    cols, em, why = body_columns(lines)
    if why is not None:
        return None, why
    xs = sorted(x for x, n in cols.items() if n >= BODY_MIN_CELLS)
    if len(xs) < PITCH_MIN_COLUMNS:
        return None, "%d body column(s), need %d" % (len(xs), PITCH_MIN_COLUMNS)
    gaps = [xs[i + 1] - xs[i] for i in range(len(xs) - 1)]
    gaps = [g for g in gaps if COL_BAND[0] <= g <= COL_BAND[1]]
    if len(gaps) < PITCH_MIN_GAPS:
        return None, "%d in-band gap(s), need %d" % (len(gaps), PITCH_MIN_GAPS)
    # Dominant gap, binned at 0.01 pt (the extractor's coordinate resolution).
    bins = {}
    for g in gaps:
        k = round(g, 2)
        bins[k] = bins.get(k, 0) + 1
    k, count = sorted(bins.items(), key=lambda kv: (-kv[1], kv[0]))[0]
    if count < PITCH_MODE_SHARE * len(gaps):
        return None, "no dominant gap (%d/%d at %.2f pt)" % (
            count, len(gaps), k)
    exact = sorted(g for g in gaps if round(g, 2) == k)
    mid = len(exact) // 2
    pitch = exact[mid] if len(exact) % 2 else (exact[mid - 1] + exact[mid]) / 2
    return pitch, "%d columns, %d/%d gaps at %.2f pt" % (
        len(xs), count, len(gaps), k)


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
    pitched = 0          # tate pages whose column pitch was gated
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
            # out vertical writing natively and its coordinates differ.  Raw
            # positions and edges are therefore not comparable; the comparable
            # positional quantity is the COLUMN PITCH along x (see the module
            # docstring), measured on body-size boxes only.
            pa, why_a = column_pitch(la)
            pb, why_b = column_pitch(lb)
            if pa is not None and pb is not None:
                pitched += 1
                ok = abs(pa - pb) <= COLUMN_PITCH_TOL
                print("PITCH: %s: page %d tate column pitch ours=%.3f "
                      "ref=%.3f (tolerance %.2f pt; %s)"
                      % (label, i + 1, pa, pb, COLUMN_PITCH_TOL,
                         "ours " + why_a + ", ref " + why_b))
                if not ok:
                    fail("page %d: tate column pitch ours=%.3f ref=%.3f "
                         "diff=%.3f pt exceeds %.2f pt"
                         % (i + 1, pa, pb, abs(pa - pb), COLUMN_PITCH_TOL))
            elif (pa is None) != (pb is None):
                # One side has a measurable body grid and the other does not:
                # the page structures are not comparable, which is a defect,
                # not a reason to skip the gate.
                fail("page %d: tate column pitch measurable on one side only "
                     "(ours: %s; ref: %s)" % (i + 1, why_a, why_b))
            else:
                print("INFO: %s: page %d tate column pitch n/a (ours: %s; "
                      "ref: %s)" % (label, i + 1, why_a, why_b))
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

    # A tate comparison that never gated a column pitch verified nothing about
    # position, which is what R14 exists to prevent.
    if tate and pitched == 0 and not failures:
        fail("no homogeneous body page: tate column pitch unverified "
             "on %d page(s)" % min(len(doc_a), len(doc_b)))

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
