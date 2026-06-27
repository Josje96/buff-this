-- DEV-only: write built-in level edits back to the real levels/data.lua source.
--
-- love.filesystem.write() always targets the save directory, never the project
-- source, so it can't edit shipped code. This module uses love.filesystem
-- .getSource() (the project path when running unpacked, e.g. `love .`) plus
-- plain Lua io to surgically replace one `levels[N] = { ... }` block, leaving
-- comments, zone headers and every other level untouched.
--
-- Only meaningful while developing: a fused/packaged build ships DEV=false and
-- getSource() points inside the archive, so saveBuiltin is never called there.

local format   = require("levels.format")
local palettes = require("levels.palettes")

local devlevels = {}

local function dataPath()
    local src = love.filesystem.getSource()
    if not src or src == "" then return nil end
    return src .. "/levels/data.lua"
end

-- Replace the `levels[idx] = { ... }` block in data.lua with a freshly encoded
-- one. Returns true, or nil, errmsg.
function devlevels.saveBuiltin(idx, def)
    local path = dataPath()
    if not path then return nil, "no source path (packaged build?)" end

    local f, oerr = io.open(path, "r")
    if not f then return nil, oerr or "cannot open data.lua" end
    local src = f:read("*a")
    f:close()

    local lines = {}
    for line in (src .. "\n"):gmatch("(.-)\n") do lines[#lines+1] = line end

    -- locate `levels[idx] = {` and its matching closing `}` (the next line that
    -- is just "}" at column 0 — map's inner brace is indented, so it's skipped).
    local startLine, endLine
    local pat = "^levels%[" .. idx .. "%]%s*=%s*{"
    for i, line in ipairs(lines) do
        if line:match(pat) then
            startLine = i
            for j = i + 1, #lines do
                if lines[j]:match("^}%s*$") then endLine = j; break end
            end
            break
        end
    end
    if not startLine or not endLine then
        return nil, "could not locate levels[" .. idx .. "] block"
    end

    -- splice the new block in place of the old one
    local block = format.encodeLua(def, idx)
    local out = {}
    for i = 1, startLine - 1 do out[#out+1] = lines[i] end
    out[#out+1] = block
    for i = endLine + 1, #lines do out[#out+1] = lines[i] end

    local w, werr = io.open(path, "w")
    if not w then return nil, werr or "cannot write data.lua" end
    w:write(table.concat(out, "\n"))
    w:close()

    -- keep the already-required level table fresh so the rest of this session
    -- (level select, launching the level) reflects the edit without a restart.
    local levels = require("levels.data")
    levels[idx] = {
        name      = def.name,
        palette   = palettes.resolve(def.palette),
        forceBuff = def.buff,
        map       = def.map,
    }
    return true
end

return devlevels
