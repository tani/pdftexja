-- -*- coding: utf-8 -*-
-- pdftexja-jfm-ujis.lua --- PRESET descriptor for the UJIS/UJISV JFM.
--
-- Source data: data/jfm-ujis.lua (yoko) and data/jfm-ujisv.lua (tate),
-- derivatives of LuaTeX-ja pinned sources.  composition=paverage,
-- boundary_semantics=jfm, character_semantics=jfm (class preset semantics;
-- per-scalar break/spacing policy comes from
-- data/pdftexja-class-character-policy.lua at runtime).

return function(base_dir)
  local yoko_src = dofile(base_dir .. "/jfm-ujis.lua")
  local tate_src = dofile(base_dir .. "/jfm-ujisv.lua")

  local roles = {
    normal = 0, latin = 0, nox_latin = 100, paragraph = 199,
    box = 99, glue = 99, other = 0,
  }

  return {
    format = 1,
    id = "ujis",
    composition = "paverage",
    boundary_semantics = "jfm",
    character_semantics = "jfm",
    variants = {
      {
        id = "base", dir = "yoko",
        file = "pdftexja-jfm-ujis-yoko-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = yoko_src(), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "ujis", gt = "ujis" },
        source = "jfm-ujis.lua",
      },
      {
        id = "base", dir = "tate",
        file = "pdftexja-jfm-ujis-tate-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = tate_src(), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "ujisv", gt = "ujisv" },
        source = "jfm-ujisv.lua",
      },
    },
  }
end
