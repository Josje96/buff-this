-- Ceiling-mounted stalactite. Stays fixed; periodically drops a spike projectile.
-- Each instance gets a phase offset so a row of stalactites doesn't all fire at once.

local Stalactite = {}
Stalactite.__index = Stalactite

local CYCLE       = 1.5    -- seconds between drops
local WARN_TIME   = 0.35   -- seconds before drop where the tile flashes
local SPIKE_SPEED = 440    -- px/s
local SPIKE_W     = 8
local SPIKE_H     = 22

function Stalactite.new(x, y, phaseOffset)
    local self = setmetatable({}, Stalactite)
    self.x      = x
    self.y      = y
    self.w      = 40
    self.h      = 40
    self.timer  = phaseOffset or 0
    self.spikes = {}
    return self
end

function Stalactite:update(dt, level)
    self.timer = self.timer + dt
    if self.timer >= CYCLE then
        self.timer = self.timer - CYCLE
        self.spikes[#self.spikes + 1] = {
            x  = self.x + self.w / 2 - SPIKE_W / 2,
            y  = self.y + self.h,
            vy = SPIKE_SPEED,
        }
    end

    local _, lh = level.getSize()
    local alive = {}
    for _, sp in ipairs(self.spikes) do
        sp.y = sp.y + sp.vy * dt
        local blocked = sp.y > lh
        if not blocked then
            for _, t in ipairs(level.getTilesInRect(sp.x, sp.y, SPIKE_W, SPIKE_H)) do
                if t.solid then blocked = true; break end
            end
        end
        if not blocked then alive[#alive + 1] = sp end
    end
    self.spikes = alive
end

function Stalactite:overlapsAnySpike(px, py, pw, ph)
    for _, sp in ipairs(self.spikes) do
        if px < sp.x + SPIKE_W and px + pw > sp.x
        and py < sp.y + SPIKE_H and py + ph > sp.y then
            return true
        end
    end
    return false
end

function Stalactite:draw(camX, camY, palette)
    local ts  = self.w
    local sx  = self.x - camX
    local sy  = self.y - camY
    local col = (palette and palette.hazard) or {0.90, 0.25, 0.20}

    -- fixture: body (top block) + downward tip
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", sx + 8, sy, ts - 16, ts * 0.40)
    love.graphics.polygon("fill",
        sx + 8,         sy + ts * 0.40,
        sx + ts - 8,    sy + ts * 0.40,
        sx + ts * 0.5,  sy + ts * 0.88)

    -- edge highlight
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line",
        sx + 8,         sy + ts * 0.40,
        sx + ts - 8,    sy + ts * 0.40,
        sx + ts * 0.5,  sy + ts * 0.88)

    -- warning flash before drop
    local timeLeft = CYCLE - self.timer
    if timeLeft < WARN_TIME then
        local a = (1 - timeLeft / WARN_TIME) * 0.55
        love.graphics.setColor(1, 0.95, 0.20, a)
        love.graphics.rectangle("fill", sx + 8, sy, ts - 16, ts * 0.40)
        love.graphics.polygon("fill",
            sx + 8,         sy + ts * 0.40,
            sx + ts - 8,    sy + ts * 0.40,
            sx + ts * 0.5,  sy + ts * 0.88)
    end

    -- falling spikes
    love.graphics.setColor(col)
    for _, sp in ipairs(self.spikes) do
        local spx = sp.x - camX
        local spy = sp.y - camY
        love.graphics.polygon("fill",
            spx,               spy,
            spx + SPIKE_W,     spy,
            spx + SPIKE_W / 2, spy + SPIKE_H)
        love.graphics.setColor(1, 1, 1, 0.28)
        love.graphics.polygon("line",
            spx,               spy,
            spx + SPIKE_W,     spy,
            spx + SPIKE_W / 2, spy + SPIKE_H)
        love.graphics.setColor(col)
    end

    love.graphics.setLineWidth(1)
end

return Stalactite
