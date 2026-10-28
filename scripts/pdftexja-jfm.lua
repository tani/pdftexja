#!/usr/bin/env texlua
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
  pdftexja-jfm.lua --- CLI for the pdftexja JFM data generator.

    texlua pdftexja-jfm.lua --input PRESET.lua --outdir DIR \
        --manifest FILE --assets FILE

  Loads scripts/pdftexja-jfm-lib.lua from this script's own directory (the
  script never looks for jlreq or class loaders) and writes the payload .def
  files, the runtime index, the Lua semantic manifest and the make asset
  fragment.
-----------------------------------------------------------------------------]]

local scriptdir = arg and arg[0] and arg[0]:match("^(.*)/[^/]*$") or "."
package.path = scriptdir .. "/?.lua;" .. package.path
local lib = dofile(scriptdir .. "/pdftexja-jfm-lib.lua")

local opts = { outdir = nil, input = nil, manifest = nil, assets = nil }
local i = 1
while i <= #arg do
  local a = arg[i]
  local key, val = a:match("^%-%-(%w+)(.*)$")
  if key and val:sub(1, 1) == "=" then val = val:sub(2) end
  if key and (key == "input" or key == "outdir" or key == "manifest"
      or key == "assets") then
    if val == "" and arg[i + 1] and not arg[i + 1]:match("^%-%-") then
      val = arg[i + 1]
      i = i + 1
    end
    opts[key] = val
  elseif a == "--help" then
    print("usage: texlua pdftexja-jfm.lua --input PRESET.lua --outdir DIR "
      .. "[--manifest FILE] [--assets FILE]")
    os.exit(0)
  else
    io.stderr:write("pdftexja-jfm.lua: unknown or incomplete option " .. a .. "\n")
    os.exit(2)
  end
  i = i + 1
end
if not opts.input then
  io.stderr:write("pdftexja-jfm.lua: --input PRESET.lua is required\n")
  os.exit(2)
end
if not opts.outdir then opts.outdir = "." end

local ok, preset = pcall(lib.load_preset, opts.input)
if not ok then
  io.stderr:write("pdftexja-jfm.lua: " .. tostring(preset) .. "\n")
  os.exit(1)
end
local okgen, result = pcall(lib.generate, preset, opts.outdir,
  opts.manifest, opts.assets)
if not okgen then
  io.stderr:write("pdftexja-jfm.lua: " .. tostring(result) .. "\n")
  os.exit(1)
end
io.stderr:write(string.format(
  "pdftexja-jfm.lua %s: preset %s, %d payload/index file(s)\n",
  lib.GEN_VERSION, preset.id, #result))
for _, name in ipairs(result) do
  io.stderr:write("  " .. name .. "\n")
end
os.exit(0)
