local fonts = require("systems.fonts")
local input = require("systems.input")
local GameOver = {}
GameOver.__index = GameOver

local C = {
    bg     = {0.06, 0.02, 0.02},
    title  = {0.95, 0.20, 0.20},
    label  = {0.90, 0.90, 0.90},
    dim    = {0.45, 0.45, 0.55},
    select = {1.00, 0.85, 0.10},
}

function GameOver.new(states, r)
    local self   = setmetatable({}, GameOver)
    self.states  = states
    self.run     = r
    self.cursor  = 1
    self.flash   = 0
    return self
end

function GameOver:update(dt)
    self.flash = (self.flash + dt * 3) % (2 * math.pi)
end

function GameOver:draw()
    local W, H  = love.graphics.getDimensions()
    local alpha = 0.6 + 0.4 * math.abs(math.sin(self.flash))

    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    local bigFont = fonts.get(72)
    love.graphics.setFont(bigFont)
    love.graphics.setColor(C.title[1], C.title[2], C.title[3], alpha)
    local header = "GAME OVER"
    love.graphics.print(header, W/2 - bigFont:getWidth(header)/2, H * 0.18)

    local subFont = fonts.get(20)
    love.graphics.setFont(subFont)
    love.graphics.setColor(C.dim)
    local reached = string.format("You reached level %d of %d", self.run.levelIdx, self.run.maxLevels)
    love.graphics.print(reached, W/2 - subFont:getWidth(reached)/2, H * 0.18 + 84)

    -- options
    local menuFont = fonts.get(32)
    love.graphics.setFont(menuFont)
    local opts    = { "Try Again", "Main Menu" }
    local startY  = H * 0.55
    local spacing = 56

    for i, label in ipairs(opts) do
        local isSel = (self.cursor == i)
        if isSel then
            love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
        else
            love.graphics.setColor(C.label)
        end
        local text = (isSel and "> " or "  ") .. label
        love.graphics.print(text, W/2 - menuFont:getWidth(text)/2, startY + (i-1) * spacing)
    end

    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(C.dim)
    local hint = "Arrow keys / D-pad   Enter / A to select"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
end

function GameOver:_confirm()
    if self.cursor == 1 then
        self.states.switch("game", require("systems.run").new())
    else
        self.states.switch("menu")
    end
end

function GameOver:_navigate(dir)
    self.cursor = ((self.cursor - 1 + dir) % 2) + 1
end

function GameOver:keypressed(key)
    if key == "up"    then self:_navigate(-1)
    elseif key == "down"  then self:_navigate(1)
    elseif key == "return" or key == "space" then self:_confirm()
    elseif key == "escape" then self.states.switch("menu")
    end
end

function GameOver:gamepadpressed(joystick, button)
    if button == "dpup"       then self:_navigate(-1)
    elseif button == "dpdown" then self:_navigate(1)
    elseif button == "a"      then self:_confirm()
    elseif button == "b" or button == "start" then self.states.switch("menu")
    end
end

function GameOver:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if nav == "up"   then self:_navigate(-1)
    elseif nav == "down" then self:_navigate(1)
    end
end

return GameOver
