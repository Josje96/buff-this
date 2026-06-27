function love.conf(t)
    t.window.title   = "Buff This"
    t.window.icon    = nil
    t.window.width   = 1280
    t.window.height  = 720
    t.window.borderless = true
    t.window.fullscreen = false   -- borderless windowed; not exclusive fullscreen
    t.window.fullscreentype = "desktop"
    t.window.resizable  = false
    t.window.vsync      = 1
    t.window.msaa       = 0
    t.window.display    = 1
    t.window.highdpi    = false
    t.window.x          = nil
    t.window.y          = nil

    t.modules.joystick  = true
    t.modules.audio     = true
    t.modules.sound     = true
    t.modules.physics   = false  -- using manual physics, not Box2D
end
