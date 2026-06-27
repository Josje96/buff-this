local Victory = {}
Victory.__index = Victory

local C = {
    bg     = {0.04, 0.08, 0.04},
    title  = {1.00, 0.85, 0.10},
    sub    = {0.20, 0.90, 0.60},
    dim    = {0.45, 0.45, 0.55},
    select = {1.00, 0.85, 0.10},
}

function Victory.new(states, r)
    local self  = setmetatable({}, Victory)
    self.states = states
    self.run    = r
    self.flash  = 0
    self.stars  = {}
    for _ = 1, 60 do
        self.stars[#self.stars+1] = {
            x = math.random(), y = math.random(),
            s = math.random() * 0.8 + 0.2,
            v = math.random() * 0.04 + 0.01,
        }
    end
    return self
end

function Victory:update(dt)
    self.flash = (self.flash + dt * 2) % (2 * math.pi)
    for _, s in ipairs(self.stars) do
        s.y = s.y + s.v * dt
        if s.y > 1 then s.y = 0 end
    end
end

function Victory:draw()
    local W, H  = love.graphics.getDimensions()
    local alpha = 0.7 + 0.3 * math.abs(math.sin(self.flash))

    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    -- confetti stars
    for _, s in ipairs(self.stars) do
        local r = math.abs(math.sin(s.x * 7 + self.flash))
        local g = math.abs(math.sin(s.x * 13 + self.flash + 2))
        local b = math.abs(math.sin(s.x * 5 + self.flash + 4))
        love.graphics.setColor(r, g, b, s.s * 0.8)
        local sz = s.s * 6
        love.graphics.rectangle("fill", s.x * W, s.y * H, sz, sz, 1, 1)
    end

    -- title
    local bigFont = love.graphics.newFont(72)
    love.graphics.setFont(bigFont)
    love.graphics.setColor(C.title[1], C.title[2], C.title[3], alpha)
    local header = "YOU DID IT!"
    love.graphics.print(header, W/2 - bigFont:getWidth(header)/2, H * 0.15)

    local subFont = love.graphics.newFont(28)
    love.graphics.setFont(subFont)
    love.graphics.setColor(C.sub)
    local sub = "All 45 levels complete."
    love.graphics.print(sub, W/2 - subFont:getWidth(sub)/2, H * 0.15 + 84)

    -- play again
    local menuFont = love.graphics.newFont(32)
    love.graphics.setFont(menuFont)
    love.graphics.setColor(C.title[1], C.title[2], C.title[3], alpha)
    local msg = "> Play Again"
    love.graphics.print(msg, W/2 - menuFont:getWidth(msg)/2, H * 0.62)

    love.graphics.setColor(C.dim)
    local msg2 = "  Main Menu"
    love.graphics.print(msg2, W/2 - menuFont:getWidth(msg2)/2, H * 0.62 + 56)

    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.setColor(C.dim)
    local hint = "Enter / A — play again     Esc — main menu"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
end

function Victory:keypressed(key)
    if key == "return" or key == "space" then
        self.states.switch("game", require("systems.run").new())
    elseif key == "escape" then
        self.states.switch("menu")
    end
end

function Victory:gamepadpressed(joystick, button)
    if button == "a" then
        self.states.switch("game", require("systems.run").new())
    elseif button == "b" or button == "start" then
        self.states.switch("menu")
    end
end

return Victory
