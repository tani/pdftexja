#!/usr/bin/env python3
# Copyright 2017-2026, Noriyuki Abe.  All rights reserved.
# Derived from jlreq's make_pdftex_fonts.py, distributed under the 2-clause
# BSD license:
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""pdftexja-fonts.py -- build the pdftexja auxiliary vertical fonts.

Reads the mincho/gothic fonts with fontTools (cmap, GSUB vert/vrt2,
hmtx/vmtx, VORG, exact outline ink bboxes), selects the vertical glyph set,
and emits into --outdir:

  pdftexjav-<fontset>-<fam>-<shard>.ttf   auxiliary TTF: slot 0 = .notdef,
                            slot i = the i-th entry of the sorted vert/vrt2
                            selection, named pdftexjavXXXX (XXXX = source
                            codepoint hex).  Fixed internal dates,
                            deterministic glyph order.
  pdftexjav-<fontset>-<fam>-<shard>.enc   explicit 256-element encoding
                            (PostScript /encname [ ... ] def form).
  pdftexjav-<fontset>-<fam>-<shard>.tfm   built with ttf2tfm.
  pdftexja-fonts-<fontset>.def            profile data consumed by the
                            runtime: per family shard/tfm/enc names, map
                            lines, per-slot ToUnicode hex and per-codepoint
                            em-unit metrics {sub, advance, vorg, ink, shard,
                            slot, uni} (\\pdftexja@vglyph@<DECIMAL>).
  pdftexja-license-<fontset>-<fam>.txt    license/source attribution from
                            the source font's name table.
  pdftexja-haranoaji-{mincho,mincho-bold,gothic,gothic-bold}-ttf.ttf
                            full quadratic TTF conversions for the HaranoAji
                            horizontal chain.

All emitted data are deterministic: fixed head.created/modified, sorted
glyph order, sorted output text, %.6f fixed decimals, no timestamps.

Build-time tool only: normal documents never run this script.

Usage:
  pdftexja-fonts.py --fontset ipaex|ipa|haranoaji|all [--outdir DIR]
      [--manifest FILE] [--print-manifest] [--shard-size N]
  pdftexja-fonts.py --fontset custom --name NAME --mincho FONT --gothic FONT \
      --profile FILE [--outdir DIR] [--manifest FILE]
"""

import argparse
import os
import re
import subprocess
import sys

try:
    from fontTools.ttLib import TTFont, newTable
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.cu2quPen import Cu2QuPen
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.pens.boundsPen import BoundsPen
except ImportError:
    sys.stderr.write("pdftexja-fonts.py: fontTools is required "
                     "(python3 -m pip install fonttools)\n")
    raise SystemExit(1)

GEN_VERSION = "1.0"

# ttf2tfm flags (empirically verified, TeX Live 2025 ttf2tfm 2.0):
#   -N  use only PS names and no cmap (our aux glyphs carry no cmap)
#   -u  output only characters from the encoding (no extra slots)
#   -p ENCFILE  explicit 256-element input encoding
# The option ORDER matters on this build: options must come AFTER the font
# file argument, or the parser counts the option values as non-option
# arguments ("Need at most two non-option arguments").
TTF2TFM_CMD = ["ttf2tfm", "<ttf>", "-N", "-u", "-p", "<enc>", "<base>"]

# Fixed internal date (determinism): 2000-01-01 00:00:00 UTC.
FIXED_DATE = 946684800

# Cu2QuPen max approximation error (font units) for CFF->TrueType outline
# conversion (HaranoAji upem=1000 -> 0.5 = upem/2000).
CFF_TO_QUADRATIC_MAX_ERR = 0.5

# --------------------------------------------------------------- fontsets

FONTSETS = {
    "ipaex": {"mincho": "ipaexm.ttf", "gothic": "ipaexg.ttf"},
    "ipa": {"mincho": "ipam.ttf", "gothic": "ipag.ttf"},
    "haranoaji": {"mincho": "HaranoAjiMincho-Regular.otf",
                  "gothic": "HaranoAjiGothic-Regular.otf"},
}

BUILTIN_NAMES = ("ipaex", "ipa", "haranoaji")

# haranoaji horizontal-chain output names (full quadratic TTF conversions
# consumed by bxcjkjatype's \setminchofont etc.).  mc/mincho regular,
# mcb/mincho bold, gt/gothic, gtb/gothic bold.
HORIZONTAL_TTFS = {
    "mc": "pdftexja-haranoaji-mincho-ttf.ttf",
    "mcb": "pdftexja-haranoaji-mincho-bold-ttf.ttf",
    "gt": "pdftexja-haranoaji-gothic-ttf.ttf",
    "gtb": "pdftexja-haranoaji-gothic-bold-ttf.ttf",
}

# --------------------------------------------------------------- utilities


def kpsewhich(name):
    r = subprocess.run(["kpsewhich", name], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        raise SystemExit("pdftexja-fonts.py: cannot find %s via kpsewhich"
                         % name)
    return r.stdout.strip()


def utf16_hex(cp):
    """Source codepoint -> ToUnicode UTF-16BE hex (surrogate pair non-BMP)."""
    if cp < 0x10000:
        return "%04X" % cp
    cp -= 0x10000
    return "%04X%04X" % (0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF))


def num(v):
    return "%.6f" % v


def glyph_name(cp):
    return "pdftexjav%04X" % cp if cp <= 0xFFFF else "pdftexjav%05X" % cp


def ps_name(fslabel, fam, shard):
    return "PDFTeXjaVert%s%s%02d" % (fslabel, fam, shard)


def aux_base(fslabel, fam, shard):
    return "pdftexjav-%s-%s-%02d" % (fslabel, fam, shard)


# --------------------------------------------------------- font analysis


class GlyphData(object):
    """Per-codepoint vertical metrics in EM units (all /unitsPerEm)."""

    def __init__(self):
        self.name = None          # pdftexjavXXXX
        self.codepoint = None     # source unicode
        self.substituted = False  # vert/vrt2 target used (aux glyph)
        self.target_glyph = None  # source-font glyph object name
        self.advance = 1.0        # vmtx advance / upem
        self.vorigin = None       # vertical origin (em, from baseline)
        self.ink = None           # (x0, y0, x1, y1) em units
        self.hmtx = None          # (advance, lsb) of the drawn glyph
        self.shard = None
        self.slot = None


def read_font(path):
    return TTFont(path)


def gsub_single_subst(font, tag):
    """All SingleSubst mappings of feature `tag` (per-lookup union)."""
    if "GSUB" not in font:
        return {}
    gsub = font["GSUB"].table
    out = {}
    for fr in gsub.FeatureList.FeatureRecord:
        if fr.FeatureTag != tag:
            continue
        for li in fr.Feature.LookupListIndex:
            lookup = gsub.LookupList.Lookup[li]
            for st in lookup.SubTable:
                if getattr(st, "mapping", None):
                    out.update(st.mapping)
                elif hasattr(st, "coverage") and st.coverage is not None:
                    delta = getattr(st, "deltaGlyphID", None)
                    if delta is not None:
                        for g in st.coverage.glyphs:
                            tgt = font.getGlyphID(g) + delta
                            out[g] = font.getGlyphOrder()[tgt]
    return out


def vert_substitutions(font):
    """vrt2 first (higher priority), vert as fallback; merged per source."""
    m = gsub_single_subst(font, "vert")
    m2 = gsub_single_subst(font, "vrt2")
    merged = dict(m)
    merged.update(m2)  # vrt2 wins on conflicts
    return merged


def vorigin_of(font, glyph_name_, upem, bounds):
    """Vertical origin in em units (y of the horizontal baseline plane where
    the vertical advance starts, measured UP from the glyph baseline).

    VORG (OpenType) first; else vmtx: origin = bbox_yMax + tsb (top side
    bearing) as OpenType does.
    """
    vorg = font.get("VORG")
    if vorg is not None:
        try:
            y = vorg.vertOriginY.get(glyph_name_, vorg.defaultVertOriginY)
            return y / float(upem)
        except AttributeError:
            pass
    if "vmtx" in font:
        adv, tsb = font["vmtx"].metrics.get(glyph_name_, (upem, 0))
        if bounds is not None:
            return (bounds[3] + tsb) / float(upem)
        return tsb / float(upem)
    asc = font["hhea"].ascent if "hhea" in font else int(0.88 * upem)
    return asc / float(upem)


def selection_for(font, cmap, vert):
    """Every cmap codepoint that reaches a real vert/vrt2 substitution.

    The plan removes the old JFM placement-class union: aux selection is
    exactly the set of real vertical substitutions reachable from each
    family's own cmap (reverse-cmap aliases included).
    """
    rev = {}
    for cp, gname in cmap.items():
        rev.setdefault(gname, []).append(cp)
    cps = set()
    for gname in vert:
        for cp in rev.get(gname, []):
            cps.add(cp)
    return sorted(cps)


def analyze_font(path):
    """Return (font, cmap, vert, per-cp GlyphData dict, upem)."""
    font = read_font(path)
    upem = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    vert = vert_substitutions(font)
    gs = font.getGlyphSet()
    cps = selection_for(font, cmap, vert)

    data = {}
    for cp in cps:
        g = GlyphData()
        g.codepoint = cp
        g.name = glyph_name(cp)
        src_glyph = cmap[cp]
        tgt = vert.get(src_glyph)
        drawn = tgt if tgt is not None else src_glyph
        g.substituted = tgt is not None
        g.target_glyph = drawn
        bp = BoundsPen(gs)
        gs[drawn].draw(bp)
        g.ink = None if bp.bounds is None else tuple(
            v / float(upem) for v in bp.bounds)
        g.advance = None
        if "vmtx" in font:
            adv, tsb = font["vmtx"].metrics.get(drawn, (upem, 0))
            g.advance = adv / float(upem)
            g.vorigin = vorigin_of(font, drawn, upem, bp.bounds)
        else:
            ha = font["hmtx"].metrics.get(drawn, (upem, 0))
            g.advance = ha[0] / float(upem)
            g.vorigin = None
        ha, lsb = font["hmtx"].metrics.get(drawn, (upem, 0))
        g.hmtx = (ha, lsb)
        data[cp] = g
    return font, cmap, vert, data, upem


def shard_count_for(path, shard_size):
    font = read_font(path)
    cmap = font.getBestCmap()
    vert = vert_substitutions(font)
    n = len(selection_for(font, cmap, vert))
    return (n + shard_size - 1) // shard_size


# ------------------------------------------------------------ aux TTF


def build_aux_font(src_font, gs, sel, out_ttf, upem, fslabel, fam, shard):
    """sel: list of (cp, GlyphData) sorted by cp.  Slots: 0=.notdef,
    i=sel[i-1].  Returns the glyph order used."""
    order = [".notdef"]
    glyphs = {".notdef": TTGlyphPen(gs).glyph()}
    hmtx = {".notdef": (upem, 0)}
    vmtx = {".notdef": (upem, 0)}
    for cp, g in sel:
        pen = TTGlyphPen(gs)
        gs[g.target_glyph].draw(Cu2QuPen(
            pen, max_err=CFF_TO_QUADRATIC_MAX_ERR,
            reverse_direction=True))
        glyphs[g.name] = pen.glyph()
        order.append(g.name)
        adv, lsb = g.hmtx
        hmtx[g.name] = (adv, lsb)
        vadv = int(round(g.advance * upem)) if g.advance else upem
        if g.ink is not None and g.vorigin is not None:
            tsb = int(round((g.vorigin - g.ink[3]) * upem))
        else:
            tsb = 0
        vmtx[g.name] = (vadv, tsb)

    fb = FontBuilder(upem, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(hmtx)
    fb.setupHorizontalHeader(asce=882, des=-162, lineGap=0)
    fb.setupCharacterMap({})
    name = ps_name(fslabel, fam, shard)
    fb.setupNameTable({
        "familyName": name,
        "styleName": "Regular",
        "fullName": name,
        "psName": name,
    })
    fb.setupOS2(sTypoAscender=882, sTypoDescender=-162,
                usWinAscent=882, usWinDescent=162)
    fb.setupVerticalMetrics(vmtx)
    fb.setupVerticalHeader(asce=1802, des=246, lineGap=0)
    fb.setupPost()
    font = fb.font
    font["head"].created = FIXED_DATE
    font["head"].modified = FIXED_DATE
    font["name"].setName("Version 001.000 (pdftexja aux vertical)", 5, 3, 1, 0x409)
    font.save(out_ttf)
    return order


def build_enc(order_sel, shard, enc_name, out_enc):
    """256-element PostScript encoding; slot i = sel[i-1] (i>=1)."""
    lines = ["/%s [" % enc_name]
    lines.append("/.notdef")
    for cp, g in order_sel:
        lines.append("/" + g.name)
    while len(lines) < 257:
        lines.append("/.notdef")
    lines.append("] def")
    with open(out_enc, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def build_tfm(ttf, enc, base, outdir):
    outbase = os.path.join(outdir, base)
    cmd = ["ttf2tfm", os.path.join(outdir, ttf), "-N", "-u",
           "-p", os.path.join(outdir, enc), outbase]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(outbase + ".tfm"):
        sys.stderr.write("pdftexja-fonts.py: ttf2tfm failed (%s):\n%s\n"
                         % (" ".join(cmd), r.stdout + r.stderr))
        raise SystemExit(1)
    return outbase + ".tfm"


# --------------------------------------------------------------- profile


def build_profile(families, profile_path, license_note):
    """families: {'mc': [...], 'gt': [...]} shard entry lists."""
    out = []
    a = out.append
    a("%%%% pdftexja font profile (generated by pdftexja-fonts.py %s)"
      % GEN_VERSION)
    a("%% DO NOT EDIT; regenerate with the class build.")
    a("%% Source license/attribution:")
    for line in license_note.splitlines():
        a("%%   " + line)
    a("\\def\\pdftexja@fontprofile@version{%s}" % GEN_VERSION)
    for fam, entries in sorted(families.items()):
        a("")
        a("%%%% ---- family %s" % fam)
        maplines = []
        tfms = []
        encs = []
        for e in entries:
            tfms.append(e["tfm"])
            encs.append(e["enc"])
            maplines.append(e["mapline"])
        a("\\def\\pdftexja@fontprofile@%s@shards{%d}" % (fam, len(tfms)))
        for i, t in enumerate(tfms):
            a("\\expandafter\\def\\csname pdftexja@fontprofile@%s@tfm@%d\\endcsname{%s}"
              % (fam, i, t))
        for i, e in enumerate(encs):
            a("\\expandafter\\def\\csname pdftexja@fontprofile@%s@enc@%d\\endcsname{%s}"
              % (fam, i, e))
        for ml in maplines:
            a("\\pdfmapline{%s}" % ml)
        # \pdftexja@vglyph@<DECIMAL>{{sub}{adv}{vorg}{ink}{shard}{slot}{uni}}
        # (DECIMAL key: the runtime looks the table up with \number\pdftexja@cp,
        #  same contract as the old jlreq profile)
        for e in entries:
            for cp, g in e["sel"]:
                sub = "1" if g.substituted else "0"
                ink = "{%s}{%s}{%s}{%s}" % (
                    num(g.ink[0]), num(g.ink[1]),
                    num(g.ink[2]), num(g.ink[3])) if g.ink else "{}"
                vo = num(g.vorigin) if g.vorigin is not None else "{}"
                adv = num(g.advance) if g.advance is not None else "{}"
                shard = str(e["shard"])
                slot = str(g.slot)
                uni = utf16_hex(cp)
                a("\\expandafter\\def\\csname pdftexja@vglyph@%d\\endcsname"
                  "{{%s}{%s}{%s}{%s}{%s}{%s}{%s}}"
                  % (cp, sub, adv, vo, ink, shard, slot, uni))
                a("\\pdfglyphtounicode{%s}{%s}" % (g.name, uni))
    a("")
    a("\\pdfgentounicode=1\\relax")
    text = "\n".join(out) + "\n"
    with open(profile_path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return text


# --------------------------------------------------------------- driver


def build_family(fam, fslabel, src_path, outdir, shard_size):
    font, cmap, vert, data, upem = analyze_font(src_path)
    gs = font.getGlyphSet()
    selpairs = sorted(data.items())          # (cp, GlyphData)
    shards = []
    for si in range(0, len(selpairs), shard_size):
        chunk = selpairs[si:si + shard_size]
        shard = len(shards)
        base = aux_base(fslabel, fam, shard)
        ttf = base + ".ttf"
        enc = base + ".enc"
        tfm = base
        order_sel = [(cp, g) for cp, g in chunk]
        for i, (cp, g) in enumerate(order_sel):
            g.slot = i + 1
            g.shard = shard
        build_aux_font(font, gs, order_sel,
                       os.path.join(outdir, ttf), upem, fslabel, fam, shard)
        build_enc(order_sel, shard, ps_name(fslabel, fam, shard),
                  os.path.join(outdir, enc))
        build_tfm(ttf, enc, tfm, outdir)
        shards.append({
            "shard": shard, "ttf": ttf, "enc": enc, "tfm": tfm + ".tfm",
            "sel": order_sel,
            "mapline": "=%s <%s ReEncodeFont <%s" % (tfm, enc, ttf),
        })
    return shards, font, len(selpairs)


def convert_to_ttf(src_path, out_ttf):
    """Full-font CFF (OTF) -> quadratic TrueType conversion for the
    HaranoAji horizontal chain (pdfTeX/TrueType machinery reads glyf)."""
    font = read_font(src_path)
    if "CFF " not in font:
        raise SystemExit("pdftexja-fonts.py: convert_to_ttf: %s has no "
                         "CFF table (it is not an OTF)" % src_path)
    order = font.getGlyphOrder()
    gs = font.getGlyphSet()
    glyphs = {}
    for name in order:
        pen = TTGlyphPen(gs)
        gs[name].draw(Cu2QuPen(
            pen, max_err=CFF_TO_QUADRATIC_MAX_ERR,
            reverse_direction=True))
        glyphs[name] = pen.glyph()
    glyf = newTable("glyf")
    glyf.glyphs = glyphs
    glyf.glyphOrder = order
    loca = newTable("loca")
    loca.locations = [0] * (len(order) + 1)
    del font["CFF "]
    if "VORG" in font:
        del font["VORG"]
    font["glyf"] = glyf
    font["loca"] = loca
    font["maxp"].numGlyphs = len(order)
    font["maxp"].version = 1.0
    font["head"].glyphDataFormat = 0
    font["head"].created = FIXED_DATE
    font["head"].modified = FIXED_DATE
    font.recalcTimestamp = False
    font.save(out_ttf)
    return out_ttf


def license_text_from(font):
    lines = []
    for nid, what in ((0, "copyright"), (13, "license")):
        v = font["name"].getDebugName(nid)
        if v:
            lines.append("%s: %s" % (what, v))
    if not lines:
        lines.append("license: (source font name table has no "
                     "copyright/license entries)")
    return "\n".join(lines)


# --------------------------------------------------------------- manifests


def manifest_fragment(names):
    names = sorted(names)
    lines = ["PDFTEXJA_FONT_ASSETS := \\"]
    for i, n in enumerate(names):
        if i < len(names) - 1:
            lines.append("\t" + n + " \\")
        else:
            lines.append("\t" + n)
    return "\n".join(lines) + "\n"


def write_manifest(path, names):
    if path:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(manifest_fragment(names))


def predicted_baselines(fontset, shard_size, mincho=None, gothic=None,
                        profile=None, name=None):
    """Exact output basenames for --print-manifest (no TTF generation).

    Built-in fonts are resolved through kpsewhich and their vert/vrt2
    selection is analysed, so the shard counts are exact rather than a
    hardcoded over-approximation.
    """
    names = set()
    if fontset == "custom":
        srcs = {"mc": mincho, "gt": gothic}
        fslabel = name or "custom"
        names.add(os.path.basename(profile
                                   or ("pdftexja-fonts-%s.def" % fslabel)))
        for fam, src in srcs.items():
            n = shard_count_for(src, shard_size)
            names.add("pdftexja-license-%s-%s.txt" % (fslabel, fam))
            for shard in range(n):
                base = aux_base(fslabel, fam, shard)
                names.add(base + ".ttf")
                names.add(base + ".enc")
                names.add(base + ".tfm")
        return names
    for fslabel in ([fontset] if fontset in BUILTIN_NAMES else BUILTIN_NAMES):
        names.add("pdftexja-fonts-%s.def" % fslabel)
        for fam in ("mc", "gt"):
            src = kpsewhich(FONTSETS[fslabel]["mincho" if fam == "mc"
                                              else "gothic"])
            n = shard_count_for(src, shard_size)
            names.add("pdftexja-license-%s-%s.txt" % (fslabel, fam))
            for shard in range(n):
                base = aux_base(fslabel, fam, shard)
                names.add(base + ".ttf")
                names.add(base + ".enc")
                names.add(base + ".tfm")
        if fslabel == "haranoaji":
            for v in HORIZONTAL_TTFS.values():
                names.add(v)
    return names


# --------------------------------------------------------------- main


def build_one(fontset, args, outdir):
    """Build one fontset; return the set of produced basenames."""
    produced = set()
    if fontset == "custom":
        fslabel = args.name
        mincho, gothic = args.mincho, args.gothic
        profile = args.profile
    else:
        fslabel = fontset
        mincho = kpsewhich(FONTSETS[fontset]["mincho"])
        gothic = kpsewhich(FONTSETS[fontset]["gothic"])
        profile = None
    if not profile:
        profile = "pdftexja-fonts-%s.def" % fslabel
    profile_path = os.path.join(outdir, os.path.basename(profile))
    produced.add(os.path.basename(profile_path))

    families = {}
    license_notes = []
    horizontal = []
    for fam, src in (("mc", mincho), ("gt", gothic)):
        shards, font, nsel = build_family(fam, fslabel, src, outdir,
                                          args.shard_size)
        families[fam] = shards
        for e in shards:
            produced.add(e["ttf"])
            produced.add(e["enc"])
            produced.add(e["tfm"])
        license_notes.append("== %s (%s) ==" % (fam, os.path.basename(src)))
        license_notes.append(license_text_from(font))
        licname = "pdftexja-license-%s-%s.txt" % (fslabel, fam)
        with open(os.path.join(outdir, licname), "w", encoding="utf-8") as fh:
            fh.write("Auxiliary vertical font for pdftexja.\n")
            fh.write("Derived from %s; the glyph outlines are the source "
                     "font's vertical (vert/vrt2) forms.\n" % src)
            fh.write(license_text_from(font) + "\n")
        produced.add(licname)
        sys.stderr.write("pdftexja-fonts.py %s: %s/%s: %d codepoint(s), "
                         "%d shard(s)\n"
                         % (GEN_VERSION, fslabel, fam, nsel, len(shards)))
        if fontset == "haranoaji":
            base = os.path.basename(src)
            out = os.path.join(outdir, HORIZONTAL_TTFS[fam])
            convert_to_ttf(src, out)
            horizontal.append(out)
            produced.add(os.path.basename(out))
            bold_src = os.path.join(
                os.path.dirname(src),
                base.replace("-Regular.otf", "-Bold.otf"))
            if not os.path.exists(bold_src):
                raise SystemExit(
                    "pdftexja-fonts.py: haranoaji needs %s (via the "
                    "haranoaji package); not found next to %s"
                    % (os.path.basename(bold_src), base))
            outb = os.path.join(outdir, HORIZONTAL_TTFS[fam + "b"])
            convert_to_ttf(bold_src, outb)
            horizontal.append(outb)
            produced.add(os.path.basename(outb))

    text = build_profile(families, profile_path, "\n".join(license_notes))
    sys.stderr.write("pdftexja-fonts.py %s: wrote %s (%d bytes, "
                     "mc %d shards, gt %d shards"
                     % (GEN_VERSION, profile_path, len(text),
                        len(families["mc"]), len(families["gt"])))
    if horizontal:
        sys.stderr.write("; horizontal TTFs: %s"
                         % ", ".join(os.path.basename(p) for p in horizontal))
    sys.stderr.write("\n")
    return produced


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fontset",
                    choices=["ipaex", "ipa", "haranoaji", "all", "custom"],
                    default=None)
    ap.add_argument("--name", help="custom fontset NAME "
                                   "(ASCII alphanumerics or hyphen)")
    ap.add_argument("--mincho", help="mincho TTF (custom fontset)")
    ap.add_argument("--gothic", help="gothic TTF (custom fontset)")
    ap.add_argument("--profile", help="profile .def output (custom fontset)")
    ap.add_argument("--outdir", default="fonts/pdftexja")
    ap.add_argument("--manifest", default=None)
    ap.add_argument("--shard-size", type=int, default=255)
    ap.add_argument("--print-manifest", action="store_true")
    args = ap.parse_args()

    if not (1 <= args.shard_size <= 255):
        ap.error("--shard-size must be 1..255")

    fontset = args.fontset
    if fontset == "custom":
        if not (args.name and args.mincho and args.gothic and args.profile):
            ap.error("--fontset custom requires --name NAME --mincho FILE "
                     "--gothic FILE --profile FILE")
        if not re.match(r'^[A-Za-z0-9-]+$', args.name):
            ap.error("--name must use ASCII alphanumerics or hyphen only")
        if args.name in BUILTIN_NAMES or args.name in ("all", "custom"):
            ap.error("--name %s collides with a built-in fontset" % args.name)
        _check_exists(args.mincho, "--mincho")
        _check_exists(args.gothic, "--gothic")

    if args.print_manifest:
        if fontset == "custom":
            if not (args.mincho and args.gothic):
                ap.error("--print-manifest with --fontset custom needs "
                         "--mincho and --gothic")
            names = predicted_baselines("custom", args.shard_size,
                                        args.mincho, args.gothic,
                                        args.profile, args.name)
        else:
            names = predicted_baselines(fontset or "all", args.shard_size)
        for n in sorted(names):
            print(n)
        return 0

    os.makedirs(args.outdir, exist_ok=True)
    targets = ["ipaex", "ipa", "haranoaji"] if fontset in (None, "all") \
        else [fontset]
    produced = set()
    for fs in targets:
        produced |= build_one(fs, args, args.outdir)
    if args.manifest:
        write_manifest(args.manifest, produced)
        sys.stderr.write("pdftexja-fonts.py %s: wrote manifest %s "
                         "(%d asset(s))\n"
                         % (GEN_VERSION, args.manifest, len(produced)))
    return 0


def _check_exists(path, what):
    if not os.path.exists(path):
        raise SystemExit("pdftexja-fonts.py: %s %s does not exist"
                         % (what, path))


if __name__ == "__main__":
    sys.exit(main())
