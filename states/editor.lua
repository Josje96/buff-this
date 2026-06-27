local fonts = require("systems.fonts")
-- In-game level editor.
--
-- Construct with an optional editable def to edit it, or nil for a blank level:
--   Editor.new(states)            -- new blank level
--   Editor.new(states, def)       -- edit an existing def (custom or built-in)
--
-- An "editable def" is { id?, name, palette=<name>, buff=<name|nil>, map={rows} }.
-- The editor paints a character grid (# solid, X hazard, S spawn, G goal,
-- space air) and can playtest, save, copy a share code, or (in DEV) copy a
-- Lua snippet to paste into levels/data.lua.
--
-- Input has full keyboard AND controller parity. Common actions are direct
-- buttons; the rest live in a controller-navigable command menu, and rename
-- uses an on-screen keyboard so a gamepad can type.

local palettes   = require("levels.palettes")
local format     = require("levels.format")
local userlevels = require("systems.userlevels")
local devlevels  = require("systems.devlevels")
local buffs      = require("systems.buffs")
local run        = require("systems.run")
local input      = require("systems.input")

local Editor = {}
Editor.__index = Editor

local CELL = 30   -- on-screen size of an editor cell

-- brush options: { char, label }
local BRUSHES = {
    { ch = "#", label = "Solid"  },
    { ch = "X", label = "Hazard" },
    { ch = "S", label = "Spawn"  },
    { ch = "G", label = "Goal"   },
    { ch = " ", label = "Erase"  },
}

-- on-screen keyboard layout (last row holds special keys)
local KB_ROWS = {
    "ABCDEFGHIJKLM",
    "NOPQRSTUVWXYZ",
    "0123456789 -_",
}
local KB_SPECIAL = { "SPACE", "DEL", "DONE" }

-- buff cycle list: nil (random) + every buff name
local function buffNames()
    local list = { nil }
    for _, b in ipairs(buffs.getAll()) do list[#list+1] = b.name end
    return list
end

-- ── construction ─────────────────────────────────────────────
local function blankGrid(w, h)
    local g = {}
    for r = 1, h do
        g[r] = {}
        for c = 1, w do g[r][c] = " " end
    end
    return g
end

local function gridFromMap(mapRows)
    local h = #mapRows
    local w = 0
    for _, row in ipairs(mapRows) do w = math.max(w, #row) end
    local g = blankGrid(w, h)
    for r = 1, h do
        local row = mapRows[r]
        for c = 1, w do
            local ch = row:sub(c, c)
            if ch == "#" or ch == "X" or ch == "S" or ch == "G" then
                g[r][c] = ch
            end
        end
    end
    return g, w, h
end

function Editor.new(states, def)
    local self = setmetatable({}, Editor)
    self.states = states

    if def and def.map then
        self.grid, self.W, self.H = gridFromMap(def.map)
        self.name        = def.name or "Untitled"
        self.paletteName = def.palette or "forest"
        self.buffName    = def.buff
        self.id          = def.id
        self.luaIdx      = def._builtinIdx   -- set when editing a data.lua level
    else
        self.W, self.H   = 40, 10
        self.grid        = blankGrid(self.W, self.H)
        for c = 1, self.W do self.grid[self.H][c] = "#" end  -- floor
        self.grid[5][3]          = "S"
        self.grid[self.H-1][self.W-3] = "G"
        self.name        = "New Level"
        self.paletteName = "forest"
        self.buffName    = nil
        self.id          = nil
    end

    self.cx, self.cy = 3, 5     -- cursor (col,row), 1-based
    self.brushIdx    = 1
    self.camX, self.camY = 0, 0
    self.flash       = 0        -- pulse for cursor
    self.msg, self.msgTimer = nil, 0

    self.mode      = "paint"    -- "paint" | "command" | "rename"
    self.cmdCursor = 1
    self.kbx, self.kby = 1, 1   -- on-screen keyboard cursor

    self.buffList = buffNames()
    return self
end

-- ── model helpers ────────────────────────────────────────────
function Editor:_message(text)
    self.msg, self.msgTimer = text, 2.5
end

function Editor:_clearUnique(target)
    for r = 1, self.H do
        for c = 1, self.W do
            if self.grid[r][c] == target then self.grid[r][c] = " " end
        end
    end
end

function Editor:_paint()
    local ch = BRUSHES[self.brushIdx].ch
    if ch == "S" or ch == "G" then self:_clearUnique(ch) end  -- only one each
    self.grid[self.cy][self.cx] = ch
end

function Editor:_cycleBrush(dir)
    self.brushIdx = ((self.brushIdx - 1 + dir) % #BRUSHES) + 1
end

function Editor:_moveCursor(dx, dy)
    self.cx = math.max(1, math.min(self.W, self.cx + dx))
    self.cy = math.max(1, math.min(self.H, self.cy + dy))
end

function Editor:_resize(dw, dh)
    -- no upper cap on level size; just a sane floor so the grid stays valid
    local newW = math.max(4, self.W + dw)
    local newH = math.max(4, self.H + dh)
    local g = blankGrid(newW, newH)
    for r = 1, math.min(self.H, newH) do
        for c = 1, math.min(self.W, newW) do g[r][c] = self.grid[r][c] end
    end
    self.grid, self.W, self.H = g, newW, newH
    self.cx = math.min(self.cx, newW)
    self.cy = math.min(self.cy, newH)
end

function Editor:_cyclePalette(dir)
    local order = palettes.order
    local idx = 1
    for i, n in ipairs(order) do if n == self.paletteName then idx = i end end
    idx = ((idx - 1 + dir) % #order) + 1
    self.paletteName = order[idx]
end

function Editor:_cycleBuff(dir)
    local idx = 1
    for i = 1, #self.buffList do
        if self.buffList[i] == self.buffName then idx = i end
    end
    idx = ((idx - 1 + dir) % #self.buffList) + 1
    self.buffName = self.buffList[idx]   -- may be nil (random)
end

-- editable def from current state
function Editor:_def()
    local rows = {}
    for r = 1, self.H do rows[r] = table.concat(self.grid[r]) end
    return {
        id      = self.id,
        name    = self.name,
        palette = self.paletteName,
        buff    = self.buffName,
        map     = rows,
        -- carry the built-in link so it survives a playtest round-trip (the
        -- editor is rebuilt from this def on return); otherwise a built-in
        -- edit would silently fall back to saving as a custom level.
        _builtinIdx = self.luaIdx,
    }
end

-- ── actions ──────────────────────────────────────────────────
function Editor:_playtest()
    local r = run.new()
    r.dev         = true
    r.lives       = math.huge
    r.onExit      = "editor"
    r.exitArg     = self:_def()
    r.customLevel = format.toPlayable(self:_def())
    self.states.switch("game", r)
end

function Editor:_save()
    -- DEV: editing a built-in writes straight back to levels/data.lua so level
    -- design iterates fast. Everything else (and any shipped build) saves a
    -- copy to the user's custom levels.
    if DEV and self.luaIdx then
        local ok, err = devlevels.saveBuiltin(self.luaIdx, self:_def())
        if ok then
            self:_message("Saved to data.lua (level " .. self.luaIdx .. ")")
        else
            self:_message("Save failed: " .. tostring(err))
        end
        return
    end

    local id, err = userlevels.save(self:_def())
    if id then
        self.id = id
        self:_message("Saved to custom levels")
    else
        self:_message("Save failed: " .. tostring(err))
    end
end

function Editor:_copyCode()
    love.system.setClipboardText(format.encode(self:_def()))
    self:_message("Share code copied to clipboard")
end

function Editor:_copyLua()
    love.system.setClipboardText(format.encodeLua(self:_def(), self.luaIdx))
    local where = self.luaIdx and ("levels[" .. self.luaIdx .. "]") or "levels[N]"
    self:_message("Lua copied (" .. where .. ") — paste into levels/data.lua")
end

-- ── command menu ─────────────────────────────────────────────
-- Each item: { label fn, kind, adjust? }. kind drives behavior.
function Editor:_cmdItems()
    local items = {
        { kind = "palette",  value = function() return self.paletteName end,            adjust = true },
        { kind = "buff",     value = function() return self.buffName or "random" end,   adjust = true },
        { kind = "width",    value = function() return tostring(self.W) end,            adjust = true },
        { kind = "height",   value = function() return tostring(self.H) end,            adjust = true },
        { kind = "rename",   label = "Rename" },
        { kind = "save",     label = (DEV and self.luaIdx)
                                     and ("Save to data.lua (lvl " .. self.luaIdx .. ")")
                                     or  "Save to custom levels" },
        { kind = "copycode", label = "Copy share code" },
    }
    if DEV then items[#items+1] = { kind = "copylua", label = "Copy Lua (data.lua)" } end
    items[#items+1] = { kind = "playtest", label = "Playtest" }
    items[#items+1] = { kind = "close",    label = "Close menu" }
    return items
end

function Editor:_cmdLabel(item)
    if item.adjust then
        local names = { palette = "Palette", buff = "Buff", width = "Width", height = "Height" }
        return string.format("%-8s  < %s >", names[item.kind], item.value())
    end
    return item.label
end

function Editor:_cmdAdjust(dir)
    local item = self:_cmdItems()[self.cmdCursor]
    if not item then return end
    if     item.kind == "palette" then self:_cyclePalette(dir)
    elseif item.kind == "buff"    then self:_cycleBuff(dir)
    elseif item.kind == "width"   then self:_resize(dir, 0)
    elseif item.kind == "height"  then self:_resize(0, dir)
    end
end

function Editor:_cmdActivate()
    local item = self:_cmdItems()[self.cmdCursor]
    if not item then return end
    if     item.kind == "rename"   then self.mode = "rename"
    elseif item.kind == "save"     then self:_save()
    elseif item.kind == "copycode" then self:_copyCode(); self.mode = "paint"
    elseif item.kind == "copylua"  then self:_copyLua();  self.mode = "paint"
    elseif item.kind == "playtest" then self:_playtest()
    elseif item.kind == "close"    then self.mode = "paint"
    -- palette/buff/width/height are adjusted with left/right, A does nothing
    end
end

function Editor:_cmdMove(d)
    local n = #self:_cmdItems()
    self.cmdCursor = ((self.cmdCursor - 1 + d) % n) + 1
end

-- ── on-screen keyboard (rename) ──────────────────────────────
function Editor:_kbChar()
    if self.kby <= #KB_ROWS then
        local row = KB_ROWS[self.kby]
        return row:sub(self.kbx, self.kbx)
    else
        return KB_SPECIAL[self.kbx]   -- special row
    end
end

function Editor:_kbPress()
    if self.kby <= #KB_ROWS then
        if #self.name < 28 then self.name = self.name .. self:_kbChar() end
    else
        local key = KB_SPECIAL[self.kbx]
        if     key == "SPACE" then if #self.name < 28 then self.name = self.name .. " " end
        elseif key == "DEL"   then self.name = self.name:sub(1, -2)
        elseif key == "DONE"  then self.mode = "command"
        end
    end
end

function Editor:_kbMove(dx, dy)
    self.kby = self.kby + dy
    if self.kby < 1 then self.kby = #KB_ROWS + 1 end
    if self.kby > #KB_ROWS + 1 then self.kby = 1 end
    local rowLen = (self.kby <= #KB_ROWS) and #KB_ROWS[self.kby] or #KB_SPECIAL
    self.kbx = self.kbx + dx
    if self.kbx < 1 then self.kbx = rowLen end
    if self.kbx > rowLen then self.kbx = 1 end
end

-- ── update ───────────────────────────────────────────────────
function Editor:update(dt)
    self.flash = (self.flash + dt * 5) % (2 * math.pi)
    if self.msgTimer > 0 then self.msgTimer = self.msgTimer - dt end

    -- camera centers on the cursor (only while painting)
    if self.mode == "paint" then
        local Wd, Hd = love.graphics.getDimensions()
        local targetX = (self.cx - 0.5) * CELL - Wd / 2
        local targetY = (self.cy - 0.5) * CELL - Hd / 2
        self.camX = self.camX + (targetX - self.camX) * math.min(1, 12 * dt)
        self.camY = self.camY + (targetY - self.camY) * math.min(1, 12 * dt)
    end
end

-- ── draw ─────────────────────────────────────────────────────
function Editor:draw()
    local Wd, Hd = love.graphics.getDimensions()
    local p = palettes.resolve(self.paletteName)
    love.graphics.clear(p.bg[1], p.bg[2], p.bg[3])

    -- grid cells
    for r = 1, self.H do
        for c = 1, self.W do
            local sx = (c - 1) * CELL - self.camX
            local sy = (r - 1) * CELL - self.camY
            if sx + CELL >= 0 and sx <= Wd and sy + CELL >= 0 and sy <= Hd then
                local ch = self.grid[r][c]
                love.graphics.setColor(1, 1, 1, 0.05)
                love.graphics.rectangle("line", sx, sy, CELL, CELL)
                if ch == "#" then
                    love.graphics.setColor(p.ground)
                    love.graphics.rectangle("fill", sx, sy, CELL, CELL)
                    love.graphics.setColor(p.platform)
                    love.graphics.rectangle("line", sx, sy, CELL, CELL)
                elseif ch == "X" then
                    love.graphics.setColor(p.hazard)
                    love.graphics.rectangle("fill", sx + 2, sy + 2, CELL - 4, CELL - 4)
                elseif ch == "S" then
                    love.graphics.setColor(0.2, 0.8, 1.0)
                    love.graphics.rectangle("fill", sx + 6, sy + 4, CELL - 12, CELL - 6, 3, 3)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print("S", sx + CELL/2 - 4, sy + CELL/2 - 8)
                elseif ch == "G" then
                    love.graphics.setColor(p.goal)
                    love.graphics.rectangle("fill", sx + 5, sy + 2, CELL - 10, CELL - 4, 3, 3)
                    love.graphics.setColor(0, 0, 0, 0.6)
                    love.graphics.print("!", sx + CELL/2 - 3, sy + CELL/2 - 8)
                end
            end
        end
    end

    -- cursor
    local cux = (self.cx - 1) * CELL - self.camX
    local cuy = (self.cy - 1) * CELL - self.camY
    local a = 0.5 + 0.4 * math.abs(math.sin(self.flash))
    love.graphics.setColor(1, 1, 0.3, a)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", cux, cuy, CELL, CELL)

    -- ── HUD ──
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, Wd, 64)
    love.graphics.rectangle("fill", 0, Hd - 52, Wd, 52)

    love.graphics.setFont(fonts.get(16))
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.print("EDITOR — " .. self.name, 14, 10)

    love.graphics.setFont(fonts.get(13))
    love.graphics.setColor(0.85, 0.85, 0.9)
    local meta = string.format("Brush: %s    Palette: %s    Buff: %s    Size: %dx%d    (%d,%d)",
        BRUSHES[self.brushIdx].label, self.paletteName, self.buffName or "random",
        self.W, self.H, self.cx, self.cy)
    love.graphics.print(meta, 14, 36)

    love.graphics.setColor(0.7, 0.7, 0.8)
    local kbHelp = "KB: Move WASD/Arrows  Paint Space  Brush Tab  Palette P/O  Buff U/I  Size -/=,[/]  Rename N  Playtest F5  Save F2  Code F3  Menu M"
    local padHelp = "Pad: Move stick/dpad  Paint A  Brush LB/RB  Playtest X  Save Y  Menu (Back)  Quit (Start)"
    love.graphics.print(kbHelp, 14, Hd - 46)
    love.graphics.print(padHelp, 14, Hd - 28)

    -- transient message
    if self.msgTimer > 0 and self.msg then
        love.graphics.setFont(fonts.get(16))
        love.graphics.setColor(0.2, 0.95, 0.6, math.min(1, self.msgTimer))
        love.graphics.print(self.msg, Wd/2 - love.graphics.getFont():getWidth(self.msg)/2, 70)
    end

    if self.mode == "command" then self:_drawCommand(Wd, Hd) end
    if self.mode == "rename"  then self:_drawKeyboard(Wd, Hd) end
end

function Editor:_drawCommand(Wd, Hd)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, Wd, Hd)
    local items = self:_cmdItems()
    love.graphics.setFont(fonts.get(22))
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.print("Editor Menu", Wd/2 - 110, Hd * 0.18)
    love.graphics.setFont(fonts.get(20))
    local y = Hd * 0.18 + 50
    for i, item in ipairs(items) do
        local isSel = (i == self.cmdCursor)
        love.graphics.setColor(isSel and {0.2, 0.95, 0.6} or {0.8, 0.8, 0.85})
        local prefix = isSel and "> " or "  "
        love.graphics.print(prefix .. self:_cmdLabel(item), Wd/2 - 150, y + (i-1) * 32)
    end
    love.graphics.setFont(fonts.get(13))
    love.graphics.setColor(0.6, 0.6, 0.7)
    local hint = "Up/Down move   Left/Right adjust   A/Enter select   B/Esc close"
    love.graphics.print(hint, Wd/2 - love.graphics.getFont():getWidth(hint)/2, Hd - 40)
end

function Editor:_drawKeyboard(Wd, Hd)
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, Wd, Hd)
    love.graphics.setFont(fonts.get(28))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Name: " .. self.name .. "_", Wd/2 - 250, Hd * 0.22)

    love.graphics.setFont(fonts.get(22))
    local startX, startY, gap = Wd/2 - 250, Hd * 0.36, 36
    for ry = 1, #KB_ROWS do
        local row = KB_ROWS[ry]
        for cx = 1, #row do
            local sel = (self.kby == ry and self.kbx == cx)
            love.graphics.setColor(sel and {0.2, 0.95, 0.6} or {0.8, 0.8, 0.85})
            love.graphics.print(row:sub(cx, cx), startX + (cx-1) * gap, startY + (ry-1) * gap)
        end
    end
    -- special row
    local sy = startY + #KB_ROWS * gap + 6
    local sx = startX
    for i, label in ipairs(KB_SPECIAL) do
        local sel = (self.kby == #KB_ROWS + 1 and self.kbx == i)
        love.graphics.setColor(sel and {0.2, 0.95, 0.6} or {0.85, 0.7, 0.4})
        love.graphics.print("[" .. label .. "]", sx, sy)
        sx = sx + love.graphics.getFont():getWidth("[" .. label .. "]  ")
    end

    love.graphics.setFont(fonts.get(13))
    love.graphics.setColor(0.6, 0.6, 0.7)
    local hint = "Move dpad/stick   A add   Y backspace   Start done   (keyboard: just type, Enter done)"
    love.graphics.print(hint, Wd/2 - love.graphics.getFont():getWidth(hint)/2, Hd - 40)
end

-- ── input: keyboard ──────────────────────────────────────────
function Editor:textinput(t)
    if self.mode == "rename" and #self.name < 28 then
        -- accept printable text typed on a physical keyboard
        if t:match("^[%w%s%-_]$") then self.name = self.name .. t end
    end
end

function Editor:keypressed(key)
    if self.mode == "rename" then
        if     key == "return" then self.mode = "command"
        elseif key == "escape" then self.mode = "command"
        elseif key == "backspace" then self.name = self.name:sub(1, -2)
        end
        return
    end

    if self.mode == "command" then
        if     key == "up"    then self:_cmdMove(-1)
        elseif key == "down"  then self:_cmdMove(1)
        elseif key == "left"  then self:_cmdAdjust(-1)
        elseif key == "right" then self:_cmdAdjust(1)
        elseif key == "return" or key == "space" then self:_cmdActivate()
        elseif key == "escape" or key == "m" then self.mode = "paint"
        end
        return
    end

    -- paint mode
    if     key == "left"  or key == "a" then self:_moveCursor(-1, 0)
    elseif key == "right" or key == "d" then self:_moveCursor( 1, 0)
    elseif key == "up"    or key == "w" then self:_moveCursor( 0, -1)
    elseif key == "down"  or key == "s" then self:_moveCursor( 0,  1)
    elseif key == "space" or key == "return" then self:_paint()
    elseif key == "tab"   or key == "b" then self:_cycleBrush(1)
    elseif key == "1" then self.brushIdx = 1
    elseif key == "2" then self.brushIdx = 2
    elseif key == "3" then self.brushIdx = 3
    elseif key == "4" then self.brushIdx = 4
    elseif key == "5" then self.brushIdx = 5
    elseif key == "p" then self:_cyclePalette(1)
    elseif key == "o" then self:_cyclePalette(-1)
    elseif key == "u" then self:_cycleBuff(1)
    elseif key == "i" then self:_cycleBuff(-1)
    elseif key == "-" then self:_resize(-1, 0)
    elseif key == "=" then self:_resize( 1, 0)
    elseif key == "[" then self:_resize(0, -1)
    elseif key == "]" then self:_resize(0,  1)
    elseif key == "n" then self.mode = "rename"
    elseif key == "m" then self.mode = "command"; self.cmdCursor = 1
    elseif key == "f5" then self:_playtest()
    elseif key == "f2" then self:_save()
    elseif key == "f3" then self:_copyCode()
    elseif key == "f4" then if DEV then self:_copyLua() end
    elseif key == "escape" then self.states.switch("menu")
    end
end

-- ── input: gamepad ───────────────────────────────────────────
function Editor:gamepadpressed(joystick, button)
    if self.mode == "rename" then
        if     button == "dpleft"  then self:_kbMove(-1, 0)
        elseif button == "dpright" then self:_kbMove( 1, 0)
        elseif button == "dpup"    then self:_kbMove( 0, -1)
        elseif button == "dpdown"  then self:_kbMove( 0,  1)
        elseif button == "a"       then self:_kbPress()
        elseif button == "y"       then self.name = self.name:sub(1, -2)
        elseif button == "b"       then self.mode = "command"
        elseif button == "start"   then self.mode = "command"
        end
        return
    end

    if self.mode == "command" then
        if     button == "dpup"    then self:_cmdMove(-1)
        elseif button == "dpdown"  then self:_cmdMove(1)
        elseif button == "dpleft"  then self:_cmdAdjust(-1)
        elseif button == "dpright" then self:_cmdAdjust(1)
        elseif button == "a"       then self:_cmdActivate()
        elseif button == "b" or button == "back" or button == "start" then self.mode = "paint"
        end
        return
    end

    -- paint mode
    if     button == "dpleft"  then self:_moveCursor(-1, 0)
    elseif button == "dpright" then self:_moveCursor( 1, 0)
    elseif button == "dpup"    then self:_moveCursor( 0, -1)
    elseif button == "dpdown"  then self:_moveCursor( 0,  1)
    elseif button == "a"             then self:_paint()
    elseif button == "leftshoulder"  then self:_cycleBrush(-1)
    elseif button == "rightshoulder" then self:_cycleBrush(1)
    elseif button == "x"       then self:_playtest()
    elseif button == "y"       then self:_save()
    elseif button == "back" or button == "b" then self.mode = "command"; self.cmdCursor = 1
    elseif button == "start"   then self.states.switch("menu")
    end
end

function Editor:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if not nav then return end
    if self.mode == "rename" then
        if     nav == "left"  then self:_kbMove(-1, 0)
        elseif nav == "right" then self:_kbMove( 1, 0)
        elseif nav == "up"    then self:_kbMove( 0, -1)
        elseif nav == "down"  then self:_kbMove( 0,  1)
        end
    elseif self.mode == "command" then
        if     nav == "up"    then self:_cmdMove(-1)
        elseif nav == "down"  then self:_cmdMove(1)
        elseif nav == "left"  then self:_cmdAdjust(-1)
        elseif nav == "right" then self:_cmdAdjust(1)
        end
    else
        if     nav == "left"  then self:_moveCursor(-1, 0)
        elseif nav == "right" then self:_moveCursor( 1, 0)
        elseif nav == "up"    then self:_moveCursor( 0, -1)
        elseif nav == "down"  then self:_moveCursor( 0,  1)
        end
    end
end

return Editor
