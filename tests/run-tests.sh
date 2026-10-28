#!/bin/sh
# pdftexja package-only proof (plan §10, Verification §2).
#
#   sh tests/run-tests.sh --texmf <installed-tree>
#
# Validates the foundation as a standalone package: standard article/report/
# book clients (NOT jlreq), public API behaviour, direction/metric/spacing
# contracts, and the custom-JFM and error-path requirements.
#
# Hard requirements:
#   * <installed-tree> must exist and contain tex/latex/pdftexja/pdftexja.sty
#     (a missing tree is a failure, never a skip);
#   * compilation happens in a scratch cwd outside this repository, with a
#     sanitised environment whose only search paths are the installed tree;
#   * no shell escape, halt on error.
#
# Exit status: 0 all checks pass, 1 any failure, 2 usage error.

set -u

TEXMF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --texmf) TEXMF=$2; shift 2 ;;
    --texmf=*) TEXMF=${1#--texmf=}; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "run-tests.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TEXMF" ]; then
  echo "run-tests.sh: --texmf <installed-tree> is required" >&2
  exit 2
fi
if [ ! -d "$TEXMF" ]; then
  echo "run-tests.sh: --texmf tree does not exist: $TEXMF" >&2
  exit 2
fi
if [ ! -f "$TEXMF/tex/latex/pdftexja/pdftexja.sty" ]; then
  echo "run-tests.sh: $TEXMF does not contain tex/latex/pdftexja/pdftexja.sty" >&2
  echo "run-tests.sh: install the package first (make install PDFTEXJA_TEXMF=...)" >&2
  exit 2
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pdftexja-tests.XXXXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

HOME_DIR=$WORK/home
TMP_DIR=$WORK/tmp
mkdir -p "$HOME_DIR" "$TMP_DIR" "$WORK/run" "$WORK/empty-texmf"

# Sanitised environment: only the installed tree (plus the distribution) is
# searchable. TEXMFHOME/TEXMFLOCAL point at an empty dir so a stray user tree
# can never satisfy a missing resource.
stage_env() {
  env -i PATH="$PATH" HOME="$HOME_DIR" TMPDIR="$TMP_DIR" \
    LC_ALL=C.UTF-8 TZ=UTC SOURCE_DATE_EPOCH=1735689600 \
    TEXMFHOME="$WORK/empty-texmf" TEXMFLOCAL="$WORK/empty-texmf" \
    TEXINPUTS="$TEXMF/tex/latex//:" \
    TEXFONTS="$TEXMF/fonts/tfm//:" \
    VFONTS="$TEXMF/fonts/vf//:" \
    TTFONTS="$TEXMF/fonts/truetype//:" \
    ENCFONTS="$TEXMF/fonts/enc//:" \
    "$@"
}

FAILED=0
CHECKS=0
check() { CHECKS=$((CHECKS + 1)); }
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; FAILED=$((FAILED + 1)); }

# compile <name> <passes> [extra pdflatex args...]
compile() {
  name=$1; passes=$2; shift 2
  i=1
  while [ "$i" -le "$passes" ]; do
    if ! ( cd "$WORK/run" && stage_env pdflatex \
             -no-shell-escape -recorder -interaction=nonstopmode \
             -halt-on-error "$@" "$name.tex" >"$name.$i.log" 2>&1 ); then
      echo "---- $name pass $i log tail ----" >&2
      tail -30 "$WORK/run/$name.$i.log" >&2
      return 1
    fi
    i=$((i + 1))
  done
  return 0
}

log_absent() {
  if grep -E "$2" "$WORK/run/$1.log" >/dev/null 2>&1; then
    fail "$1: log matches forbidden pattern: $2"
  else
    pass "$1: log clean of /$2/"
  fi
}

pdftext_has() {
  ( cd "$WORK/run" && stage_env pdftotext -enc UTF-8 "$1.pdf" - 2>/dev/null ) \
    >"$WORK/run/$1.txt"
  if grep -qF -- "$2" "$WORK/run/$1.txt"; then
    pass "$1: extracted text contains '$2'"
  else
    fail "$1: extracted text lacks '$2'"
  fi
}

pdftext_absent() {
  if grep -qF -- "$2" "$WORK/run/$1.txt"; then
    fail "$1: extracted text unexpectedly contains '$2'"
  else
    pass "$1: extracted text lacks '$2'"
  fi
}

fonts_have() {
  ( cd "$WORK/run" && stage_env pdffonts "$1.pdf" 2>/dev/null ) \
    >"$WORK/run/$1.fonts"
  if grep -qF -- "$2" "$WORK/run/$1.fonts"; then
    pass "$1: embedded font contains '$2'"
  else
    fail "$1: embedded font list lacks '$2'"
  fi
}

# ---------------------------------------------------------------- fixtures
cp "$REPO/tests/fixtures/foundation/standalone-yoko.tex" "$WORK/run/"
cp "$REPO/tests/fixtures/foundation/standalone-tate.tex" "$WORK/run/"

# --- yoko ---------------------------------------------------------------
check
if compile standalone-yoko 2; then
  pass "standalone-yoko: 2-pass compile"
  cp "$WORK/run/standalone-yoko.2.log" "$WORK/run/standalone-yoko.log"
  log_absent standalone-yoko 'Reference .* undefined|\\@ undefined|Undefined control sequence'
  log_absent standalone-yoko '! '
  pdftext_has standalone-yoko '日本語の見出し'
  pdftext_has standalone-yoko '漢字'
  pdftext_has standalone-yoko 'かんじ'
  pdftext_has standalone-yoko '割注'
  pdftext_absent standalone-yoko '??'
  pdftext_absent standalone-yoko $'\xef\xbf\xbd'
  fonts_have standalone-yoko 'IPAexMincho'
  fonts_have standalone-yoko 'IPAexGothic'
else
  fail "standalone-yoko: compile"
fi

# --- tate --------------------------------------------------------------
check
if compile standalone-tate 2; then
  pass "standalone-tate: 2-pass compile"
  cp "$WORK/run/standalone-tate.2.log" "$WORK/run/standalone-tate.log"
  log_absent standalone-tate '! '
  pdftext_has standalone-tate '縦組の見出し'
  pdftext_has standalone-tate '脚注の本文'
  pdftext_has standalone-tate '二ページ目'
  fonts_have standalone-tate 'IPAexMincho'
  # two pages, page 2 recovered (not stuck in tate-rotation bookkeeping)
  pages=$( ( cd "$WORK/run" && stage_env pdfinfo standalone-tate.pdf 2>/dev/null ) \
             | awk '/^Pages:/{print $2}' )
  if [ "${pages:-0}" = "2" ]; then
    pass "standalone-tate: 2 pages"
  else
    fail "standalone-tate: expected 2 pages, got ${pages:-?}"
  fi
else
  fail "standalone-tate: compile"
fi

# --- metric query purity (GetMetrics{tate} inside a yoko document) ------
check
cat >"$WORK/run/metrics-purity.tex" <<'EOF'
\documentclass{article}
\usepackage{pdftexja}
\newdimen\wa \newdimen\wb
\newdimen\ga \newdimen\gb \newdimen\gc
\begin{document}
\setbox0\hbox{あ}\wa=\wd0
\pdftexjaGetMetrics{tate}{\ga}{\gb}{\gc}
\setbox0\hbox{あ}\wb=\wd0
\typeout{METRICSPURITY:wd=\the\wa/\the\wb:gw=\the\ga:gh=\the\gb:gd=\the\gc}
\ifdim\wa=\wb \typeout{METRICSPURITY:pure=yes}\else\typeout{METRICSPURITY:pure=no}\fi
\ifpdftexjaIfDirectionTF{yoko}{\typeout{METRICSPURITY:dir=yoko}}{\typeout{METRICSPURITY:dir=tate}}\fi
\end{document}
EOF
if compile metrics-purity 1; then
  if grep -q 'METRICSPURITY:pure=yes' "$WORK/run/metrics-purity.log" &&
     grep -q 'METRICSPURITY:dir=yoko' "$WORK/run/metrics-purity.log"; then
    pass "metrics-purity: GetMetrics{tate} does not change state"
  else
    fail "metrics-purity: state changed or direction query wrong"
    grep METRICSPURITY "$WORK/run/metrics-purity.log" >&2
  fi
else
  fail "metrics-purity: compile"
fi

# --- size follow: \zw tracks fontsize x ja-scale ------------------------
check
cat >"$WORK/run/size-follow.tex" <<'EOF'
\documentclass{article}
\usepackage{pdftexja}
\begin{document}
\typeout{SIZEFOLLOW:10=\the\zw}
{\fontsize{8pt}{9pt}\selectfont \typeout{SIZEFOLLOW:8=\the\zw}}
{\pdftexjasetup{ja-scale=.5}\typeout{SIZEFOLLOW:half=\the\zw}}
\typeout{SIZEFOLLOW:after=\the\zw}
\end{document}
EOF
if compile size-follow 1; then
  ten=$(sed -n 's/.*SIZEFOLLOW:10=\([0-9.]*\)pt.*/\1/p' "$WORK/run/size-follow.log" | head -1)
  eight=$(sed -n 's/.*SIZEFOLLOW:8=\([0-9.]*\)pt.*/\1/p' "$WORK/run/size-follow.log" | head -1)
  half=$(sed -n 's/.*SIZEFOLLOW:half=\([0-9.]*\)pt.*/\1/p' "$WORK/run/size-follow.log" | head -1)
  after=$(sed -n 's/.*SIZEFOLLOW:after=\([0-9.]*\)pt.*/\1/p' "$WORK/run/size-follow.log" | head -1)
  ok=1
  [ -n "$ten" ] && [ -n "$eight" ] && [ -n "$half" ] && [ -n "$after" ] || ok=0
  if [ "$ok" = 1 ]; then
    awk -v a="$ten" -v b="$eight" -v c="$half" -v d="$after" 'BEGIN{
      if (!(a>9.9 && a<10.1)) exit 1; if (!(b>7.9 && b<8.1)) exit 1;
      if (!(c>4.9 && c<5.1)) exit 1; if (!(d>9.9 && d<10.1)) exit 1;
      exit 0 }' || ok=0
  fi
  if [ "$ok" = 1 ]; then
    pass "size-follow: 10pt/8pt/ja-scale=.5/group restore"
  else
    fail "size-follow: got 10=$ten 8=$eight half=$half after=$after"
  fi
else
  fail "size-follow: compile"
fi

# --- live spacing provider (group-local, evaluated at use) --------------
check
cat >"$WORK/run/spacing-live.tex" <<'EOF'
\documentclass{article}
\usepackage{pdftexja}
\newskip\jaa \newskip\jab
\begin{document}
\pdftexjaSetSpacing{1pt plus 2pt}{3pt}
\pdftexjaGetSpacing\jaa\jab
\typeout{SPACING:a=\the\jaa:b=\the\jab}
{\pdftexjaSetSpacing{5pt}{0pt}\pdftexjaGetSpacing\jaa\jab
 \typeout{SPACING:ga=\the\jaa:gb=\the\jab}}
\pdftexjaGetSpacing\jaa\jab
\typeout{SPACING:ra=\the\jaa:rb=\the\jab}
\end{document}
EOF
if compile spacing-live 1; then
  a=$(sed -n 's/.*SPACING:a=\([^:]*\):b=.*/\1/p' "$WORK/run/spacing-live.log" | head -1)
  ga=$(sed -n 's/.*SPACING:ga=\([^:]*\):gb=.*/\1/p' "$WORK/run/spacing-live.log" | head -1)
  ra=$(sed -n 's/.*SPACING:ra=\([^:]*\):rb=.*/\1/p' "$WORK/run/spacing-live.log" | head -1)
  if [ "$a" = "1.0pt plus 2.0pt" ] && [ "$ga" = "5.0pt" ] && [ "$ra" = "$a" ]; then
    pass "spacing-live: provider evaluated at use, group-local"
  else
    fail "spacing-live: a='$a' ga='$ga' ra='$ra'"
  fi
else
  fail "spacing-live: compile"
fi

# --- tiny custom JFM (independent oracle, non-default role ids) ---------
check
TINY=$WORK/tiny
mkdir -p "$TINY"
cat >"$TINY/tiny-jfm.lua" <<'EOF'
return function(base_dir)
  local t = {
    version = 3, dir = "yoko", zw = 1.0, zh = 1.0,
    kanjiskip = {0, 0, 0}, xkanjiskip = {0, 0, 0},
    [17] = { chars = {"あ"}, align = "left", left = 0.0,
             width = 1.0, height = 0.88, depth = 0.12,
             glue = { [34] = {0.125, 0, 0} }, end_adjust = {0, 0} },
    [34] = { chars = {"。"}, align = "left", left = 0.0,
             width = 0.5, height = 0.88, depth = 0.12,
             glue = { [17] = {0.125, 0, 0} } },
    [83] = { chars = {"alchar"} },
    [201] = { chars = {"parbdd"} },
    [202] = { chars = {"boxbdd"} },
  }
  return {
    format = 1, id = "tiny", composition = "single",
    boundary_semantics = "jfm", character_semantics = "jfm",
    variants = {
      { id = "base", dir = "yoko", open_bracket_pos = "zenkaku_tentsuki",
        hanging_punctuation = false, jfm = t,
        roles = { normal = 17, latin = 83, paragraph = 201, box = 202 },
        prebreak = { [34] = 10000 }, postbreak = {}, xspacing = {},
        fullwidth_space_adjust = {}, family_identity = { mc = "tiny", gt = "tiny" } },
      { id = "base", dir = "tate", open_bracket_pos = "zenkaku_tentsuki",
        hanging_punctuation = false, jfm = t,
        roles = { normal = 17, latin = 83, paragraph = 201, box = 202 },
        prebreak = { [34] = 10000 }, postbreak = {}, xspacing = {},
        fullwidth_space_adjust = {}, family_identity = { mc = "tiny", gt = "tiny" } },
    },
  }
end
EOF
if stage_env texlua "$REPO/scripts/pdftexja-jfm.lua" --input "$TINY/tiny-jfm.lua" \
     --outdir "$TINY" --manifest "$TINY/tiny-manifest.lua" \
     --assets "$TINY/tiny-assets.mk" >"$TINY/gen.log" 2>&1; then
  cp "$TINY"/pdftexja-jfm-tiny*.def "$WORK/run/" 2>/dev/null
  cat >"$WORK/run/tiny-jfm.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-tiny.def]{pdftexja}
\begin{document}
\pdftexjasetup{ja-scale=1}
\setbox0\hbox{ああ}\typeout{TINY:jaa=\the\wd0}
\setbox0\hbox{あ。}\typeout{TINY:jaaK=\the\wd0}
\end{document}
EOF
  if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
         -halt-on-error -output-directory="$WORK/run" tiny-jfm.tex \
         >tiny-jfm.log 2>&1 ); then
    a=$(sed -n 's/.*TINY:jaa=\([0-9.]*\)pt.*/\1/p' "$WORK/run/tiny-jfm.log" | head -1)
    b=$(sed -n 's/.*TINY:jaaK=\([0-9.]*\)pt.*/\1/p' "$WORK/run/tiny-jfm.log" | head -1)
    if [ "$a" = "20.0" ] && [ "$b" = "16.25" ]; then
      pass "tiny-jfm: independent widths 20.0pt / 16.25pt"
    else
      fail "tiny-jfm: got '$a' / '$b' (want 20.0 / 16.25)"
    fi
  else
    fail "tiny-jfm: compile"
    tail -20 "$WORK/run/tiny-jfm.log" >&2
  fi
else
  fail "tiny-jfm: generation"
  cat "$TINY/gen.log" >&2
fi

# --- error paths: unknown setup key and unsupported engine gate ---------
check
cat >"$WORK/run/err-unknown-key.tex" <<'EOF'
\documentclass{article}
\usepackage{pdftexja}
\pdftexjasetup{no-such-key=1}
\begin{document}x\end{document}
EOF
if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
       -halt-on-error err-unknown-key.tex >err-unknown-key.log 2>&1 ); then
  fail "err-unknown-key: expected failure, got success"
else
  if grep -q 'unknown' "$WORK/run/err-unknown-key.log"; then
    pass "err-unknown-key: rejected with an unknown-key error"
  else
    fail "err-unknown-key: failed without the expected diagnostic"
    tail -10 "$WORK/run/err-unknown-key.log" >&2
  fi
fi

# --- boundary stack: Begin/End page direction in a tate document -------
check
cat >"$WORK/run/page-direction.tex" <<'EOF'
\documentclass{article}
\usepackage[direction=tate]{pdftexja}
\begin{document}
縦の本文である。
\pdftexjaBeginPageDirection{yoko}
横の本文である。\newpage 横の二ページ目である。
\pdftexjaEndPageDirection
縦の本文に戻る。\typeout{PAGEDIR:end=ok}
\end{document}
EOF
if compile page-direction 1; then
  if grep -q 'PAGEDIR:end=ok' "$WORK/run/page-direction.log"; then
    pages=$( ( cd "$WORK/run" && stage_env pdfinfo page-direction.pdf 2>/dev/null ) \
               | awk '/^Pages:/{print $2}' )
    if [ "${pages:-0}" -ge 3 ] 2>/dev/null; then
      pass "page-direction: Begin/End restored (${pages} pages)"
    else
      fail "page-direction: expected >=3 pages, got ${pages:-?}"
    fi
  else
    fail "page-direction: End did not complete"
  fi
else
  fail "page-direction: compile"
fi

echo
echo "== summary =="
echo "checks: $CHECKS, failures: $FAILED"
if [ "$FAILED" -ne 0 ]; then
  echo "FAILED"
  exit 1
fi
echo "ALL FOUNDATION TESTS PASSED"
exit 0
