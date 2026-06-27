DEV = true   -- set to false to ship

local Menu         = require("states.menu")
local Game         = require("states.game")
local Results      = require("states.results")
local GameOver     = require("states.gameover")
local Victory      = require("states.victory")
local LevelSelect  = require("states.levelselect")
local Editor       = require("states.editor")
local CustomLevels = require("states.customlevels")
local userlevels   = require("systems.userlevels")

local state  = nil
local states = {}

function states.switch(name, ...)
    if state and state.leave then state:leave() end
    if     name == "menu"        then state = Menu.new(states, ...)
    elseif name == "game"        then state = Game.new(states, ...)
    elseif name == "results"     then state = Results.new(states, ...)
    elseif name == "gameover"    then state = GameOver.new(states, ...)
    elseif name == "victory"     then state = Victory.new(states, ...)
    elseif name == "levelselect" then state = LevelSelect.new(states, ...)
    elseif name == "editor"      then state = Editor.new(states, ...)
    elseif name == "customlevels" then state = CustomLevels.new(states, ...)
    end
end

function love.load()
    math.randomseed(os.time())
    math.random() math.random()
    love.graphics.setDefaultFilter("nearest", "nearest")
    states.switch("menu")
end

function love.update(dt)
    if state and state.update then state:update(dt) end
end

function love.draw()
    if state and state.draw then state:draw() end
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" then
        local fs = love.window.getFullscreen()
        love.window.setFullscreen(not fs, "desktop")
        return
    end
    if state and state.keypressed then state:keypressed(key, scancode, isrepeat) end
end

function love.keyreleased(key)
    if state and state.keyreleased then state:keyreleased(key) end
end

function love.textinput(t)
    if state and state.textinput then state:textinput(t) end
end

-- Drag a .txt level file onto the window to import it.
function love.filedropped(file)
    local ok = file:open("r")
    if not ok then return end
    local text = file:read()
    file:close()
    local def = userlevels.importText(text)
    if def then
        states.switch("customlevels")
    end
end

function love.gamepadpressed(joystick, button)
    if state and state.gamepadpressed then state:gamepadpressed(joystick, button) end
end

function love.gamepadreleased(joystick, button)
    if state and state.gamepadreleased then state:gamepadreleased(joystick, button) end
end

function love.gamepadaxis(joystick, axis, value)
    if state and state.gamepadaxis then state:gamepadaxis(joystick, axis, value) end
end
