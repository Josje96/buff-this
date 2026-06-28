local Enemy = {}
Enemy.__index = Enemy

local W      = 28
local H      = 32
local SPEED  = 80
local GRAVITY   = 1400
local MAX_FALL  = 800

function Enemy.new(x, y)
    local self = setmetatable({}, Enemy)
    self.x    = x
    self.y    = y
    self.w    = W
    self.h    = H
    self.vx   = SPEED
    self.vy   = 0
    self.onGround = false
    self.dead = false
    return self
end

function Enemy:update(dt, level)
    if self.dead then return end

    self.vy = math.min(self.vy + GRAVITY * dt, MAX_FALL)

    self.x = self.x + self.vx * dt
    self:_resolveX(level)

    self.onGround = false
    self.y = self.y + self.vy * dt
    self:_resolveY(level)

    -- turn at platform edges when standing
    if self.onGround then
        local aheadX = self.vx > 0 and (self.x + self.w + 2) or (self.x - 2)
        local belowY = self.y + self.h + 2
        if #level.getTilesInRect(aheadX, belowY, 1, 1) == 0 then
            self.vx = -self.vx
        end
    end

    local _, lh = level.getSize()
    if self.y > lh + 100 then self.dead = true end
end

function Enemy:_resolveX(level)
    local tiles   = level.getTilesInRect(self.x, self.y, self.w, self.h)
    local flipped = false
    for _, t in ipairs(tiles) do
        if t.solid then
            if self.vx > 0 then self.x = t.x - self.w
            elseif self.vx < 0 then self.x = t.x + t.w end
            if not flipped then self.vx = -self.vx; flipped = true end
        end
    end
end

function Enemy:_resolveY(level)
    local tiles = level.getTilesInRect(self.x, self.y, self.w, self.h)
    for _, t in ipairs(tiles) do
        if t.solid then
            if self.vy > 0 then
                self.y = t.y - self.h; self.vy = 0; self.onGround = true
            elseif self.vy < 0 then
                self.y = t.y + t.h; self.vy = 0
            end
        end
    end
end

function Enemy:overlaps(px, py, pw, ph)
    return px < self.x + self.w and px + pw > self.x
       and py < self.y + self.h and py + ph > self.y
end

function Enemy:draw(camX, camY)
    if self.dead then return end
    local sx = self.x - camX
    local sy = self.y - camY

    love.graphics.setColor(0.95, 0.25, 0.15)
    love.graphics.rectangle("fill", sx, sy, self.w, self.h, 4, 4)
    love.graphics.setColor(0.65, 0.10, 0.05)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx, sy, self.w, self.h, 4, 4)
    love.graphics.setLineWidth(1)

    -- eye facing direction of travel
    local eyeX = self.vx > 0 and (sx + self.w - 9) or (sx + 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", eyeX, sy + 9, 4)
    love.graphics.setColor(0.05, 0.05, 0.05)
    local poff = self.vx > 0 and 1.5 or -1.5
    love.graphics.circle("fill", eyeX + poff, sy + 10, 2)
end

return Enemy
