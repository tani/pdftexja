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
-- jfm-jis.lua --- standalone table data derived from LuaTeX-ja src/jfm-jis.lua.
--
-- Provenance: derivative of LuaTeX-ja ce50758ee8f094fb6b8e1fbe3ffaa123578db13c src/jfm-jis.lua (BSD-3-Clause,
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

   [0] = {
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },

   [1] = { -- 開き括弧類
      chars = {
	 '‘', '“', '〈', '《', '「', '『', '【', '〔', '〖',
	 '〘', '〝', '（', '［', '｛', '｟'
      },
      align = 'right', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [3] = { 0.25, 0.0, 0.25 }
      }
   },

   [2] = { -- 閉じ括弧類
      chars = {
	 '’', '”', '、', '〉', '》', '」', '』', '】', '〕',
	 '〗', '〙', '〟', '）', '，', '］', '｝', '｠'
      },
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0] = { 0.5 , 0.0, 0.5  },
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 },
	 [5] = { 0.5 , 0.0, 0.5  },
      }
   },

   [3] = { -- 中点類
      chars = {'・', '：', '；'},
      align = 'middle', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0] = { 0.25, 0.0, 0.25 },
	 [1] = { 0.25, 0.0, 0.25 },
	 [2] = { 0.25, 0.0, 0.25 },
	 [3] = { 0.5 , 0.0, 0.5  },
	 [4] = { 0.25, 0.0, 0.25 },
	 [5] = { 0.25, 0.0, 0.25 },
      }
   },

   [4] = { -- 句点類
      chars = {'。', '．'},
      align = 'left', left = 0.0, down = 0.0,
      width = 0.5, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [0] = { 0.5 , 0.0, 0.0  },
	 [1] = { 0.5 , 0.0, 0.0  },
	 [3] = { 0.75, 0.0, 0.25 },
	 [5] = { 0.5 , 0.0, 0.0  },
      }
   },

   [5] = { -- ダッシュ
      chars = { '―', '‥', '…' },
      align = 'left', left = 0.0, down = 0.0,
      width = 1.0, height = vht, depth = vdp, italic=0.0,
      glue = {
	 [1] = { 0.5 , 0.0, 0.5  },
	 [3] = { 0.25, 0.0, 0.25 }
      },
      kern = {
	 [5] = 0.0
      }
   },

   [99] = { -- box末尾
      chars = {'boxbdd', 'parbdd'},
   },

}
return t
end
