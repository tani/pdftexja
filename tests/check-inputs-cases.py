#!/usr/bin/env python3
"""check-inputs-cases.py -- self-test matrix for the provenance checker.

Runs the checker against eight synthetic recorder files, each exercising one
boundary rule, so a change to the checker (precedence, tree membership, the
class-owned preset carve-out) is re-verified rather than assumed:

  1 foundation happy path            -> rc 0
  2 provider file from another tree  -> rc 1
  3 relative INPUT resolved via PWD  -> rc 0
  4 leak from a SOURCE checkout      -> rc 1
  5 pdftexja runtime in native mode  -> rc 1
  6 jlreq-mode happy path            -> rc 0
  7 class-owned preset from the WRONG
    tree (carve-out bypass attempt)  -> rc 1
  8 usage error (unknown mode)       -> rc 2

Exit 0 when every case matches its expected rc.
"""
import os, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
CHECK = os.environ.get("PDFTEXJA_CHECK_INPUTS",
                       os.path.join(HERE, "..", "scripts", "pdftexja-check-inputs.py"))
root = tempfile.mkdtemp()
P = os.path.join(root, "P"); J = os.path.join(root, "J")
PSRC = os.path.join(root, "Psrc"); JSRC = os.path.join(root, "Jsrc")
OTHER = os.path.join(root, "other")
for d in (P, J, PSRC, JSRC, OTHER, os.path.join(root, "run")):
    os.makedirs(d, exist_ok=True)
def touch(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write("x")
touch(os.path.join(P, "tex/latex/pdftexja/pdftexja.sty"))
touch(os.path.join(P, "tex/latex/pdftexja/pdftexja-rules.sty"))
touch(os.path.join(P, "tex/latex/pdftexja/pdfjarticle.cls"))
touch(os.path.join(J, "tex/latex/jlreq/jlreq.cls"))
touch(os.path.join(J, "tex/latex/jlreq/pdftexja-jfm-jlreq.def"))
touch(os.path.join(OTHER, "pdftexja.sty"))
touch(os.path.join(PSRC, "tex/pdftexja-fonts.sty"))
touch(os.path.join(JSRC, "jlreq.cls"))
def fls(name, lines):
    path = os.path.join(root, name)
    with open(path, "w") as fh:
        fh.write("PWD %s\n" % os.path.join(root, "run"))
        for l in lines: fh.write("INPUT %s\n" % l)
    return path
STD = "/nix/store/xxx/tex/latex/base/article.cls"
cases = [
 ("1 foundation ok", "foundation",
  [os.path.join(P,"tex/latex/pdftexja/pdftexja.sty"), os.path.join(P,"tex/latex/pdftexja/pdfjarticle.cls"), STD], P, "-", "-", "-", 0),
 ("2 wrong-tree provider", "foundation",
  [os.path.join(OTHER,"pdftexja.sty")], P, "-", "-", "-", 1),
 ("3 relative input", "foundation",
  ["../P/tex/latex/pdftexja/pdftexja.sty"], P, "-", "-", "-", 0),
 ("4 source leak", "foundation",
  [os.path.join(P,"tex/latex/pdftexja/pdftexja.sty"), os.path.join(PSRC,"tex/pdftexja-fonts.sty")], P, "-", PSRC, "-", 1),
 ("5 native leak", "native",
  [os.path.join(J,"tex/latex/jlreq/jlreq.cls"), os.path.join(P,"tex/latex/pdftexja/pdftexja.sty")], P, J, "-", "-", 1),
 ("6 jlreq ok", "jlreq",
  [os.path.join(P,"tex/latex/pdftexja/pdftexja.sty"), os.path.join(J,"tex/latex/jlreq/jlreq.cls"), os.path.join(J,"tex/latex/jlreq/pdftexja-jfm-jlreq.def"), STD], P, J, "-", "-", 0),
 ("7 class-owned preset from the WRONG tree", "jlreq",
  [os.path.join(P,"tex/latex/pdftexja/pdftexja.sty"), os.path.join(J,"tex/latex/jlreq/jlreq.cls"), os.path.join(P,"tex/latex/pdftexja/pdftexja-jfm-jlreq.def")], P, J, "-", "-", 1),
]
bad = 0
for name, mode, inputs, p, j, ps, js, want in cases:
    f = fls("c%d.fls" % len(name), inputs)
    r = subprocess.run([sys.executable, CHECK, mode, f, p, j, ps, js],
                       capture_output=True, text=True)
    ok = (r.returncode == want)
    print("%-6s %-44s rc=%d want=%d %s" % ("PASS" if ok else "FAIL", name, r.returncode, want, "" if ok else r.stderr.strip().splitlines()[-1] if r.stderr.strip() else ""))
    bad += 0 if ok else 1
# usage errors
r = subprocess.run([sys.executable, CHECK, "bogus", "x"], capture_output=True, text=True)
print("%-6s %-44s rc=%d want=2" % ("PASS" if r.returncode == 2 else "FAIL", "8 usage error", r.returncode))
bad += 0 if r.returncode == 2 else 1
shutil.rmtree(root)
sys.exit(0 if bad == 0 else 1)
