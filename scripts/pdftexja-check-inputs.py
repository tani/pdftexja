#!/usr/bin/env python3
"""pdftexja-check-inputs.py -- installed-tree provenance checker (plan §10).

Usage:
  pdftexja-check-inputs.py MODE FLS PDFTEXJA_TREE JLREQ_TREE \
                            PDFTEXJA_SOURCE JLREQ_SOURCE

  MODE            foundation | jlreq | native
  FLS             pdflatex -recorder output of the run under test
  PDFTEXJA_TREE   installed pdftexja tree (or "-")
  JLREQ_TREE      installed jlreq tree (or "-")
  PDFTEXJA_SOURCE pdftexja checkout (or "-")
  JLREQ_SOURCE    jlreq checkout (or "-")

Exit status:
  0  every loaded file is inside the trees the mode allows
  1  missing file, or an input resolved inside a forbidden tree
  2  usage error (bad argument count, unknown mode)

The point of this checker is the *boundary*, not the full dependency set:
each mode names the trees that MAY provide the runtime, and the checker
proves that (a) the required entry files really were read from them and
(b) nothing was silently satisfied from a source checkout instead.
"""

import os
import sys


def usage_error(msg):
    sys.stderr.write("pdftexja-check-inputs.py: %s\n" % msg)
    sys.exit(2)


def read_fls(path):
    """Return (pwd, [inputs]) with inputs resolved to absolute real paths."""
    if not os.path.exists(path):
        sys.stderr.write("pdftexja-check-inputs.py: FLS not found: %s\n" % path)
        sys.exit(1)
    pwd = os.path.dirname(os.path.abspath(path))
    raw = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith("PWD "):
                pwd = line[4:]
            elif line.startswith("INPUT "):
                raw.append(line[6:])

    def resolve(name):
        if not os.path.isabs(name):
            name = os.path.join(pwd, name)
        return os.path.realpath(name)

    return pwd, [resolve(n) for n in raw]


def is_under(path, root):
    """True when path is root or inside root (path-component safe)."""
    if not root or root == "-":
        return False
    root = os.path.realpath(root)
    if path == root:
        return True
    return path.startswith(root + os.sep)


def inside_any(path, roots):
    return any(is_under(path, r) for r in roots)


def main(argv):
    if len(argv) != 7:
        usage_error("expected 6 arguments, got %d" % (len(argv) - 1))
    mode, fls, p_tree, j_tree, p_src, j_src = argv[1:]

    if mode not in ("foundation", "jlreq", "native"):
        usage_error("unknown MODE %r (want foundation|jlreq|native)" % mode)

    for label, value in (("PDFTEXJA_TREE", p_tree), ("JLREQ_TREE", j_tree),
                         ("PDFTEXJA_SOURCE", p_src), ("JLREQ_SOURCE", j_src)):
        if value != "-" and not os.path.exists(value):
            sys.stderr.write("pdftexja-check-inputs.py: %s does not exist: %s\n"
                             % (label, value))
            sys.exit(1)

    pwd, inputs = read_fls(fls)
    errors = []

    def require_under(rel, root, what):
        """Require that some input ends with rel and lives under root."""
        hits = [p for p in inputs if p.endswith(os.sep + rel)
                or os.path.basename(p) == os.path.basename(rel)]
        if not hits:
            errors.append("required %s was not loaded (%s)" % (what, rel))
            return
        hit = [p for p in hits if is_under(p, root)]
        if not hit:
            errors.append("%s was loaded from outside %s: %s"
                          % (what, root, hits[0]))

    def forbid_under(roots, what):
        for p in inputs:
            if inside_any(p, roots):
                errors.append("%s must not be loaded in %s mode: %s"
                              % (what, mode, p))

    pdftexja_res = [r for r in (p_tree,) if r != "-"]
    jlreq_res = [r for r in (j_tree,) if r != "-"]
    sources = [r for r in (p_src, j_src) if r != "-"]

    # any checkout source tree is a forbidden provider in every mode: the
    # proof is about the installed artifacts, and a source-tree hit means the
    # installed tree was incomplete.
    for p in inputs:
        if inside_any(p, sources):
            errors.append("input resolved inside a source checkout: %s" % p)

    if mode == "foundation":
        require_under("pdftexja.sty", p_tree, "the package entry")
        forbid_under(jlreq_res, "jlreq runtime")
        # every pdfj*/pdfjs* class and class helper must come from the package
        for p in inputs:
            b = os.path.basename(p)
            if (b.startswith("pdfj") and (b.endswith(".cls") or b.endswith(".clo")
                                          or b.startswith("pdftexja-class"))):
                if not is_under(p, p_tree):
                    errors.append("class resource outside the pdftexja tree: %s" % p)
        for p in inputs:
            if is_under(p, jlreq_res):
                errors.append("jlreq resource used in foundation mode: %s" % p)

    elif mode == "jlreq":
        require_under("jlreq.cls", j_tree, "the jlreq class")
        require_under("pdftexja.sty", p_tree, "the pdftexja package")
        for p in inputs:
            b = os.path.basename(p)
            if b.startswith("pdfj") and (b.endswith(".cls") or b.endswith(".clo")
                                         or b.startswith("pdftexja-class")):
                errors.append("bundled class loaded in jlreq mode: %s" % p)
        # jlreq class data must not leak out of its tree, and pdftexja data
        # must not leak out of the package tree
        for p in inputs:
            b = os.path.basename(p)
            if b.startswith("jlreq") and (b.endswith(".sty") or b.endswith(".cls")
                                          or b.endswith(".def") or b.endswith(".lua")):
                if not is_under(p, j_tree):
                    errors.append("jlreq resource outside the jlreq tree: %s" % p)
            if b.startswith("pdftexja-"):
                if not is_under(p, p_tree):
                    errors.append("pdftexja resource outside the pdftexja tree: %s" % p)

    else:  # native
        require_under("jlreq.cls", j_tree, "the jlreq class")
        forbid_under(pdftexja_res, "pdftexja runtime")
        for p in inputs:
            b = os.path.basename(p)
            if b.startswith("pdftexja"):
                errors.append("pdftexja resource used in native mode: %s" % p)

    if errors:
        for e in errors:
            sys.stderr.write("pdftexja-check-inputs.py: %s\n" % e)
        sys.stderr.write("pdftexja-check-inputs.py: %d violation(s) in %s mode\n"
                         % (len(errors), mode))
        return 1
    sys.stdout.write("pdftexja-check-inputs.py: %s mode OK (%d inputs, pwd %s)\n"
                     % (mode, len(inputs), pwd))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
