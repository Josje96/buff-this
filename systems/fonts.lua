-- Cached fonts. Creating a font rasterizes a glyph atlas, so doing it inside
-- draw() (as the states used to) reallocates every frame and causes GC stutter.
-- fonts.get(size) builds each size once and reuses it.

local fonts = {}
local cache = {}

function fonts.get(size)
    local f = cache[size]
    if not f then
        f = love.graphics.newFont(size)
        f:setFilter("nearest", "nearest")
        cache[size] = f
    end
    return f
end

return fonts
