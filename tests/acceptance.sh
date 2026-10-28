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

echo
if [ "$fail" -ne 0 ]; then
  echo "ACCEPTANCE: FAILED (logs under $STAGE)"
  exit 1
fi
echo "ACCEPTANCE: all steps passed"
grep -h "ALL FOUNDATION TESTS PASSED\|class parity summary" "$STAGE/foundation.log" "$STAGE/classes.log" 2>/dev/null
exit 0
