-- Copyright 2017-2026, Noriyuki Abe.  All rights reserved.
-- jlreq is distributed under the 2-clause BSD license:
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
--   * Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--   * Redistributions in binary form must reproduce the above copyright
--     notice, this list of conditions and the following disclaimer in the
--     documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
-- HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-- LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
-- DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
-- THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--[[---------------------------------------------------------------------------
  pdftexja-jfm-lib.lua --- build-time JFM data generator/validator library
  for pdftexja.

  Extracted from jlreq's make_pdftex_jfm.lua (field validation, normalization,
  TeX serialization, manifest output) and check_jfm_pdftex.lua (generic .def
  parser and structural checks).  The library is class-agnostic: it receives a
  preset descriptor and never reads the `jlreq` global.

  Public API (texlua):
    load_preset(path)              -> preset table (validated + normalized)
    generate(preset, outdir, manifest_path, assets_path) -> asset basenames
    check(preset, manifest, assets[, outdir])            -> ok, error_list
    read_variant(path)             -> parsed payload table

  PRESET descriptor contract
    The descriptor is a Lua file returning `function(base_dir) ... return
    preset end`; base_dir is the absolute directory of the descriptor itself.

    preset = {
      format = 1,
      id = "<preset id>",
      composition = "single"|"paverage"|"both",
      boundary_semantics = "existing"|"jfm",
      character_semantics = "sequence"|"jfm",
      variants = { <variant record>, ... },
    }

    variant record:
      id                  variant id ("base", "b", "z", "bz", "n", "bn", ...)
      file                payload basename (default
                          pdftexja-jfm-<preset>@<dir>-<id>.def)
      dir                 "yoko"|"tate"
      open_bracket_pos    "zenkaku_tentsuki"|"zenkakunibu_nibu"|
                          "nibu_tentsuki"|nil (no bracket axis)
      hanging_punctuation boolean
      jfm                 loaded source JFM table
      roles               { normal=, latin=, paragraph=, box=,
                            nox_latin=, glue=, other= }  (last three optional)
      prebreak            { [class] = penalty }        (absent = 0)
      postbreak           { [class] = penalty }        (absent = 0)
      xspacing            { [class] = "none"|"pre"|"post"|"both" }
                                                        (absent = "both")
      fullwidth_space_adjust { [class] = true }
      family_identity     { mc = "<id>", gt = "<id>" }  (required unless
                                                        composition=="single")
      source              source data basename (relative to base_dir) whose
                          sha256 is recorded in the payload header; defaults
                          to the descriptor itself.

  Output contract (see local://pdftexja-contracts.md):
    payload macros      \pdftexja@data@<preset>@<variant>@<dir>@...
    index macros        \pdftexja@jfm@...
    asset fragment      PDFTEXJA_JFM_<preset>_ASSETS := <sorted basenames>
    semantic manifest   Lua table (returned by dofile)
-----------------------------------------------------------------------------]]

local M = {}

local GEN_VERSION = "1.0"
M.GEN_VERSION = GEN_VERSION

-- ------------------------------ basics -------------------------------------
local U = unicode.utf8

local function fail(fmt, ...)
  error(string.format(fmt, ...), 0)
end

-- Data sources are LuaTeX-ja/jlreq JFM snapshots that use lualibs'
-- table.fastcopy.  Provide the same deep-copy semantics so the data files
-- stay byte-compatible with their upstream sources and load standalone.
if not table.fastcopy then
  local function fastcopy(t)
    local r = {}
    for k, v in pairs(t) do
      if type(v) == "table" then v = fastcopy(v) end
      r[k] = v
    end
    return r
  end
  table.fastcopy = fastcopy
end

local function sha256_hex(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  if not sha2 then
    local ok = pcall(require, "lualibs")
    if not ok then pcall(require, "sha2") end
  end
  if not sha2 then
    fail("pdftexja-jfm-lib: sha256 support (sha2/lualibs) is unavailable")
  end
  local raw = sha2.digest256(data)
  return (raw:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function basename(path)
  return (path:gsub("\\", "/"):match("([^/]*)$"))
end

local function dirname(path)
  local d = path:match("^(.*)/[^/]*$")
  return d or "."
end

local function currentdir()
  local ok, lfs = pcall(require, "lfs")
  if ok and lfs and lfs.currentdir then return lfs.currentdir() end
  local p = io.popen("pwd")
  if not p then return "." end
  local d = p:read("*l")
  p:close()
  return d or "."
end

local function absolute(path)
  if path:sub(1, 1) == "/" then return path end
  return currentdir() .. "/" .. path
end
M.absolute = absolute

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d
end

local function write_file(path, text)
  local f, err = io.open(path, "wb")
  if not f then fail("pdftexja-jfm-lib: cannot write %s: %s", path, tostring(err)) end
  f:write(text)
  f:close()
end

local function mkdir_p(dir)
  -- Paths are build-tool controlled (no user quoting surprises); keep it
  -- simple and POSIX-only like the rest of the tool chain.
  local ok = os.execute("mkdir -p '" .. dir:gsub("'", "'\\''") .. "'")
  return ok == true or ok == 0
end

local function num(x)
  if x == 0 then x = 0 end -- normalize -0.0
  return string.format("%.6f", x)
end

local function hexn(cp) return string.format("%X", cp) end

local function lua_str(s)
  return string.format("%q", s)
end

-- Deterministic name/value emission.  Names made only of letters and "@"
-- can be written as plain \def; digit-bearing names MUST go through
-- \csname (a plain \def would read the first digit as the start of the
-- parameter text).
local function is_plain_name(name)
  return name:match("^[A-Za-z@]+$") ~= nil
end

local function defop(out, name, body)
  if is_plain_name(name) then
    out[#out + 1] = "\\def\\" .. name .. "{" .. body .. "}"
  else
    out[#out + 1] = "\\expandafter\\def\\csname " .. name
      .. "\\endcsname{" .. body .. "}"
  end
end

-- ------------------------------ parsing ------------------------------------
-- split_groups(s): list of top-level {..} group contents in s.
local function split_groups(s)
  local groups = {}
  local pos = 1
  while true do
    local s0 = s:find("{", pos, true)
    if not s0 then break end
    local depth, p = 1, s0 + 1
    while depth > 0 and p <= #s do
      local c = s:sub(p, p)
      if c == "{" then depth = depth + 1
      elseif c == "}" then depth = depth - 1 end
      p = p + 1
    end
    if depth ~= 0 then return nil end
    groups[#groups + 1] = s:sub(s0 + 1, p - 2)
    pos = p
  end
  return groups
end

-- read_variant(path): generic parser for a generated payload .def.
-- Returns { header = {lines}, defs = {name -> {group,...}}, names = {...},
--           lines = n }.
function M.read_variant(path)
  local text = read_file(path)
  if not text then return nil, "cannot open " .. path end
  local parsed = { header = {}, defs = {}, names = {}, lines = 0 }
  local n = 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    if line:sub(1, 2) == "%%" then
      parsed.header[#parsed.header + 1] = line:sub(3)
    elseif line:sub(1, 1) == "%" then
      -- section comment
    elseif line:match("^\\expandafter\\def\\csname") then
      local name, rest = line:match(
        "^\\expandafter\\def\\csname ([^ ]+)\\endcsname(.*)$")
      if not name then return nil, "line " .. n .. ": unparseable csname def" end
      local groups = split_groups(rest)
      if not groups then return nil, "line " .. n .. ": unbalanced braces" end
      if parsed.defs[name] then return nil, "line " .. n .. ": duplicate " .. name end
      parsed.defs[name] = groups
      parsed.names[#parsed.names + 1] = name
    elseif line:match("^\\def\\") then
      local name, rest = line:match("^\\def\\([^ {]+)(.*)$")
      if not name then return nil, "line " .. n .. ": unparseable \\def" end
      local groups = split_groups(rest)
      if not groups then return nil, "line " .. n .. ": unbalanced braces" end
      if parsed.defs[name] then return nil, "line " .. n .. ": duplicate " .. name end
      parsed.defs[name] = groups
      parsed.names[#parsed.names + 1] = name
    elseif line:match("^%s*$") then
      -- blank
    else
      return nil, "line " .. n .. ": unrecognized line: " .. line
    end
  end
  parsed.lines = n
  return parsed
end

-- ------------------------------ normalization ------------------------------
local CLASS_FIELDS = {
  chars = true, align = true, width = true, height = true, depth = true,
  left = true, down = true, italic = true, glue = true, kern = true,
  end_adjust = true, round_threshold = true,
}
local TOP_FIELDS = {
  dir = true, zw = true, zh = true, version = true,
  kanjiskip = true, xkanjiskip = true,
}

local PSEUDO_NAMES = {
  alchar = true, nox_alchar = true, parbdd = true, boxbdd = true,
  jcharbdd = true, glue = true,
}

local REQUIRED_ROLES = { "normal", "latin", "paragraph", "box" }
local OPTIONAL_ROLES = { "nox_latin", "glue", "other" }
local ROLE_NAMES = {}
for _, r in ipairs(REQUIRED_ROLES) do ROLE_NAMES[r] = true end
for _, r in ipairs(OPTIONAL_ROLES) do ROLE_NAMES[r] = true end

local VALID_XSPACING = { none = true, pre = true, post = true, both = true }

local function norm_val(a)
  if a == nil or a == false or a == 0 then return 0
  elseif a == true then return 1
  else return a end
end

local function check_number(v, what)
  if type(v) ~= "number" then fail("%s must be a number, got %s", what, type(v)) end
  return v
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function normalize_glue(g, f, t)
  if type(g) ~= "table" then
    fail("pair %d->%d: glue entry must be a table", f, t)
  end
  for k in pairs(g) do
    local ok = (k == 1 or k == 2 or k == 3 or k == 4 or k == 5
      or k == "ratio" or k == "priority"
      or k == "kanjiskip_natural" or k == "kanjiskip_stretch"
      or k == "kanjiskip_shrink")
    if not ok then
      fail("pair %d->%d: unknown glue field %q (extend the generator)",
        f, t, tostring(k))
    end
  end
  local nat = g[1] or 0
  local st = g[2] or 0
  local sh = g[3] or 0
  check_number(nat, string.format("pair %d->%d natural", f, t))
  check_number(st, string.format("pair %d->%d stretch", f, t))
  check_number(sh, string.format("pair %d->%d shrink", f, t))
  local ratio = g.ratio
  if ratio == nil then
    ratio = (g[5] ~= nil) and 0.5 * (1 + g[5]) or 0.5
  end
  check_number(ratio, string.format("pair %d->%d ratio", f, t))
  local pri = g.priority
  local spri, shpri = 0, 0
  if pri ~= nil then
    if type(pri) == "table" then
      spri = pri[1] or 0
      shpri = pri[2] or 0
    elseif type(pri) == "number" then
      -- Scalar priority (LuaTeX-ja numeric priority) means the same
      -- priority on both axes for the pdfTeX data model (plan §5.2).
      spri, shpri = pri, pri
    else
      fail("pair %d->%d: priority must be a number or {stretch,shrink}", f, t)
    end
    check_number(spri, string.format("pair %d->%d stretch priority", f, t))
    check_number(shpri, string.format("pair %d->%d shrink priority", f, t))
  end
  return {
    kind = "glue",
    nat = nat, stretch = st, shrink = sh, ratio = ratio,
    stretch_priority = spri, shrink_priority = shpri,
    kanjiskip_natural = norm_val(g.kanjiskip_natural),
    kanjiskip_stretch = norm_val(g.kanjiskip_stretch),
    kanjiskip_shrink = norm_val(g.kanjiskip_shrink),
  }
end

local function normalize_kern(k, f, t)
  if type(k) == "number" then
    return { kind = "kern", amount = k, ratio = 0.5 }
  elseif type(k) == "table" then
    local amount = k[1] or 0
    check_number(amount, string.format("pair %d->%d kern amount", f, t))
    local ratio = k.ratio
    if ratio == nil then
      ratio = (k[2] ~= nil) and 0.5 * (1 + k[2]) or 0.5
    end
    check_number(ratio, string.format("pair %d->%d kern ratio", f, t))
    for key in pairs(k) do
      if not (key == 1 or key == 2 or key == "ratio") then
        fail("pair %d->%d: unknown kern field %q", f, t, tostring(key))
      end
    end
    return { kind = "kern", amount = amount, ratio = ratio }
  end
  fail("pair %d->%d: kern entry must be a number or a table", f, t)
end

-- classify_chars(jfm, variant, character_semantics)
local function classify_chars(jfm, variant, character_semantics)
  local single = {}      -- [cp] = class
  local single_order = {}
  local combos = {}      -- [class] = { {cp,...}, ... }
  local ajones = {}      -- [class] = { gid, ... }
  local pseudos = {}     -- [name] = class
  local opaque = {}      -- ordered { {cp,...}, class }
  local chars_hex = {}   -- [class] = { token, ... }

  local function add_single(cp, c)
    if single[cp] then
      fail("duplicate char U+%X in classes %d and %d", cp, single[cp], c)
    end
    single[cp] = c
    single_order[#single_order + 1] = cp
  end

  for _, c in ipairs(variant.norm.classes) do
    local list = jfm[c].chars
    if list then
      local hexes = {}
      for _, ch in ipairs(list) do
        if type(ch) == "number" then
          if ch == -1 then
            -- LuaTeX-ja skip marker
          else
            add_single(ch, c)
            hexes[#hexes + 1] = "U+" .. hexn(ch)
          end
        elseif type(ch) == "string" and ch:sub(1, 4) == "AJ1-" then
          local gid = tonumber(ch:sub(5))
          if not gid then fail("bad AJ1 entry %q", ch) end
          ajones[c] = ajones[c] or {}
          ajones[c][#ajones[c] + 1] = gid
          hexes[#hexes + 1] = ch
        elseif type(ch) == "string" and PSEUDO_NAMES[ch] then
          if pseudos[ch] then fail("duplicate pseudo char %q", ch) end
          pseudos[ch] = c
          -- pseudo names have no codepoint: they live in pseudo@<name>
          -- only (chars@<n> stays a U+XXXX / AJ1-<gid> list)
        elseif type(ch) == "string" then
          local n = U.len(ch)
          local star = nil
          if character_semantics == "jfm" and n == 2
              and U.sub(ch, 2, 2) == "*" then
            -- plan §5.2: '，*' is the scalar U+FF0C in jfm semantics;
            -- the trailing '*' is not part of the key.
            star = U.byte(ch, 1)
          end
          if star then
            add_single(star, c)
            hexes[#hexes + 1] = "U+" .. hexn(star)
          elseif n == 1 then
            local cp = U.byte(ch)
            add_single(cp, c)
            hexes[#hexes + 1] = "U+" .. hexn(cp)
          elseif n >= 2 then
            if character_semantics == "jfm" then
              -- Opaque key: never trimmed, never scalar-classified and
              -- never interpreted as a sequence (plan §5.2).
              local cps = {}
              local hs = {}
              for k = 1, n do
                local cp = U.byte(ch, k)
                cps[#cps + 1] = cp
                hs[#hs + 1] = "U+" .. hexn(cp)
              end
              opaque[#opaque + 1] = { cps = cps, class = c }
              hexes[#hexes + 1] = table.concat(hs, ",")
            else
              local cps = {}
              for k = 1, n do cps[#cps + 1] = U.byte(ch, k) end
              combos[c] = combos[c] or {}
              combos[c][#combos[c] + 1] = cps
              local hs = {}
              for _, cp in ipairs(cps) do hs[#hs + 1] = "U+" .. hexn(cp) end
              hexes[#hexes + 1] = table.concat(hs, ",")
            end
          else
            fail("unclassifiable chars entry %q in class %d", ch, c)
          end
        else
          fail("unclassifiable chars entry in class %d", c)
        end
      end
      if #hexes > 0 then chars_hex[c] = hexes end
    end
  end

  -- deterministic ordering of combos by codepoint sequence
  local combo_list = {}
  for _, c in ipairs(variant.norm.classes) do
    local list = combos[c]
    if list then
      table.sort(list, function(a, b)
        for k = 1, math.max(#a, #b) do
          local x, y = a[k] or -1, b[k] or -1
          if x ~= y then return x < y end
        end
        return false
      end)
      for _, seq in ipairs(list) do
        combo_list[#combo_list + 1] = { class = c, cps = seq }
      end
    end
  end
  table.sort(single_order)
  return {
    single = single,
    single_order = single_order,
    combos = combos,
    combo_list = combo_list,
    ajones = ajones,
    pseudos = pseudos,
    opaque = opaque,
    chars_hex = chars_hex,
  }
end

local function normalize_class_metrics(jfm, c, out)
  local v = jfm[c]
  if type(v) ~= "table" then fail("class %d is not a table", c) end
  for k in pairs(v) do
    if not CLASS_FIELDS[k] then
      fail("unknown class field %q in class %d -- extend the generator",
        tostring(k), c)
    end
  end
  if v.left ~= nil and v.left ~= 0 then
    fail("class %d: left must be 0 (got %s); the backend cannot represent it",
      c, tostring(v.left))
  end
  if v.down ~= nil and v.down ~= 0 then
    fail("class %d: down must be 0 (got %s)", c, tostring(v.down))
  end
  if v.italic ~= nil and v.italic ~= 0 then
    fail("class %d: italic must be 0 (got %s)", c, tostring(v.italic))
  end
  local align = v.align or "left"
  if align ~= "left" and align ~= "middle" and align ~= "right" then
    fail("class %d: unknown align %q", c, tostring(align))
  end
  local width = v.width
  if width == nil then width = 1 end
  local height = v.height
  if height == nil then height = 0.88 end
  local depth = v.depth
  if depth == nil then depth = 0.12 end
  check_number(width, string.format("class %d width", c))
  check_number(height, string.format("class %d height", c))
  check_number(depth, string.format("class %d depth", c))
  out.metrics[c] = {
    width = width, height = height, depth = depth,
    align = align, left = 0,
  }
  -- end_adjust is emitted only where the source sets it
  if v.end_adjust ~= nil then
    if type(v.end_adjust) ~= "table" then
      fail("class %d: end_adjust must be a table", c)
    end
    if #v.end_adjust == 0 then
      fail("class %d: end_adjust is set but empty", c)
    end
    local copy = {}
    for i = 1, #v.end_adjust do copy[i] = v.end_adjust[i] end
    table.sort(copy)
    out.end_adjust[c] = copy
  end
  if v.round_threshold ~= nil then
    check_number(v.round_threshold, string.format("class %d round_threshold", c))
  end
  if v.round_threshold ~= nil and out.version >= 3 and c == 0 then
    out.round_threshold[c] = v.round_threshold
  end
end

local function normalize_jfm(variant, jfm, character_semantics)
  if type(jfm) ~= "table" then fail("variant %q: jfm is not a table", variant.id) end
  -- top-level fields
  for k in pairs(jfm) do
    if type(k) == "number" then
      -- class
    elseif not TOP_FIELDS[k] then
      fail("unknown JFM top-level field %q -- extend the generator", tostring(k))
    end
  end
  local zw = check_number(jfm.zw, "jfm.zw")
  local zh = check_number(jfm.zh, "jfm.zh")
  local dir = jfm.dir
  if dir ~= "yoko" and dir ~= "tate" then
    fail("jfm.dir must be 'yoko' or 'tate' (got %s)", tostring(dir))
  end
  if dir ~= variant.dir then
    fail("variant %q: jfm.dir=%s does not match variant dir %s",
      variant.id, dir, variant.dir)
  end
  local version = jfm.version
  if version == nil then version = 1 end
  check_number(version, "jfm.version")
  local ksp = jfm.kanjiskip
  local ksp_present = (ksp ~= nil)
  if not ksp_present then ksp = { 0, 0, 0 } end
  local xksp = jfm.xkanjiskip
  local xksp_present = (xksp ~= nil)
  if not xksp_present then xksp = { 0, 0, 0 } end
  for i = 1, 3 do
    check_number(ksp[i], string.format("jfm.kanjiskip[%d]", i))
    check_number(xksp[i], string.format("jfm.xkanjiskip[%d]", i))
  end

  local e = variant.norm
  e.zw, e.zh, e.dir, e.version = zw, zh, dir, version
  e.kanjiskip = { ksp[1], ksp[2], ksp[3] }
  e.xkanjiskip = { xksp[1], xksp[2], xksp[3] }
  e.kanjiskip_present = ksp_present
  e.xkanjiskip_present = xksp_present

  local classes = {}
  for k in pairs(jfm) do if type(k) == "number" then classes[#classes + 1] = k end end
  table.sort(classes)
  if #classes == 0 then fail("variant %q: JFM has no classes", variant.id) end
  e.classes = classes
  e.metrics = {}
  e.end_adjust = {}
  e.round_threshold = {}
  for _, c in ipairs(classes) do
    normalize_class_metrics(jfm, c, e)
  end

  -- pairs
  e.pairs = {}
  e.pair_list = {}
  for _, f in ipairs(classes) do
    local g = jfm[f].glue or {}
    local k = jfm[f].kern or {}
    if type(g) ~= "table" or type(k) ~= "table" then
      fail("class %d: glue/kern must be tables", f)
    end
    local targets = {}
    for t in pairs(g) do targets[t] = true end
    for t in pairs(k) do
      if g[t] ~= nil then
        fail("pair %d->%d is defined as BOTH glue and kern", f, t)
      end
      targets[t] = true
    end
    local tlist = sorted_keys(targets)
    e.pairs[f] = {}
    for _, t in ipairs(tlist) do
      if type(t) ~= "number" then fail("class %d: non-numeric pair target", f) end
      local rec
      if g[t] ~= nil then
        rec = normalize_glue(g[t], f, t)
      else
        rec = normalize_kern(k[t], f, t)
      end
      e.pairs[f][t] = rec
      e.pair_list[#e.pair_list + 1] = { f = f, t = t, rec = rec }
    end
  end

  e.chars = classify_chars(jfm, variant, character_semantics)
  return e
end

local function validate_roles(variant, classes_set)
  local roles = variant.roles
  if type(roles) ~= "table" then fail("variant %q: roles missing", variant.id) end
  -- top-level optional role spellings are accepted too
  for _, r in ipairs(OPTIONAL_ROLES) do
    if roles[r] == nil and variant[r] ~= nil then roles[r] = variant[r] end
  end
  for r in pairs(roles) do
    if not ROLE_NAMES[r] then fail("variant %q: unknown role %q", variant.id, tostring(r)) end
  end
  for _, r in ipairs(REQUIRED_ROLES) do
    if roles[r] == nil then
      fail("variant %q: required role %q missing", variant.id, r)
    end
  end
  for r, cls in pairs(roles) do
    if type(cls) ~= "number" then
      fail("variant %q: role %q is not a class id", variant.id, r)
    end
    if not classes_set[cls] then
      fail("variant %q: role %q references unknown class %d",
        variant.id, r, cls)
    end
  end
end

local function check_class_map(map, classes_set, what, value_ok)
  local out = {}
  if map == nil then return out end
  if type(map) ~= "table" then fail("%s must be a table", what) end
  for cls, v in pairs(map) do
    if type(cls) ~= "number" then fail("%s: non-numeric class key", what) end
    if not classes_set[cls] then
      fail("%s references unknown class %d", what, cls)
    end
    if value_ok and not value_ok(v) then
      fail("%s: invalid value %s for class %d", what, tostring(v), cls)
    end
    out[cls] = v
  end
  return out
end

local VARIANT_KEYS = {
  id = true, file = true, dir = true, open_bracket_pos = true,
  hanging_punctuation = true, jfm = true, roles = true,
  prebreak = true, postbreak = true, xspacing = true,
  fullwidth_space_adjust = true, family_identity = true, source = true,
  nox_latin = true, glue = true, other = true,
}

local OBP_VALUES = {
  zenkaku_tentsuki = true, zenkakunibu_nibu = true, nibu_tentsuki = true,
}

local function normalize_variant(preset, variant, base_dir, preset_path)
  if type(variant) ~= "table" then fail("preset %s: variant is not a table", preset.id) end
  for k in pairs(variant) do
    if not VARIANT_KEYS[k] then
      fail("preset %s: unknown variant field %q", preset.id, tostring(k))
    end
  end
  if type(variant.id) ~= "string" or variant.id == ""
    or not variant.id:match("^[A-Za-z0-9_]+$") then
    fail("preset %s: invalid variant id %s", preset.id, tostring(variant.id))
  end
  if variant.dir ~= "yoko" and variant.dir ~= "tate" then
    fail("variant %q: dir must be 'yoko' or 'tate'", variant.id)
  end
  if variant.open_bracket_pos ~= nil
    and not OBP_VALUES[variant.open_bracket_pos] then
    fail("variant %q: unknown open_bracket_pos %s",
      variant.id, tostring(variant.open_bracket_pos))
  end
  local variant_norm = {
    id = variant.id,
    dir = variant.dir,
    file = variant.file
      or string.format("pdftexja-jfm-%s-%s-%s.def", preset.id, variant.dir, variant.id),
    open_bracket_pos = variant.open_bracket_pos,
    hanging_punctuation = variant.hanging_punctuation and true or false,
  }
  if not variant_norm.file:match("^[%w%._%-]+$") then
    fail("variant %q: file must be a basename", variant.id)
  end
  variant.norm = variant_norm

  local e = normalize_jfm(variant, variant.jfm, preset.character_semantics)
  local classes_set = {}
  for _, c in ipairs(e.classes) do classes_set[c] = true end

  validate_roles(variant, classes_set)
  variant_norm.roles = {}
  for r, cls in pairs(variant.roles) do variant_norm.roles[r] = cls end
  variant_norm.prebreak = check_class_map(variant.prebreak, classes_set,
    string.format("variant %q prebreak", variant.id),
    function(v) return type(v) == "number" end)
  variant_norm.postbreak = check_class_map(variant.postbreak, classes_set,
    string.format("variant %q postbreak", variant.id),
    function(v) return type(v) == "number" end)
  variant_norm.xspacing = check_class_map(variant.xspacing, classes_set,
    string.format("variant %q xspacing", variant.id),
    function(v) return VALID_XSPACING[v] ~= nil end)
  variant_norm.fullwidth_space_adjust =
    check_class_map(variant.fullwidth_space_adjust, classes_set,
      string.format("variant %q fullwidth_space_adjust", variant.id),
      function(v) return v == true or v == 1 end)
  if variant.family_identity ~= nil then
    local fi = variant.family_identity
    if type(fi) ~= "table" or type(fi.mc) ~= "string" or type(fi.gt) ~= "string" then
      fail("variant %q: family_identity must be {mc=..., gt=...}", variant.id)
    end
    variant_norm.family_identity = { mc = fi.mc, gt = fi.gt }
  elseif preset.composition ~= "single" then
    fail("variant %q: family_identity is required for composition=%s",
      variant.id, preset.composition)
  end

  local src = variant.source
  local src_path, src_name
  if src ~= nil then
    if type(src) ~= "string" then fail("variant %q: source must be a string", variant.id) end
    src_path = (src:sub(1, 1) == "/") and src or (base_dir .. "/" .. src)
    src_name = basename(src)
  else
    src_path = preset_path
    src_name = basename(preset_path)
  end
  variant_norm.source = src_name
  variant_norm.source_sha256 = sha256_hex(src_path)
  if not variant_norm.source_sha256 then
    fail("variant %q: cannot read source %s", variant.id, src_path)
  end
  return variant_norm
end

local function normalize_preset(preset, base_dir, preset_path)
  if type(preset) ~= "table" then fail("preset descriptor did not return a table") end
  if preset.format ~= 1 then
    fail("preset %s: format must be 1", tostring(preset.id))
  end
  if type(preset.id) ~= "string" or not preset.id:match("^[A-Za-z0-9_%-]+$") then
    fail("preset: invalid id %s", tostring(preset.id))
  end
  local COMP = { single = true, paverage = true, both = true }
  if not COMP[preset.composition] then
    fail("preset %s: composition must be single|paverage|both", preset.id)
  end
  local BS = { existing = true, jfm = true }
  if not BS[preset.boundary_semantics] then
    fail("preset %s: boundary_semantics must be existing|jfm", preset.id)
  end
  local CS = { sequence = true, jfm = true }
  if not CS[preset.character_semantics] then
    fail("preset %s: character_semantics must be sequence|jfm", preset.id)
  end
  if type(preset.variants) ~= "table" or #preset.variants == 0 then
    fail("preset %s: variants missing", preset.id)
  end
  preset.base_dir = base_dir
  preset.path = preset_path
  local seen = {}
  local variants = {}
  for _, v in ipairs(preset.variants) do
    local nv = normalize_variant(preset, v, base_dir, preset_path)
    local key = nv.id .. "@" .. nv.dir
    if seen[key] then fail("preset %s: duplicate variant (id=%s, dir=%s)",
      preset.id, nv.id, nv.dir) end
    seen[key] = true
    variants[#variants + 1] = nv
  end
  preset.norm_variants = variants
  -- index-level consistency: one class set and one policy per preset
  local ref = variants[1]
  local function same_map(a, b)
    local keys = {}
    for k in pairs(a) do keys[k] = true end
    for k in pairs(b) do
      if not a[k] then return false end
    end
    for k in pairs(a) do
      if b[k] ~= a[k] then return false end
    end
    return true
  end
  -- Direction variants may carry different class sets (the LuaTeX-ja
  -- yoko/tate JFMs do), so the preset-wide index uses the union of the
  -- classes and a merged policy map.  Two variants must however agree on
  -- every policy value they both define.
  local union = {}
  for _, v in ipairs(variants) do
    for _, c in ipairs(v.classes) do union[c] = true end
    if not same_map(ref.roles or {}, v.roles or {}) then
      fail("preset %s: variant %s@%s has a different roles map than %s@%s",
        preset.id, v.id, v.dir, ref.id, ref.dir)
    end
  end
  local union_list = {}
  for c in pairs(union) do union_list[#union_list + 1] = c end
  table.sort(union_list)
  preset.classes = union_list
  preset.roles = ref.roles
  for _, field in ipairs({ "prebreak", "postbreak", "xspacing",
      "fullwidth_space_adjust" }) do
    local merged = {}
    for _, v in ipairs(variants) do
      for k, val in pairs(v[field]) do
        if merged[k] ~= nil and merged[k] ~= val then
          fail("preset %s: conflicting %s value for class %d (%s vs %s)",
            preset.id, field, k, tostring(merged[k]), tostring(val))
        end
        merged[k] = val
      end
    end
    preset[field] = merged
  end
  return preset
end

function M.load_preset(path)
  local abs = absolute(path)
  local base_dir = dirname(abs)
  local chunk, err = loadfile(abs)
  if not chunk then fail("cannot load preset %s: %s", path, tostring(err)) end
  local fn = chunk()
  if type(fn) ~= "function" then
    fail("%s must return function(base_dir) ... return preset end", path)
  end
  local preset = fn(base_dir)
  return normalize_preset(preset, base_dir, abs)
end

-- ------------------------------ serialization ------------------------------
local function prefix_for(preset, v)
  return "pdftexja@data@" .. preset.id .. "@" .. v.id .. "@" .. v.dir .. "@"
end

local function emit_header(out, kind, preset, v)
  out[#out + 1] = "%% pdftexja JFM " .. kind .. ": preset " .. preset.id
    .. (v and (", variant " .. v.id .. ", direction " .. v.dir) or "")
  out[#out + 1] = "%% generated by pdftexja-jfm-lib.lua " .. GEN_VERSION
    .. " -- DO NOT EDIT; regenerate with `make jfm`"
  if v then
    out[#out + 1] = "%% source: " .. v.source
    out[#out + 1] = "%% source sha256: " .. v.source_sha256
    out[#out + 1] = "%% options: preset=" .. preset.id
      .. " variant=" .. v.id .. " dir=" .. v.dir
      .. " open_bracket_pos=" .. tostring(v.open_bracket_pos)
      .. " hanging_punctuation=" .. tostring(v.hanging_punctuation)
      .. " composition=" .. preset.composition
      .. " boundary_semantics=" .. preset.boundary_semantics
      .. " character_semantics=" .. preset.character_semantics
  end
  out[#out + 1] = "%% deterministic: sorted keys, %.6f fixed decimals, no timestamps"
  out[#out + 1] = "%% loader contract: \\makeatletter (catcode @ = 11) before \\input;"
  out[#out + 1] = "%%   standard catcodes otherwise; the file does not restore them."
  out[#out + 1] = "%%   Retrieval of digit-bearing names needs \\csname + \\edef."
  if v then
    out[#out + 1] = "%% all lengths are in zw units (jfm.zw = " .. num(v.zw) .. ")"
  end
end

local function render_payload(preset, v)
  local out = {}
  emit_header(out, "payload", preset, v)
  local P = prefix_for(preset, v)
  defop(out, P .. "dir", v.dir)
  defop(out, P .. "zw", num(v.zw))
  defop(out, P .. "zh", num(v.zh))
  defop(out, P .. "version", tostring(v.version))
  defop(out, P .. "kanjiskip",
    "{" .. num(v.kanjiskip[1]) .. "}{" .. num(v.kanjiskip[2])
    .. "}{" .. num(v.kanjiskip[3]) .. "}")
  defop(out, P .. "xkanjiskip",
    "{" .. num(v.xkanjiskip[1]) .. "}{" .. num(v.xkanjiskip[2])
    .. "}{" .. num(v.xkanjiskip[3]) .. "}")
  defop(out, P .. "classlist", table.concat(v.classes, ","))
  out[#out + 1] = ""

  out[#out + 1] = "% ---- class metrics: " .. P .. "class@<n>{{w}{h}{d}{align}{left}}"
  for _, c in ipairs(v.classes) do
    local m = v.metrics[c]
    defop(out, P .. "class@" .. c,
      string.format("{%s}{%s}{%s}{%s}{%s}", num(m.width), num(m.height),
        num(m.depth), m.align, num(m.left)))
  end

  local ea_classes = sorted_keys(v.end_adjust)
  if #ea_classes > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- end_adjust (sorted ascending; absent classes are not emitted)"
    for _, c in ipairs(ea_classes) do
      local body = {}
      for _, x in ipairs(v.end_adjust[c]) do body[#body + 1] = "{" .. num(x) .. "}" end
      defop(out, P .. "endadj@" .. c, table.concat(body))
    end
  end

  local rt_classes = sorted_keys(v.round_threshold)
  if #rt_classes > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- active round_threshold (source version >= 3, real class 0)"
    for _, c in ipairs(rt_classes) do
      defop(out, P .. "round@" .. c, num(v.round_threshold[c]))
    end
  end

  out[#out + 1] = ""
  out[#out + 1] = "% ---- full char lists per class (debug/verification; dispatch is cls@<hex>)"
  for _, c in ipairs(v.classes) do
    if v.chars.chars_hex[c] then
      defop(out, P .. "chars@" .. c, table.concat(v.chars.chars_hex[c], " "))
    end
  end

  out[#out + 1] = ""
  out[#out + 1] = "% ---- char -> class dispatch (single-codepoint chars), sorted by cp"
  for _, cp in ipairs(v.chars.single_order) do
    defop(out, P .. "cls@" .. hexn(cp), tostring(v.chars.single[cp]))
  end

  if #v.chars.combo_list > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- multi-codepoint sequences (combos) per class"
    for _, c in ipairs(v.classes) do
      local list = v.chars.combos[c]
      if list then
        local items = {}
        for _, seq in ipairs(list) do
          local hs = {}
          for _, cp in ipairs(seq) do hs[#hs + 1] = "U+" .. hexn(cp) end
          items[#items + 1] = table.concat(hs, ",")
        end
        defop(out, P .. "combo@" .. c, table.concat(items, " "))
      end
    end
  end

  local aj_classes = sorted_keys(v.chars.ajones)
  if #aj_classes > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- Adobe-Japan1 glyph ids per class"
    for _, c in ipairs(aj_classes) do
      local list = v.chars.ajones[c]
      table.sort(list)
      local items = {}
      for _, gid in ipairs(list) do items[#items + 1] = "{" .. gid .. "}" end
      defop(out, P .. "ajone@" .. c, table.concat(items))
    end
  end

  local pseudo_names = sorted_keys(v.chars.pseudos)
  if #pseudo_names > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- pseudo chars (not codepoints): alchar=latin run, parbdd/boxbdd=bounds"
    for _, name in ipairs(pseudo_names) do
      defop(out, P .. "pseudo@" .. name, tostring(v.chars.pseudos[name]))
    end
  end

  if #v.chars.opaque > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- opaque multi-codepoint keys (character_semantics=jfm):"
    out[#out + 1] = "% ---- never trimmed, never scalar-classified, never sequences"
    for i, op in ipairs(v.chars.opaque) do
      local hs = {}
      for _, cp in ipairs(op.cps) do hs[#hs + 1] = "U+" .. hexn(cp) end
      defop(out, P .. "opaque@" .. (i - 1),
        "{" .. op.class .. "}{" .. table.concat(hs, ",") .. "}")
    end
  end

  out[#out + 1] = ""
  out[#out + 1] = "% ---- pair data: " .. P .. "pair@<from>@<to>"
  out[#out + 1] = "% ----   body is \\pdftexja@data@glue{9 args} or \\pdftexja@data@kern{2 args}"
  out[#out + 1] = "% ---- full table: every defined pair of the source JFM"
  for _, p in ipairs(v.pair_list) do
    local name = P .. "pair@" .. p.f .. "@" .. p.t
    local body
    if p.rec.kind == "glue" then
      body = string.format(
        "\\pdftexja@data@glue{%s}{%s}{%s}{%s}{%d}{%d}{%d}{%d}{%d}",
        num(p.rec.nat), num(p.rec.stretch), num(p.rec.shrink),
        num(p.rec.ratio), p.rec.stretch_priority, p.rec.shrink_priority,
        p.rec.kanjiskip_natural, p.rec.kanjiskip_stretch,
        p.rec.kanjiskip_shrink)
    else
      body = string.format("\\pdftexja@data@kern{%s}{%s}",
        num(p.rec.amount), num(p.rec.ratio))
    end
    defop(out, name, body)
  end
  out[#out + 1] = ""
  out[#out + 1] = "%% end of payload"
  return table.concat(out, "\n") .. "\n"
end

local function render_index(preset)
  local out = {}
  emit_header(out, "index", preset, nil)
  out[#out + 1] = "%% sources:"
  for _, v in ipairs(preset.norm_variants) do
    out[#out + 1] = "%%   " .. v.dir .. "/" .. v.id .. ": " .. v.source
      .. " sha256 " .. v.source_sha256
  end
  local P = "pdftexja@jfm@"
  defop(out, P .. "preset", preset.id)
  defop(out, P .. "composition", preset.composition)
  defop(out, P .. "boundarysemantics", preset.boundary_semantics)
  defop(out, P .. "charactersemantics", preset.character_semantics)
  for _, r in ipairs(REQUIRED_ROLES) do
    defop(out, P .. "role@" .. r, tostring(preset.roles[r]))
  end
  for _, r in ipairs(OPTIONAL_ROLES) do
    if preset.roles[r] ~= nil then
      defop(out, P .. "role@" .. r, tostring(preset.roles[r]))
    end
  end
  out[#out + 1] = ""
  out[#out + 1] = "% ---- line-start / line-end penalties per class (absent = 0)"
  for _, c in ipairs(preset.classes) do
    defop(out, P .. "kin@pre@" .. c, tostring(preset.prebreak[c] or 0))
  end
  for _, c in ipairs(preset.classes) do
    defop(out, P .. "kin@post@" .. c, tostring(preset.postbreak[c] or 0))
  end
  out[#out + 1] = ""
  out[#out + 1] = "% ---- Latin<->JA xspacing permission per class (absent = both)"
  for _, c in ipairs(preset.classes) do
    defop(out, P .. "xsp@" .. c, preset.xspacing[c] or "both")
  end
  out[#out + 1] = ""
  out[#out + 1] = "% ---- full-width-space adjustment classes (only true entries)"
  local fw = sorted_keys(preset.fullwidth_space_adjust)
  for _, c in ipairs(fw) do
    defop(out, P .. "fullwidthspace@" .. c, "1")
  end
  local fi = preset.norm_variants[1].family_identity
  if fi then
    out[#out + 1] = ""
    out[#out + 1] = "% ---- family metric identity"
    defop(out, P .. "famid@mc", fi.mc)
    defop(out, P .. "famid@gt", fi.gt)
    -- direction-qualified identity (same information, keyed by axis)
    local seen = {}
    for _, v in ipairs(preset.norm_variants) do
      if not seen[v.dir] then
        seen[v.dir] = true
        if v.family_identity then
          defop(out, P .. "famid@" .. v.dir .. "@mc", v.family_identity.mc)
          defop(out, P .. "famid@" .. v.dir .. "@gt", v.family_identity.gt)
        end
      end
    end
  end
  out[#out + 1] = ""
  out[#out + 1] = "% ---- selection axis -> payload basename"
  for _, v in ipairs(preset.norm_variants) do
    defop(out, P .. "index@file@" .. v.id .. "@" .. v.dir, v.file)
  end
  out[#out + 1] = ""
  out[#out + 1] = "%% end of index"
  return table.concat(out, "\n") .. "\n"
end

-- render(preset): in-memory rendering, used by generate() and check().
function M.render(preset)
  if not preset.norm_variants then
    fail("render() requires a preset from load_preset()")
  end
  local files = {}
  local asset_names = {}
  for _, v in ipairs(preset.norm_variants) do
    local text = render_payload(preset, v)
    files[#files + 1] = { name = v.file, text = text }
    asset_names[#asset_names + 1] = v.file
  end
  local index_name = "pdftexja-jfm-" .. preset.id .. ".def"
  files[#files + 1] = { name = index_name, text = render_index(preset) }
  asset_names[#asset_names + 1] = index_name
  table.sort(asset_names)
  files.assets = asset_names
  return files
end

local sha256_text

local function render_manifest(preset, files)
  local out = {}
  local function a(s) out[#out + 1] = s end
  a("-- pdftexja-jfm-" .. preset.id .. "-manifest.lua --- generated by pdftexja-jfm-lib.lua " .. GEN_VERSION)
  a("-- DO NOT EDIT; regenerate with `make jfm`.")
  a("-- Semantic manifest: preset metadata, per-variant source/hash, class")
  a("-- metrics, policy maps and payload digests.  The runtime reads the")
  a("-- payload/index .def files; this file is build-time data only.")
  a("return {")
  a("  format = " .. preset.format .. ",")
  a("  gen_version = " .. lua_str(GEN_VERSION) .. ",")
  a("  id = " .. lua_str(preset.id) .. ",")
  a("  composition = " .. lua_str(preset.composition) .. ",")
  a("  boundary_semantics = " .. lua_str(preset.boundary_semantics) .. ",")
  a("  character_semantics = " .. lua_str(preset.character_semantics) .. ",")
  a("  preset_file = " .. lua_str(basename(preset.path or "")) .. ",")
  a("  preset_sha256 = " .. lua_str(sha256_hex(preset.path or "") or "") .. ",")
  a("  assets = {")
  local digest = {}
  for _, f in ipairs(files) do digest[f.name] = f.text end
  for _, name in ipairs(files.assets) do
    a("    " .. lua_str(name) .. ",")
  end
  a("  },")
  a("  variants = {")
  for _, v in ipairs(preset.norm_variants) do
    a("    {")
    a("      id = " .. lua_str(v.id) .. ",")
    a("      dir = " .. lua_str(v.dir) .. ",")
    a("      file = " .. lua_str(v.file) .. ",")
    if v.open_bracket_pos == nil then
      a("      open_bracket_pos = nil,")
    else
      a("      open_bracket_pos = " .. lua_str(v.open_bracket_pos) .. ",")
    end
    a("      hanging_punctuation = " .. tostring(v.hanging_punctuation) .. ",")
    a("      source = " .. lua_str(v.source) .. ",")
    a("      source_sha256 = " .. lua_str(v.source_sha256) .. ",")
    a("      version = " .. v.version .. ",")
    a("      zw = " .. num(v.zw) .. ", zh = " .. num(v.zh) .. ",")
    a("      kanjiskip_present = " .. tostring(v.kanjiskip_present) .. ",")
    a("      xkanjiskip_present = " .. tostring(v.xkanjiskip_present) .. ",")
    a("      classes = { " .. table.concat(v.classes, ", ") .. " },")
    a("      roles = {")
    for _, r in ipairs(REQUIRED_ROLES) do
      a("        " .. r .. " = " .. v.roles[r] .. ",")
    end
    for _, r in ipairs(OPTIONAL_ROLES) do
      if v.roles[r] ~= nil then a("        " .. r .. " = " .. v.roles[r] .. ",") end
    end
    a("      },")
    local function map_emit(name, map, quote)
      local ks = sorted_keys(map)
      if #ks == 0 then
        a("      " .. name .. " = {},")
      else
        a("      " .. name .. " = {")
        for _, k in ipairs(ks) do
          local val = map[k]
          a(string.format("        [%d] = %s,", k,
            quote and lua_str(val) or tostring(val)))
        end
        a("      },")
      end
    end
    map_emit("prebreak", v.prebreak, false)
    map_emit("postbreak", v.postbreak, false)
    map_emit("xspacing", v.xspacing, true)
    map_emit("fullwidth_space_adjust", v.fullwidth_space_adjust, false)
    if v.family_identity then
      a("      family_identity = { mc = " .. lua_str(v.family_identity.mc)
        .. ", gt = " .. lua_str(v.family_identity.gt) .. " },")
    end
    a("      metrics = {")
    for _, c in ipairs(v.classes) do
      local m = v.metrics[c]
      a(string.format("        [%d] = { %s, %s, %s, %s, %s },", c,
        num(m.width), num(m.height), num(m.depth), lua_str(m.align), num(m.left)))
    end
    a("      },")
    local ea = sorted_keys(v.end_adjust)
    if #ea == 0 then
      a("      end_adjust = {},")
    else
      a("      end_adjust = {")
      for _, c in ipairs(ea) do
        local xs = {}
        for _, x in ipairs(v.end_adjust[c]) do xs[#xs + 1] = num(x) end
        a("        [" .. c .. "] = { " .. table.concat(xs, ", ") .. " },")
      end
      a("      },")
    end
    local pc = 0
    for _, list in pairs(v.pairs) do for _ in pairs(list) do pc = pc + 1 end end
    a("      pair_count = " .. pc .. ",")
    a("      char_count = " .. #v.chars.single_order .. ",")
    a("      combo_count = " .. #v.chars.combo_list .. ",")
    local naj = 0
    for _, l in pairs(v.chars.ajones) do naj = naj + #l end
    a("      ajone_count = " .. naj .. ",")
    local npse = 0
    for _ in pairs(v.chars.pseudos) do npse = npse + 1 end
    a("      pseudo_count = " .. npse .. ",")
    a("      opaque_count = " .. #v.chars.opaque .. ",")
    a("      payload_sha256 = " .. lua_str(sha256_text(digest[v.file])) .. ",")
    a("    },")
  end
  a("  },")
  a("}")
  return table.concat(out, "\n") .. "\n"
end

-- sha256 of a string (no file wrapper)
function sha256_text(data)
  if not sha2 then
    local ok = pcall(require, "lualibs")
    if not ok then pcall(require, "sha2") end
  end
  if not sha2 then fail("pdftexja-jfm-lib: sha256 support is unavailable") end
  local raw = sha2.digest256(data)
  return (raw:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function render_assets(preset, names)
  local var = "PDFTEXJA_JFM_" .. preset.id:gsub("%-", "_") .. "_ASSETS"
  local lines = { var .. " := \\" }
  for i, name in ipairs(names) do
    if i < #names then
      lines[#lines + 1] = "\t" .. name .. " \\"
    else
      lines[#lines + 1] = "\t" .. name
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

function M.generate(preset, outdir, manifest_path, assets_path)
  outdir = outdir or "."
  mkdir_p(outdir)
  local files = M.render(preset)
  for _, f in ipairs(files) do
    write_file(outdir .. "/" .. f.name, f.text)
  end
  if manifest_path then
    write_file(manifest_path, render_manifest(preset, files))
  end
  if assets_path then
    write_file(assets_path, render_assets(preset, files.assets))
  end
  return files.assets
end

-- ------------------------------ checking -----------------------------------
local function expected_glue_body(rec)
  return string.format("\\pdftexja@data@glue{%s}{%s}{%s}{%s}{%d}{%d}{%d}{%d}{%d}",
    num(rec.nat), num(rec.stretch), num(rec.shrink), num(rec.ratio),
    rec.stretch_priority, rec.shrink_priority, rec.kanjiskip_natural,
    rec.kanjiskip_stretch, rec.kanjiskip_shrink)
end

local function expected_kern_body(rec)
  return string.format("\\pdftexja@data@kern{%s}{%s}", num(rec.amount), num(rec.ratio))
end

local function check_payload_text(preset, v, text, errors)
  local P = prefix_for(preset, v)
  local defs, names = {}, {}
  local n = 0
  local header = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    if line:sub(1, 2) == "%%" then
      header[#header + 1] = line:sub(3)
    elseif line:sub(1, 1) == "%" then
    elseif line:match("^\\expandafter\\def\\csname") then
      local name, rest = line:match(
        "^\\expandafter\\def\\csname ([^ ]+)\\endcsname(.*)$")
      if not name then errors[#errors + 1] = "payload line " .. n .. ": bad csname def" 
      else
        local g = split_groups(rest)
        if not g then errors[#errors + 1] = "payload line " .. n .. ": unbalanced braces"
        else
          if defs[name] then errors[#errors + 1] = "duplicate def " .. name end
          defs[name] = g
          names[#names + 1] = name
        end
      end
    elseif line:match("^\\def\\") then
      local name, rest = line:match("^\\def\\([^ {]+)(.*)$")
      if not name then errors[#errors + 1] = "payload line " .. n .. ": bad \\def"
      else
        local g = split_groups(rest)
        if not g then errors[#errors + 1] = "payload line " .. n .. ": unbalanced braces"
        else
          if defs[name] then errors[#errors + 1] = "duplicate def " .. name end
          defs[name] = g
          names[#names + 1] = name
        end
      end
    elseif line:match("^%s*$") then
    else
      errors[#errors + 1] = "payload line " .. n .. ": unrecognized: " .. line
    end
  end
  local h = table.concat(header, "\n")
  local tag = v.id .. "@" .. v.dir
  local function must(cond, msg)
    if not cond then errors[#errors + 1] = "payload " .. tag .. ": " .. msg end
  end
  must(h:find("source: " .. v.source, 1, true), "source basename mismatch")
  must(h:find("source sha256: " .. v.source_sha256, 1, true), "source sha256 mismatch")
  must(h:find("generated by pdftexja-jfm-lib.lua " .. GEN_VERSION, 1, true),
    "generator version line missing")
  must(h:find("character_semantics=" .. preset.character_semantics, 1, true),
    "options line mismatch")

  local function d(name) return defs[P .. name] end
  local function body(name)
    local g = d(name)
    return g and g[1]
  end

  -- metrics
  must(body("dir") == v.dir, "dir mismatch")
  must(body("zw") == num(v.zw), "zw mismatch")
  must(body("zh") == num(v.zh), "zh mismatch")
  must(body("version") == tostring(v.version), "version mismatch")
  local ks = split_groups(body("kanjiskip") or "")
  local xs = split_groups(body("xkanjiskip") or "")
  must(ks and ks[1] == num(v.kanjiskip[1]) and ks[2] == num(v.kanjiskip[2])
    and ks[3] == num(v.kanjiskip[3]), "kanjiskip mismatch")
  must(xs and xs[1] == num(v.xkanjiskip[1]) and xs[2] == num(v.xkanjiskip[2])
    and xs[3] == num(v.xkanjiskip[3]), "xkanjiskip mismatch")
  local cl = body("classlist")
  local expected_cl = table.concat(v.classes, ",")
  must(cl == expected_cl, "classlist mismatch (got " .. tostring(cl)
    .. ", want " .. expected_cl .. ")")
  for _, c in ipairs(v.classes) do
    local m = v.metrics[c]
    local g = split_groups(body("class@" .. c) or "")
    must(g and g[1] == num(m.width) and g[2] == num(m.height)
      and g[3] == num(m.depth) and g[4] == m.align and g[5] == num(m.left),
      "class " .. c .. " metrics mismatch")
    local ea = v.end_adjust[c]
    local ge = body("endadj@" .. c)
    if ea then
      local inner = ge and split_groups(ge)
      must(inner and #inner == #ea, "class " .. c .. " end_adjust mismatch")
      if inner then
        for k = 1, #ea do
          must(inner[k] == num(ea[k]), "class " .. c .. " end_adjust[" .. k .. "] mismatch")
        end
      end
    else
      must(ge == nil, "class " .. c .. " has endadj but no source end_adjust")
    end
  end

  -- dispatch coverage against the normalized source
  for cp, c in pairs(v.chars.single) do
    must(body("cls@" .. hexn(cp)) == tostring(c),
      string.format("char U+%X dispatch mismatch", cp))
  end
  local ncls = 0
  for _, name in ipairs(names) do
    if name:match("^" .. P:gsub("%-", "%%-") .. "cls@") then ncls = ncls + 1 end
  end
  local nsingle = 0
  for _ in pairs(v.chars.single) do nsingle = nsingle + 1 end
  must(ncls == nsingle, "extra cls@ dispatch entries")
  for _, seq in ipairs(v.chars.combo_list) do
    local hs = {}
    for _, cp in ipairs(seq.cps) do hs[#hs + 1] = "U+" .. hexn(cp) end
    local want = table.concat(hs, ",")
    local b = body("combo@" .. seq.class)
    local found = false
    if b then for item in b:gmatch("%S+") do if item == want then found = true end end end
    must(found, "combo " .. want .. " missing from class " .. seq.class)
  end
  for _, c in ipairs(v.classes) do
    local list = v.chars.ajones[c]
    if list then
      local b = body("ajone@" .. c)
      local inner = b and split_groups(b)
      must(inner ~= nil, "ajone missing for class " .. c)
      if inner then
        local set = {}
        for _, x in ipairs(inner) do set[x] = true end
        for _, gid in ipairs(list) do
          must(set[tostring(gid)], "AJ1 " .. gid .. " missing from class " .. c)
        end
      end
    end
  end
  for name, c in pairs(v.chars.pseudos) do
    must(body("pseudo@" .. name) == tostring(c), "pseudo " .. name .. " mismatch")
  end
  for i, op in ipairs(v.chars.opaque) do
    local hs = {}
    for _, cp in ipairs(op.cps) do hs[#hs + 1] = "U+" .. hexn(cp) end
    local want = "{" .. op.class .. "}{" .. table.concat(hs, ",") .. "}"
    must(body("opaque@" .. (i - 1)) == want, "opaque key " .. i .. " mismatch")
  end
  local nopaque = 0
  for _, name in ipairs(names) do
    if name:match("^" .. P:gsub("%-", "%%-") .. "opaque@") then nopaque = nopaque + 1 end
  end
  must(nopaque == #v.chars.opaque, "extra opaque entries")

  -- pairs, independently from the normalized source
  local npairs = 0
  for _, p in ipairs(v.pair_list) do
    npairs = npairs + 1
    local b = body("pair@" .. p.f .. "@" .. p.t)
    local want = (p.rec.kind == "glue") and expected_glue_body(p.rec)
      or expected_kern_body(p.rec)
    must(b == want, string.format("pair %d->%d mismatch (got %s, want %s)",
      p.f, p.t, tostring(b), want))
  end
  local ndefpairs = 0
  for _, name in ipairs(names) do
    if name:match("^" .. P:gsub("%-", "%%-") .. "pair@") then ndefpairs = ndefpairs + 1 end
  end
  must(ndefpairs == npairs, string.format("extra pairs (%d defined, %d expected)",
    ndefpairs, npairs))

  -- family sanity: every def belongs to the documented families
  local fams = {}
  for _, name in ipairs(names) do
    local fam = name:match("^" .. P:gsub("%-", "%%-") .. "([%w]+)")
    if fam then fams[fam] = true end
  end
  local okfams = {
    dir = true, zw = true, zh = true, version = true,
    kanjiskip = true, xkanjiskip = true, classlist = true,
    class = true, endadj = true, round = true, chars = true, cls = true,
    combo = true, ajone = true, pseudo = true, opaque = true, pair = true,
  }
  for f in pairs(fams) do
    if not okfams[f] then errors[#errors + 1] = "payload " .. tag .. ": unknown macro family " .. f end
  end
end

local function check_index_text(preset, text, errors)
  local parsed, perr = (function()
    local fname = os.tmpname()
    local f = io.open(fname, "wb"); f:write(text); f:close()
    local r, e = M.read_variant(fname)
    os.remove(fname)
    return r, e
  end)()
  if not parsed then
    errors[#errors + 1] = "index: " .. tostring(perr)
    return
  end
  local P = "pdftexja@jfm@"
  local function b(name)
    local g = parsed.defs[P .. name]
    return g and g[1]
  end
  local function must(cond, msg)
    if not cond then errors[#errors + 1] = "index: " .. msg end
  end
  local P_roles = preset.roles
  must(b("preset") == preset.id, "preset mismatch")
  must(b("composition") == preset.composition, "composition mismatch")
  must(b("boundarysemantics") == preset.boundary_semantics, "boundary_semantics mismatch")
  must(b("charactersemantics") == preset.character_semantics, "character_semantics mismatch")
  for _, r in ipairs(REQUIRED_ROLES) do
    must(b("role@" .. r) == tostring(P_roles[r]), "role " .. r .. " mismatch")
  end
  for _, r in ipairs(OPTIONAL_ROLES) do
    if P_roles[r] ~= nil then
      must(b("role@" .. r) == tostring(P_roles[r]), "role " .. r .. " mismatch")
    else
      must(parsed.defs[P .. "role@" .. r] == nil, "unexpected optional role " .. r)
    end
  end
  for _, c in ipairs(preset.classes) do
    must(b("kin@pre@" .. c) == tostring(preset.prebreak[c] or 0),
      "kin@pre@" .. c .. " mismatch")
    must(b("kin@post@" .. c) == tostring(preset.postbreak[c] or 0),
      "kin@post@" .. c .. " mismatch")
    must(b("xsp@" .. c) == (preset.xspacing[c] or "both"),
      "xsp@" .. c .. " mismatch")
  end
  for _, c in ipairs(sorted_keys(preset.fullwidth_space_adjust)) do
    must(b("fullwidthspace@" .. c) == "1", "fullwidthspace@" .. c .. " mismatch")
  end
  local nfw = 0
  for _, name in ipairs(parsed.names) do
    if name:match("^pdftexja@jfm@fullwidthspace@") then nfw = nfw + 1 end
  end
  local nfwe = 0
  for _ in pairs(preset.fullwidth_space_adjust) do nfwe = nfwe + 1 end
  must(nfw == nfwe, "extra fullwidthspace entries")
  local fi = preset.norm_variants[1].family_identity
  if fi then
    must(b("famid@mc") == fi.mc, "famid@mc mismatch")
    must(b("famid@gt") == fi.gt, "famid@gt mismatch")
    local seen = {}
    for _, v in ipairs(preset.norm_variants) do
      if v.family_identity and not seen[v.dir] then
        seen[v.dir] = true
        must(b("famid@" .. v.dir .. "@mc") == v.family_identity.mc,
          "famid@" .. v.dir .. "@mc mismatch")
        must(b("famid@" .. v.dir .. "@gt") == v.family_identity.gt,
          "famid@" .. v.dir .. "@gt mismatch")
      end
    end
  else
    must(parsed.defs[P .. "famid@mc"] == nil, "unexpected famid@mc")
    must(parsed.defs[P .. "famid@gt"] == nil, "unexpected famid@gt")
  end
  for _, v in ipairs(preset.norm_variants) do
    must(b("index@file@" .. v.id .. "@" .. v.dir) == v.file,
      "index@file@" .. v.id .. "@" .. v.dir .. " mismatch")
  end
end

local function parse_assets(path)
  local text = read_file(path)
  if not text then return nil, "cannot read " .. path end
  local aid, body = text:match("^PDFTEXJA_JFM_([%w_]+)_ASSETS%s*:=%s*(.*)$")
  if not aid then return nil, "missing PDFTEXJA_JFM_<id>_ASSETS assignment" end
  local names = {}
  for tok in body:gmatch("[^%s\\]+") do
    names[#names + 1] = tok
  end
  table.sort(names)
  return names, aid
end

local function check_manifest(preset, files, manifest_path, errors)
  local ok, manifest = pcall(dofile, manifest_path)
  if not ok then
    errors[#errors + 1] = "manifest: cannot load " .. manifest_path .. ": "
      .. tostring(manifest)
    return
  end
  if type(manifest) ~= "table" then
    errors[#errors + 1] = "manifest: not a Lua table"
    return
  end
  local function must(cond, msg)
    if not cond then errors[#errors + 1] = "manifest: " .. msg end
  end
  must(manifest.format == 1, "format must be 1")
  must(manifest.gen_version == GEN_VERSION, "gen_version mismatch")
  must(manifest.id == preset.id, "id mismatch")
  must(manifest.composition == preset.composition, "composition mismatch")
  must(manifest.boundary_semantics == preset.boundary_semantics, "boundary_semantics mismatch")
  must(manifest.character_semantics == preset.character_semantics, "character_semantics mismatch")
  local assets = manifest.assets or {}
  must(#assets == #files.assets, "asset list length mismatch")
  for i = 1, math.min(#assets, #files.assets) do
    must(assets[i] == files.assets[i], "asset[" .. i .. "] mismatch")
  end
  local seen = {}
  for _, mv in ipairs(manifest.variants or {}) do
    seen[tostring(mv.id) .. "@" .. tostring(mv.dir)] = mv
  end
  for _, v in ipairs(preset.norm_variants) do
    local key = v.id .. "@" .. v.dir
    local mv = seen[key]
    must(mv ~= nil, "variant " .. key .. " missing")
    if mv then
      must(mv.file == v.file, "variant " .. key .. " file mismatch")
      must(mv.source == v.source, "variant " .. key .. " source mismatch")
      must(mv.source_sha256 == v.source_sha256, "variant " .. key .. " source_sha256 mismatch")
      must(mv.version == v.version, "variant " .. key .. " version mismatch")
      must(num(mv.zw) == num(v.zw) and num(mv.zh) == num(v.zh),
        "variant " .. key .. " zw/zh mismatch")
      must(mv.kanjiskip_present == v.kanjiskip_present,
        "variant " .. key .. " kanjiskip presence mismatch")
      must(mv.xkanjiskip_present == v.xkanjiskip_present,
        "variant " .. key .. " xkanjiskip presence mismatch")
      local cls = mv.classes or {}
      must(#cls == #v.classes, "variant " .. key .. " class count mismatch")
      for i = 1, math.min(#cls, #v.classes) do
        must(cls[i] == v.classes[i], "variant " .. key .. " class[" .. i .. "] mismatch")
      end
      for _, r in ipairs(REQUIRED_ROLES) do
        must(mv.roles and mv.roles[r] == v.roles[r],
          "variant " .. key .. " role " .. r .. " mismatch")
      end
      for _, r in ipairs(OPTIONAL_ROLES) do
        local want = v.roles[r]
        local got = mv.roles and mv.roles[r]
        must(got == want, "variant " .. key .. " role " .. r .. " mismatch")
      end
      for _, mname in ipairs({ "prebreak", "postbreak", "xspacing",
          "fullwidth_space_adjust" }) do
        local got = mv[mname] or {}
        local want = v[mname]
        local keys = {}
        for k in pairs(want) do keys[k] = true end
        for k in pairs(got) do
          if not want[k] then keys[k] = true end
        end
        for k in pairs(keys) do
          must(got[k] == want[k], "variant " .. key .. " " .. mname .. "[" .. k .. "] mismatch")
        end
      end
      local metrics = mv.metrics or {}
      for _, c in ipairs(v.classes) do
        local m = v.metrics[c]
        local gm = metrics[c]
        must(gm and num(gm[1]) == num(m.width) and num(gm[2]) == num(m.height)
          and num(gm[3]) == num(m.depth) and gm[4] == m.align
          and num(gm[5]) == num(m.left),
          "variant " .. key .. " metrics[" .. c .. "] mismatch")
      end
      -- payload digest: recompute from the freshly rendered text
      local text
      for _, f in ipairs(files) do if f.name == v.file then text = f.text end end
      must(mv.payload_sha256 == sha256_text(text or ""),
        "variant " .. key .. " payload_sha256 mismatch")
    end
  end
end

local function check_files_on_disk(preset, files, outdir, errors)
  -- Regenerate into a throwaway directory first (the contract requires a
  -- real regeneration, not a comparison against in-memory output only).
  local tmp = os.tmpname()
  os.remove(tmp)
  local gen_ok, gen_err = pcall(function()
    mkdir_p(tmp)
    M.generate(preset, tmp)
  end)
  if not gen_ok then
    errors[#errors + 1] = "regeneration failed: " .. tostring(gen_err)
    os.execute("rm -rf '" .. tmp:gsub("'", "'\\''") .. "'")
    return
  end
  for _, f in ipairs(files) do
    local fresh = read_file(tmp .. "/" .. f.name)
    local path = outdir .. "/" .. f.name
    local text = read_file(path)
    if fresh ~= f.text then
      errors[#errors + 1] = "regenerated output differs from in-memory render: "
        .. f.name
    end
    if not text then
      errors[#errors + 1] = "missing generated file " .. path
    elseif text ~= fresh then
      errors[#errors + 1] = "byte mismatch in " .. path
    end
  end
  os.execute("rm -rf '" .. tmp:gsub("'", "'\\''") .. "'")
end

-- check(preset, manifest, assets[, outdir]) -> ok, errors
function M.check(preset, manifest_path, assets_path, outdir)
  local errors = {}
  if not preset.norm_variants then
    return false, { "check() requires a preset from load_preset()" }
  end
  local files = M.render(preset)
  outdir = outdir or (manifest_path and dirname(absolute(manifest_path))) or "."
  check_files_on_disk(preset, files, outdir, errors)

  -- independent parse of every payload (source-normalized expectations)
  for _, v in ipairs(preset.norm_variants) do
    local text = read_file(outdir .. "/" .. v.file)
    if text then
      check_payload_text(preset, v, text, errors)
    end
  end
  local index_text = read_file(outdir .. "/pdftexja-jfm-" .. preset.id .. ".def")
  if index_text then
    check_index_text(preset, index_text, errors)
  end

  if manifest_path and read_file(manifest_path) then
    check_manifest(preset, files, manifest_path, errors)
  else
    errors[#errors + 1] = "missing manifest " .. tostring(manifest_path)
  end
  if assets_path and read_file(assets_path) then
    local names, err = parse_assets(assets_path)
    if not names then
      errors[#errors + 1] = "assets: " .. tostring(err)
    else
      if #names ~= #files.assets then
        errors[#errors + 1] = "assets: entry count mismatch (" .. #names
          .. " vs " .. #files.assets .. ")"
      end
      for i = 1, math.min(#names, #files.assets) do
        if names[i] ~= files.assets[i] then
          errors[#errors + 1] = "assets[" .. i .. "] = " .. names[i]
            .. ", want " .. files.assets[i]
        end
      end
    end
  else
    errors[#errors + 1] = "missing assets fragment " .. tostring(assets_path)
  end
  return #errors == 0, errors
end

return M
