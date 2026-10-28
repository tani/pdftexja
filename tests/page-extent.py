#!/usr/bin/env python3
"""page-extent.py -- diagnostic only (not a gate).

Usage: page-extent.py OUR.pdf REF.pdf LABEL

Prints the painted extent of page 1 for both documents:
  INFO: <label>: page1 extent ours=x0..x1/y0..y1 ref=x0..x1/y0..y1

Why this exists: the tate parity gates assert the extracted text and the
column pitch, because pdftexja rotates a horizontal galley while LuaTeX-ja
lays out vertical writing natively (raw coordinates are not comparable).
Those gates therefore CANNOT see a constant drift of the whole set area --
e.g. a furniture or first-line-offset regression moving every column by the
same amount.  This line keeps such a drift visible in the test log without
turning an orientation artefact into a false failure.

Exit status is always 0; callers must not gate on it.
"""

import sys

try:
    import pymupdf
except ImportError:  # older bindings
    import fitz as pymupdf


def extent(path):
    doc = pymupdf.open(path)
    page = doc[0]
    xs, ys = [], []
    for block in page.get_text("dict").get("blocks", []):
        for line in block.get("lines", []):
            b = line.get("bbox", (0, 0, 0, 0))
            xs += [b[0], b[2]]
            ys += [b[1], b[3]]
    if not xs:
        return "empty"
    return "%.2f..%.2f/%.2f..%.2f" % (min(xs), max(xs), min(ys), max(ys))


def main(argv):
    if len(argv) != 4:
        sys.stderr.write("page-extent.py: expected OUR REF LABEL\n")
        return 2
    ours, ref, label = argv[1:4]
    print("INFO: %s: page1 extent ours=%s ref=%s"
          % (label, extent(ours), extent(ref)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
