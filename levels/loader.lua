local fonts    = require("systems.fonts")
local palettes = require("levels.palettes")
local assets   = require("systems.assets")
local loader   = {}

local TILE_SIZE = 40

function loader.load(levelDef)
    local level             = {}
    local tiles             = {}
    local enemySpawns       = {}
    local stalactiteSpawns  = {}
    local spawn             = {x = 100, y = 100}
    local goal              = nil
    local cols              = 0
    local rows              = #levelDef.map

    for row, line in ipairs(levelDef.map) do
        if #line > cols then cols = #line end
        for col = 1, #line do
            local ch = line:sub(col, col)
            local wx = (col - 1) * TILE_SIZE
            local wy = (row - 1) * TILE_SIZE

            if     ch == 'S' then
                spawn = { x = wx, y = wy }
            elseif ch == 'G' then
                goal = { x = wx, y = wy, w = TILE_SIZE, h = TILE_SIZE }
            elseif ch == '#' or ch == 'P' then
                tiles[#tiles + 1] = {
                    x = wx, y = wy,
                    w = TILE_SIZE, h = TILE_SIZE,
                    solid = true, kind = "ground",
                }
            elseif ch == 'X' then
                tiles[#tiles + 1] = {
                    x = wx, y = wy,
                    w = TILE_SIZE, h = TILE_SIZE,
                    solid = false, kind = "hazard",
                }
            elseif ch == 'E' then
                enemySpawns[#enemySpawns + 1] = { x = wx, y = wy }
            elseif ch == 'V' then
                stalactiteSpawns[#stalactiteSpawns + 1] = { x = wx, y = wy }
            end
        end
    end

    level.tiles             = tiles
    level.enemySpawns       = enemySpawns
    level.stalactiteSpawns  = stalactiteSpawns
    level.spawn             = spawn
    level.goal              = goal
    level.name              = levelDef.name
    level.forceBuff         = levelDef.forceBuff
    level.width             = cols * TILE_SIZE
    level.height            = rows * TILE_SIZE
    level.tileSize          = TILE_SIZE

    -- Resolve palette to color table and keep the name for backgrounds
    if type(levelDef.palette) == "string" then
        level.palette     = palettes.resolve(levelDef.palette)
        level.paletteName = levelDef.palette
    else
        level.palette     = levelDef.palette
        level.paletteName = palettes.nameOf(levelDef.palette)
    end

    -- Tile sprites: <palette>-ground.png per biome, shared danger-tile.png
    level.sprites = {
        ground = assets.image("assets/tiles/" .. level.paletteName .. "-ground.png"),
        hazard = assets.image("assets/tiles/danger-tile.png"),
    }

    -- Optional background image (assets/backgrounds/<biome>.png)
    level.bgImage = assets.image("assets/backgrounds/" .. level.paletteName .. ".png")

    function level.getSize()
        return level.width, level.height
    end

    function level.getTilesInRect(x, y, w, h)
        local result = {}
        for _, t in ipairs(tiles) do
            if t.solid
            and x < t.x + t.w and x + w > t.x
            and y < t.y + t.h and y + h > t.y then
                result[#result + 1] = t
            end
        end
        return result
    end

    function level.getHazardsInRect(x, y, w, h)
        local result = {}
        for _, t in ipairs(tiles) do
            if t.kind == "hazard"
            and x < t.x + t.w and x + w > t.x
            and y < t.y + t.h and y + h > t.y then
                result[#result + 1] = t
            end
        end
        return result
    end

    return level
end

function loader.draw(level, camX, camY)
    local p  = level.palette
    local ts = level.tileSize
    local W, H = love.graphics.getDimensions()

    -- Background image (tiled, 30% parallax)
    if level.bgImage then
        local iw = level.bgImage:getWidth()
        local ih = level.bgImage:getHeight()
        local bx = (-(camX * 0.3)) % iw
        local by = (-(camY * 0.3)) % ih
        love.graphics.setColor(1, 1, 1)
        local x = bx - iw
        while x < W do
            local y = by - ih
            while y < H do
                love.graphics.draw(level.bgImage, x, y)
                y = y + ih
            end
            x = x + iw
        end
    end

    -- Tiles
    for _, t in ipairs(level.tiles) do
        local sx = t.x - camX
        local sy = t.y - camY

        if sx + ts < 0 or sx > W or sy + ts < 0 or sy > H then
            goto continue
        end

        if t.kind == "ground" then
            if level.sprites.ground then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(level.sprites.ground, sx, sy)
            else
                love.graphics.setColor(p.ground)
                love.graphics.rectangle("fill", sx, sy, ts, ts)
                love.graphics.setColor(p.platform)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", sx, sy, ts, ts)
            end
        elseif t.kind == "hazard" then
            if level.sprites.hazard then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(level.sprites.hazard, sx, sy)
            else
                love.graphics.setColor(p.hazard)
                love.graphics.rectangle("fill", sx, sy, ts, ts)
                love.graphics.setColor(1, 1, 1, 0.25)
                local spikes = 4
                local sw = ts / spikes
                for s = 0, spikes - 1 do
                    love.graphics.polygon("fill",
                        sx + s * sw,        sy + ts * 0.4,
                        sx + s * sw + sw/2, sy,
                        sx + s * sw + sw,   sy + ts * 0.4)
                end
            end
        end

        ::continue::
    end

    -- Goal
    if level.goal then
        local gx = level.goal.x - camX
        local gy = level.goal.y - camY
        love.graphics.setColor(p.goal)
        love.graphics.rectangle("fill", gx + 4, gy, ts - 8, ts, 4, 4)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setFont(fonts.get(20))
        love.graphics.print("!", gx + ts/2 - 5, gy + 8)
    end
end

return loader
