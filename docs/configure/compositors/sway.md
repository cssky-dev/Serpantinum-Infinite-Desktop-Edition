---
sidebar_position: 3
title: Sway
sidebar_label: Sway
slug: /configure/compositors/sway
---

# Sway

Configuration is stored in `~/.config/sway`. The main file is `config`, which includes modular files from `configDir/`:

- `variables` - modifier keys and default applications
- `input` - keyboard and touchpad settings
- `output` - display and monitor configurations
- `layout` - window borders and gaps
- `autostart` - startup processes
- `window-rules` - floating window rules and assignments
- `keybinds` - keybindings for compositor actions and shell controls

## Autostart

The shell daemon and clipboard history are launched from `configDir/autostart`:

```ini
exec wl-paste --type text --watch cliphist store
exec wl-paste --type image --watch cliphist store
exec serpantinumd start
```

`serpantinumd start` also starts the [audio engine](/audio).

## Keybindings

Shell overlays and controls are bound in `configDir/keybinds` using `exec serpantinum msg toggle <module>`:

- `launcher` - application launcher (`$mod+D`)
- `system` - system control panel (`$mod+B`)
- `clipboard` - clipboard history (`$mod+C`)
- `music` - media player (`$mod+M`)
- `wallpaper` - wallpaper selector (`$mod+W`)
- `calendar` - calendar popout (`$mod+S`)
- `network` - network connections (`$mod+N`)
- `volume` - audio popout (`$mod+V`)
- `settings` - cheat sheet for keybindings (`$mod+H`)

Workspace switching is routed through the shell to update bar indicators:

```ini
bindsym $mod+1 exec serpantinum msg workspace 1
bindsym $mod+Shift+1 exec serpantinum msg workspace 1 move
# ... up to workspace 10 ($mod+0)
```

Quick utility actions:
- Lock screen: `$mod+L exec serpantinum lock`
- Reload shell: `$mod+R exec serpantinum reload`
- Bar autohide: `$mod+A exec serpantinum msg bar autohide`
- Screenshots: `Print exec serpantinum screenshot` (add `--edit` or `--full`)
- Brightness: `XF86MonBrightnessDown` and `XF86MonBrightnessUp`
- Volume: `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, and `XF86AudioMute`

## Infinite desktop

Sway supports the Infinite desktop. The default `configDir/keybinds` binds `$mod+G` to toggle it, plus zoom, pan, overview, tidy and marks. Arrow keys call `serpantinum canvas focus <dir>`, which falls back to the normal Sway focus when the canvas is off; workspaces move to `$mod+Alt+Up` / `$mod+Alt+Down`.

The canvas is driven through `swaymsg` by `src/scripts/canvas/sway.py`, which needs `python3`. Sway cannot report the pointer position, so zoom anchors to the centre of the focused output. Floating windows whose centre leaves their output are handed to the neighbouring output by Sway, so one canvas monitor works best.
