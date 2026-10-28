#!/usr/bin/env python3
"""pdf-text.py -- extract a PDF's text with PyMuPDF (all pages).

Usage: pdf-text.py FILE.pdf

Why not pdftotext: pdftexja ships tate pages as a rotated horizontal galley
inside a normal portrait page (no /Rotate flag), and pdftotext's
rotated-layout filtering drops that content entirely -- measured: 0
characters from tests/fixtures/foundation/standalone-tate.pdf, while
PyMuPDF returns the full text (115 + 13 characters, including the heading,
the punctuation run, the TCY digits and the formula).  The extraction gates
therefore measure the DOCUMENT, not a parser quirk, and use this helper.

Exit: 0 on success, 2 on usage/IO error.
"""

import sys

try:
    import pymupdf
except ImportError:  # older bindings
    import fitz as pymupdf


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("pdf-text.py: expected FILE.pdf\n")
        return 2
    try:
        doc = pymupdf.open(argv[1])
    except Exception as exc:
        sys.stderr.write("pdf-text.py: cannot open %s: %s\n" % (argv[1], exc))
        return 2
    out = []
    for page in doc:
        out.append("".join(
            span.get("text", "")
            for block in page.get_text("dict").get("blocks", [])
            for line in block.get("lines", [])
            for span in line.get("spans", [])))
        out.append("\n")
    sys.stdout.write("".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
