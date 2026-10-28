# pdftexja --- pdfLaTeX direct-PDF Japanese typesetting foundation
#
# Ownership split (plan §9):
#   classes : docstrip generation of the 12 bundled classes + 12 .clo files
#   jfm     : 5 built-in JFM presets (payloads, runtime indexes, manifests)
#   fonts   : aux vertical fonts, profiles, schema2 metrics, sidecars
#   check-* : deterministic regeneration + structural checks
#   install/tds/uninstall : TDS placement, each owning only its own paths
#
# NOTE: never name a variable TEXMF here: kpathsea's TEXMF tree list is
# polluted by GNU make 4.4+ command-line export (same reason as jlreq).

PDFTEXJA_TEXMF ?= $(shell kpsewhich -var-value=TEXMFHOME)
TEXMF_DEFAULT := $(shell kpsewhich -var-value=TEXMFHOME)

TEXLUA ?= texlua
PYTHON ?= python3
TEX    ?= tex

SCRIPTS := scripts
TEXDIR  := tex
DATADIR := data
FONTDIR := fonts/pdftexja

# ---------------------------------------------------------------------------
# JFM presets
# ---------------------------------------------------------------------------
JFM_PRESETS := standard ujis min jis ptexmin
# Variant tokens per preset: standard has the 6 bracket/hanging variants,
# the class presets only "base".
JFM_VARIANTS_standard := base b z bz n bn
JFM_VARIANTS_ujis     := base
JFM_VARIANTS_min      := base
JFM_VARIANTS_jis      := base
JFM_VARIANTS_ptexmin  := base

# Variant ids are used verbatim in the payload file name (plan §5):
# base,b,z,bz,n,bn -> pdftexja-jfm-<preset>-<dir>-<variant>.def
JFM_DEFS := $(foreach p,$(JFM_PRESETS),$(TEXDIR)/pdftexja-jfm-$(p).def) \
  $(foreach p,$(JFM_PRESETS),$(foreach v,$(JFM_VARIANTS_$(p)), \
    $(TEXDIR)/pdftexja-jfm-$(p)-yoko-$(v).def \
    $(TEXDIR)/pdftexja-jfm-$(p)-tate-$(v).def))
JFM_MANIFESTS := $(foreach p,$(JFM_PRESETS), \
  $(TEXDIR)/pdftexja-jfm-$(p)-manifest.lua $(TEXDIR)/pdftexja-jfm-$(p)-assets.mk)

# ---------------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------------
FONT_PROFILES := pdftexja-fonts-ipaex.def pdftexja-fonts-ipa.def \
                 pdftexja-fonts-haranoaji.def
# asset list from the generator's manifest mode (single source, and works on
# a fresh checkout where no generated file exists yet).
FONT_ASSETS := $(filter-out $(FONT_PROFILES),$(shell $(PYTHON) $(SCRIPTS)/pdftexja-fonts.py --print-manifest 2>/dev/null))

# ---------------------------------------------------------------------------
# Classes (docstrip)
# ---------------------------------------------------------------------------
PDFJ_CLASSES := $(TEXDIR)/pdfjarticle.cls $(TEXDIR)/pdfjreport.cls \
  $(TEXDIR)/pdfjbook.cls $(TEXDIR)/pdfjtarticle.cls \
  $(TEXDIR)/pdfjtreport.cls $(TEXDIR)/pdfjtbook.cls
PDFJ_CLOS := $(TEXDIR)/pdfjsize10.clo $(TEXDIR)/pdfjsize11.clo \
  $(TEXDIR)/pdfjsize12.clo $(TEXDIR)/pdfjbk10.clo $(TEXDIR)/pdfjbk11.clo \
  $(TEXDIR)/pdfjbk12.clo $(TEXDIR)/pdfjtsize10.clo $(TEXDIR)/pdfjtsize11.clo \
  $(TEXDIR)/pdfjtsize12.clo $(TEXDIR)/pdfjtbk10.clo $(TEXDIR)/pdfjtbk11.clo \
  $(TEXDIR)/pdfjtbk12.clo
PDFJS_CLASSES := $(TEXDIR)/pdfjsarticle.cls $(TEXDIR)/pdfjsbook.cls \
  $(TEXDIR)/pdfjsreport.cls $(TEXDIR)/pdfjspf.cls $(TEXDIR)/pdfjskiyou.cls
PDFJLTXDOC_CLASSES := $(TEXDIR)/pdfjltxdoc.cls

CLASS_HELPERS := $(TEXDIR)/pdftexja-class.def $(TEXDIR)/pdftexja-class-crop.def

RUNTIME_STYS := $(TEXDIR)/pdftexja.sty $(TEXDIR)/pdftexja-fonts.sty \
  $(TEXDIR)/pdftexja-rules.sty $(TEXDIR)/pdftexja-direction.sty \
  $(TEXDIR)/pdftexja-paper.sty $(TEXDIR)/pdftexja-math.sty \
  $(TEXDIR)/pdftexja-latex.sty $(TEXDIR)/pdftexja-inline.sty \
  $(TEXDIR)/pdftexja-ruby.sty $(TEXDIR)/pdftexja-paragraph.sty

DOCS := README.md LICENSE

.PHONY: all classes jfm fonts check-jfm check-fonts check install tds \
        uninstall clean distclean

all: classes jfm fonts

# ---------------------------------------------------------------------------
# classes: one grouped recipe per .ins (all outputs of one family are owned
# by a single recipe, so -jN cannot interleave two docstrip runs into tex/).
# docstrip runs in a scratch cwd with source/ on TEXINPUTS, then the produced
# files are moved into tex/ (the repository-relative build location).
# ---------------------------------------------------------------------------
classes: $(PDFJ_CLASSES) $(PDFJ_CLOS) $(PDFJS_CLASSES) $(PDFJLTXDOC_CLASSES)

$(PDFJ_CLASSES) $(PDFJ_CLOS) &: source/pdfjclasses.dtx source/pdfjclasses.ins
	@tmp=`mktemp -d "$${TMPDIR:-/tmp}/pdftexja-ds.XXXXXXXX"` || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	cd "$$tmp" || exit 1; \
	TEXINPUTS="$(CURDIR)/source:" $(TEX) -interaction=nonstopmode \
	  -halt-on-error "$(CURDIR)/source/pdfjclasses.ins" >docstrip.log 2>&1 \
	  || { cat docstrip.log; exit 1; }; \
	for f in $(notdir $(PDFJ_CLASSES) $(PDFJ_CLOS)); do \
	  test -f "$$tmp/$$f" || { echo "classes: missing $$f" >&2; exit 1; }; \
	  cp "$$tmp/$$f" "$(CURDIR)/$(TEXDIR)/"; \
	done

$(PDFJS_CLASSES) &: source/pdfjsclasses.dtx source/pdfjsclasses.ins
	@tmp=`mktemp -d "$${TMPDIR:-/tmp}/pdftexja-ds.XXXXXXXX"` || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	cd "$$tmp" || exit 1; \
	TEXINPUTS="$(CURDIR)/source:" $(TEX) -interaction=nonstopmode \
	  -halt-on-error "$(CURDIR)/source/pdfjsclasses.ins" >docstrip.log 2>&1 \
	  || { cat docstrip.log; exit 1; }; \
	for f in $(notdir $(PDFJS_CLASSES)); do \
	  test -f "$$tmp/$$f" || { echo "classes: missing $$f" >&2; exit 1; }; \
	  cp "$$tmp/$$f" "$(CURDIR)/$(TEXDIR)/"; \
	done

$(PDFJLTXDOC_CLASSES) &: source/pdfjltxdoc.dtx source/pdfjltxdoc.ins
	@tmp=`mktemp -d "$${TMPDIR:-/tmp}/pdftexja-ds.XXXXXXXX"` || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	cd "$$tmp" || exit 1; \
	TEXINPUTS="$(CURDIR)/source:" $(TEX) -interaction=nonstopmode \
	  -halt-on-error "$(CURDIR)/source/pdfjltxdoc.ins" >docstrip.log 2>&1 \
	  || { cat docstrip.log; exit 1; }; \
	for f in $(notdir $(PDFJLTXDOC_CLASSES)); do \
	  test -f "$$tmp/$$f" || { echo "classes: missing $$f" >&2; exit 1; }; \
	  cp "$$tmp/$$f" "$(CURDIR)/$(TEXDIR)/"; \
	done

# ---------------------------------------------------------------------------
# jfm: per-preset generation. One grouped recipe per preset owns its payload
# set + index + manifests (so -jN cannot interleave two writers).
# Outputs are committed (plan §5.1); check-jfm proves regeneration equality.
# ---------------------------------------------------------------------------
jfm: $(JFM_DEFS) $(JFM_MANIFESTS)

JFM_STANDARD_PAYLOADS := $(foreach v,$(JFM_VARIANTS_standard), \
  $(TEXDIR)/pdftexja-jfm-standard-yoko-$(v).def \
  $(TEXDIR)/pdftexja-jfm-standard-tate-$(v).def)

$(TEXDIR)/pdftexja-jfm-standard.def $(JFM_STANDARD_PAYLOADS) \
$(TEXDIR)/pdftexja-jfm-standard-manifest.lua \
$(TEXDIR)/pdftexja-jfm-standard-assets.mk &: \
    $(DATADIR)/pdftexja-jfm-standard.lua $(DATADIR)/jfm-standard-yoko.lua \
    $(DATADIR)/jfm-standard-tate.lua $(SCRIPTS)/pdftexja-jfm-lib.lua \
    $(SCRIPTS)/pdftexja-jfm.lua
	$(TEXLUA) $(SCRIPTS)/pdftexja-jfm.lua \
	  --input $(DATADIR)/pdftexja-jfm-standard.lua --outdir $(TEXDIR) \
	  --manifest $(TEXDIR)/pdftexja-jfm-standard-manifest.lua \
	  --assets $(TEXDIR)/pdftexja-jfm-standard-assets.mk

define jfm_preset_rule
$(TEXDIR)/pdftexja-jfm-$(1).def \
$(TEXDIR)/pdftexja-jfm-$(1)-yoko-base.def \
$(TEXDIR)/pdftexja-jfm-$(1)-tate-base.def \
$(TEXDIR)/pdftexja-jfm-$(1)-manifest.lua \
$(TEXDIR)/pdftexja-jfm-$(1)-assets.mk &: \
    $$(DATADIR)/pdftexja-jfm-$(1).lua $$(SCRIPTS)/pdftexja-jfm-lib.lua \
    $$(SCRIPTS)/pdftexja-jfm.lua
	$$(TEXLUA) $$(SCRIPTS)/pdftexja-jfm.lua \
	  --input $$(DATADIR)/pdftexja-jfm-$(1).lua --outdir $$(TEXDIR) \
	  --manifest $$(TEXDIR)/pdftexja-jfm-$(1)-manifest.lua \
	  --assets $$(TEXDIR)/pdftexja-jfm-$(1)-assets.mk
endef
$(foreach p,$(filter-out standard,$(JFM_PRESETS)),$(eval $(call jfm_preset_rule,$(p))))

# ---------------------------------------------------------------------------
# fonts: build into fonts/pdftexja/, then place the tracked profiles in tex/.
# ---------------------------------------------------------------------------
fonts: $(addprefix $(FONTDIR)/,$(FONT_PROFILES) $(FONT_ASSETS))

$(addprefix $(FONTDIR)/,$(FONT_PROFILES) $(FONT_ASSETS)) &: \
    $(SCRIPTS)/pdftexja-fonts.py
	@$(PYTHON) $(SCRIPTS)/pdftexja-fonts.py --fontset all \
	  --outdir $(FONTDIR) --manifest $(FONTDIR)/pdftexja-font-assets.mk \
	  || exit 1
	@for f in $(FONT_PROFILES); do \
	  test -f "$(FONTDIR)/$$f" || { echo "fonts: missing $$f" >&2; exit 1; }; \
	  cp "$(FONTDIR)/$$f" "$(TEXDIR)/"; \
	done
	@echo "fonts: aux vertical fonts + profiles built into $(FONTDIR)"

# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------
check-jfm:
	@tmp=`mktemp -d "$${TMPDIR:-/tmp}/pdftexja-jfm-check.XXXXXXXX"`; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	rc=0; \
	for p in $(JFM_PRESETS); do \
	  $(TEXLUA) $(SCRIPTS)/pdftexja-jfm.lua \
	    --input $(DATADIR)/pdftexja-jfm-$$p.lua --outdir "$$tmp" \
	    --manifest "$$tmp/pdftexja-jfm-$$p-manifest.lua" \
	    --assets "$$tmp/pdftexja-jfm-$$p-assets.mk" || { rc=1; continue; }; \
	  for f in "$$tmp"/pdftexja-jfm-$$p*.def; do \
	    b=`basename "$$f"`; \
	    cmp -s "$$f" "$(TEXDIR)/$$b" || { \
	      echo "FAIL: check-jfm: regenerated $$b differs" >&2; rc=1; }; \
	  done; \
	  cmp -s "$$tmp/pdftexja-jfm-$$p-assets.mk" \
	         "$(TEXDIR)/pdftexja-jfm-$$p-assets.mk" || { \
	    echo "FAIL: check-jfm: regenerated $$p asset manifest differs" >&2; rc=1; }; \
	  $(TEXLUA) $(SCRIPTS)/pdftexja-check-jfm.lua \
	    --input $(DATADIR)/pdftexja-jfm-$$p.lua --manifest \
	    "$(TEXDIR)/pdftexja-jfm-$$p-manifest.lua" \
	    --assets "$(TEXDIR)/pdftexja-jfm-$$p-assets.mk" || rc=1; \
	done; \
	test $$rc -eq 0 && echo "check-jfm: regeneration diff zero, 5 presets validated"; \
	exit $$rc

check-fonts:
	@tmp=`mktemp -d "$${TMPDIR:-/tmp}/pdftexja-fonts-check.XXXXXXXX"`; \
	trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	cp -r $(FONTDIR) "$$tmp/regen1" || exit 1; \
	$(PYTHON) $(SCRIPTS)/pdftexja-fonts.py --fontset all --outdir "$$tmp/regen1" \
	  --manifest "$$tmp/regen1/pdftexja-font-assets.mk" || exit 1; \
	diff -r "$$tmp/regen1" $(FONTDIR) || { \
	  echo "FAIL: check-fonts: regeneration is not byte-identical" >&2; exit 1; }; \
	$(PYTHON) tests/check-fonts.py $(FONTDIR) $(FONT_PROFILES) || exit 1; \
	echo "check-fonts: deterministic regeneration + structural checks OK"

check: check-jfm check-fonts
	sh tests/run-tests.sh --texmf "$(PDFTEXJA_TEXMF)"

# ---------------------------------------------------------------------------
# install / tds / uninstall
# ---------------------------------------------------------------------------
RUNTIME_TEX_INSTALL := $(RUNTIME_STYS) $(CLASS_HELPERS) \
  $(PDFJ_CLASSES) $(PDFJ_CLOS) $(PDFJS_CLASSES) $(PDFJLTXDOC_CLASSES)
JFM_INSTALL := $(JFM_DEFS) $(JFM_MANIFESTS)
PROFILE_INSTALL := $(addprefix $(TEXDIR)/,$(FONT_PROFILES))

install: classes jfm fonts
	mkdir -p $(PDFTEXJA_TEXMF)/tex/latex/pdftexja
	install $(RUNTIME_TEX_INSTALL) $(JFM_INSTALL) $(PROFILE_INSTALL) \
	  $(PDFTEXJA_TEXMF)/tex/latex/pdftexja
	@# font sidecars live next to the profiles in the installed tex dir
	@for f in $(FONTDIR)/pdftexja-fonts-*-adv.def $(FONTDIR)/pdftexja-fonts-*-cid.def; do \
	  test -e "$$f" && install "$$f" $(PDFTEXJA_TEXMF)/tex/latex/pdftexja || true; \
	done
	mkdir -p $(PDFTEXJA_TEXMF)/fonts/truetype/public/pdftexja
	@for f in $(FONTDIR)/*.ttf; do test -e "$$f" && install "$$f" \
	  $(PDFTEXJA_TEXMF)/fonts/truetype/public/pdftexja || true; done
	mkdir -p $(PDFTEXJA_TEXMF)/fonts/tfm/public/pdftexja
	@for f in $(FONTDIR)/*.tfm; do test -e "$$f" && install "$$f" \
	  $(PDFTEXJA_TEXMF)/fonts/tfm/public/pdftexja || true; done
	mkdir -p $(PDFTEXJA_TEXMF)/fonts/enc/dvips/pdftexja
	@for f in $(FONTDIR)/*.enc; do test -e "$$f" && install "$$f" \
	  $(PDFTEXJA_TEXMF)/fonts/enc/dvips/pdftexja || true; done
	mkdir -p $(PDFTEXJA_TEXMF)/scripts/pdftexja
	install $(SCRIPTS)/pdftexja-jfm-lib.lua $(SCRIPTS)/pdftexja-jfm.lua \
	  $(SCRIPTS)/pdftexja-check-jfm.lua $(SCRIPTS)/pdftexja-fonts.py \
	  $(SCRIPTS)/pdftexja-check-inputs.py \
	  $(PDFTEXJA_TEXMF)/scripts/pdftexja
	mkdir -p $(PDFTEXJA_TEXMF)/doc/latex/pdftexja
	@for f in $(DOCS); do test -e "$$f" && install "$$f" \
	  $(PDFTEXJA_TEXMF)/doc/latex/pdftexja || true; done
	mkdir -p $(PDFTEXJA_TEXMF)/source/latex/pdftexja
	install $(DATADIR)/*.lua source/*.dtx source/*.ins \
	  $(PDFTEXJA_TEXMF)/source/latex/pdftexja

tds: classes jfm fonts
	mkdir -p tds/tex/latex/pdftexja
	cp -f $(RUNTIME_TEX_INSTALL) $(JFM_INSTALL) $(PROFILE_INSTALL) \
	  tds/tex/latex/pdftexja
	@for f in $(FONTDIR)/pdftexja-fonts-*-adv.def $(FONTDIR)/pdftexja-fonts-*-cid.def; do \
	  test -e "$$f" && cp -f "$$f" tds/tex/latex/pdftexja || true; done
	mkdir -p tds/fonts/truetype/public/pdftexja
	@for f in $(FONTDIR)/*.ttf; do test -e "$$f" && cp -f "$$f" \
	  tds/fonts/truetype/public/pdftexja || true; done
	mkdir -p tds/fonts/tfm/public/pdftexja
	@for f in $(FONTDIR)/*.tfm; do test -e "$$f" && cp -f "$$f" \
	  tds/fonts/tfm/public/pdftexja || true; done
	mkdir -p tds/fonts/enc/dvips/pdftexja
	@for f in $(FONTDIR)/*.enc; do test -e "$$f" && cp -f "$$f" \
	  tds/fonts/enc/dvips/pdftexja || true; done
	mkdir -p tds/scripts/pdftexja
	cp -f $(SCRIPTS)/pdftexja-jfm-lib.lua $(SCRIPTS)/pdftexja-jfm.lua \
	  $(SCRIPTS)/pdftexja-check-jfm.lua $(SCRIPTS)/pdftexja-fonts.py \
	  $(SCRIPTS)/pdftexja-check-inputs.py tds/scripts/pdftexja
	mkdir -p tds/doc/latex/pdftexja
	@for f in $(DOCS); do test -e "$$f" && cp -f "$$f" \
	  tds/doc/latex/pdftexja || true; done
	mkdir -p tds/source/latex/pdftexja
	cp -f $(DATADIR)/*.lua source/*.dtx source/*.ins tds/source/latex/pdftexja

# Uninstall only ever removes pdftexja's own directories, and refuses an
# empty or root target (plan §9).
uninstall:
	@case "$(PDFTEXJA_TEXMF)" in \
	  ""|"/"|".") echo "uninstall: refusing unsafe PDFTEXJA_TEXMF='$(PDFTEXJA_TEXMF)'" >&2; exit 1;; \
	esac
	rm -rf "$(PDFTEXJA_TEXMF)/tex/latex/pdftexja"
	rm -rf "$(PDFTEXJA_TEXMF)/fonts/truetype/public/pdftexja"
	rm -rf "$(PDFTEXJA_TEXMF)/fonts/tfm/public/pdftexja"
	rm -rf "$(PDFTEXJA_TEXMF)/fonts/enc/dvips/pdftexja"
	rm -rf "$(PDFTEXJA_TEXMF)/scripts/pdftexja"
	rm -rf "$(PDFTEXJA_TEXMF)/doc/latex/pdftexja"
	rm -rf "$(PDFTEXJA_TEXMF)/source/latex/pdftexja"

clean:
	rm -rf tds
	rm -f $(FONTDIR)/*.ttf $(FONTDIR)/*.tfm $(FONTDIR)/*.enc \
	  $(FONTDIR)/*-adv.def $(FONTDIR)/*-cid.def \
	  $(FONTDIR)/pdftexja-font-assets.mk

distclean: clean
	rm -f $(JFM_DEFS) $(JFM_MANIFESTS) $(PDFJ_CLASSES) $(PDFJ_CLOS) \
	  $(PDFJS_CLASSES) $(PDFJLTXDOC_CLASSES) $(addprefix $(TEXDIR)/,$(FONT_PROFILES))
