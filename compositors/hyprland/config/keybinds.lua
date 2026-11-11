local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + Left", hl.dsp.exec_cmd("serpantinum canvas focus left"), { repeating = true })
hl.bind(mainMod .. " + Right", hl.dsp.exec_cmd("serpantinum canvas focus right"), { repeating = true })
hl.bind(mainMod .. " + Up", hl.dsp.exec_cmd("serpantinum canvas focus up"), { repeating = true })
hl.bind(mainMod .. " + Down", hl.dsp.exec_cmd("serpantinum canvas focus down"), { repeating = true })

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --edit"), { locked = true })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"), { locked = true })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --full --edit"), { locked = true })

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), { locked = true })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), { repeating = true, locked = true })

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), { repeating = true, locked = true })

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("waterfox"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("ski"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("serpantinum msg toggle launcher"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("serpantinum reload"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("serpantinum msg toggle music"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle system"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("serpantinum msg toggle calendar"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("serpantinum msg toggle network"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("serpantinum msg toggle settings"))

hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("serpantinum canvas toggle"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("serpantinum canvas overview"))
hl.bind(mainMod .. " + HOME", hl.dsp.exec_cmd("serpantinum canvas home"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("serpantinum canvas tidy"))
hl.bind(mainMod .. " + EQUAL", hl.dsp.exec_cmd("serpantinum canvas zoomIn"), { repeating = true })
hl.bind(mainMod .. " + MINUS", hl.dsp.exec_cmd("serpantinum canvas zoomOut"), { repeating = true })
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd("serpantinum canvas zoomReset"))
hl.bind(mainMod .. " + mouse_up", hl.dsp.exec_cmd("serpantinum canvas zoomIn"))
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("serpantinum canvas zoomOut"))

hl.bind(mainMod .. " + Prior", hl.dsp.exec_cmd("serpantinum canvas panPage 0 -1"))
hl.bind(mainMod .. " + Next", hl.dsp.exec_cmd("serpantinum canvas panPage 0 1"))
hl.bind(mainMod .. " + ALT + Left", hl.dsp.exec_cmd("serpantinum canvas panPage -1 0"))
hl.bind(mainMod .. " + ALT + Right", hl.dsp.exec_cmd("serpantinum canvas panPage 1 0"))

hl.bind(mainMod .. " + CTRL + mouse_down", hl.dsp.exec_cmd("serpantinum canvas panBy 0 160"))
hl.bind(mainMod .. " + CTRL + mouse_up", hl.dsp.exec_cmd("serpantinum canvas panBy 0 -160"))
hl.bind(mainMod .. " + CTRL + SHIFT + mouse_down", hl.dsp.exec_cmd("serpantinum canvas panBy 160 0"))
hl.bind(mainMod .. " + CTRL + SHIFT + mouse_up", hl.dsp.exec_cmd("serpantinum canvas panBy -160 0"))

for i = 1, 9 do
  hl.bind(mainMod .. " + ALT + " .. i, hl.dsp.exec_cmd("serpantinum canvas markGo " .. i))
  hl.bind(mainMod .. " + ALT + SHIFT + " .. i, hl.dsp.exec_cmd("serpantinum canvas markSet " .. i))
end

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("serpantinum redactor"))

for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws .. " move"))
end
