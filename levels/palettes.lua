-- Named color palettes, shared by the built-in levels (data.lua) and the
-- editor / custom-level format. Each palette is a set of colors used to draw a
-- level. Levels reference palettes by name so they can be serialized safely.

local P = {
    forest  = { bg={0.05,0.09,0.05}, ground={0.20,0.65,0.25}, platform={0.15,0.50,0.18}, hazard={0.90,0.25,0.20}, goal={1.00,0.85,0.10} },
    ocean   = { bg={0.04,0.06,0.18}, ground={0.20,0.45,0.80}, platform={0.15,0.35,0.65}, hazard={0.95,0.40,0.05}, goal={1.00,0.85,0.10} },
    lava    = { bg={0.12,0.04,0.04}, ground={0.55,0.20,0.08}, platform={0.45,0.15,0.06}, hazard={0.95,0.45,0.05}, goal={1.00,0.85,0.10} },
    night   = { bg={0.04,0.04,0.12}, ground={0.35,0.35,0.70}, platform={0.25,0.25,0.55}, hazard={0.90,0.20,0.50}, goal={1.00,0.85,0.10} },
    candy   = { bg={0.10,0.04,0.12}, ground={0.80,0.25,0.70}, platform={0.65,0.15,0.55}, hazard={0.30,0.90,0.50}, goal={1.00,0.90,0.20} },
    desert  = { bg={0.14,0.10,0.04}, ground={0.75,0.55,0.20}, platform={0.60,0.42,0.12}, hazard={0.90,0.25,0.20}, goal={1.00,0.85,0.10} },
    neon    = { bg={0.02,0.02,0.06}, ground={0.10,0.90,0.55}, platform={0.06,0.70,0.40}, hazard={0.95,0.10,0.30}, goal={0.90,0.90,0.10} },
    ice     = { bg={0.07,0.10,0.18}, ground={0.55,0.80,0.95}, platform={0.40,0.65,0.80}, hazard={0.95,0.95,1.00}, goal={1.00,0.85,0.10} },
    void    = { bg={0.02,0.01,0.05}, ground={0.50,0.20,0.80}, platform={0.38,0.12,0.62}, hazard={0.80,0.10,0.90}, goal={0.90,0.90,0.10} },
}

-- Stable display/cycle order for the editor picker.
local order = { "forest", "ocean", "lava", "night", "candy", "desert", "neon", "ice", "void" }

local palettes = {
    order = order,
}

-- name -> color table (falls back to forest for unknown names)
function palettes.resolve(name)
    return P[name] or P.forest
end

-- color table -> name (reverse lookup; used when editing a built-in level)
function palettes.nameOf(tbl)
    for name, colors in pairs(P) do
        if colors == tbl then return name end
    end
    return "forest"
end

-- Allow palettes.forest style access (so data.lua can `local P = require(...)`)
return setmetatable(palettes, { __index = P })
