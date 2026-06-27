-- Buff/debuff definitions.
-- Each entry: { name, description, color, apply(player), drawFX(dt) }
-- apply() writes into player.mod; reset() is called on level exit.
-- drawFX() is optional — called after the scene draws for screen effects.

local buffs = {}

local all = {}

-- helpers
local function resetMod(player)
    player.mod.speedMult = 1
    player.mod.jumpMult  = 1
    player.mod.gravMult  = 1
    player.mod.maxJumps  = 1
    player.mod.invertX   = false
    player.mod.slippery  = false
end

-- ── No modifier ──────────────────────────────────────────────
all[#all+1] = {
    name        = "No Modifier",
    description = "Just you and the level. Good luck.",
    color       = {0.7, 0.7, 0.7},
    apply = function(player) resetMod(player) end,
    drawFX = nil,
}

-- ── Infinite Jump ────────────────────────────────────────────
all[#all+1] = {
    name        = "Infinite Jump",
    description = "You can jump forever. Time it right to fly.",
    color       = {0.40, 0.90, 1.00},
    apply = function(player)
        resetMod(player)
        player.mod.maxJumps = 999
    end,
    drawFX = nil,
}

-- ── Molasses ─────────────────────────────────────────────────
all[#all+1] = {
    name        = "Molasses",
    description = "Everything is sloooow.",
    color       = {0.70, 0.45, 0.10},
    apply = function(player)
        resetMod(player)
        player.mod.speedMult = 0.35
        player.mod.jumpMult  = 0.60
        player.mod.gravMult  = 0.40
    end,
    drawFX = nil,
}

-- ── Speed Demon ───────────────────────────────────────────────
all[#all+1] = {
    name        = "Speed Demon",
    description = "Way too fast. Good luck stopping.",
    color       = {1.00, 0.30, 0.20},
    apply = function(player)
        resetMod(player)
        player.mod.speedMult = 2.6
    end,
    drawFX = nil,
}

-- ── Floaty ────────────────────────────────────────────────────
all[#all+1] = {
    name        = "Floaty",
    description = "Low gravity. Big floaty jumps.",
    color       = {0.60, 0.80, 1.00},
    apply = function(player)
        resetMod(player)
        player.mod.gravMult = 0.35
        player.mod.jumpMult = 0.70
        player.mod.maxJumps = 2
    end,
    drawFX = nil,
}

-- ── Heavy ─────────────────────────────────────────────────────
all[#all+1] = {
    name        = "Heavy",
    description = "Gravity hates you today.",
    color       = {0.50, 0.30, 0.70},
    apply = function(player)
        resetMod(player)
        player.mod.gravMult = 2.8
        -- jumpMult = sqrt(gravMult) keeps peak jump height equal to a standard
        -- jump (height scales as jumpMult^2 / gravMult); fall is just faster.
        player.mod.jumpMult = 1.70
    end,
    drawFX = nil,
}

-- ── Backwards ─────────────────────────────────────────────────
all[#all+1] = {
    name        = "Backwards",
    description = "Left is right. Right is left. Deal with it.",
    color       = {0.90, 0.20, 0.70},
    apply = function(player)
        resetMod(player)
        player.mod.invertX = true
    end,
    drawFX = nil,
}

-- ── Double Jump ───────────────────────────────────────────────
all[#all+1] = {
    name        = "Double Jump",
    description = "Two jumps. Use them wisely.",
    color       = {0.20, 0.90, 0.60},
    apply = function(player)
        resetMod(player)
        player.mod.maxJumps = 2
    end,
    drawFX = nil,
}

-- ── Trippy ────────────────────────────────────────────────────
local trippyTime = 0
all[#all+1] = {
    name        = "Trippy",
    description = "The screen is doing its own thing. Stay focused.",
    color       = {0.80, 0.20, 0.90},
    apply = function(player)
        resetMod(player)
        trippyTime = 0
    end,
    drawFX = function(dt)
        trippyTime = trippyTime + dt
        local W, H = love.graphics.getDimensions()
        -- pulsing color overlay
        local r = 0.5 + 0.5 * math.sin(trippyTime * 1.7)
        local g = 0.5 + 0.5 * math.sin(trippyTime * 2.3 + 2)
        local b = 0.5 + 0.5 * math.sin(trippyTime * 3.1 + 4)
        love.graphics.setColor(r * 0.15, g * 0.15, b * 0.15, 0.55)
        love.graphics.rectangle("fill", 0, 0, W, H)
        -- scanline shimmer
        love.graphics.setColor(1, 1, 1, 0.04)
        local offset = (trippyTime * 60) % 4
        for y = offset, H, 4 do
            love.graphics.rectangle("fill", 0, y, W, 2)
        end
        -- edge warp indicator lines
        local wobble = math.sin(trippyTime * 5) * 6
        love.graphics.setColor(r, g * 0.5, b, 0.25)
        love.graphics.setLineWidth(2)
        love.graphics.line(wobble, 0, wobble, H)
        love.graphics.line(W + wobble, 0, W + wobble, H)
    end,
}

-- ── Ice ───────────────────────────────────────────────────────
all[#all+1] = {
    name        = "Ice",
    description = "The floor is slippery. Stopping is optional.",
    color       = {0.70, 0.95, 1.00},
    apply = function(player)
        resetMod(player)
        player.mod.slippery = true
    end,
    drawFX = function(dt)
        -- subtle blue-white tint
        local W, H = love.graphics.getDimensions()
        love.graphics.setColor(0.70, 0.95, 1.00, 0.08)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end,
}

-- ── Public API ────────────────────────────────────────────────

function buffs.random()
    return all[math.random(#all)]
end

function buffs.getAll()
    return all
end

-- returns the buff with the given name (and its index), or nil
function buffs.byName(name)
    for i, b in ipairs(all) do
        if b.name == name then return b, i end
    end
    return nil
end

function buffs.apply(buff, player)
    if buff and buff.apply then buff.apply(player) end
end

function buffs.reset(player)
    resetMod(player)
end

return buffs
