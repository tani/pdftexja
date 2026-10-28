-- -*- coding: utf-8 -*-
-- pdftexja-jfm-jis.lua --- PRESET descriptor for the JIS/UJISV JFM.
--
-- Source data: data/jfm-jis.lua (yoko) and data/jfm-ujisv.lua (tate).
-- composition=paverage, boundary_semantics=jfm, character_semantics=jfm.
-- No xspacing entries and no fullwidth-space adjust: per-scalar policy comes
-- from data/pdftexja-class-character-policy.lua at runtime.

return function(base_dir)
  local yoko_src = dofile(base_dir .. "/jfm-jis.lua")
  local tate_src = dofile(base_dir .. "/jfm-ujisv.lua")

  local roles = {
    normal = 0, latin = 0, nox_latin = 0, paragraph = 99,
    box = 99, glue = 0, other = 0,
  }

  return {
    format = 1,
    id = "jis",
    composition = "paverage",
    boundary_semantics = "jfm",
    character_semantics = "jfm",
    variants = {
      {
        id = "base", dir = "yoko",
        file = "pdftexja-jfm-jis-yoko-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = yoko_src(), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "jis", gt = "jis" },
        source = "jfm-jis.lua",
      },
      {
        id = "base", dir = "tate",
        file = "pdftexja-jfm-jis-tate-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = tate_src(), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "jis", gt = "jis" },
        source = "jfm-ujisv.lua",
      },
    },
  }
end
