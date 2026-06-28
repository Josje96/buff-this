-- Cached font loader. fonts.get(size) builds each size once and reuses it.
-- To use a custom TTF: set fonts.source = "fonts/MyFont.ttf" before the first
-- call, or call fonts.setSource("fonts/MyFont.ttf") at any time to hot-swap.

local fonts = {}
local cache = {}

fonts.source = nil  -- nil = Love2D default; set to a .ttf path for custom font

function fonts.setSource(path)
    fonts.source = path
    cache = {}  -- clear so next get() rasterises with the new typeface
end

function fonts.get(size)
    local f = cache[size]
    if not f then
        if fonts.source then
            f = love.graphics.newFont(fonts.source, size)
            f:setFilter("linear", "linear")
        else
            f = love.graphics.newFont(size)
            f:setFilter("nearest", "nearest")
        end
        cache[size] = f
    end
    return f
end

return fonts
