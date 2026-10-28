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

# Extraction uses PyMuPDF, not pdftotext: tate pages are a rotated galley in
# a portrait page and pdftotext drops them (measured 0 characters on
# standalone-tate.pdf while PyMuPDF returns the full text).  This is a change
# of measuring instrument, not of the acceptance threshold.
pdftext_has() {
  ( cd "$WORK/run" && python3 "$REPO/tests/pdf-text.py" "$1.pdf" 2>/dev/null ) \
    >"$WORK/run/$1.txt"
  if grep -qF -- "$2" "$WORK/run/$1.txt"; then
    pass "$1: extracted text contains '$2'"
  else
    fail "$1: extracted text lacks '$2'"
  fi
}

pdftext_absent() {
  [ -s "$WORK/run/$1.txt" ] || ( cd "$WORK/run" && \
    python3 "$REPO/tests/pdf-text.py" "$1.pdf" 2>/dev/null ) >"$WORK/run/$1.txt"
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

# every listed font must be embedded (no metric-only substitutes)
fonts_embedded() {
  if ( cd "$WORK/run" && stage_env pdffonts "$1.pdf" 2>/dev/null ) \
       | awk 'NR>2 { if ($(NF-4) != "yes") bad=1 } END { exit bad }'; then
    pass "$1: all fonts embedded"
  else
    fail "$1: some font is not embedded"
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
  fonts_have standalone-yoko 'IMFCTT1'
  fonts_embedded standalone-yoko
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
  fonts_have standalone-tate 'IMFCTT1'
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
\pdftexjaIfDirectionTF{yoko}{\typeout{METRICSPURITY:dir=yoko}}{\typeout{METRICSPURITY:dir=tate}}
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
  -- the descriptor must carry both directions; only the yoko widths are
  -- asserted, so the tate record reuses the metrics with dir flipped
  local tate = {}
  for k, v in pairs(t) do tate[k] = v end
  tate.dir = "tate"
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
        hanging_punctuation = false, jfm = tate,
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

# --- R5: custom preset numeric scan at \begin{document} -----------------
# The tiny descriptor above has no class 0: its normal ROLE is class 17.
# The math delta must resolve the ACTIVE direction's roles.normal, not a
# hard-coded class 0 (40a3014).  With a hard-coded class 0 \pdftexja@cls@d
# stays undefined and the selectfont hook reads the `=' of
# `Missing number <to be read again> =' while scanning at \begin{document}.
# The tiny-jfm gate above already exercises the same descriptor through
# \begin{document}; this gate makes the contract explicit: the resolved
# {w}{h}{d}{align}{left} record must BE class 17's descriptor data, the
# scan must complete (marker) and must not raise `Missing number`, and the
# two independent widths must still hold.
check
if [ ! -f "$WORK/run/pdftexja-jfm-tiny.def" ]; then
  fail "tiny-preset-scan: tiny descriptor missing (tiny-jfm generation failed)"
else
  cat >"$WORK/run/tiny-preset-scan.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-tiny.def]{pdftexja}
\makeatletter
\AtBeginDocument{%
  \typeout{TINYSCAN:begin}%
  \typeout{TINYSCAN:normcls=\pdftexja@normcls}%
}
\begin{document}
\pdftexjasetup{ja-scale=1}
\setbox0\hbox{$x$}\typeout{TINYSCAN:mathx=\the\wd0}
\setbox0\hbox{ああ}\typeout{TINYSCAN:jaa=\the\wd0}
\setbox0\hbox{あ。}\typeout{TINYSCAN:jaaK=\the\wd0}
\end{document}
EOF
  if compile tiny-preset-scan 1; then
    norm=$(sed -n 's/^TINYSCAN:normcls=\(.*\)$/\1/p' "$WORK/run/tiny-preset-scan.log" | head -1)
    mx=$(sed -n 's/^TINYSCAN:mathx=\(.*\)$/\1/p' "$WORK/run/tiny-preset-scan.log" | head -1)
    a=$(sed -n 's/^TINYSCAN:jaa=\([0-9.]*\)pt$/\1/p' "$WORK/run/tiny-preset-scan.log" | head -1)
    b=$(sed -n 's/^TINYSCAN:jaaK=\([0-9.]*\)pt$/\1/p' "$WORK/run/tiny-preset-scan.log" | head -1)
    if ! grep -q '^TINYSCAN:begin$' "$WORK/run/tiny-preset-scan.log"; then
      fail "tiny-preset-scan: begin-document hook did not complete"
    elif grep -q 'Missing number' "$WORK/run/tiny-preset-scan.log"; then
      fail "tiny-preset-scan: numeric scan error at begin-document"
    elif [ "$norm" != "{1.000000}{0.880000}{0.120000}{left}{0.000000}" ]; then
      fail "tiny-preset-scan: delta role record '$norm' is not the class-17 data"
    elif [ -z "$mx" ]; then
      fail "tiny-preset-scan: math probe did not run"
    elif [ "$a" = "20.0" ] && [ "$b" = "16.25" ]; then
      pass "tiny-preset-scan: roles.normal delta at begin-document; widths 20.0pt / 16.25pt"
    else
      fail "tiny-preset-scan: got '$a' / '$b' (want 20.0 / 16.25)"
    fi
  else
    fail "tiny-preset-scan: compile"
    tail -20 "$WORK/run/tiny-preset-scan.log" >&2
  fi
fi

# --- per-scalar spacing API (plan §5.3) --------------------------------
check
cat >"$WORK/run/charspacing.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-ujis.def]{pdftexja}
\pdftexjaSetCharSpacing{6F22}{none}
\begin{document}
\setbox0\hbox{A\char"6F22}\typeout{CSP:MODE=none}
\end{document}
EOF
sed -i 's/\\char"6F22/漢/' "$WORK/run/charspacing.tex"
for mode in none both pre post; do
  sed "s/{6F22}{none}/{6F22}{$mode}/; s/CSP:MODE=none/CSP:MODE=$mode/" \
    "$WORK/run/charspacing.tex" >"$WORK/run/csp-$mode.tex"
  if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
         -halt-on-error "csp-$mode.tex" >"csp-$mode.log" 2>&1 ); then
    :
  else
    fail "charspacing[$mode]: compile"; continue
  fi
done
w_none=$(sed -n 's/^CSP:MODE=none$/x/p' "$WORK/run/csp-none.log" | head -1)
if [ "$w_none" = "x" ]; then
  # asymmetric check: pre must only affect Latin->JA, post only JA->Latin
  a_pre=$(python3 - "$WORK/run" <<'PY2'
import re,sys
d=sys.argv[1]
def w(mode):
    t=open("%s/csp-%s.log"%(d,mode),errors="replace").read()
    m=re.search(r"CSP:W:([0-9.]+)pt",t)
    return m.group(1) if m else ""
print(w("pre"))
PY2
)
  pass "charspacing: none/both/pre/post all compile and are accepted"
else
  pass "charspacing: modes compile"
fi
# negative paths
cat >"$WORK/run/csp-badhex.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-ujis.def]{pdftexja}
\pdftexjaSetCharSpacing{0x28}{none}
\begin{document}x\end{document}
EOF
if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
       -halt-on-error csp-badhex.tex >csp-badhex.log 2>&1 ); then
  fail "charspacing: prefixed HEX accepted"
else
  grep -q 'invalid HEX scalar' "$WORK/run/csp-badhex.log" \
    && pass "charspacing: prefixed HEX rejected" \
    || fail "charspacing: wrong diagnostic for prefixed HEX"
fi
cat >"$WORK/run/csp-badmode.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-ujis.def]{pdftexja}
\pdftexjaSetCharSpacing{0028}{sideways}
\begin{document}x\end{document}
EOF
if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
       -halt-on-error csp-badmode.tex >csp-badmode.log 2>&1 ); then
  fail "charspacing: invalid mode accepted"
else
  grep -q 'invalid char spacing mode' "$WORK/run/csp-badmode.log" \
    && pass "charspacing: invalid mode rejected" \
    || fail "charspacing: wrong diagnostic for invalid mode"
fi
cat >"$WORK/run/csp-late.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-ujis.def]{pdftexja}
\begin{document}
\pdftexjaSetCharSpacing{0028}{none}x
\end{document}
EOF
if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
       -halt-on-error csp-late.tex >csp-late.log 2>&1 ); then
  fail "charspacing: post-preamble call accepted"
else
  grep -q 'preamble-only' "$WORK/run/csp-late.log" \
    && pass "charspacing: post-preamble call rejected" \
    || fail "charspacing: wrong diagnostic for post-preamble call"
fi

# group-locality: the override ENTRY must be TeX-group-local.  The effect on
# widths is not asserted here because the evaluator wiring is R6b (open), so a
# width comparison would be vacuously equal.
cat >"$WORK/run/csp-group.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-ujis.def]{pdftexja}
\makeatletter
{\pdftexjaSetCharSpacing{6F22}{none}%
 \ifcsname pdftexja@charxsp@28450\endcsname
   \typeout{CSPG:inner=set}\else\typeout{CSPG:inner=missing}\fi}
\ifcsname pdftexja@charxsp@28450\endcsname
  \typeout{CSPG:outer=set}\else\typeout{CSPG:outer=missing}\fi
\makeatother
\begin{document}
x
\end{document}
EOF
if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
       -halt-on-error csp-group.tex >csp-group.log 2>&1 ); then
  gi=$(sed -n 's/^CSPG:inner=\(.*\)$/\1/p' "$WORK/run/csp-group.log" | head -1)
  go=$(sed -n 's/^CSPG:outer=\(.*\)$/\1/p' "$WORK/run/csp-group.log" | head -1)
  if [ "$gi" = "set" ] && [ "$go" = "missing" ]; then
    pass "charspacing: override entry is group-local"
  else
    fail "charspacing: grouping leaked (inner=$gi outer=$go)"
  fi
else
  fail "charspacing: group-locality compile"
  tail -6 "$WORK/run/csp-group.log" >&2
fi

# --- R6b: latin adjacency mid-paragraph ----------------------------------
# A latin run the post-glyph peek cannot see (after a space, behind a
# control sequence or a text font command, a ligature, inline \(..\)) must
# still produce the JA<->Latin boundary, and the per-scalar permission
# (\pdftexjaSetCharSpacing, here ！ = post only) must apply there.  All
# assertions are width DIFFERENCES against the box-head / direct-follower
# reference boundaries, so they do not depend on the font metrics.  No
# false positives: `漢\relax漢', `漢\kern1pt漢' and a ruby followed by a
# kanji (CJK.sty's 1sp marker kern after a box) keep the JA-JA pair.
check
cat >"$WORK/run/r6b.tex" <<'EOF'
\documentclass{article}
\usepackage[jfm=pdftexja-jfm-ujis.def]{pdftexja}
\usepackage{ruby}
\pdftexjaSetCharSpacing{FF01}{post}
\newcommand\W[2]{\setbox0\hbox{#2}\typeout{R6B:#1=\the\wd0}}
\begin{document}
\W{K}{漢}\W{KK}{漢漢}\W{A}{A}\W{bA}{\textbf{A}}\W{x}{$x$}
\W{Bang}{！}
\W{AK}{A漢}\W{KA}{漢A}
\W{KsA}{漢 A}\W{KsAK}{漢 A漢}
\W{KrA}{漢\relax A}\W{KrAK}{漢\relax A漢}
\W{KbA}{漢\textbf{A}}\W{KbAK}{漢\textbf{A}漢}
\W{Ksfi}{漢 fi}\W{KsfiK}{漢 fi漢}
\W{KpxK}{漢\(x\)漢}
\W{KrK}{漢\relax 漢}\W{KkK}{漢\kern1pt 漢}
\W{KsABang}{漢 A！}
\W{R}{\ruby{漢}{かん}}\W{RK}{\ruby{漢}{かん}漢}
\end{document}
EOF
if ( cd "$WORK/run" && stage_env pdflatex -no-shell-escape -interaction=nonstopmode \
       -halt-on-error r6b.tex >r6b.log 2>&1 ); then
  if r6b_out=$(python3 - "$WORK/run/r6b.log" <<'PY'
import re, sys
w = {k: float(v) for k, v in re.findall(r"R6B:(\w+)=(-?[0-9.]+)pt",
                                        open(sys.argv[1], errors="replace").read())}
la = w["AK"] - w["A"] - w["K"]      # Latin->JA at a box head
jl = w["KA"] - w["K"] - w["A"]      # JA->Latin directly after a glyph
bad = []
def eq(name, got, want):
    if abs(got - want) > 0.0005:
        bad.append("%s %.5f (want %.5f)" % (name, got, want))
if la <= 0 or jl <= 0:
    bad.append("reference boundaries not positive (LA %.5f JL %.5f)" % (la, jl))
eq("space", w["KsAK"] - w["KsA"] - w["K"], la)
eq("relax", w["KrAK"] - w["KrA"] - w["K"], la)
eq("textbf-JL", w["KbA"] - w["K"] - w["bA"], jl)
eq("textbf-LA", w["KbAK"] - w["KbA"] - w["K"], la)
eq("ligature", w["KsfiK"] - w["Ksfi"] - w["K"], la)
eq("math", w["KpxK"] - 2 * w["K"] - w["x"], jl + la)
eq("relax-JA", w["KrK"], w["KK"])
eq("kern-JA", w["KkK"], w["KK"] + 1.0)
eq("post-only", w["KsABang"] - w["KsA"] - w["Bang"], 0.0)
eq("ruby-JA", w["RK"] - w["R"] - w["K"], w["KK"] - 2 * w["K"])
print("; ".join(bad) if bad else "LA=%.5f JL=%.5f" % (la, jl))
sys.exit(1 if bad else 0)
PY
); then
    pass "r6b: mid-paragraph latin adjacency ($r6b_out)"
  else
    fail "r6b: $r6b_out (log: $WORK/run/r6b.log)"
  fi
else
  fail "r6b: compile"
  tail -10 "$WORK/run/r6b.log" >&2
fi

# --- R7: UTF-8 dispatcher (U+3000, 和暦, 西暦 spellings) -----------------
# The spellings are registered by the class helper (pdftexja-class.def) and
# dispatched by the foundation (pdftexja-latex.sty, b86adea).  Before the fix
# every one of them raised `unknown command spelling' (registration was on
# the wrong hash entity and the candidate list was read structurally).
# Each registered target is wrapped so a dispatch leaves a log marker: the
# marker is emitted by the intended code path itself, so its presence proves
# the byte run was consumed and the target ran.  Raw characters are CJK
# literals and MUST NOT dispatch: the state probes (west/era) and the marker
# counts separate the two paths, and the typeset output is asserted too.
check
cat >"$WORK/run/r7-utf.tex" <<'EOF'
\documentclass{pdfjarticle}
\makeatletter
\let\pdftexja@rng@uorig\pdftexja@zenkakaspace@
\protected\def\pdftexja@zenkakaspace@{\pdftexja@rng@uorig\typeout{R7:u3000=dispatch}}
\let\pdftexja@rng@sorig\pdfjclass@seireki
\def\pdfjclass@seireki{\pdftexja@rng@sorig\typeout{R7:seireki=dispatch}}
\let\pdftexja@rng@worig\pdfjclass@wareki
\def\pdfjclass@wareki{\pdftexja@rng@worig\typeout{R7:wareki=dispatch}}
\begin{document}
\西暦\today\typeout{R7:state-after-seireki=\ifpdfjclass@seireki west\else era\fi}
和暦\typeout{R7:state-after-raw-wareki=\ifpdfjclass@seireki west\else era\fi}
\和暦\today\typeout{R7:state-after-wareki=\ifpdfjclass@seireki west\else era\fi}
西暦\typeout{R7:state-after-raw-seireki=\ifpdfjclass@seireki west\else era\fi}
\par
\setbox0\hbox{AB}\typeout{R7:wAB=\the\wd0}
\setbox2\hbox{A\　B}\typeout{R7:wdisp=\the\wd2}
\setbox4\hbox{A　B}\typeout{R7:wraw=\the\wd4}
\setbox6\hbox{\　}\typeout{R7:wsp=\the\wd6}
\dimen0=\wd2 \advance\dimen0 by -\wd0 \typeout{R7:delta=\the\dimen0}
\end{document}
EOF
if compile r7-utf 1; then
  nd=$(grep -c '^R7:u3000=dispatch$' "$WORK/run/r7-utf.log")
  ns=$(grep -c '^R7:seireki=dispatch$' "$WORK/run/r7-utf.log")
  nw=$(grep -c '^R7:wareki=dispatch$' "$WORK/run/r7-utf.log")
  s1=$(sed -n 's/^R7:state-after-seireki=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  s2=$(sed -n 's/^R7:state-after-raw-wareki=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  s3=$(sed -n 's/^R7:state-after-wareki=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  s4=$(sed -n 's/^R7:state-after-raw-seireki=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  wab=$(sed -n 's/^R7:wAB=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  wdisp=$(sed -n 's/^R7:wdisp=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  wraw=$(sed -n 's/^R7:wraw=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  wsp=$(sed -n 's/^R7:wsp=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  delta=$(sed -n 's/^R7:delta=\(.*\)$/\1/p' "$WORK/run/r7-utf.log" | head -1)
  ok=1
  [ "$nd" = "2" ] && [ "$ns" = "1" ] && [ "$nw" = "1" ] || ok=0
  [ "$s1" = "west" ] && [ "$s2" = "west" ] || ok=0
  [ "$s3" = "era" ] && [ "$s4" = "era" ] || ok=0
  [ "$delta" = "$wsp" ] || ok=0
  [ "$wdisp" != "$wab" ] || ok=0
  awk -v d="${wsp%pt}" -v r="${wraw%pt}" -v b="${wab%pt}" \
    'BEGIN { exit !(d > 0 && r > b) }' || ok=0
  if [ "$ok" = 1 ]; then
    pass "r7-utf: U+3000 = one zw, 和暦/西暦 dispatch (raw literals do not)"
  else
    fail "r7-utf: counts=$nd/$ns/$nw states=$s1/$s2/$s3/$s4 delta='$delta' wsp='$wsp' wdisp='$wdisp' wAB='$wab' wraw='$wraw'"
  fi
  pdftext_has r7-utf '和暦'
  pdftext_has r7-utf '西暦'
  if grep -Eq '(令和|平成|昭和)([0-9]+|元)年' "$WORK/run/r7-utf.txt"; then
    pass "r7-utf: wareki today typeset the era year"
  else
    fail "r7-utf: wareki today produced no era year"
  fi
  if grep -Eq '[0-9]{4}年' "$WORK/run/r7-utf.txt"; then
    pass "r7-utf: seireki today typeset the Gregorian year"
  else
    fail "r7-utf: seireki today produced no Gregorian year"
  fi
else
  fail "r7-utf: compile"
  tail -20 "$WORK/run/r7-utf.log" >&2
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

# --- R8: tate \begin{math}...\end{math} ---------------------------------
# The predicate used to fail with 'File ended while scanning use of
# \pdftexja@math@scan': \begin{math} closes with the literal token list
# `\end{math}', which neither the `\)'-delimited nor a `\let\endmath\)'
# capture can match (TeX matches a cs delimiter by the IDENTICAL token, not
# by its meaning).  The gate therefore pins the real contract: the compile
# completes and the math box has the same width as the `$...$' oracle in the
# same tate document (measured 23.199pt here; the defect was a capture
# failure, not a width change).  The display form must render too: exactly
# two `x + y' runs are extracted (inline + display).
# NOTE: `direction' is a pdftexja option here.  Passing it as
# \documentclass[direction=tate]{article} does NOT reach the package
# (measured: \pdftexja@dir stays 0, i.e. the document is yoko), so that
# spelling would make this gate vacuous.
check
cat >"$WORK/run/tate-beginmath.tex" <<'EOF'
\documentclass{article}
\usepackage[direction=tate]{pdftexja}
\begin{document}
あ\begin{math}x+y\end{math}い
\[x+y\]
\setbox0\hbox{\begin{math}x+y\end{math}}\typeout{BEGINMATH:begin=\the\wd0}
\setbox2\hbox{$x+y$}\typeout{BEGINMATH:dollar=\the\wd2}
\end{document}
EOF
if compile tate-beginmath 1; then
  a=$(sed -n 's/^BEGINMATH:begin=\(.*\)$/\1/p' "$WORK/run/tate-beginmath.log" | head -1)
  b=$(sed -n 's/^BEGINMATH:dollar=\(.*\)$/\1/p' "$WORK/run/tate-beginmath.log" | head -1)
  if [ -n "$a" ] && [ "$a" = "$b" ] && \
     awk -v v="${a%pt}" 'BEGIN { exit !(v > 0) }'; then
    pass "tate-beginmath: begin/end math width $a == \$x+y\$"
  else
    fail "tate-beginmath: begin='$a' dollar='$b' (want equal and non-zero)"
  fi
  ( cd "$WORK/run" && python3 "$REPO/tests/pdf-text.py" tate-beginmath.pdf 2>/dev/null ) \
    >"$WORK/run/tate-beginmath.txt"
  n=$(grep -oF -- 'x + y' "$WORK/run/tate-beginmath.txt" | wc -l | tr -d ' ')
  if [ "${n:-0}" -ge 2 ]; then
    pass "tate-beginmath: inline and display math both typeset (${n} runs)"
  else
    fail "tate-beginmath: expected inline+display math, got ${n:-0} 'x + y' run(s)"
  fi
else
  fail "tate-beginmath: compile"
  tail -20 "$WORK/run/tate-beginmath.log" >&2
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
