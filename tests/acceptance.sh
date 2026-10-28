#!/bin/sh
# acceptance.sh -- the plan's local acceptance sequence, reproducible.
#
#   sh tests/acceptance.sh --pdftexja <checkout> --jlreq <checkout>
#
# Runs, in order, with staged install trees under one scratch directory:
#   1. pdftexja build, jfm/font checks, install into stage/pdftexja
#   2. foundation proof, class parity, staged provenance (incl. jlreq mode)
#   3. jlreq JFM generation + canary check + install into stage/jlreq
#   4. staged provenance over both trees again (jlreq-yoko / jlreq-tate)
#   5. jlreq consumer suite (class-level gates)
#   6. TDS bundle: `make tds` into the scratch tree, payload presence, and
#      absence of the uninstall sentinel
#
# Every step prints its own PASS/FAIL; the script exits non-zero if any step
# fails.  Nothing here re-records a baseline and no threshold is relaxed.

set -u

PDFTEXJA=""
JLREQ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pdftexja) PDFTEXJA=$2; shift 2 ;;
    --pdftexja=*) PDFTEXJA=${1#--pdftexja=}; shift ;;
    --jlreq) JLREQ=$2; shift 2 ;;
    --jlreq=*) JLREQ=${1#--jlreq=}; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "acceptance.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$PDFTEXJA" ] && [ -n "$JLREQ" ] || {
  echo "acceptance.sh: --pdftexja and --jlreq are required" >&2; exit 2; }
[ -d "$PDFTEXJA" ] && [ -d "$JLREQ" ] || {
  echo "acceptance.sh: both checkouts must exist" >&2; exit 2; }

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/pdftexja-accept.XXXXXXXX") || exit 2
trap 'echo "acceptance stage: $STAGE"' EXIT HUP INT TERM
P="$STAGE/pdftexja"
J="$STAGE/jlreq"
fail=0

step() { echo; echo "== $* =="; }

step "1. pdftexja build + checks"
make -C "$PDFTEXJA" -j4 all >"$STAGE/build.log" 2>&1 || { echo "FAIL: build"; tail -5 "$STAGE/build.log"; fail=1; }
make -C "$PDFTEXJA" check-jfm >>"$STAGE/build.log" 2>&1 || { echo "FAIL: check-jfm"; fail=1; }
make -C "$PDFTEXJA" check-fonts >>"$STAGE/build.log" 2>&1 || { echo "FAIL: check-fonts"; fail=1; }
make -C "$PDFTEXJA" check-uninstall >>"$STAGE/build.log" 2>&1 || { echo "FAIL: check-uninstall"; fail=1; }

step "2. pdftexja install + proofs"
make -C "$PDFTEXJA" -j4 install PDFTEXJA_TEXMF="$P" >>"$STAGE/build.log" 2>&1 \
  || { echo "FAIL: install"; fail=1; }
sh "$PDFTEXJA/tests/run-tests.sh" --texmf "$P" >"$STAGE/foundation.log" 2>&1 \
  || { echo "FAIL: foundation proof"; tail -12 "$STAGE/foundation.log"; fail=1; }
sh "$PDFTEXJA/tests/run-class-tests.sh" --texmf "$P" >"$STAGE/classes.log" 2>&1 \
  || { echo "FAIL: class parity"; grep -E '^FAIL' "$STAGE/classes.log"; fail=1; }

step "3. jlreq JFM + canary + install"
make -C "$JLREQ" -j4 pdftex-jfm PDFTEXJA_SCRIPTS="$P/scripts/pdftexja" >>"$STAGE/build.log" 2>&1 \
  || { echo "FAIL: jlreq pdftex-jfm"; fail=1; }
make -C "$JLREQ" check-pdftex-jfm PDFTEXJA_SCRIPTS="$P/scripts/pdftexja" >"$STAGE/jfm.log" 2>&1 \
  || { echo "FAIL: jlreq check-pdftex-jfm"; tail -6 "$STAGE/jfm.log"; fail=1; }
make -C "$JLREQ" -j4 jfm >>"$STAGE/build.log" 2>&1 || { echo "FAIL: jlreq jfm"; fail=1; }
make -C "$JLREQ" -j4 install JLREQ_TEXMF="$J" PDFTEXJA_SCRIPTS="$P/scripts/pdftexja" \
  >>"$STAGE/build.log" 2>&1 || { echo "FAIL: jlreq install"; fail=1; }

step "4. staged provenance (foundation + jlreq)"
sh "$PDFTEXJA/tests/staged-proof.sh" --texmf "$P" --jlreq-tree "$J" \
  >"$STAGE/provenance.log" 2>&1 \
  || { echo "FAIL: staged provenance"; tail -12 "$STAGE/provenance.log"; fail=1; }

step "5. jlreq consumer suite (class-level gates)"
if [ -x "$JLREQ/tests/run-pdftex-tests.sh" ] || [ -f "$JLREQ/tests/run-pdftex-tests.sh" ]; then
  if ( cd "$JLREQ" && env PDFTEXJA_TEXMF="$P" JLREQ_TEXMF="$J" \
         sh tests/run-pdftex-tests.sh ) >"$STAGE/jlreq-suite.log" 2>&1; then
    echo "PASS: jlreq consumer suite"
  else
    echo "FAIL: jlreq consumer suite"; tail -20 "$STAGE/jlreq-suite.log"; fail=1
  fi
else
  echo "SKIP: jlreq consumer suite missing"; fail=1
fi

step "6. TDS bundle (make tds)"
TDS="$STAGE/tds"
if make -C "$PDFTEXJA" tds TDS="$TDS" >"$STAGE/tds.log" 2>&1; then
  echo "PASS: make tds"
else
  echo "FAIL: make tds"; tail -10 "$STAGE/tds.log"; fail=1
fi

# TDS contents.  Every required path is named individually so a missing file
# fails (never skips) and the log says exactly which one is absent.  The list
# mirrors the Makefile's install sets: 12 classes, the runtime .sty modules
# and class helpers, the 25 JFM payloads + 5 manifests, and the 3 font
# profiles.
tds_missing=0
tds_need() {
  if [ -e "$TDS/tex/latex/pdftexja/$1" ]; then
    :
  else
    echo "FAIL: tds: missing $TDS/tex/latex/pdftexja/$1"
    tds_missing=$((tds_missing + 1))
    fail=1
  fi
}
for c in pdfjarticle pdfjreport pdfjbook pdfjtarticle pdfjtreport pdfjtbook \
         pdfjsarticle pdfjsreport pdfjsbook pdfjspf pdfjskiyou pdfjltxdoc; do
  tds_need "$c.cls"
done
for f in pdftexja pdftexja-fonts pdftexja-rules pdftexja-direction \
         pdftexja-paper pdftexja-math pdftexja-latex pdftexja-inline \
         pdftexja-ruby pdftexja-paragraph; do
  tds_need "$f.sty"
done
for f in pdftexja-class.def pdftexja-class-crop.def; do
  tds_need "$f"
done
for p in standard ujis min jis ptexmin; do
  tds_need "pdftexja-jfm-$p.def"
  tds_need "pdftexja-jfm-$p-manifest.lua"
done
for v in base b z bz n bn; do
  tds_need "pdftexja-jfm-standard-yoko-$v.def"
  tds_need "pdftexja-jfm-standard-tate-$v.def"
done
for p in ujis min jis ptexmin; do
  tds_need "pdftexja-jfm-$p-yoko-base.def"
  tds_need "pdftexja-jfm-$p-tate-base.def"
done
for f in pdftexja-fonts-ipaex.def pdftexja-fonts-ipa.def pdftexja-fonts-haranoaji.def; do
  tds_need "$f"
done
if [ "$tds_missing" -eq 0 ]; then
  echo "PASS: tds: required TDS payload present (12 classes, 10 modules, 2 helpers, 25 JFM payloads + 5 manifests, 3 profiles)"
fi

# The uninstall sentinel (a file named SENTINEL containing exactly `keep`,
# see check-uninstall) must never survive into a distributable bundle.
if find "$TDS" -name 'SENTINEL*' -print 2>/dev/null | grep -q .; then
  echo "FAIL: tds: uninstall sentinel leaked into the bundle"
  find "$TDS" -name 'SENTINEL*' -print
  fail=1
elif grep -rlx 'keep' "$TDS" >/dev/null 2>&1; then
  echo "FAIL: tds: uninstall sentinel content ('keep') leaked into the bundle"
  grep -rlx 'keep' "$TDS"
  fail=1
else
  echo "PASS: tds: no uninstall sentinel in the bundle"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "ACCEPTANCE: FAILED (logs under $STAGE)"
  exit 1
fi
echo "ACCEPTANCE: all steps passed"
grep -h "ALL FOUNDATION TESTS PASSED\|class parity summary" "$STAGE/foundation.log" "$STAGE/classes.log" 2>/dev/null
exit 0
