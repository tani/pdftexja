-- -*- coding: utf-8 -*-
-- pdftexja-jfm-min.lua --- PRESET descriptor for the MIN/UJISV JFM.
--
-- Source data: data/jfm-min.lua (yoko) and data/jfm-ujisv.lua (tate).
-- composition=paverage, boundary_semantics=jfm, character_semantics=jfm.
-- No xspacing entries and no fullwidth-space adjust: per-scalar policy comes
-- from data/pdftexja-class-character-policy.lua at runtime.

return function(base_dir)
  local yoko_src = dofile(base_dir .. "/jfm-min.lua")
  local tate_src = dofile(base_dir .. "/jfm-ujisv.lua")

  local roles = {
    normal = 0, latin = 0, nox_latin = 0, paragraph = 99,
    box = 99, glue = 0, other = 0,
  }

  return {
    format = 1,
    id = "min",
    composition = "paverage",
    boundary_semantics = "jfm",
    character_semantics = "jfm",
    variants = {
      {
        id = "base", dir = "yoko",
        file = "pdftexja-jfm-min-yoko-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = yoko_src(), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "min", gt = "min" },
        source = "jfm-min.lua",
      },
      {
        id = "base", dir = "tate",
        file = "pdftexja-jfm-min-tate-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = tate_src(), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "min", gt = "min" },
        source = "jfm-ujisv.lua",
      },
    },
  }
end
