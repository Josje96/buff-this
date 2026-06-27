local input = require("systems.input")

local Player = {}
Player.__index = Player

-- Base physics constants
local BASE = {
    speed       = 220,
    jumpForce   = -520,
    gravity     = 1400,
    maxFallSpeed = 900,
    maxJumps    = 1,     -- buffs can raise this
}

local W = 28
local H = 36
local COYOTE_TIME  = 0.08   -- seconds after walking off ledge where jump still works
local JUMP_BUFFER  = 0.10   -- seconds before landing where jump input is buffered

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
    self.w  = W
    self.h  = H

    self.onGround    = false
    self.jumpsLeft   = BASE.maxJumps
    self.coyoteTimer = 0
    self.jumpBuffer  = 0

    -- modifier overrides (set by buff system)
    self.mod = {
        speedMult  = 1,
        jumpMult   = 1,
        gravMult   = 1,
        maxJumps   = BASE.maxJumps,
        invertX    = false,
        slippery   = false,
    }

    self.dead       = false
    self.facingRight = true
    return self
end

function Player:update(dt, level)
    if self.dead then return end

    local mod = self.mod

    -- horizontal
    local dir = input.moveX()
    if mod.invertX then dir = -dir end
    local targetVX = dir * BASE.speed * mod.speedMult

    if mod.slippery then
        -- ice: lerp toward target instead of snapping
        local friction = self.onGround and 4 or 1.5
        self.vx = self.vx + (targetVX - self.vx) * friction * dt
    else
        self.vx = targetVX
    end

    if dir > 0 then self.facingRight = true
    elseif dir < 0 then self.facingRight = false end

    -- jump buffering
    if self.jumpBuffer > 0 then self.jumpBuffer = self.jumpBuffer - dt end

    if input.pressed("jump") then
        self.jumpBuffer = JUMP_BUFFER
    end

    -- coyote time
    if self.onGround then
        self.coyoteTimer  = COYOTE_TIME
        self.jumpsLeft    = mod.maxJumps
    else
        self.coyoteTimer = math.max(0, self.coyoteTimer - dt)
    end

    -- execute jump
    local canJump = (self.coyoteTimer > 0) or (self.jumpsLeft > 0)
    if self.jumpBuffer > 0 and canJump then
        self.vy          = BASE.jumpForce * mod.jumpMult
        self.jumpBuffer  = 0
        self.coyoteTimer = 0
        self.jumpsLeft   = self.jumpsLeft - 1
    end

    -- gravity
    local grav = BASE.gravity * mod.gravMult
    self.vy = math.min(self.vy + grav * dt, BASE.maxFallSpeed)

    -- move and collide
    self.x = self.x + self.vx * dt
    self:_resolveX(level)

    self.onGround = false
    self.y = self.y + self.vy * dt
    self:_resolveY(level)

    -- fell out of world
    local _, levelH = level.getSize()
    if self.y > levelH + 200 then
        self.dead = true
    end
end

function Player:_resolveX(level)
    local tiles = level.getTilesInRect(self.x, self.y, self.w, self.h)
    for _, tile in ipairs(tiles) do
        if tile.solid then
            if self.vx > 0 then
                self.x = tile.x - self.w
            elseif self.vx < 0 then
                self.x = tile.x + tile.w
            end
            self.vx = 0
        end
    end
end

function Player:_resolveY(level)
    local tiles = level.getTilesInRect(self.x, self.y, self.w, self.h)
    for _, tile in ipairs(tiles) do
        if tile.solid then
            if self.vy > 0 then
                self.y        = tile.y - self.h
                self.vy       = 0
                self.onGround = true
            elseif self.vy < 0 then
                self.y  = tile.y + tile.h
                self.vy = 0
            end
        end
    end
end

local COLORS = {
    body    = {0.20, 0.80, 1.00},
    outline = {0.10, 0.40, 0.60},
    eye     = {1.00, 1.00, 1.00},
    pupil   = {0.05, 0.05, 0.10},
}

function Player:draw(camX, camY)
    if self.dead then return end
    local px = self.x - camX
    local py = self.y - camY

    -- body
    love.graphics.setColor(COLORS.body)
    love.graphics.rectangle("fill", px, py, self.w, self.h, 4, 4)
    love.graphics.setColor(COLORS.outline)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, self.w, self.h, 4, 4)

    -- eye
    local eyeX = self.facingRight and (px + self.w - 10) or (px + 6)
    love.graphics.setColor(COLORS.eye)
    love.graphics.circle("fill", eyeX, py + 10, 5)
    love.graphics.setColor(COLORS.pupil)
    local pupilOff = self.facingRight and 2 or -2
    love.graphics.circle("fill", eyeX + pupilOff, py + 11, 2.5)
end

function Player:getRect()
    return self.x, self.y, self.w, self.h
end

return Player
