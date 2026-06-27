local fonts = require("systems.fonts")
-- Browser for player-made / imported levels stored in the save directory.
-- Play, edit, delete, or import a level (paste a share code from the clipboard).

local userlevels = require("systems.userlevels")
local format     = require("levels.format")
local run        = require("systems.run")
local input      = require("systems.input")

local CustomLevels = {}
CustomLevels.__index = CustomLevels

local C = {
    bg     = {0.06, 0.06, 0.10},
    title  = {1.00, 0.75, 0.10},
    sel    = {0.20, 0.90, 0.60},
    normal = {0.80, 0.80, 0.85},
    dim    = {0.45, 0.45, 0.55},
    warn   = {0.95, 0.55, 0.20},
}

function CustomLevels.new(states)
    local self = setmetatable({}, CustomLevels)
    self.states = states
    self.cursor = 1
    self.flash  = 0
    self.msg, self.msgTimer = nil, 0
    self.confirmDelete = false
    self:_refresh()
    return self
end

function CustomLevels:_refresh()
    self.items = userlevels.list()
    if self.cursor > #self.items then self.cursor = math.max(1, #self.items) end
end

function CustomLevels:_message(t)
    self.msg, self.msgTimer = t, 2.5
end

function CustomLevels:update(dt)
    self.flash = (self.flash + dt * 4) % (2 * math.pi)
    if self.msgTimer > 0 then self.msgTimer = self.msgTimer - dt end
end

function CustomLevels:draw()
    local W, H = love.graphics.getDimensions()
    local alpha = 0.6 + 0.4 * math.abs(math.sin(self.flash))
    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    love.graphics.setFont(fonts.get(32))
    love.graphics.setColor(C.title)
    local header = "Custom Levels"
    love.graphics.print(header, W/2 - love.graphics.getFont():getWidth(header)/2, 28)

    if #self.items == 0 then
        love.graphics.setFont(fonts.get(18))
        love.graphics.setColor(C.dim)
        local none = "No custom levels yet."
        love.graphics.print(none, W/2 - love.graphics.getFont():getWidth(none)/2, H * 0.4)
        local hint = "Press C to create one, or I to import a share code from your clipboard."
        love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H * 0.4 + 30)
    else
        love.graphics.setFont(fonts.get(20))
        local startY = 110
        local rowH   = 34
        local maxRows = math.floor((H - startY - 90) / rowH)
        local top = 1
        if self.cursor > maxRows then top = self.cursor - maxRows + 1 end

        for i = top, math.min(#self.items, top + maxRows - 1) do
            local item  = self.items[i]
            local isSel = (i == self.cursor)
            local y = startY + (i - top) * rowH
            love.graphics.setColor(isSel and C.sel or C.normal)
            local prefix = isSel and "> " or "  "
            local meta = string.format("  [%s%s]", item.def.palette or "?",
                item.def.buff and (" / " .. item.def.buff) or "")
            love.graphics.print(prefix .. item.def.name, W/2 - 280, y)
            love.graphics.setColor(C.dim)
            love.graphics.print(meta, W/2 + 80, y)
        end
    end

    -- footer
    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(C.dim)
    local hint
    if self.confirmDelete then
        love.graphics.setColor(C.warn)
        hint = "Press D / RB again to DELETE this level, or any other key to cancel"
    else
        hint = "play Enter/A   edit E/X   new C/LB   import I/Y   delete D/RB   back Esc/B"
    end
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)

    if self.msgTimer > 0 and self.msg then
        love.graphics.setColor(0.2, 0.95, 0.6, math.min(1, self.msgTimer))
        love.graphics.print(self.msg, W/2 - love.graphics.getFont():getWidth(self.msg)/2, H - 64)
    end
end

-- ── actions ──
function CustomLevels:_play()
    local item = self.items[self.cursor]
    if not item then return end
    local r = run.new()
    r.customLevel = format.toPlayable(item.def)
    r.onExit      = "customlevels"
    self.states.switch("game", r)
end

function CustomLevels:_edit()
    local item = self.items[self.cursor]
    if not item then return end
    self.states.switch("editor", item.def)
end

function CustomLevels:_delete()
    local item = self.items[self.cursor]
    if not item then return end
    userlevels.delete(item.id)
    self:_message("Deleted " .. item.def.name)
    self:_refresh()
end

function CustomLevels:_import()
    local text = love.system.getClipboardText()
    local def, err = userlevels.importText(text)
    if def then
        self:_message("Imported: " .. (def.name or "level"))
        self:_refresh()
    else
        self:_message("Import failed: " .. tostring(err))
    end
end

function CustomLevels:_navigate(dir)
    if #self.items == 0 then return end
    self.cursor = ((self.cursor - 1 + dir) % #self.items) + 1
end

function CustomLevels:keypressed(key)
    -- delete confirmation swallows the next keypress
    if self.confirmDelete then
        self.confirmDelete = false
        if key == "d" then self:_delete() end
        return
    end

    if     key == "up"     then self:_navigate(-1)
    elseif key == "down"   then self:_navigate(1)
    elseif key == "return" or key == "space" then self:_play()
    elseif key == "e"      then self:_edit()
    elseif key == "c"      then self.states.switch("editor")
    elseif key == "i"      then self:_import()
    elseif key == "d"      then if self.items[self.cursor] then self.confirmDelete = true end
    elseif key == "escape" then self.states.switch("menu")
    end
end

function CustomLevels:gamepadpressed(joystick, button)
    -- delete confirmation swallows the next button
    if self.confirmDelete then
        self.confirmDelete = false
        if button == "rightshoulder" then self:_delete() end
        return
    end

    if     button == "dpup"   then self:_navigate(-1)
    elseif button == "dpdown" then self:_navigate(1)
    elseif button == "a"      then self:_play()
    elseif button == "x"      then self:_edit()
    elseif button == "y"      then self:_import()
    elseif button == "leftshoulder"  then self.states.switch("editor")          -- new
    elseif button == "rightshoulder" then if self.items[self.cursor] then self.confirmDelete = true end
    elseif button == "b" or button == "start" then self.states.switch("menu")
    end
end

function CustomLevels:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if nav == "up" then self:_navigate(-1) elseif nav == "down" then self:_navigate(1) end
end

return CustomLevels
