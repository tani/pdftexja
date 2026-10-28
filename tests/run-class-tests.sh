#!/bin/sh
# pdftexja class-parity tests (plan §10, Verification §3).
#
#   sh tests/run-class-tests.sh --texmf <installed-pdftexja-tree>
#        [--classes "pdfjarticle pdfjsarticle ..."]
#
# For every bundled class the SAME body (tests/fixtures/classes/
# shared-body.tex) is typeset twice:
#
#   ours       : <pdftexja class> with pdfLaTeX, installed tree only
#   reference  : the PINNED LuaTeX-ja class (ltj*/ltjs*/ltjltxdoc) with
#                LuaLaTeX, i.e. the implementation we claim equivalence with
#
# and the two PDFs are compared by tests/compare-pdf.py: page count,
# MediaBox, extracted Unicode text (whitespace-insensitive, glyph-level
# ToUnicode), line-breaking decisions, baseline pitch and block structure.
# Additionally the layout numbers each class computes itself are compared
# numerically (GEOM: line in the log, tw/th/bs/pi/cs within 0.03 pt), which
# is the class-level "same quality" contract and is independent of the font
# outlines in use.  The values are parsed as numbers: the label (`tw=') and
# the unit (`pt') are stripped before awk sees them.
#
# Exit: 0 all class pairs pass, 1 any failure, 2 usage/installation error.

set -u

TEXMF=""
CLASSES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --texmf) TEXMF=$2; shift 2 ;;
    --texmf=*) TEXMF=${1#--texmf=}; shift ;;
    --classes) CLASSES=$2; shift 2 ;;
    --classes=*) CLASSES=${1#--classes=}; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "run-class-tests.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TEXMF" ]; then
  echo "run-class-tests.sh: --texmf <installed-tree> is required" >&2; exit 2
fi
if [ ! -d "$TEXMF" ]; then
  echo "run-class-tests.sh: tree does not exist: $TEXMF" >&2; exit 2
fi
for f in tex/latex/pdftexja/pdftexja.sty tex/latex/pdftexja/pdfjarticle.cls; do
  if [ ! -f "$TEXMF/$f" ]; then
    echo "run-class-tests.sh: $TEXMF lacks $f (install the package first)" >&2
    exit 2
  fi
done

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pdftexja-classes.XXXXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$WORK/run" "$WORK/home" "$WORK/tmp" "$WORK/empty"

stage_env() {
  env -i PATH="$PATH" HOME="$WORK/home" TMPDIR="$WORK/tmp" \
    LC_ALL=C.UTF-8 TZ=UTC SOURCE_DATE_EPOCH=1735689600 \
    TEXMFHOME="$WORK/empty" TEXMFLOCAL="$WORK/empty" \
    TEXINPUTS="$TEXMF/tex/latex//:" \
    TEXFONTS="$TEXMF/fonts/tfm//:" \
    TTFONTS="$TEXMF/fonts/truetype//:" \
    ENCFONTS="$TEXMF/fonts/enc//:" \
    "$@"
}
# the reference side needs the distribution's LuaTeX-ja; no installed-tree
# paths for it beyond the normal distribution search
ref_env() {
  env -i PATH="$PATH" HOME="$WORK/home" TMPDIR="$WORK/tmp" \
    LC_ALL=C.UTF-8 TZ=UTC SOURCE_DATE_EPOCH=1735689600 \
    TEXMFHOME="$WORK/empty" TEXMFLOCAL="$WORK/empty" "$@"
}

# class pair table: <ours> <reference> <tate:0|1> [extra preamble]
pairs() {
  cat <<'EOF'
pdfjarticle ltjarticle 0
pdfjreport ltjreport 0
pdfjbook ltjbook 0
pdfjtarticle ltjtarticle 1
pdfjtreport ltjtreport 1
pdfjtbook ltjtbook 1
pdfjsarticle ltjsarticle 0
pdfjsreport ltjsreport 0
pdfjsbook ltjsbook 0
# pdfjspf/pdfjskiyou require a title block BY CLASS CONTRACT (the class
# prints it), so the shared body alone would fail to build; the extra
# preamble below supplies the minimum the class demands, identically on both
# sides.  A future layout fixture that changes this table must keep that
# property, otherwise the failure shows up as a compile error, not a gate.
pdfjspf ltjspf 0 \title{標題}\author{著者}\date{}\def\Keywords{キーワード}\def\Email{e@x}
pdfjskiyou ltjskiyou 0
pdfjltxdoc ltjltxdoc 0
EOF
}

FAILED=0
PASSED=0
SKIPPED=0

while read -r ours ref tate extra; do
  [ -n "${ours:-}" ] || continue
  case "${ours}" in \#*) continue;; esac
  case " ${CLASSES:-all} " in
    *" all "*|*" $ours "*) ;;
    *) continue ;;
  esac
  dir="$WORK/run/$ours"
  mkdir -p "$dir"
  cp "$REPO/tests/fixtures/classes/shared-body.tex" "$dir/body.tex"

  printf '\\documentclass%s{%s}\n%s\n\\begin{document}\n\\input{body}\n\\end{document}\n' \
    "$([ "$tate" = 1 ] && echo '[tate]')" "$ours" "$extra" > "$dir/ours.tex"
  printf '\\documentclass%s{%s}\n%s\n\\begin{document}\n\\input{body}\n\\end{document}\n' \
    "$([ "$tate" = 1 ] && echo '[tate]')" "$ref" "$extra" > "$dir/ref.tex"

  if ! ( cd "$dir" && stage_env pdflatex -no-shell-escape -recorder \
           -interaction=nonstopmode -halt-on-error ours.tex >ours.log 2>&1 ); then
    echo "FAIL: $ours: compile"; tail -15 "$dir/ours.log" >&2
    FAILED=$((FAILED + 1)); continue
  fi
  if ! ( cd "$dir" && ref_env lualatex -no-shell-escape -recorder \
           -interaction=nonstopmode -halt-on-error ref.tex >ref.log 2>&1 ); then
    echo "SKIP: $ours: reference $ref does not compile here"
    SKIPPED=$((SKIPPED + 1)); continue
  fi

  # (1) class-level layout numbers must agree verbatim
  ga=$(sed -n 's/^GEOM:\(.*\)$/\1/p' "$dir/ours.log" | head -1)
  gb=$(sed -n 's/^GEOM:\(.*\)$/\1/p' "$dir/ref.log" | head -1)
  if [ -z "$ga" ] || [ -z "$gb" ]; then
    echo "FAIL: $ours: GEOM probe missing (ours='$ga' ref='$gb')"
    FAILED=$((FAILED + 1)); continue
  fi
  # The GEOM text is `tw=<len>pt:th=<len>pt:bs=<len>pt:pi=<len>pt:cs=<len>pt`.
  # Split on `:' first, then strip the `key=' label and the `pt' unit; only
  # the remaining number is numeric.  (The old code fed `tw=322.0' to awk,
  # which scans as 0, making every comparison trivially true.)
  geom_ok=1
  for key in tw th bs pi cs; do
    va=$(printf '%s\n' "$ga" | tr ':' '\n' |
         sed -n "s/^${key}=\(.*\)pt\$/\1/p")
    vb=$(printf '%s\n' "$gb" | tr ':' '\n' |
         sed -n "s/^${key}=\(.*\)pt\$/\1/p")
    if [ -z "$va" ] || [ -z "$vb" ]; then
      echo "FAIL: $ours: GEOM field '$key' missing (ours='$ga' ref='$gb')"
      geom_ok=0; break
    fi
    # Tolerance: PLAN.md verification, class geometry 0.03 pt.
    if ! awk -v a="$va" -v b="$vb" -v k="$key" \
        'BEGIN { d = a - b; if (d < 0) d = -d
                 if (d > 0.03) { printf "GEOM DIFF %s ours=%.5f ref=%.5f delta=%.5f\n", k, a, b, d; exit 1 } }'; then
      geom_ok=0
    fi
  done
  if [ "$geom_ok" = 1 ]; then
    echo "PASS: $ours: class geometry matches $ref ($ga)"
  else
    echo "FAIL: $ours: class geometry ours($ga) vs ref($gb)"
    FAILED=$((FAILED + 1)); continue
  fi

  # (1b) DIAGNOSTIC ONLY: the page-1 painted extent.  The tate gates assert
  # text + column pitch, which cannot see a constant drift of the whole set
  # area (e.g. a furniture/topskip regression); logging the extent keeps such
  # a drift visible without turning an orientation artefact into FAIL.
  python3 "$REPO/tests/page-extent.py" "$dir/ours.pdf" "$dir/ref.pdf" "$ours"

  # (2) PDF-level parity
  if python3 "$REPO/tests/compare-pdf.py" "$dir/ours.pdf" "$dir/ref.pdf" "$ours" \
       $([ "$tate" = 1 ] && echo --tate); then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done <<EOF
$(pairs)
EOF

echo
echo "== class parity summary: $PASSED passed, $FAILED failed, $SKIPPED skipped =="
[ "$FAILED" -eq 0 ] || exit 1
exit 0
