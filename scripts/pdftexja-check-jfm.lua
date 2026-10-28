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
  pdftexja-check-jfm.lua --- verify committed pdftexja JFM data against its
  preset descriptor.

    texlua pdftexja-check-jfm.lua --input PRESET.lua --outdir DIR \
        --manifest FILE --assets FILE

  The checker regenerates every payload/index into a temporary directory,
  byte-compares the result with --outdir, independently reparses each
  payload (source-normalized expectations, not the serializer output),
  checks the Lua semantic manifest structure and the make asset fragment.
  Exit status: 0 = all checks passed, 1 = failures, 2 = usage error.
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
    print("usage: texlua pdftexja-check-jfm.lua --input PRESET.lua "
      .. "--outdir DIR --manifest FILE --assets FILE")
    os.exit(0)
  else
    io.stderr:write("pdftexja-check-jfm.lua: unknown or incomplete option "
      .. a .. "\n")
    os.exit(2)
  end
  i = i + 1
end
if not opts.input then
  io.stderr:write("pdftexja-check-jfm.lua: --input PRESET.lua is required\n")
  os.exit(2)
end
if not opts.manifest or not opts.assets then
  io.stderr:write("pdftexja-check-jfm.lua: --manifest and --assets are required\n")
  os.exit(2)
end

local ok, preset = pcall(lib.load_preset, opts.input)
if not ok then
  io.stderr:write("pdftexja-check-jfm.lua: " .. tostring(preset) .. "\n")
  os.exit(1)
end
local outdir = opts.outdir
  or (opts.manifest:match("^(.*)/[^/]*$") or ".")
local passed, errors = lib.check(preset, opts.manifest, opts.assets, outdir)
if passed then
  print(string.format("pdftexja-check-jfm: PASS (%s, %d payload/index file(s))",
    preset.id, #preset.norm_variants + 1))
  os.exit(0)
end
print("pdftexja-check-jfm: FAIL (" .. #errors .. " failure(s))")
for _, e in ipairs(errors) do print("  " .. e) end
os.exit(1)
