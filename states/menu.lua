local fonts = require("systems.fonts")
local run        = require("systems.run")
local input      = require("systems.input")
local userlevels = require("systems.userlevels")
local Menu = {}
Menu.__index = Menu

-- Retro palette
local C = {
    bg      = {0.08, 0.06, 0.12},
    title   = {1.00, 0.85, 0.10},
    item    = {0.90, 0.90, 0.90},
    select  = {0.20, 0.90, 0.60},
    dim     = {0.45, 0.45, 0.55},
}

local RESOLUTIONS = {
    { w = 0,    h = 0,    label = "Auto (desktop)" },
    { w = 1920, h = 1080, label = "1920 x 1080" },
    { w = 1280, h = 720,  label = "1280 x 720" },
    { w = 1600, h = 900,  label = "1600 x 900" },
    { w = 2560, h = 1440, label = "2560 x 1440" },
}

local function getItems()
    local t = { "Play", "Custom Levels", "Level Editor", "Import Level", "Resolution" }
    if DEV then t[#t+1] = "Level Select" end
    t[#t+1] = "Quit"
    return t
end

function Menu.new(states)
    local self = setmetatable({}, Menu)
    self.states      = states
    self.cursor      = 1
    self.resCursor   = 1
    self.resOpen     = false
    self.flash       = 0
    self.items       = getItems()
    return self
end

function Menu:update(dt)
    self.flash = (self.flash + dt * 3) % (2 * math.pi)
    if self.importMsgTimer and self.importMsgTimer > 0 then
        self.importMsgTimer = self.importMsgTimer - dt
    end
end

function Menu:draw()
    local W, H = love.graphics.getDimensions()
    local alpha = 0.6 + 0.4 * math.abs(math.sin(self.flash))

    love.graphics.setBackgroundColor(C.bg[1], C.bg[2], C.bg[3])
    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    -- title
    local titleFont = fonts.get(64)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(C.title)
    local title = "BUFF THIS"
    love.graphics.print(title, W/2 - titleFont:getWidth(title)/2, H * 0.15)

    -- subtitle
    local subFont18 = fonts.get(18)
    love.graphics.setFont(subFont18)
    love.graphics.setColor(C.dim)
    local sub = "a platformer with modifiers"
    love.graphics.print(sub, W/2 - subFont18:getWidth(sub)/2, H * 0.15 + 72)

    local menuFont = fonts.get(32)
    love.graphics.setFont(menuFont)
    local startY  = H * 0.42
    local spacing = 56

    if self.resOpen then
        -- show only "Resolution" header + the submenu list so nothing overlaps
        love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
        local header = "Resolution"
        love.graphics.print(header, W/2 - menuFont:getWidth(header)/2, startY)

        local subFont = fonts.get(28)
        love.graphics.setFont(subFont)
        local listY = startY + spacing + 8
        for i, res in ipairs(RESOLUTIONS) do
            local isSel = (self.resCursor == i)
            if isSel then
                love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
            else
                love.graphics.setColor(C.dim)
            end
            local prefix = isSel and "> " or "  "
            local rtext  = prefix .. res.label
            love.graphics.print(rtext, W/2 - subFont:getWidth(rtext)/2, listY + (i-1) * 44)
        end

        -- hint
        love.graphics.setFont(fonts.get(14))
        love.graphics.setColor(C.dim)
        local hint = "Up/Down to pick   Enter / A to apply   Esc / B to cancel"
        love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
    else
        -- normal main menu
        for i, label in ipairs(self.items) do
            local isSel = (self.cursor == i)
            if isSel then
                love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
            else
                love.graphics.setColor(C.item)
            end
            local prefix = isSel and "> " or "  "
            local text   = prefix .. label
            if label == "Resolution" then
                text = text .. "   [" .. RESOLUTIONS[self.resCursor].label .. "]"
            end
            love.graphics.print(text, W/2 - menuFont:getWidth(text)/2, startY + (i-1) * spacing)
        end

        -- hint
        love.graphics.setFont(fonts.get(14))
        love.graphics.setColor(C.dim)
        local hint = "Arrow keys / D-pad   Enter / A to select   F11 fullscreen"
        love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
    end

    if self.importMsgTimer and self.importMsgTimer > 0 and self.importMsg then
        love.graphics.setFont(fonts.get(15))
        love.graphics.setColor(0.95, 0.55, 0.20, math.min(1, self.importMsgTimer))
        love.graphics.print(self.importMsg, W/2 - love.graphics.getFont():getWidth(self.importMsg)/2, H - 62)
    end
end

function Menu:_confirm()
    local item = self.items[self.cursor]
    if item == "Play" then
        self.states.switch("game", run.new())
    elseif item == "Custom Levels" then
        self.states.switch("customlevels")
    elseif item == "Level Editor" then
        self.states.switch("editor")
    elseif item == "Import Level" then
        local def = userlevels.importText(love.system.getClipboardText())
        self.importMsg = def and ("Imported: " .. (def.name or "level"))
                              or  "Clipboard had no valid level code"
        self.importMsgTimer = 2.5
        if def then self.states.switch("customlevels") end
    elseif item == "Level Select" then
        self.states.switch("levelselect")
    elseif item == "Resolution" then
        if self.resOpen then
            self:_applyResolution()
            self.resOpen = false
        else
            self.resOpen = true
        end
    elseif item == "Quit" then
        love.event.quit()
    end
end

function Menu:_applyResolution()
    local res = RESOLUTIONS[self.resCursor]
    if res.w == 0 then
        -- auto: match desktop
        local dw, dh = love.window.getDesktopDimensions()
        love.window.setMode(dw, dh, { borderless = true, fullscreen = false })
    else
        love.window.setMode(res.w, res.h, { borderless = true, fullscreen = false })
    end
end

function Menu:_navigate(dir)
    if self.resOpen then
        self.resCursor = ((self.resCursor - 1 + dir) % #RESOLUTIONS) + 1
    else
        self.cursor = ((self.cursor - 1 + dir) % #self.items) + 1
    end
end

function Menu:keypressed(key)
    if key == "up"    then self:_navigate(-1)
    elseif key == "down"  then self:_navigate(1)
    elseif key == "return" or key == "space" then self:_confirm()
    elseif key == "escape" then
        if self.resOpen then self.resOpen = false
        else love.event.quit() end
    end
end

function Menu:gamepadpressed(joystick, button)
    if button == "dpup"   then self:_navigate(-1)
    elseif button == "dpdown" then self:_navigate(1)
    elseif button == "a" or button == "start" then self:_confirm()
    elseif button == "b"      then
        if self.resOpen then self.resOpen = false end
    end
end

function Menu:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if nav == "up"   then self:_navigate(-1)
    elseif nav == "down" then self:_navigate(1)
    end
end

return Menu
