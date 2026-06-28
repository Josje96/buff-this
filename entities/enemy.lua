local assets = require("systems.assets")

local Enemy = {}
Enemy.__index = Enemy

local W          = 28
local H          = 32
local SPEED      = 80
local GRAVITY    = 1400
local MAX_FALL   = 800
local FRAME_TIME = 0.14   -- seconds per animation frame

local FRAME_PATHS = {
    "assets/enemy-bear1.png",
    "assets/enemy-bear2.png",
    "assets/enemy-bear3.png",
}
local frames = nil   -- loaded on first draw

local function getFrames()
    if not frames then
        frames = {}
        for _, p in ipairs(FRAME_PATHS) do
            frames[#frames + 1] = assets.image(p)
        end
    end
    return frames
end

function Enemy.new(x, y)
    local self = setmetatable({}, Enemy)
    self.x         = x
    self.y         = y
    self.w         = W
    self.h         = H
    self.vx        = SPEED
    self.vy        = 0
    self.onGround  = false
    self.dead      = false
    self.animTimer = 0
    self.animFrame = 1
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
        if #level.getTilesInRect(aheadX, self.y + self.h + 2, 1, 1) == 0 then
            self.vx = -self.vx
        end
    end

    -- advance animation
    self.animTimer = self.animTimer + dt
    if self.animTimer >= FRAME_TIME then
        self.animTimer = self.animTimer - FRAME_TIME
        self.animFrame = self.animFrame % #FRAME_PATHS + 1
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
    local img = getFrames()[self.animFrame]

    if img then
        love.graphics.setColor(1, 1, 1)
        if self.vx >= 0 then
            love.graphics.draw(img, sx, sy)
        else
            -- flip horizontally: anchor at right edge, scale x by -1
            love.graphics.draw(img, sx + self.w, sy, 0, -1, 1)
        end
    else
        -- fallback procedural
        love.graphics.setColor(0.95, 0.25, 0.15)
        love.graphics.rectangle("fill", sx, sy, self.w, self.h, 4, 4)
        love.graphics.setColor(0.65, 0.10, 0.05)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, self.w, self.h, 4, 4)
        love.graphics.setLineWidth(1)
        local eyeX = self.vx >= 0 and (sx + self.w - 9) or (sx + 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", eyeX, sy + 9, 4)
        love.graphics.setColor(0.05, 0.05, 0.05)
        love.graphics.circle("fill", eyeX + (self.vx >= 0 and 1.5 or -1.5), sy + 10, 2)
    end
end

return Enemy
