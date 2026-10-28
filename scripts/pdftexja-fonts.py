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
import bisect
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

# UAX #50 (Unicode 17.0.0) Vertical_Orientation = R ("rotate sideways in
# vertical text"), as the sorted boundary list LuaTeX-ja uses
# (reference/pinned/ltj-jfont.lua, list_rotate_glyphs / rotate_in_uax50:
# t[1] <= cp < t[2] rotates, t[2] <= cp < t[3] does not, ...).  LuaTeX-ja
# rotates such a character in tate unless the font substitutes a vertical
# (vert/vrt2) form; its only exceptions (U+FF1A, U+FF1B) concern the zht
# language and do not apply to Japanese.
UAX50_ROTATE_BOUNDS = (
    0, 167, 168, 169, 170, 174, 175, 177, 178, 188, 191, 215, 216, 247, 248,
    746, 748, 888, 890, 896, 900, 907, 908, 909, 910, 930, 931, 1328, 1329,
    1367, 1369, 1419, 1421, 1424, 1425, 1480, 1488, 1515, 1519, 1525, 1536,
    1806, 1807, 1867, 1869, 1970, 1984, 2043, 2045, 2094, 2096, 2111, 2112,
    2140, 2142, 2143, 2144, 2155, 2160, 2194, 2199, 2436, 2437, 2445, 2447,
    2449, 2451, 2473, 2474, 2481, 2482, 2483, 2486, 2490, 2492, 2501, 2503,
    2505, 2507, 2511, 2519, 2520, 2524, 2526, 2527, 2532, 2534, 2559, 2561,
    2564, 2565, 2571, 2575, 2577, 2579, 2601, 2602, 2609, 2610, 2612, 2613,
    2615, 2616, 2618, 2620, 2621, 2622, 2627, 2631, 2633, 2635, 2638, 2641,
    2642, 2649, 2653, 2654, 2655, 2662, 2679, 2689, 2692, 2693, 2702, 2703,
    2706, 2707, 2729, 2730, 2737, 2738, 2740, 2741, 2746, 2748, 2758, 2759,
    2762, 2763, 2766, 2768, 2769, 2784, 2788, 2790, 2802, 2809, 2816, 2817,
    2820, 2821, 2829, 2831, 2833, 2835, 2857, 2858, 2865, 2866, 2868, 2869,
    2874, 2876, 2885, 2887, 2889, 2891, 2894, 2901, 2904, 2908, 2910, 2911,
    2916, 2918, 2936, 2946, 2948, 2949, 2955, 2958, 2961, 2962, 2966, 2969,
    2971, 2972, 2973, 2974, 2976, 2979, 2981, 2984, 2987, 2990, 3002, 3006,
    3011, 3014, 3017, 3018, 3022, 3024, 3025, 3031, 3032, 3046, 3067, 3072,
    3085, 3086, 3089, 3090, 3113, 3114, 3130, 3132, 3141, 3142, 3145, 3146,
    3150, 3157, 3159, 3160, 3163, 3164, 3166, 3168, 3172, 3174, 3184, 3191,
    3213, 3214, 3217, 3218, 3241, 3242, 3252, 3253, 3258, 3260, 3269, 3270,
    3273, 3274, 3278, 3285, 3287, 3292, 3295, 3296, 3300, 3302, 3312, 3313,
    3316, 3328, 3341, 3342, 3345, 3346, 3397, 3398, 3401, 3402, 3408, 3412,
    3428, 3430, 3456, 3457, 3460, 3461, 3479, 3482, 3506, 3507, 3516, 3517,
    3518, 3520, 3527, 3530, 3531, 3535, 3541, 3542, 3543, 3544, 3552, 3558,
    3568, 3570, 3573, 3585, 3643, 3647, 3676, 3713, 3715, 3716, 3717, 3718,
    3723, 3724, 3748, 3749, 3750, 3751, 3774, 3776, 3781, 3782, 3783, 3784,
    3791, 3792, 3802, 3804, 3808, 3840, 3912, 3913, 3949, 3953, 3992, 3993,
    4029, 4030, 4045, 4046, 4059, 4096, 4294, 4295, 4296, 4301, 4302, 4304,
    4352, 4608, 4681, 4682, 4686, 4688, 4695, 4696, 4697, 4698, 4702, 4704,
    4745, 4746, 4750, 4752, 4785, 4786, 4790, 4792, 4799, 4800, 4801, 4802,
    4806, 4808, 4823, 4824, 4881, 4882, 4886, 4888, 4955, 4957, 4989, 4992,
    5018, 5024, 5110, 5112, 5118, 5120, 5121, 5760, 5789, 5792, 5881, 5888,
    5910, 5919, 5943, 5952, 5972, 5984, 5997, 5998, 6001, 6002, 6004, 6016,
    6110, 6112, 6122, 6128, 6138, 6144, 6170, 6176, 6265, 6272, 6315, 6400,
    6431, 6432, 6444, 6448, 6460, 6464, 6465, 6468, 6510, 6512, 6517, 6528,
    6572, 6576, 6602, 6608, 6619, 6622, 6684, 6686, 6751, 6752, 6781, 6783,
    6794, 6800, 6810, 6816, 6830, 6832, 6878, 6880, 6892, 6912, 6989, 6990,
    7156, 7164, 7224, 7227, 7242, 7245, 7307, 7312, 7355, 7357, 7368, 7376,
    7419, 7424, 7958, 7960, 7966, 7968, 8006, 8008, 8014, 8016, 8024, 8025,
    8026, 8027, 8028, 8029, 8030, 8031, 8062, 8064, 8117, 8118, 8133, 8134,
    8148, 8150, 8156, 8157, 8176, 8178, 8181, 8182, 8191, 8192, 8214, 8215,
    8224, 8226, 8240, 8242, 8251, 8253, 8258, 8259, 8263, 8266, 8273, 8274,
    8293, 8294, 8306, 8308, 8335, 8336, 8349, 8352, 8386, 8400, 8413, 8417,
    8418, 8421, 8433, 8450, 8451, 8458, 8463, 8464, 8467, 8469, 8470, 8472,
    8478, 8484, 8485, 8486, 8487, 8488, 8489, 8490, 8494, 8495, 8501, 8512,
    8517, 8523, 8524, 8526, 8527, 8586, 8588, 8592, 8734, 8735, 8756, 8758,
    8960, 8968, 8972, 8992, 8996, 9001, 9003, 9004, 9085, 9115, 9150, 9166,
    9167, 9168, 9169, 9180, 9186, 9251, 9252, 9472, 9632, 9754, 9760, 10088,
    10102, 10132, 11026, 11056, 11088, 11098, 11124, 11126, 11159, 11160,
    11192, 11218, 11219, 11244, 11248, 11264, 11508, 11513, 11558, 11559,
    11560, 11565, 11566, 11568, 11624, 11631, 11633, 11647, 11671, 11680,
    11687, 11688, 11695, 11696, 11703, 11704, 11711, 11712, 11719, 11720,
    11727, 11728, 11735, 11736, 11743, 11744, 11856, 11858, 11870, 12296,
    12306, 12308, 12320, 12336, 12337, 12448, 12449, 12540, 12541, 42192,
    42540, 42560, 42744, 42752, 42973, 42993, 43053, 43056, 43066, 43072,
    43128, 43136, 43206, 43214, 43226, 43232, 43348, 43359, 43360, 43392,
    43470, 43471, 43482, 43486, 43519, 43520, 43575, 43584, 43598, 43600,
    43610, 43612, 43715, 43739, 43767, 43777, 43783, 43785, 43791, 43793,
    43799, 43808, 43815, 43816, 43823, 43824, 43884, 43888, 44014, 44016,
    44026, 55296, 57344, 64256, 64263, 64275, 64280, 64285, 64311, 64312,
    64317, 64318, 64319, 64320, 64322, 64323, 64325, 64326, 64976, 65008,
    65040, 65056, 65072, 65097, 65104, 65112, 65119, 65123, 65127, 65136,
    65141, 65142, 65277, 65279, 65280, 65288, 65290, 65293, 65294, 65306,
    65311, 65339, 65340, 65341, 65342, 65343, 65344, 65371, 65471, 65474,
    65480, 65482, 65488, 65490, 65496, 65498, 65501, 65507, 65508, 65512,
    65519, 65529, 65532, 65536, 65548, 65549, 65575, 65576, 65595, 65596,
    65598, 65599, 65614, 65616, 65630, 65664, 65787, 65792, 65795, 65799,
    65844, 65847, 65935, 65936, 65949, 65952, 65953, 66000, 66046, 66176,
    66205, 66208, 66257, 66272, 66300, 66304, 66340, 66349, 66379, 66384,
    66427, 66432, 66462, 66463, 66500, 66504, 66518, 66560, 66718, 66720,
    66730, 66736, 66772, 66776, 66812, 66816, 66856, 66864, 66916, 66927,
    66939, 66940, 66955, 66956, 66963, 66964, 66966, 66967, 66978, 66979,
    66994, 66995, 67002, 67003, 67005, 67008, 67060, 67072, 67383, 67392,
    67414, 67424, 67432, 67456, 67462, 67463, 67505, 67506, 67515, 67584,
    67590, 67592, 67593, 67594, 67638, 67639, 67641, 67644, 67645, 67647,
    67670, 67671, 67743, 67751, 67760, 67808, 67827, 67828, 67830, 67835,
    67868, 67871, 67898, 67903, 67930, 68000, 68024, 68028, 68048, 68050,
    68100, 68101, 68103, 68108, 68116, 68117, 68120, 68121, 68150, 68152,
    68155, 68159, 68169, 68176, 68185, 68192, 68256, 68288, 68327, 68331,
    68343, 68352, 68406, 68409, 68438, 68440, 68467, 68472, 68498, 68505,
    68509, 68521, 68528, 68608, 68681, 68736, 68787, 68800, 68851, 68858,
    68904, 68912, 68922, 68928, 68966, 68969, 68998, 69006, 69008, 69216,
    69247, 69248, 69290, 69291, 69294, 69296, 69298, 69314, 69320, 69328,
    69337, 69370, 69416, 69424, 69466, 69488, 69514, 69552, 69580, 69600,
    69623, 69632, 69710, 69714, 69750, 69759, 69827, 69837, 69838, 69840,
    69865, 69872, 69882, 69888, 69941, 69942, 69960, 69968, 70007, 70016,
    70112, 70113, 70133, 70144, 70162, 70163, 70210, 70272, 70279, 70280,
    70281, 70282, 70286, 70287, 70302, 70303, 70314, 70320, 70379, 70384,
    70394, 70400, 70404, 70405, 70413, 70415, 70417, 70419, 70441, 70442,
    70449, 70450, 70452, 70453, 70458, 70459, 70469, 70471, 70473, 70475,
    70478, 70480, 70481, 70487, 70488, 70493, 70500, 70502, 70509, 70512,
    70517, 70528, 70538, 70539, 70540, 70542, 70543, 70544, 70582, 70583,
    70593, 70594, 70595, 70597, 70598, 70599, 70603, 70604, 70614, 70615,
    70617, 70625, 70627, 70656, 70748, 70749, 70754, 70784, 70856, 70864,
    70874, 71168, 71237, 71248, 71258, 71264, 71277, 71296, 71354, 71360,
    71370, 71376, 71396, 71424, 71451, 71453, 71468, 71472, 71495, 71680,
    71740, 71840, 71923, 71935, 71943, 71945, 71946, 71948, 71956, 71957,
    71959, 71960, 71990, 71991, 71993, 71995, 72007, 72016, 72026, 72096,
    72104, 72106, 72152, 72154, 72165, 72384, 72441, 72448, 72458, 72544,
    72552, 72640, 72674, 72688, 72698, 72704, 72713, 72714, 72759, 72760,
    72774, 72784, 72813, 72816, 72848, 72850, 72872, 72873, 72887, 72960,
    72967, 72968, 72970, 72971, 73015, 73018, 73019, 73020, 73022, 73023,
    73032, 73040, 73050, 73056, 73062, 73063, 73065, 73066, 73103, 73104,
    73106, 73107, 73113, 73120, 73130, 73136, 73180, 73184, 73194, 73440,
    73465, 73472, 73489, 73490, 73531, 73534, 73563, 73648, 73649, 73664,
    73714, 73727, 74650, 74752, 74863, 74864, 74869, 74880, 75076, 77712,
    77811, 90368, 90426, 92160, 92729, 92736, 92767, 92768, 92778, 92782,
    92863, 92864, 92874, 92880, 92910, 92912, 92918, 92928, 92998, 93008,
    93018, 93019, 93026, 93027, 93048, 93053, 93072, 93504, 93562, 93760,
    93851, 93856, 93881, 93883, 93908, 93952, 94027, 94031, 94088, 94095,
    94112, 113664, 113771, 113776, 113789, 113792, 113801, 113808, 113818,
    113820, 113828, 117760, 118013, 118016, 118452, 118458, 118464, 119296,
    119366, 119488, 119508, 119808, 119893, 119894, 119965, 119966, 119968,
    119970, 119971, 119973, 119975, 119977, 119981, 119982, 119994, 119995,
    119996, 119997, 120004, 120005, 120070, 120071, 120075, 120077, 120085,
    120086, 120093, 120094, 120122, 120123, 120127, 120128, 120133, 120134,
    120135, 120138, 120145, 120146, 120486, 120488, 120780, 120782, 120832,
    122624, 122655, 122661, 122667, 122880, 122887, 122888, 122905, 122907,
    122914, 122915, 122917, 122918, 122923, 122928, 122990, 123023, 123024,
    123136, 123181, 123184, 123198, 123200, 123210, 123214, 123216, 123536,
    123567, 123584, 123642, 123647, 123648, 124112, 124154, 124368, 124411,
    124415, 124416, 124608, 124639, 124640, 124662, 124670, 124672, 124896,
    124903, 124904, 124908, 124909, 124911, 124912, 124927, 124928, 125125,
    125127, 125143, 125184, 125260, 125264, 125274, 125278, 125280, 126065,
    126133, 126209, 126270, 126464, 126468, 126469, 126496, 126497, 126499,
    126500, 126501, 126503, 126504, 126505, 126515, 126516, 126520, 126521,
    126522, 126523, 126524, 126530, 126531, 126535, 126536, 126537, 126538,
    126539, 126540, 126541, 126544, 126545, 126547, 126548, 126549, 126551,
    126552, 126553, 126554, 126555, 126556, 126557, 126558, 126559, 126560,
    126561, 126563, 126564, 126565, 126567, 126571, 126572, 126579, 126580,
    126584, 126585, 126589, 126590, 126591, 126592, 126602, 126603, 126620,
    126625, 126628, 126629, 126634, 126635, 126652, 126704, 126706, 129024,
    129036, 129040, 129096, 129104, 129114, 129120, 129160, 129168, 129198,
    129200, 129212, 129216, 129218, 129232, 129241, 129792, 129939, 129940,
    130043, 917505, 917506, 917536, 917632, 917760, 918000,
)


def uax50_rotates(cp):
    """True when UAX #50 rotates cp sideways in vertical text."""
    return bisect.bisect_right(UAX50_ROTATE_BOUNDS, cp) % 2 == 1

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


def build_profile(families, profile_path, license_note, sideways=()):
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
    # \pdftexja@vrot@<DECIMAL>: UAX #50 Vertical_Orientation=R codepoints of
    # the families' cmaps that have no vertical form above; in tate they are
    # set sideways (unrotated in the rotated galley), as LuaTeX-ja does.
    a("")
    a("%% ---- UAX #50 sideways (R without a vert/vrt2 form)")
    for cp in sorted(sideways):
        a("\\expandafter\\def\\csname pdftexja@vrot@%d\\endcsname{}" % cp)
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
    return shards, font, len(selpairs), set(data)


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
    cmap_cps = set()
    vert_cps = set()
    for fam, src in (("mc", mincho), ("gt", gothic)):
        shards, font, nsel, selected = build_family(fam, fslabel, src, outdir,
                                                    args.shard_size)
        families[fam] = shards
        cmap_cps.update(font.getBestCmap())
        vert_cps.update(selected)
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

    # only non-ASCII codepoints reach the CJK glyph layer
    sideways = sorted(cp for cp in cmap_cps - vert_cps
                      if cp >= 0x80 and uax50_rotates(cp))
    text = build_profile(families, profile_path, "\n".join(license_notes),
                         sideways)
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
