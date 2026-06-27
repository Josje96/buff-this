DEV = true   -- set to false to ship

local Menu        = require("states.menu")
local Game        = require("states.game")
local Results     = require("states.results")
local GameOver    = require("states.gameover")
local Victory     = require("states.victory")
local LevelSelect = require("states.levelselect")

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

function love.gamepadpressed(joystick, button)
    if state and state.gamepadpressed then state:gamepadpressed(joystick, button) end
end

function love.gamepadreleased(joystick, button)
    if state and state.gamepadreleased then state:gamepadreleased(joystick, button) end
end

function love.gamepadaxis(joystick, axis, value)
    if state and state.gamepadaxis then state:gamepadaxis(joystick, axis, value) end
end
