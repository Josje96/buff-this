local data     = require("levels.data")
local run      = require("systems.run")
local input    = require("systems.input")
local palettes = require("levels.palettes")

local LevelSelect = {}
LevelSelect.__index = LevelSelect

local C = {
    bg      = {0.06, 0.06, 0.10},
    title   = {1.00, 0.75, 0.10},
    normal  = {0.75, 0.75, 0.80},
    sel     = {0.20, 0.90, 0.60},
    dim     = {0.35, 0.35, 0.45},
}

local COLS       = 9   -- levels per row
local CELL_W     = 100
local CELL_H     = 52
local GRID_PAD_X = 60
local GRID_PAD_Y = 130

function LevelSelect.new(states)
    local self    = setmetatable({}, LevelSelect)
    self.states   = states
    self.cursor   = 1
    self.flash    = 0
    return self
end

function LevelSelect:update(dt)
    self.flash = (self.flash + dt * 4) % (2 * math.pi)
end

function LevelSelect:draw()
    local W, H = love.graphics.getDimensions()
    local alpha = 0.6 + 0.4 * math.abs(math.sin(self.flash))

    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    -- header
    love.graphics.setColor(C.title)
    local hFont = love.graphics.newFont(32)
    love.graphics.setFont(hFont)
    local header = "[DEV] Level Select"
    love.graphics.print(header, W/2 - hFont:getWidth(header)/2, 28)

    -- grid
    local cellFont = love.graphics.newFont(14)
    local nameFont = love.graphics.newFont(11)
    local totalW   = COLS * CELL_W
    local startX   = W/2 - totalW/2

    for i, level in ipairs(data) do
        local col  = (i - 1) % COLS
        local row  = math.floor((i - 1) / COLS)
        local cx   = startX + col * CELL_W
        local cy   = GRID_PAD_Y + row * CELL_H
        local isSel = (self.cursor == i)

        -- cell bg
        if isSel then
            love.graphics.setColor(C.sel[1], C.sel[2], C.sel[3], alpha * 0.25)
            love.graphics.rectangle("fill", cx + 2, cy + 2, CELL_W - 6, CELL_H - 6, 4, 4)
            love.graphics.setColor(C.sel[1], C.sel[2], C.sel[3], alpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx + 2, cy + 2, CELL_W - 6, CELL_H - 6, 4, 4)
        else
            love.graphics.setColor(0.15, 0.15, 0.22)
            love.graphics.rectangle("fill", cx + 2, cy + 2, CELL_W - 6, CELL_H - 6, 4, 4)
            love.graphics.setColor(0.25, 0.25, 0.35)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", cx + 2, cy + 2, CELL_W - 6, CELL_H - 6, 4, 4)
        end

        -- level number
        love.graphics.setFont(cellFont)
        love.graphics.setColor(isSel and C.sel or C.normal)
        local num = tostring(i)
        love.graphics.print(num, cx + CELL_W/2 - cellFont:getWidth(num)/2, cy + 6)

        -- level name (truncated)
        love.graphics.setFont(nameFont)
        love.graphics.setColor(isSel and {1,1,1} or C.dim)
        local name = level.name
        if nameFont:getWidth(name) > CELL_W - 10 then
            -- truncate
            while nameFont:getWidth(name .. "…") > CELL_W - 10 and #name > 0 do
                name = name:sub(1, -2)
            end
            name = name .. "…"
        end
        love.graphics.print(name, cx + CELL_W/2 - nameFont:getWidth(name)/2, cy + 26)
    end

    -- selected level info
    local sel = data[self.cursor]
    love.graphics.setColor(C.title)
    local infoFont = love.graphics.newFont(16)
    love.graphics.setFont(infoFont)
    local info = string.format("Level %d — %s", self.cursor, sel.name)
    love.graphics.print(info, W/2 - infoFont:getWidth(info)/2, H - 56)

    love.graphics.setFont(love.graphics.newFont(13))
    love.graphics.setColor(C.dim)
    local hint = "navigate Arrows/stick   play Enter/A   edit E/Y   back Esc/B"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 30)
end

function LevelSelect:_launch()
    local r = run.new()
    r.levelIdx = self.cursor
    r.lives    = math.huge   -- infinite lives in dev mode
    r.dev      = true
    self.states.switch("game", r)
end

-- Open the highlighted built-in level in the editor (DEV). Editing + F4 there
-- copies a Lua snippet to paste back into levels/data.lua.
function LevelSelect:_editBuiltin()
    local d = data[self.cursor]
    if not d then return end
    self.states.switch("editor", {
        _builtinIdx = self.cursor,
        name        = d.name,
        palette     = palettes.nameOf(d.palette),
        buff        = d.forceBuff,
        map         = d.map,
    })
end

function LevelSelect:_navigate(dx, dy)
    local n    = #data
    local cur  = self.cursor - 1
    local col  = cur % COLS
    local row  = math.floor(cur / COLS)

    col = (col + dx) % COLS
    row = row + dy
    local newIdx = row * COLS + col + 1

    if newIdx >= 1 and newIdx <= n then
        self.cursor = newIdx
    end
end

function LevelSelect:keypressed(key)
    if key == "left"   then self:_navigate(-1,  0)
    elseif key == "right"  then self:_navigate( 1,  0)
    elseif key == "up"     then self:_navigate( 0, -1)
    elseif key == "down"   then self:_navigate( 0,  1)
    elseif key == "return" or key == "space" then self:_launch()
    elseif key == "e"      then self:_editBuiltin()
    elseif key == "escape" then self.states.switch("menu")
    end
end

function LevelSelect:gamepadpressed(joystick, button)
    if button == "dpleft"  then self:_navigate(-1,  0)
    elseif button == "dpright" then self:_navigate( 1,  0)
    elseif button == "dpup"    then self:_navigate( 0, -1)
    elseif button == "dpdown"  then self:_navigate( 0,  1)
    elseif button == "a"       then self:_launch()
    elseif button == "y"       then self:_editBuiltin()
    elseif button == "b" or button == "start" then self.states.switch("menu")
    end
end

function LevelSelect:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if nav == "left"  then self:_navigate(-1,  0)
    elseif nav == "right" then self:_navigate( 1,  0)
    elseif nav == "up"    then self:_navigate( 0, -1)
    elseif nav == "down"  then self:_navigate( 0,  1)
    end
end

return LevelSelect
