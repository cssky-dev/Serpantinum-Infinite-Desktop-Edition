--- Hyprland Configuration
--      Made by CSSKY
-- Original dev: @Ilyamiro

-- Hyprland Configuration
hl.config({
  general = {
    border_size = 0,
    gaps_in = 3,
    gaps_out = 5,
    float_gaps = 6,
    resize_on_border = true,
    extend_border_grab_area = 30,
  },


--- Hyprland Decorations
  decoration = {
    rounding = 12,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = {
      enabled = true,
      size = 2,
      passes = 2,
      new_optimizations = true,
      xray = false,
      ignore_opacity = true,
      popups = true,
      popups_ignorealpha = 0.2,
      input_methods = true,
    },
    shadow = {
      enabled = false,
    },
  },

--- Keyboard Layouts / Inputs
  input = {
    kb_layout = "us,ru",
    kb_options = "grp:alt_shift_toggle",
    accel_profile = "flat",
    touchpad = {
      natural_scroll = true,
      disable_while_typing = false,
    },
  },


--- Misc
  misc = {
    focus_on_activate = false,
    font_family = "JetBrains Mono",
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})


---  Hyprland Animation Curves
hl.curve("elasticSmooth", { type = "spring", mass = 1, stiffness = 140, dampening = 16 })
hl.curve("canvasMove", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })


--- Hyprland Animations
hl.animation({ leaf = "windows",     enabled = true, speed = 6,  spring = "elasticSmooth", style = "popin 85%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5.4, spring = "elasticSmooth", style = "popin 88%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4.6, spring = "elasticSmooth", style = "popin 88%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 6,  spring = "elasticSmooth" })
-- Layer surfaces (launcher, calendar, polkit, ...) animate themselves inside Quickshell. Hyprland's own
-- layer fade used to stack on top of that and ghost the close / swallow the next open.
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "layersIn", enabled = false })
hl.animation({ leaf = "layersOut", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 4.5, spring = "elasticSmooth" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3.4, spring = "elasticSmooth" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3.2, spring = "elasticSmooth" })
hl.animation({ leaf = "fadeLayersIn", enabled = false })
hl.animation({ leaf = "fadeLayersOut", enabled = false })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 8,  spring = "elasticSmooth", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 4.4, spring = "elasticSmooth", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, spring = "elasticSmooth", style = "slidefade 20%" })
