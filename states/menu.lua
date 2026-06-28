local fonts     = require("systems.fonts")
local run       = require("systems.run")
local input     = require("systems.input")
local userlevels = require("systems.userlevels")

local Menu = {}
Menu.__index = Menu

local C = {
    bg      = {0.08, 0.06, 0.12},
    title   = {1.00, 0.85, 0.10},
    item    = {0.90, 0.90, 0.90},
    select  = {0.20, 0.90, 0.60},
    dim     = {0.45, 0.45, 0.55},
    box     = {0.13, 0.10, 0.20},
    boxbord = {0.28, 0.22, 0.42},
}

local RESOLUTIONS = {
    { w = 0,    h = 0,    label = "Auto (desktop)" },
    { w = 1920, h = 1080, label = "1920 x 1080" },
    { w = 1280, h = 720,  label = "1280 x 720" },
    { w = 1600, h = 900,  label = "1600 x 900" },
    { w = 2560, h = 1440, label = "2560 x 1440" },
}

local SCREENS = {
    main     = { "Play", "Dev Mode", "Settings", "Quit" },
    devmode  = { "Level Select", "Level Editor", "Custom Levels", "Import Level", "Back" },
    settings = { "Resolution", "Sound", "Back" },
}

local volume = 100  -- 0–100; wired to love.audio so it works once sounds are added

-- ──────────────────────────────────────────────────────────────
-- helpers
-- ──────────────────────────────────────────────────────────────

local function drawBox(x, y, w, h)
    love.graphics.setColor(C.box)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)
    love.graphics.setColor(C.boxbord)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 14, 14)
    love.graphics.setLineWidth(1)
end

local function drawSlider(cx, y, w, val)
    local h = 10
    love.graphics.setColor(0.18, 0.15, 0.28)
    love.graphics.rectangle("fill", cx - w/2, y, w, h, 4, 4)
    local fill = math.max(0, w * val / 100)
    love.graphics.setColor(0.20, 0.90, 0.60)
    if fill > 0 then
        love.graphics.rectangle("fill", cx - w/2, y, fill, h, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", cx - w/2 + fill, y + h/2, 6)
end

-- ──────────────────────────────────────────────────────────────

function Menu.new(states)
    local self = setmetatable({}, Menu)
    self.states    = states
    self.cursor    = 1
    self.flash     = 0
    self.screen    = "main"
    self.resCursor = 1
    self.resOpen   = false
    return self
end

function Menu:items() return SCREENS[self.screen] end

function Menu:update(dt)
    self.flash = (self.flash + dt * 3) % (2 * math.pi)
    if self.importMsgTimer and self.importMsgTimer > 0 then
        self.importMsgTimer = self.importMsgTimer - dt
    end
end

-- ──────────────────────────────────────────────────────────────
-- draw
-- ──────────────────────────────────────────────────────────────

function Menu:draw()
    local W, H = love.graphics.getDimensions()
    local alpha = 0.6 + 0.4 * math.abs(math.sin(self.flash))

    love.graphics.setBackgroundColor(C.bg[1], C.bg[2], C.bg[3])
    love.graphics.clear(C.bg[1], C.bg[2], C.bg[3])

    -- Title
    local tf = fonts.get(64)
    love.graphics.setFont(tf)
    love.graphics.setColor(C.title)
    local title = "BUFF THIS"
    love.graphics.print(title, W/2 - tf:getWidth(title)/2, H * 0.15)

    -- Subtitle
    local subf = fonts.get(18)
    love.graphics.setFont(subf)
    love.graphics.setColor(C.dim)
    local sub = "a platformer with modifiers"
    love.graphics.print(sub, W/2 - subf:getWidth(sub)/2, H * 0.15 + 72)

    if self.resOpen then
        self:_drawResolution(W, H, alpha)
    elseif self.screen == "settings" then
        self:_drawSettings(W, H, alpha)
    else
        self:_drawItemList(W, H, alpha)
    end

    -- Import feedback
    if self.importMsgTimer and self.importMsgTimer > 0 and self.importMsg then
        love.graphics.setFont(fonts.get(15))
        love.graphics.setColor(0.95, 0.55, 0.20, math.min(1, self.importMsgTimer))
        local mw = love.graphics.getFont():getWidth(self.importMsg)
        love.graphics.print(self.importMsg, W/2 - mw/2, H - 62)
    end
end

function Menu:_drawItemList(W, H, alpha)
    local items   = self:items()
    local mf      = fonts.get(32)
    local spacing = 56
    local startY  = H * 0.42
    love.graphics.setFont(mf)

    -- Size the box to the widest label
    local pad  = 60
    local maxW = 0
    for _, lbl in ipairs(items) do
        local w = mf:getWidth("> " .. lbl)
        if w > maxW then maxW = w end
    end
    local bw = maxW + pad * 2
    local bh = (#items - 1) * spacing + mf:getHeight() + 48
    drawBox(W/2 - bw/2, startY - 20, bw, bh)

    for i, lbl in ipairs(items) do
        local sel = (self.cursor == i)
        if sel then
            love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
        else
            love.graphics.setColor(C.item)
        end
        local text = (sel and "> " or "  ") .. lbl
        love.graphics.print(text, W/2 - mf:getWidth(text)/2, startY + (i-1) * spacing)
    end

    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(C.dim)
    local hint = "Arrow keys / D-pad   Enter / A to select   F11 fullscreen"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
end

function Menu:_drawSettings(W, H, alpha)
    local mf     = fonts.get(32)
    local startY = H * 0.42

    -- Per-row heights: Resolution (56), Sound text+slider (92), Back (56)
    local rowH = { 56, 92, 56 }
    local rowY = {}
    rowY[1] = startY
    for i = 2, #SCREENS.settings do rowY[i] = rowY[i-1] + rowH[i-1] end

    local totalH = 0
    for _, h in ipairs(rowH) do totalH = totalH + h end
    local bw, pad = 460, 24
    drawBox(W/2 - bw/2, startY - pad, bw, totalH + pad * 2)

    love.graphics.setFont(mf)
    for i, lbl in ipairs(SCREENS.settings) do
        local sel = (self.cursor == i)
        if sel then
            love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
        else
            love.graphics.setColor(C.item)
        end
        local prefix = sel and "> " or "  "

        if lbl == "Sound" then
            local line = prefix .. "Sound  " .. volume .. "%"
            love.graphics.print(line, W/2 - mf:getWidth(line)/2, rowY[i])
            drawSlider(W/2, rowY[i] + mf:getHeight() + 10, 280, volume)
        elseif lbl == "Resolution" then
            local text = prefix .. "Resolution  [" .. RESOLUTIONS[self.resCursor].label .. "]"
            love.graphics.print(text, W/2 - mf:getWidth(text)/2, rowY[i])
        else
            love.graphics.print(prefix .. lbl, W/2 - mf:getWidth(prefix .. lbl)/2, rowY[i])
        end
    end

    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(C.dim)
    local hint = "Up/Down   Enter/A select   Left/Right adjust volume   Esc/B back"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
end

function Menu:_drawResolution(W, H, alpha)
    local mf     = fonts.get(32)
    local sf     = fonts.get(28)
    local startY = H * 0.42
    local spacing = 56

    local bw = 400
    local bh = spacing + #RESOLUTIONS * 44 + 44
    drawBox(W/2 - bw/2, startY - 20, bw, bh)

    love.graphics.setFont(mf)
    love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
    local header = "Resolution"
    love.graphics.print(header, W/2 - mf:getWidth(header)/2, startY)

    love.graphics.setFont(sf)
    for i, res in ipairs(RESOLUTIONS) do
        local sel = (self.resCursor == i)
        if sel then
            love.graphics.setColor(C.select[1], C.select[2], C.select[3], alpha)
        else
            love.graphics.setColor(C.dim)
        end
        local text = (sel and "> " or "  ") .. res.label
        love.graphics.print(text, W/2 - sf:getWidth(text)/2, startY + spacing + (i-1) * 44)
    end

    love.graphics.setFont(fonts.get(14))
    love.graphics.setColor(C.dim)
    local hint = "Up/Down to pick   Enter / A to apply   Esc / B to cancel"
    love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 36)
end

-- ──────────────────────────────────────────────────────────────
-- actions
-- ──────────────────────────────────────────────────────────────

function Menu:_confirm()
    if self.resOpen then
        self:_applyResolution()
        self.resOpen = false
        return
    end

    local item = self:items()[self.cursor]

    if self.screen == "main" then
        if     item == "Play"     then self.states.switch("game", run.new())
        elseif item == "Dev Mode" then self.screen = "devmode";  self.cursor = 1
        elseif item == "Settings" then self.screen = "settings"; self.cursor = 1
        elseif item == "Quit"     then love.event.quit()
        end

    elseif self.screen == "devmode" then
        if     item == "Level Select"  then self.states.switch("levelselect")
        elseif item == "Level Editor"  then self.states.switch("editor")
        elseif item == "Custom Levels" then self.states.switch("customlevels")
        elseif item == "Import Level"  then
            local def = userlevels.importText(love.system.getClipboardText())
            self.importMsg   = def and ("Imported: " .. (def.name or "level"))
                                   or  "Clipboard had no valid level code"
            self.importMsgTimer = 2.5
            if def then self.states.switch("customlevels") end
        elseif item == "Back" then self.screen = "main"; self.cursor = 1
        end

    elseif self.screen == "settings" then
        if     item == "Resolution" then self.resOpen = true
        elseif item == "Back"       then self.screen = "main"; self.cursor = 1
        end
    end
end

function Menu:_applyResolution()
    local res = RESOLUTIONS[self.resCursor]
    if res.w == 0 then
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
        local items = self:items()
        self.cursor = ((self.cursor - 1 + dir) % #items) + 1
    end
end

function Menu:_adjustVolume(dir)
    if self.screen == "settings" and self:items()[self.cursor] == "Sound" then
        volume = math.max(0, math.min(100, volume + dir * 5))
        love.audio.setVolume(volume / 100)
    end
end

function Menu:_back()
    if self.resOpen then
        self.resOpen = false
    elseif self.screen ~= "main" then
        self.screen = "main"
        self.cursor = 1
    else
        love.event.quit()
    end
end

-- ──────────────────────────────────────────────────────────────
-- input
-- ──────────────────────────────────────────────────────────────

function Menu:keypressed(key)
    if     key == "up"    then self:_navigate(-1)
    elseif key == "down"  then self:_navigate(1)
    elseif key == "left"  then self:_adjustVolume(-1)
    elseif key == "right" then self:_adjustVolume(1)
    elseif key == "return" or key == "space" then self:_confirm()
    elseif key == "escape" then self:_back()
    end
end

function Menu:gamepadpressed(joystick, button)
    if     button == "dpup"    then self:_navigate(-1)
    elseif button == "dpdown"  then self:_navigate(1)
    elseif button == "dpleft"  then self:_adjustVolume(-1)
    elseif button == "dpright" then self:_adjustVolume(1)
    elseif button == "a" or button == "start" then self:_confirm()
    elseif button == "b" then self:_back()
    end
end

function Menu:gamepadaxis(joystick, axis, value)
    local nav = input.stickNav(axis, value)
    if     nav == "up"   then self:_navigate(-1)
    elseif nav == "down" then self:_navigate(1)
    end
end

return Menu
