#!/bin/sh
# staged-proof.sh -- out-of-repository provenance proof (plan §10/Verification 4).
#
#   sh tests/staged-proof.sh --texmf <installed-pdftexja-tree>
#
# Compiles the foundation fixtures from a scratch cwd that is outside every
# checkout, with the installed tree as the ONLY searchable TeX tree, then
# feeds the recorder output to scripts/pdftexja-check-inputs.py (mode
# `foundation`) so that every loaded file is proven to come from the
# installed artifacts -- never from a source checkout, never from a stray
# user tree.
#
# Exit: 0 proof passed, 1 any failure, 2 usage/installation error.

set -u

TEXMF=""
JLREQ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --texmf) TEXMF=$2; shift 2 ;;
    --texmf=*) TEXMF=${1#--texmf=}; shift ;;
    --jlreq-tree) JLREQ=$2; shift 2 ;;
    --jlreq-tree=*) JLREQ=${1#--jlreq-tree=}; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "staged-proof.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$TEXMF" ]; then
  echo "staged-proof.sh: --texmf <installed-tree> is required" >&2; exit 2
fi
if [ ! -f "$TEXMF/tex/latex/pdftexja/pdftexja.sty" ]; then
  echo "staged-proof.sh: $TEXMF does not contain the installed package" >&2
  exit 2
fi
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pdftexja-staged.XXXXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$WORK/run" "$WORK/home" "$WORK/tmp" "$WORK/empty"

# The tree under test may live INSIDE a checkout (e.g. the `make tds` bundle).
# The proof is about the artifacts alone, so take a copy outside every
# checkout and use that: a source-tree hit is then a genuine violation.
TREE=$(cd "$TEXMF" && pwd)
case "$TREE" in
  "$REPO"|"$REPO"/*|"$REPO/../jlreq"|"$REPO/../jlreq"/*)
    cp -R "$TREE" "$WORK/tree" || exit 2
    TREE="$WORK/tree"
    ;;
esac

CHECKER="$TREE/scripts/pdftexja/pdftexja-check-inputs.py"
if [ ! -f "$CHECKER" ]; then
  echo "staged-proof.sh: checker missing from the installed tree: $CHECKER" >&2
  exit 2
fi

stage_env() {
  env -i PATH="$PATH" HOME="$WORK/home" TMPDIR="$WORK/tmp" \
    LC_ALL=C.UTF-8 TZ=UTC SOURCE_DATE_EPOCH=1735689600 \
    TEXMFHOME="$WORK/empty" TEXMFLOCAL="$WORK/empty" \
    TEXINPUTS="$TREE/tex/latex//:" \
    TEXFONTS="$TREE/fonts/tfm//:" \
    TTFONTS="$TREE/fonts/truetype//:" \
    ENCFONTS="$TREE/fonts/enc//:" \
    "$@"
}

fail=0
for fixture in standalone-yoko standalone-tate; do
  cp "$REPO/tests/fixtures/foundation/$fixture.tex" "$WORK/run/"
  if ! ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -recorder \
           -interaction=nonstopmode -halt-on-error "$fixture.tex" \
           >"$fixture.log" 2>&1 ); then
    echo "FAIL: $fixture: compile" >&2; tail -12 "$WORK/run/$fixture.log" >&2
    fail=1; continue
  fi
  if python3 "$CHECKER" foundation "$WORK/run/$fixture.fls" "$TREE" - \
       "$REPO" "$REPO/../jlreq"; then
    echo "PASS: $fixture: provenance (installed tree only)"
  else
    echo "FAIL: $fixture: provenance" >&2
    fail=1
  fi
done

# Optional: the jlreq consumer boundary (class + adapter from the jlreq tree,
# package resources from the pdftexja tree, and the class-owned JFM preset
# from the jlreq tree).
if [ -n "$JLREQ" ]; then
  JTREE=$(cd "$JLREQ" && pwd)
  case "$JTREE" in
    "$REPO"|"$REPO"/*)
      cp -R "$JTREE" "$WORK/jtree" || exit 2
      JTREE="$WORK/jtree"
      ;;
  esac
  cat >"$WORK/run/jlreq-yoko.tex" <<'EOF'
\documentclass[pdflatex]{jlreq}
\begin{document}
\section{見出し}日本語の本文である。「括弧」と句読点。
\end{document}
EOF
  cat >"$WORK/run/jlreq-tate.tex" <<'EOF'
\documentclass[pdflatex,tate]{jlreq}
\begin{document}
縦組の本文である。「括弧」と句読点。
\end{document}
EOF
  for f in jlreq-yoko jlreq-tate; do
    if ! ( cd "$WORK/run" && env -i PATH="$PATH" HOME="$WORK/home" \
             TMPDIR="$WORK/tmp" LC_ALL=C.UTF-8 TZ=UTC SOURCE_DATE_EPOCH=1735689600 \
             TEXMFHOME="$WORK/empty" TEXMFLOCAL="$WORK/empty" \
             TEXINPUTS="$JTREE/tex/latex//:$TREE/tex/latex//:" \
             TEXFONTS="$TREE/fonts/tfm//:$JTREE/fonts/tfm//:" \
             VFONTS="$JTREE/fonts/vf//:" \
             TTFONTS="$TREE/fonts/truetype//:" \
             ENCFONTS="$TREE/fonts/enc//:" \
             pdflatex -no-shell-escape -recorder -interaction=nonstopmode \
             -halt-on-error "$f.tex" >"$f.log" 2>&1 ); then
      echo "FAIL: $f: compile" >&2; tail -12 "$WORK/run/$f.log" >&2
      fail=1; continue
    fi
    if python3 "$CHECKER" jlreq "$WORK/run/$f.fls" "$TREE" "$JTREE" \
         "$REPO" "$(cd "$REPO/../jlreq" 2>/dev/null && pwd)"; then
      echo "PASS: $f: provenance (jlreq mode)"
    else
      echo "FAIL: $f: provenance (jlreq mode)" >&2
      fail=1
    fi
  done
fi

[ "$fail" -eq 0 ] || exit 1
echo "staged-proof: installed-tree-only compile and provenance OK"
exit 0
