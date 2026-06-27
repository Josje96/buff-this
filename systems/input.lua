-- Unified input: maps keyboard + gamepad to named actions.
-- Usage: input.down("jump"), input.pressed("left"), input.released("right")
-- Call input.update() once per frame, input.gamepadpressed/released from love callbacks.

local input = {}

local KB_MAP = {
    left  = {"left",  "a"},
    right = {"right", "d"},
    jump  = {"up",    "w", "space", "z"},
    pause = {"escape", "p"},
}

local GP_MAP = {
    left  = {"dpleft"},
    right = {"dpright"},
    jump  = {"a", "dpup"},
    pause = {"start"},
}

local held     = {}  -- action -> bool (held this frame)
local justDown = {}  -- action -> bool (pressed this frame)
local justUp   = {}  -- action -> bool (released this frame)

local gpHeld     = {}  -- button -> bool
local gpJustDown = {}
local gpJustUp   = {}

local function actionDown(action)
    -- keyboard
    for _, key in ipairs(KB_MAP[action] or {}) do
        if love.keyboard.isDown(key) then return true end
    end
    -- gamepad
    for _, btn in ipairs(GP_MAP[action] or {}) do
        if gpHeld[btn] then return true end
    end
    return false
end

local prevDown = {}

function input.update()
    for action in pairs(KB_MAP) do
        local isDown = actionDown(action)
        justDown[action] = isDown and not prevDown[action]
        justUp[action]   = (not isDown) and prevDown[action]
        held[action]     = isDown
        prevDown[action] = isDown
    end
    -- clear per-frame gp edge flags
    gpJustDown = {}
    gpJustUp   = {}
end

-- called from love.gamepadpressed
function input.gamepadpressed(joystick, button)
    gpHeld[button]     = true
    gpJustDown[button] = true
end

-- called from love.gamepadreleased
function input.gamepadreleased(joystick, button)
    gpHeld[button]    = false
    gpJustUp[button]  = true
end

-- axis support (left stick horizontal)
local axisX = 0
function input.gamepadaxis(joystick, axis, value)
    if axis == "leftx" then axisX = value end
end

function input.down(action)    return held[action] or false end
function input.pressed(action) return justDown[action] or false end
function input.released(action) return justUp[action] or false end

-- returns -1, 0, or 1 for horizontal movement (combines keys + axis)
function input.moveX()
    local x = 0
    if input.down("left")  then x = x - 1 end
    if input.down("right") then x = x + 1 end
    if math.abs(axisX) > 0.2 then
        x = x + (axisX > 0 and 1 or -1)
    end
    return math.max(-1, math.min(1, x))
end

return input
