-- Image cache. assets.image(path) loads each file once and reuses it.
-- Returns nil (without erroring) when the file doesn't exist yet.

local assets  = {}
local cache   = {}
local MISSING = {}   -- sentinel so we don't re-check absent files

function assets.image(path)
    local hit = cache[path]
    if hit == nil then
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            img:setFilter("nearest", "nearest")
            cache[path] = img
            return img
        else
            cache[path] = MISSING
            return nil
        end
    end
    return hit ~= MISSING and hit or nil
end

return assets
