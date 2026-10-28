-- -*- coding: utf-8 -*-
-- pdftexja-jfm-ptexmin.lua --- PRESET descriptor for the paragraph-patched
-- MIN/UJISV JFM (historical ptexmin behaviour).
--
-- Source data: data/jfm-min.lua (yoko) and data/jfm-ujisv.lua (tate),
-- both patched so the `parbdd` pseudo character belongs to class 0.
-- composition=both, boundary_semantics=jfm, character_semantics=jfm.
-- Both family identities use the same paragraph-patched MIN table; only the
-- gt identity tag differs (min@goth), because the effective family is
-- resolved before the identity is chosen.
--
-- No xspacing entries and no fullwidth-space adjust: per-scalar policy
-- comes from data/pdftexja-class-character-policy.lua at runtime.

return function(base_dir)
  local yoko_src = dofile(base_dir .. "/jfm-min.lua")
  local tate_src = dofile(base_dir .. "/jfm-ujisv.lua")

  -- Move the parbdd pseudo character from whichever class holds it (99 in
  -- MIN, 199 in UJISV) into class 0, creating class 0's chars list if the
  -- source table has none.  This is the paragraph patch the ptexmin preset
  -- encodes: paragraph role = 0.
  local function patch_parbdd(t)
    local found = false
    for k, v in pairs(t) do
      if type(k) == "number" and type(v) == "table" and v.chars then
        local kept = {}
        for _, ch in ipairs(v.chars) do
          if ch == "parbdd" then
            found = true
          else
            kept[#kept + 1] = ch
          end
        end
        if #kept ~= #v.chars then v.chars = kept end
      end
    end
    if not found then
      error("ptexmin: source JFM has no parbdd pseudo character", 0)
    end
    if t[0] == nil then error("ptexmin: source JFM has no class 0", 0) end
    t[0].chars = t[0].chars or {}
    t[0].chars[#t[0].chars + 1] = "parbdd"
    return t
  end

  local roles = {
    normal = 0, latin = 0, nox_latin = 0, paragraph = 0,
    box = 99, glue = 0, other = 0,
  }

  return {
    format = 1,
    id = "ptexmin",
    composition = "both",
    boundary_semantics = "jfm",
    character_semantics = "jfm",
    variants = {
      {
        id = "base", dir = "yoko",
        file = "pdftexja-jfm-ptexmin-yoko-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = patch_parbdd(yoko_src()), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "min", gt = "min@goth" },
        source = "jfm-min.lua",
      },
      {
        id = "base", dir = "tate",
        file = "pdftexja-jfm-ptexmin-tate-base.def",
        open_bracket_pos = nil, hanging_punctuation = false,
        jfm = patch_parbdd(tate_src()), roles = roles,
        prebreak = { [2] = 10000 }, postbreak = { [1] = 10000 },
        family_identity = { mc = "min", gt = "min@goth" },
        source = "jfm-ujisv.lua",
      },
    },
  }
end
