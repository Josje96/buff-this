local input  = require("systems.input")
local Player = require("entities.player")
local loader = require("levels.loader")
local data   = require("levels.data")
local buffs  = require("systems.buffs")
local run    = require("systems.run")

local Game = {}
Game.__index = Game

local CAM_LERP    = 6
local SPLASH_TIME = 2.2

function Game.new(states, r)
    local self = setmetatable({}, Game)
    self.states = states
    self.run    = r

    self.level  = loader.load(data[r.levelIdx])
    self.player = Player.new(self.level.spawn.x, self.level.spawn.y)
    self.camX   = self.level.spawn.x
    self.camY   = self.level.spawn.y

    local allBuffs   = buffs.getAll()
    self.allBuffs    = allBuffs
    if self.level.forceBuff then
        local b, idx  = buffs.byName(self.level.forceBuff)
        self.buff     = b or buffs.random()
        self.buffIdx  = idx or 1
        self.buffLocked = (b ~= nil)
    else
        self.buffIdx  = math.random(#allBuffs)
        self.buff     = allBuffs[self.buffIdx]
        self.buffLocked = false
    end
    buffs.apply(self.buff, self.player)

    self.splashTimer = SPLASH_TIME
    self.won         = false
    self.winTimer    = 0
    self.deathTimer  = 0
    self.hintDone    = false
    self.hintTimer   = 0
    self.lastDt      = 0

    return self
end

function Game:update(dt)
    self.lastDt = dt
    input.update()

    if input.pressed("pause") then
        self.states.switch("menu")
        return
    end

    if self.splashTimer > 0 then
        if self.run.dev and not self.buffLocked then
            -- dev: hold on the splash so you can pick a buff; don't auto-advance
            local dx = input.pressed("right") and 1 or (input.pressed("left") and -1 or 0)
            if dx ~= 0 then
                self.buffIdx = ((self.buffIdx - 1 + dx) % #self.allBuffs) + 1
                self.buff    = self.allBuffs[self.buffIdx]
                buffs.apply(self.buff, self.player)
            end
        else
            self.splashTimer = self.splashTimer - dt
        end
        if input.pressed("jump") then self.splashTimer = 0 end
        return
    end

    if self.won then
        self.winTimer = self.winTimer + dt
        if self.winTimer > 1.5 then
            run.advance(self.run)
            if run.isComplete(self.run) then
                self.states.switch("victory", self.run)
            else
                self.states.switch("results", self.run, self.buff.name, self.level.name)
            end
        end
        return
    end

    self.player:update(dt, self.level)

    local px, py, pw, ph = self.player:getRect()

    if #self.level.getHazardsInRect(px, py, pw, ph) > 0 then
        self.player.dead = true
    end

    if self.player.dead then
        self.deathTimer = self.deathTimer + dt
        if self.deathTimer > 0.8 then
            if not self.run.dev then run.died(self.run) end
            if run.isOver(self.run) then
                self.states.switch("gameover", self.run)
            else
                self.states.switch("game", self.run)
            end
        end
        return
    end

    local g = self.level.goal
    if g and px < g.x + g.w and px + pw > g.x and py < g.y + g.h and py + ph > g.y then
        self.won = true
    end

    -- hint timer
    if not self.hintDone and self.splashTimer <= 0 then
        self.hintTimer = self.hintTimer + dt
        if self.hintTimer >= 3 then self.hintDone = true end
    end

    -- camera
    local W, H  = love.graphics.getDimensions()
    local targetX = self.player.x - W / 2 + self.player.w / 2
    local targetY = self.player.y - H / 2 + self.player.h / 2
    targetX = math.max(0, math.min(targetX, self.level.width  - W))
    local minCamY = math.min(0, self.level.height - H)
    local maxCamY = math.max(0, self.level.height - H)
    targetY = math.max(minCamY, math.min(targetY, maxCamY))
    self.camX = self.camX + (targetX - self.camX) * CAM_LERP * dt
    self.camY = self.camY + (targetY - self.camY) * CAM_LERP * dt
end

function Game:draw()
    local W, H = love.graphics.getDimensions()
    local p    = self.level.palette

    love.graphics.clear(p.bg[1], p.bg[2], p.bg[3])
    loader.draw(self.level, self.camX, self.camY)
    self.player:draw(self.camX, self.camY)

    if self.buff.drawFX and self.splashTimer <= 0 then
        self.buff.drawFX(self.lastDt)
    end

    -- HUD: level progress + lives
    local hudFont = love.graphics.newFont(14)
    love.graphics.setFont(hudFont)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print(string.format("Level %d / %d", self.run.levelIdx, self.run.maxLevels), 12, 12)
    love.graphics.print(self.level.name, 12, 30)

    -- lives as hearts (∞ in dev mode)
    if self.run.lives == math.huge then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("Lives: \226\136\158", W - 80, 12)
    else
        local heartX = W - 16
        for i = 1, self.run.lives do
            love.graphics.setColor(0.95, 0.20, 0.30, 0.9)
            love.graphics.rectangle("fill", heartX - 14, 10, 12, 12, 2, 2)
            heartX = heartX - 18
        end
    end

    -- buff tag
    if self.buff.name ~= "No Modifier" then
        local bFont = love.graphics.newFont(13)
        love.graphics.setFont(bFont)
        local bc = self.buff.color
        love.graphics.setColor(bc[1], bc[2], bc[3], 0.85)
        local btag = self.buff.name
        love.graphics.print(btag, W - bFont:getWidth(btag) - 12, H - 28)
    end

    -- buff splash
    if self.splashTimer > 0 then
        local fade = math.min(1, self.splashTimer / 0.4)
        love.graphics.setColor(0, 0, 0, 0.72 * fade)
        love.graphics.rectangle("fill", 0, 0, W, H)

        local bc = self.buff.color
        local titleFont = love.graphics.newFont(52)
        love.graphics.setFont(titleFont)
        love.graphics.setColor(bc[1], bc[2], bc[3], fade)
        local bname = self.buff.name
        love.graphics.print(bname, W/2 - titleFont:getWidth(bname)/2, H * 0.32)

        local descFont = love.graphics.newFont(22)
        love.graphics.setFont(descFont)
        love.graphics.setColor(0.9, 0.9, 0.9, fade * 0.9)
        local desc = self.buff.description
        love.graphics.print(desc, W/2 - descFont:getWidth(desc)/2, H * 0.32 + 68)

        -- level info during splash
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0.6, 0.6, 0.6, fade * 0.8)
        local linfo = string.format("Level %d — %s", self.run.levelIdx, self.level.name)
        love.graphics.print(linfo, W/2 - love.graphics.getFont():getWidth(linfo)/2, H * 0.32 + 108)

        if self.run.dev then
            love.graphics.setFont(love.graphics.newFont(13))
            if self.buffLocked then
                love.graphics.setColor(1.0, 0.8, 0.4, fade * 0.85)
                local locked = "this level requires this modifier"
                love.graphics.print(locked, W/2 - love.graphics.getFont():getWidth(locked)/2, H * 0.72 - 22)
            else
                love.graphics.setColor(0.6, 0.8, 1.0, fade * 0.85)
                local picker = string.format("< Left / Right to pick buff   %d / %d >", self.buffIdx, #self.allBuffs)
                love.graphics.print(picker, W/2 - love.graphics.getFont():getWidth(picker)/2, H * 0.72 - 22)
            end
        end
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.setColor(0.4, 0.4, 0.4, fade * 0.6)
        local skip = "press jump to confirm"
        love.graphics.print(skip, W/2 - love.graphics.getFont():getWidth(skip)/2, H * 0.72)
    end

    -- win flash
    if self.won then
        love.graphics.setColor(1, 1, 0.3, 0.35 + 0.2 * math.sin(self.winTimer * 8))
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(1, 1, 1)
        local wFont = love.graphics.newFont(48)
        love.graphics.setFont(wFont)
        local msg = "YOU WIN!"
        love.graphics.print(msg, W/2 - wFont:getWidth(msg)/2, H/2 - 30)
    end

    -- death flash
    if self.player.dead then
        love.graphics.setColor(1, 0.1, 0.1, 0.30)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end

    -- controls hint
    if not self.hintDone then
        local a = math.max(0, 1 - self.hintTimer / 3)
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.setColor(1, 1, 1, a)
        local hint = "Arrows/WASD move   Z/Space/Up jump   Esc menu"
        love.graphics.print(hint, W/2 - love.graphics.getFont():getWidth(hint)/2, H - 32)
    end
end

function Game:keypressed(key)
    if key == "escape" then self.states.switch("menu") end
end

function Game:gamepadpressed(joystick, button)
    input.gamepadpressed(joystick, button)
end

function Game:gamepadreleased(joystick, button)
    input.gamepadreleased(joystick, button)
end

function Game:gamepadaxis(joystick, axis, value)
    input.gamepadaxis(joystick, axis, value)
end

return Game
