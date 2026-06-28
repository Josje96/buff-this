-- Level serialization.
--
-- Two representations of a level "def":
--   editable: { name=<str>, palette=<name str>, buff=<name str|nil>, map={<rows>} }
--   playable: { name=<str>, palette=<colors>,   forceBuff=<name|nil>, map={<rows>} }
--
-- The share/save format is plain text and is parsed as DATA ONLY (no loadstring),
-- so importing a level from a stranger can never execute code. In the encoded
-- text, air is written as '.' so forums/clients that strip trailing whitespace
-- don't corrupt the map; '.' is converted back to ' ' on decode.

local palettes = require("levels.palettes")

local format = {}

local MAGIC   = "BUFFLVL"
local VERSION = "v1"

-- Characters that are meaningful in a map row. Everything else becomes air.
local VALID = { ["#"]=true, ["X"]=true, ["S"]=true, ["G"]=true, ["E"]=true, ["V"]=true, [" "]=true }

local function trimr(s) return (s:gsub("%s+$", "")) end
local function trim(s)  return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- ── editable -> playable ─────────────────────────────────────
function format.toPlayable(def)
    return {
        name      = def.name or "Untitled",
        palette   = palettes.resolve(def.palette),
        forceBuff = def.buff,            -- nil means "random"
        map       = def.map,
    }
end

-- ── editable -> share text ───────────────────────────────────
function format.encode(def)
    local rows = def.map
    local w = 0
    for _, r in ipairs(rows) do w = math.max(w, #r) end
    local h = #rows

    local out = {}
    out[#out+1] = MAGIC .. " " .. VERSION
    out[#out+1] = "name: "    .. (def.name or "Untitled")
    out[#out+1] = "palette: " .. (def.palette or "forest")
    out[#out+1] = "buff: "    .. (def.buff or "-")
    out[#out+1] = string.format("size: %dx%d", w, h)
    out[#out+1] = "="
    for _, r in ipairs(rows) do
        -- pad to width, then write air as '.'
        local padded = r .. string.rep(" ", w - #r)
        out[#out+1] = (padded:gsub(" ", "."))
    end
    return table.concat(out, "\n")
end

-- ── share text -> editable ───────────────────────────────────
-- returns def, or nil, errmsg
function format.decode(text)
    if type(text) ~= "string" then return nil, "no text" end
    text = text:gsub("\r", "")   -- normalize Windows CRLF
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines+1] = line
    end

    -- find header magic and the '=' separator
    local i = 1
    while i <= #lines and trim(lines[i]) == "" do i = i + 1 end
    if not lines[i] or not lines[i]:match("^" .. MAGIC) then
        return nil, "not a Buff This level (missing header)"
    end
    i = i + 1

    local def = { name = "Imported", palette = "forest", buff = nil }
    local declaredW = nil
    while i <= #lines do
        local line = lines[i]
        if trim(line) == "=" then i = i + 1; break end
        local key, val = line:match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
        if key == "name"    then def.name = (val ~= "" and val) or "Imported"
        elseif key == "palette" then def.palette = (val ~= "" and val) or "forest"
        elseif key == "buff"    then def.buff = (val ~= "" and val ~= "-") and val or nil
        elseif key == "size"    then declaredW = tonumber((val:match("^(%d+)")) or "")
        end
        i = i + 1
    end

    -- remaining lines are map rows
    local rows = {}
    while i <= #lines do
        rows[#rows+1] = lines[i]
        i = i + 1
    end
    -- drop trailing blank lines
    while #rows > 0 and trimr(rows[#rows]) == "" do rows[#rows] = nil end
    if #rows == 0 then return nil, "level has no map rows" end

    -- determine width
    local w = declaredW or 0
    if not declaredW then
        for _, r in ipairs(rows) do w = math.max(w, #r) end
    end

    -- sanitize: '.' -> air, unknown chars -> air, pad/truncate to width
    local clean = {}
    local hasSpawn, hasGoal = false, false
    for _, r in ipairs(rows) do
        local chars = {}
        for c = 1, w do
            local ch = r:sub(c, c)
            if ch == "." or ch == "" then ch = " " end
            if not VALID[ch] then ch = " " end
            if ch == "S" then hasSpawn = true end
            if ch == "G" then hasGoal = true end
            chars[c] = ch
        end
        clean[#clean+1] = table.concat(chars)
    end

    def.map = clean
    def.warnings = {}
    if not hasSpawn then def.warnings[#def.warnings+1] = "no spawn (S)" end
    if not hasGoal  then def.warnings[#def.warnings+1] = "no goal (G)" end
    return def
end

-- ── editable -> Lua snippet (DEV: paste into levels/data.lua) ──
function format.encodeLua(def, idx)
    local out = {}
    local key = idx and ("levels[" .. idx .. "]") or "levels[N]"
    out[#out+1] = key .. " = {"
    local buff = def.buff and (', forceBuff = "' .. def.buff .. '"') or ""
    out[#out+1] = string.format('    name = "%s", palette = P.%s%s,',
        def.name or "Untitled", def.palette or "forest", buff)
    out[#out+1] = "    map = {"
    for _, r in ipairs(def.map) do
        -- escape any embedded quotes (shouldn't happen, but be safe)
        out[#out+1] = '        "' .. r:gsub('"', '\\"') .. '",'
    end
    out[#out+1] = "    },"
    out[#out+1] = "}"
    return table.concat(out, "\n")
end

format.MAGIC   = MAGIC
format.VERSION = VERSION
return format
