-- -*- coding: utf-8 -*-
-- pdftexja-jfm-standard.lua --- PRESET descriptor for the standalone
-- standard (JLReq snapshot) JFM.
--
-- Independent snapshot of the current BSD JLReq JFM (data/jfm-standard-
-- yoko.lua and data/jfm-standard-tate.lua).  composition=single,
-- boundary_semantics=existing, character_semantics=sequence: the old
-- evaluator's intermediate TeX rounding, zero-glue elision, attachment,
-- end_adjust and explicit-space semantics are preserved, not migrated to
-- the class semantics.
--
-- Six variants per direction: base,b,z,bz,n,bn.  The variant id never
-- encodes the direction; the payload file name does:
--   pdftexja-jfm-standard-<yoko|tate>-<variant>.def
--
-- Single composition: the family identity is the preset itself (no metric
-- averaging happens).

return function(base_dir)
  local yoko_src = dofile(base_dir .. "/jfm-standard-yoko.lua")
  local tate_src = dofile(base_dir .. "/jfm-standard-tate.lua")

  -- variant id -> (open_bracket_pos, burasage)
  local AXES = {
    { id = "base", open_bracket_pos = "zenkaku_tentsuki", hanging_punctuation = false },
    { id = "b",    open_bracket_pos = "zenkaku_tentsuki", hanging_punctuation = true },
    { id = "z",    open_bracket_pos = "zenkakunibu_nibu", hanging_punctuation = false },
    { id = "bz",   open_bracket_pos = "zenkakunibu_nibu", hanging_punctuation = true },
    { id = "n",    open_bracket_pos = "nibu_tentsuki",    hanging_punctuation = false },
    { id = "bn",   open_bracket_pos = "nibu_tentsuki",    hanging_punctuation = true },
  }

  local variants = {}
  local function add_variants(dir, source_file, build)
    for _, ax in ipairs(AXES) do
      variants[#variants + 1] = {
        id = ax.id,
        dir = dir,
        file = string.format("pdftexja-jfm-standard-%s-%s.def", dir, ax.id),
        open_bracket_pos = ax.open_bracket_pos,
        hanging_punctuation = ax.hanging_punctuation,
        jfm = build({
          open_bracket_pos = ax.open_bracket_pos,
          burasage = ax.hanging_punctuation,
        }),
        roles = { normal = 0, latin = 27, paragraph = 90, box = 90 },
        -- JLReq's static line-break policy, i.e. the per-character lists of
        -- jlreq.cls:1385-1411 resolved to their JFM classes (verified
        -- against data/jfm-standard-yoko.lua: openingbrackets->1,
        -- closingbrackets->2, hyphens->300,301,302, dividing->4,
        -- middlenodes->5, fullstops->6, commas->7, inseparable->8,
        -- iterationmarks->9, prolongedsound->10, smallkana->11,
        -- prefixedabbreviations->12, hiragana->15, katakana->16).
        prebreak = { [2] = 10000, [300] = 10000, [301] = 10000,
                     [302] = 10000, [4] = 10000, [5] = 10000,
                     [6] = 10000, [7] = 10000, [9] = 10000,
                     [10] = 10000, [11] = 10000, [8] = 10000 },
        postbreak = { [1] = 10000, [12] = 10000 },
        xspacing = { [9] = "both", [10] = "both", [11] = "both",
                     [15] = "both", [16] = "both", [4] = "post" },
        fullwidth_space_adjust = { [4] = true },
        family_identity = { mc = "standard", gt = "standard" },
        source = source_file,
      }
    end
  end

  add_variants("yoko", "jfm-standard-yoko.lua", yoko_src)
  add_variants("tate", "jfm-standard-tate.lua", tate_src)

  return {
    format = 1,
    id = "standard",
    composition = "single",
    boundary_semantics = "existing",
    character_semantics = "sequence",
    variants = variants,
  }
end
