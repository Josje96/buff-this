local input = require("systems.input")
local Results = {}
Results.__index = Results

local C = {
    bg     = {0.08, 0.06, 0.12},
    title  = {0.20, 0.90, 0.60},
    label  = {0.90, 0.90, 0.90},
    dim    = {0.45, 0.45, 0.55},
    select = {1.00, 0.85, 0.10},
}

function Results.new(states, r, buffName, levelName)
    local self      = setmetatable({}, Results)
    self.states     = states
    self.run        = r
    self.buffName   = buffName or "None"
    self.levelName  = levelName or ""
    self.cursor     = 1
    self.flash      = 0
    return self
end

function Results:update(dt)
    self.flash = (self.flash + dt * 3) % (2 * math.pi)
end

function Results:draw()
    local W, H  = love.graphics.getDimensions()
    local alpha = 0.6 + 0.4 * math.abs(math.sin(self.flash))

    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    local bigFont = love.graphics.newFont(64)
    love.graphics.setFont(bigFont)
    love.graphics.setColor(C.title)
    local header = "LEVEL CLEAR"
    love.graphics.print(header, W/2 - bigFont:getWidth(header)/2, H * 0.13)

    -- level name and progress
    local infoFont = love.graphics.newFont(20)
    love.graphics.setFont(infoFont)
    love.graphics.setColor(C.dim)
    local prev = self.run.levelIdx - 1
    local linfo = string.format("%s  (%d / %d)", self.levelName, prev, self.run.maxLevels)
    love.graphics.print(linfo, W/2 - infoFont:getWidth(linfo)/2, H * 0.13 + 76)

    -- progress bar
    local barW = W * 0.5
    local barH = 10
    local barX = W/2 - barW/2
    local barY = H * 0.13 + 106
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)
    love.graphics.setColor(C.title)
    love.graphics.rectangle("fill", barX, barY, barW * (prev / self.run.maxLevels), barH, 4, 4)

    -- buff
    if self.buffName ~= "No Modifier" then
        local bFont = love.graphics.newFont(17)
        love.graphics.setFont(bFont)
        love.graphics.setColor(C.select[1], C.select[2], C.select[3], 0.85)
        local btxt = "Modifier: " .. self.buffName
        love.graphics.print(btxt, W/2 - bFont:getWidth(btxt)/2, H * 0.13 + 128)
    end

    -- lives remaining
    local livesFont = love.graphics.newFont(16)
    love.graphics.setFont(livesFont)
    love.graphics.setColor(C.dim)
    local ly = H * 0.40
    if self.run.lives == math.huge then
        local inf = "Lives remaining: ∞"
        love.graphics.print(inf, W/2 - livesFont:getWidth(inf)/2, ly)
    else
        local livesLabel = "Lives remaining: "
        local lx = W/2 - (livesFont:getWidth(livesLabel) + 18 * self.run.lives) / 2
        love.graphics.print(livesLabel, lx, ly)
        lx = lx + livesFont:getWidth(livesLabel) + 4
        for i = 1, self.run.lives do
            love.graphics.setColor(0.95, 0.20, 0.30, 0.9)
            love.graphics.rectangle("fill", lx + (i-1)*18, ly + 1, 12, 12, 2, 2)
        end
    end

    -- options
    local menuFont = love.graphics.newFont(32)
    love.graphics.setFont(menuFont)
    local opts   = { "Next Level", "Main Menu" }
    local startY = H * 0.52
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

    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.setColor(C.dim)
    local hint = "Arrow keys / D-pad   Enter / A to select"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
end

function Results:_confirm()
    if self.cursor == 1 then
        self.states.switch("game", self.run)
    else
        self.states.switch("menu")
    end
end

function Results:_navigate(dir)
    self.cursor = ((self.cursor - 1 + dir) % 2) + 1
end

function Results:keypressed(key)
    if key == "up"    then self:_navigate(-1)
    elseif key == "down"  then self:_navigate(1)
    elseif key == "return" or key == "space" then self:_confirm()
    elseif key == "escape" then self.states.switch("menu")
    end
end

function Results:gamepadpressed(joystick, button)
    if button == "dpup"       then self:_navigate(-1)
    elseif button == "dpdown" then self:_navigate(1)
    elseif button == "a"      then self:_confirm()
    elseif button == "b" or button == "start" then self.states.switch("menu")
    end
end

function Results:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if nav == "up"   then self:_navigate(-1)
    elseif nav == "down" then self:_navigate(1)
    end
end

return Results
