-- Tracks the state of a single run (3 lives, 45 levels in order).
local run = {}

local MAX_LIVES  = 3
local MAX_LEVELS = 45

function run.new()
    return {
        levelIdx  = 1,
        lives     = MAX_LIVES,
        maxLevels = MAX_LEVELS,
        dev       = false,   -- only Level Select sets this true
    }
end

function run.isOver(r)
    return r.lives <= 0
end

function run.isComplete(r)
    return r.levelIdx > MAX_LEVELS
end

function run.died(r)
    r.lives = r.lives - 1
end

function run.advance(r)
    r.levelIdx = r.levelIdx + 1
end

return run
