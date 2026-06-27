-- Custom level storage. Reads/writes the safe text format (levels/format.lua)
-- to the LÖVE save directory (e.g. %AppData%/LOVE/buff-this/userlevels/), so
-- player-made and imported levels persist across runs and never touch the
-- shipped source. Built-in levels stay in levels/data.lua.

local format = require("levels.format")

local userlevels = {}

local DIR = "userlevels"

local function ensureDir()
    if not love.filesystem.getInfo(DIR) then
        love.filesystem.createDirectory(DIR)
    end
end

local function slugify(name)
    local s = (name or "level"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if s == "" then s = "level" end
    return s
end

-- pick a filename that doesn't collide with an existing different level
local function uniqueId(base)
    ensureDir()
    local id   = base .. ".txt"
    local n    = 2
    while love.filesystem.getInfo(DIR .. "/" .. id) do
        id = base .. "_" .. n .. ".txt"
        n  = n + 1
    end
    return id
end

-- Returns an array of { id=<filename>, def=<editable def> }, sorted by name.
function userlevels.list()
    ensureDir()
    local items = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        if file:match("%.txt$") then
            local text = love.filesystem.read(DIR .. "/" .. file)
            if text then
                local def = format.decode(text)
                if def then
                    items[#items+1] = { id = file, def = def }
                end
            end
        end
    end
    table.sort(items, function(a, b)
        return (a.def.name or "") < (b.def.name or "")
    end)
    return items
end

-- Save an editable def. If def.id is set, overwrites that file; otherwise
-- creates a new file. Returns the id (filename), or nil, errmsg.
function userlevels.save(def)
    ensureDir()
    local id = def.id or uniqueId(slugify(def.name))
    local ok, err = love.filesystem.write(DIR .. "/" .. id, format.encode(def))
    if not ok then return nil, err or "write failed" end
    return id
end

function userlevels.delete(id)
    if id and love.filesystem.getInfo(DIR .. "/" .. id) then
        return love.filesystem.remove(DIR .. "/" .. id)
    end
    return false
end

-- Import from share text (clipboard paste or dropped file contents).
-- Returns def, id  or  nil, errmsg.
function userlevels.importText(text)
    local def, err = format.decode(text)
    if not def then return nil, err end
    local id, werr = userlevels.save(def)
    if not id then return nil, werr end
    def.id = id
    return def, id
end

userlevels.DIR = DIR
return userlevels
