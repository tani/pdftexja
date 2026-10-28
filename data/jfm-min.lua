-- -*- coding: utf-8 -*-
-- Copyright (c) 2011--2026 The LuaTeX-ja project, All rights reserved.
-- Derived from LuaTeX-ja ce50758ee8f094fb6b8e1fbe3ffaa123578db13c
-- (BSD 3-clause license):
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--   * Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--   * Redistributions in binary form must reproduce the above copyright
--     notice, this list of conditions and the following disclaimer in the
--     documentation and/or other materials provided with the distribution.
--   * Neither the name of the LuaTeX-ja project nor the names of its
--     contributors may be used to endorse or promote products derived from
--     this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE LUATEX-JA
-- PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-- LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
-- DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
-- THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- jfm-min.lua --- standalone table data derived from LuaTeX-ja src/jfm-min.lua.
--
-- Provenance: derivative of LuaTeX-ja ce50758ee8f094fb6b8e1fbe3ffaa123578db13c src/jfm-min.lua (BSD-3-Clause,
-- Copyright the LuaTeX-ja project).  The table contents, the t[100]/t[200]
-- post-processing loops, the AJ1 char-range expansions and every fixup are
-- kept verbatim.  Only the embedding is changed:
--   * luatexja.jfont.define_jfm{...} -> local t = {...}; return t
--   * `table.fastcopy` uses a local deep copy with the same semantics
--     (no lualibs dependency)
--   * the trailing `luatexja.jfont.jfm_feature` hinge is fixed false:
--         beginpar_middledot_zw = false
--     so no beginpar_middledot_zw patch is installed (this source has no
--     such hinge; the fixed value is recorded here for all four data files).
--
-- The value returned is a fresh table on every call.

local fastcopy
fastcopy = table.fastcopy or function(t)
  local r = {}
  for k, v in pairs(t) do
    if type(v) == "table" then v = fastcopy(v) end
    r[k] = v
  end
  return r
end

return function()
local vscale = 0.916443 / 0.962216
local vht = 0.777588 / 0.962216
local vdp = 0.138855 / 0.962216

local t = {
   dir = 'yoko',
   zw = 1.0, zh = vscale,
   kanjiskip = { 0.0, 0.091641/0.962216, 0.0 },
   xkanjiskip = { 0.229101/0.962216, 0.183283/0.962216, 0.114551/0.962216 },
   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [4] = { 0.316224, 0.0, 0.316224 },
	 [5] = { 0.238097, 0.0, 0.238097 },
	 [3] = { 0.111608, 0.0, 0.111608 },
	 [6] = { 0.476196, 0.0, 0.476196 },
      }
   },

   [1] = {
      chars = {
	 '〉', '》', '」', '』', '】', '〕', '〗', '〙', '〟', '）', '］', '｝', '｠ '
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.523804, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.476196, 0.0, 0.238097 },
	 [7]  = { 0.476196, 0.0, 0.238097 },
	 [12] = { 0.476196, 0.0, 0.238097 },
	 [13] = { 0.476196, 0.0, 0.238097 },
	 [14] = { 0.476196, 0.0, 0.238097 },
	 [10] = { 0.238097, 0.238097, 0.238097 },
	 [2]  = { 0.238097, 0.238097, 0.238097 },
	 [4]  = { 0.238097, 0.238097, 0.238097 },
	 [5]  = { 0.238097, 0.238097, 0.238097 },
	 [3]  = { 0.476196, 0.0, 0.238097 },
	 [6]  = { 0.476196, 0.0, 0.238097 },
	 [11] = { 0.0, 0.476196, 0.0 },
	 [1]  = { 0.0, 0.476196, 0.0 },
      }
   },

   [2] = {
      chars = {
	 '゛', '゜'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.367552, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.632447, 0.0, 0.238097 },
	 [7]  = { 0.632447, 0.0, 0.238097 },
	 [12] = { 0.632447, 0.0, 0.238097 },
	 [13] = { 0.632447, 0.0, 0.238097 },
	 [14] = { 0.632447, 0.0, 0.238097 },
	 [10] = { 0.0, 0.316224, 0.0 },
	 [2]  = { 0.0, 0.316224, 0.0 },
	 [4]  = { 0.476196, 0.0, 0.238097 },
	 [5]  = { 0.476196, 0.0, 0.238097 },
	 [3]  = { 0.476196, 0.0, 0.238097 },
	 [6]  = { 0.238097, 0.238097, 0.238097 },
      }
   },
   [3] = {
      chars = {
	 '∴', '♀', '♂', '〃', '々', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ ',
	 'ょ', 'ゎ', 'ゕ', 'ゖ', 'ゞ', 'ァ', 'ィ', 'ゥ', 'ェ', 'ォ', 'ッ', 'ャ', 'ュ', 'ョ',
	 'ヮ', 'ヵ', 'ヶ', 'ㇰ', 'ㇱ', 'ㇲ', 'ㇳ', 'ㇴ', 'ㇵ', 'ㇶ', 'ㇷ', 'ㇸ', 'ㇹ', 'ㇺ',
	 'ㇻ', 'ㇼ', 'ㇽ', 'ㇾ', 'ㇿ', '＄', '￠', '￡'
      },
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.776784, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.111608, 0.0, 0.111608 },
	 [7]  = { 0.111608, 0.0, 0.111608 },
	 [12] = { 0.111608, 0.0, 0.111608 },
	 [13] = { 0.111608, 0.0, 0.111608 },
	 [14] = { 0.111608, 0.0, 0.111608 },
	 [10] = { 0.0, 0.316224, 0.0},
	 [2]  = { 0.0, 0.316224, 0.0},
	 [4]  = { 0.316224, 0.0, 0.316224 },
	 [5]  = { 0.238097, 0.0, 0.238097 },
	 [6]  = { 0.476196, 0.0, 0.476196 },
	 [11] = { 0.111608, 0.0, 0.111608 },
	 [1]  = { 0.111608, 0.0, 0.111608 },
      },
  },
   [4] = {
      chars = {
	 '´', '‐', '‖', '‘', '’', '・', '！', '：', '；', '｀', '｜'
      },
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.367552, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.316224, 0.0, 0.316224 },
	 [7]  = { 0.316224, 0.0, 0.316224 },
	 [12] = { 0.316224, 0.0, 0.316224 },
	 [13] = { 0.316224, 0.0, 0.316224 },
	 [14] = { 0.316224, 0.0, 0.316224 },
	 [10] = { 0.0, 0.316224, 0.0 },
	 [2]  = { 0.0, 0.316224, 0.0 },
	 [4]  = { 0.0, 0.316224, 0.0 },
	 [5]  = { 0.0, 0.316224, 0.0 },
	 [3]  = { 0.316224, 0.0, 0.316224 },
	 [6]  = { 0.238097, 0.238097, 0.238097 },
	 [11] = { 0.316224, 0.0, 0.316224 },
	 [1]  = { 0.316224, 0.0, 0.316224 },
      }
   },
   [5] = {
      chars = {
	 '§', '¨', '°', '“', '”', '′', '″', 'ゝ', 'ヽ', '？', '＾'
      },
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.523804, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.238097, 0.0, 0.238097 },
	 [7]  = { 0.238097, 0.0, 0.238097 },
	 [12] = { 0.238097, 0.0, 0.238097 },
	 [13] = { 0.238097, 0.0, 0.238097 },
	 [14] = { 0.238097, 0.0, 0.238097 },
	 [10] = { 0.0, 0.316224, 0.0 },
	 [2]  = { 0.0, 0.316224, 0.0 },
	 [4]  = { 0.0, 0.316224, 0.0 },
	 [5]  = { 0.0, 0.316224, 0.0 },
	 [3]  = { 0.238097, 0.0, 0.238097 },
	 [6]  = { 0.238097, 0.238097, 0.238097 },
	 [11] = { 0.238097, 0.0, 0.238097 },
	 [1]  = { 0.238097, 0.0, 0.238097 },
      },
   },
   [6] = {
      chars = {
	 '〈', '《', '「', '『', '【', '〔', '〖', '〘', '〝', '（', '［', '｛', '｟'
      },
      align = 'right', left = 0.0, down = 0.0,
      width = 0.523804, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [4]  = { 0.316224, 0.0, 0.316224 },
	 [5]  = { 0.238097, 0.0, 0.238097 },
	 [3]  = { 0.111608, 0.0, 0.111608 },
	 [6]  = { 0.0, 0.476196, 0.0 },
      },
   },
   [7] = {
      chars = {
	 'う', 'く', 'ぐ', 'け', 'げ', 'す', 'ず', 'り', 'テ', 'デ', 'ヤ'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
 	 [4]  = { 0.316224, 0.0, 0.316224 },
	 [5]  = { 0.238097, 0.0, 0.238097 },
	 [3]  = { 0.111608, 0.0, 0.111608 },
	 [6]  = { 0.476196, 0.0, 0.238097 },
      },
      kern = {
	 [10] = -0.05, [11] = -0.05
      },
   },

   [10] = {
      chars = {
	 '，', '．'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.367552, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.632447, 0.0, 0.238097 },
	 [7]  = { 0.632447, 0.0, 0.238097 },
	 [12] = { 0.632447, 0.0, 0.238097 },
	 [13] = { 0.632447, 0.0, 0.238097 },
	 [14] = { 0.632447, 0.0, 0.238097 },
	 [10] = { 0.0, 0.316224, 0.0 },
	 [2]  = { 0.0, 0.316224, 0.0 },
	 [4]  = { 0.476196, 0.0, 0.238097 },
	 [5]  = { 0.476196, 0.0, 0.238097 },
	 [3]  = { 0.476196, 0.0, 0.238097 },
	 [6]  = { 0.238097, 0.238097, 0.238097 },
      }
    },
   [11] = {
      chars = {
	 '、', '。 '
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.523804, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0]  = { 0.476196, 0.0, 0.238097 },
	 [7]  = { 0.476196, 0.0, 0.238097 },
	 [12] = { 0.476196, 0.0, 0.238097 },
	 [13] = { 0.476196, 0.0, 0.238097 },
	 [14] = { 0.476196, 0.0, 0.238097 },
	 [10] = { 0.238097, 0.238097, 0.238097 },
	 [2]  = { 0.238097, 0.238097, 0.238097 },
	 [4]  = { 0.238097, 0.238097, 0.238097 },
	 [5]  = { 0.238097, 0.238097, 0.238097 },
	 [3]  = { 0.476196, 0.0, 0.238097 },
	 [6]  = { 0.476196, 0.0, 0.238097 },
	 [11] = { 0.0, 0.476196, 0.0 },
	 [1]  = { 0.0, 0.476196, 0.0 },
      }
   },
   [12] = {
      chars = {
	 'ア', 'イ', 'ウ', 'オ', 'ケ', 'ゲ', 'サ', 'ザ', 'ソ', 'ゾ', 'チ', 'ヂ', 'ツ',
	 'ヅ', 'ト', 'ド', 'ナ', 'フ', 'ブ', 'プ', 'ミ', 'メ', 'ラ', 'リ', 'ワ', 'ヲ'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
 	 [4]  = { 0.316224, 0.0, 0.316224 },
	 [5]  = { 0.238097, 0.0, 0.238097 },
	 [3]  = { 0.111608, 0.0, 0.111608 },
	 [6]  = { 0.476196, 0.0, 0.238097 },
      },
      kern = {
	 [10] = -0.1, [11] = -0.1
      },
   },
   [13] = {
      chars = {
	 'ク', 'グ', 'タ', 'ダ'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
 	 [4]  = { 0.316224, 0.0, 0.316224 },
	 [5]  = { 0.238097, 0.0, 0.238097 },
	 [3]  = { 0.111608, 0.0, 0.111608 },
	 [6]  = { 0.476196, 0.0, 0.238097 },
      },
      kern = {
	 [10] = -0.15, [11] = -0.15
      },
   },
   [14] = {
      chars = {
	 'ノ'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
 	 [4]  = { 0.316224, 0.0, 0.316224 },
	 [5]  = { 0.238097, 0.0, 0.238097 },
	 [3]  = { 0.111608, 0.0, 0.111608 },
	 [6]  = { 0.476196, 0.0, 0.238097 },
      },
      kern = {
	 [10] = -0.2, [11] = -0.2
      },
   },

   [99] = { -- box末尾
      chars = {'boxbdd', 'parbdd'},
   },
}
return t
end
