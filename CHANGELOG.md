<div align="center">

# 📜 Changelog

**Serpantinum Infinite Desktop Edition**

All notable changes are listed here, newest first. Versions follow `version.txt`.

[2.4.5](#245) · [2.4.4](#244) · [2.4.x](#24x-ported-onto-upstream-ilyamiro-241) · [2.3.x](#23x)

</div>

> **Legend:** ✨ Added · 🔧 Changed · 🐛 Fixed · 🪶 Performance · 📝 Notes

---

## 2.4.6

### ✨ Added
- **Sway support for the Infinite desktop.** The canvas engine now drives Sway through its IPC (`swaymsg`), with Super+G, zoom, pan, overview, tidy and marks wired into the default Sway config. The widget redactor snaps to apps on Sway as well.
- `src/scripts/canvas/sway.py`: small helper that translates Sway's tree and outputs for the canvas engine.

### 🔧 Changed
- **Delete all widgets** is now a single click: the "Click again to confirm" step and the trash icon were removed from the row.
- The guide settings panel keeps its dragged position when the layout recalculates, so it stays where you put it while the Infinite desktop moves.
- "Hyprland only" labels in the Desktop tab now read "Hyprland and Sway only".

### 🪶 Performance
- **Lower Quickshell RAM.** Guide settings no longer preload every tab in the background after opening. Loaded tabs are released 20 seconds after settings close (was 10 minutes).
- Settings and wallpaper panels are no longer created at startup. Cached panels (settings, wallpaper picker, system panel and the others) are destroyed after about 45 seconds hidden and recreated on demand.
- The first search in settings loads all tabs once to build the index, so that first search can take a moment.

### 📝 Notes
- Sway has no cursor-position query, so zoom on Sway is anchored to the centre of the focused output.
- On multi-monitor Sway setups, floating windows that leave their output are handed to the neighbouring output by Sway itself; the Infinite desktop works best with one canvas monitor.

---

## 2.4.4

### ✨ Added
- **Standalone Window** option in Settings > General: opens guide settings as its own window instead of the panel.
- Plain text in the Widgets tab explaining how to switch between Tiled and Infinite desktop mode.
- **Delete all widgets** in guide settings > Widgets: one button (with a confirm click) that clears every widget from both Tiled and Infinite desktop on every workspace and screen.
- Guide settings panel can be dragged by its header, including on the infinite desktop.
- New banner and screenshots in the README.

### 🔧 Changed
- Every guide settings tab now uses the same style as the Desktop tab.
- Guide settings are lighter and faster, with no gradients.
- Dock section captions are hidden while the dock is disabled.

### 🐛 Fixed
- Blank Dock tab in guide settings (Quickshell error).
- Quickshell warnings in guide settings and the infinite desktop.
- Widgets disappearing after Super+G between Tiled and Infinite desktop; each mode keeps its own layout (`layout.json` for Tiled, `layout-canvas.json` for Infinite desktop).
- Accidental dragging of apps and widgets on the desktop.

---

## 2.4.x (ported onto upstream ilyamiro 2.4.1)

### ✨ Added
- Infinite desktop and custom features ported onto the updated upstream.
- **Delete all widgets** clears both Tiled and Infinite desktop on every workspace.
- Desktop tab in guide settings, translated for all languages.
- Two selectable scroll-zoom methods: resize every app and terminal, or sarods2d-style zoom.
- "Apps switcher when opens" toggle: a newly opened app centers the desktop.
- Spring-based Hyprland animation config (`settings.lua`).

### 🔧 Changed
- Widget redactors follow the apps speed slider so they stay in sync with apps.
- Polkit dialog with improved typing and wrong-password animations.
- Quickshell RAM and CPU reduced.

### 🐛 Fixed
- Blank Desktop tab in guide settings.
- Missing guide settings tabs and labels; stray `//` comments removed.
- Apps jumping back to their last position after move or resize.

---

## 2.3.x

### ✨ Added
- Infinite desktop for Hyprland with animated zoom in/out, Super+arrow navigation, marks, tidy and overview.
- `serpantinum canvas <action>` CLI commands.
- Iridium style variants for widgets (except notes, user, github, visualizer) and a Reminder widget.
- Lockscreen animation picker and Caelestia-style clock variants.
- Scroll zoom over applications and widget redactors without resizing them.
- Super+G toggles Tiled and Infinite desktop; widgets fade out and back in, and each workspace restores its saved view.

### Removed
- Parallax wallpaper, endless dragging, hover-to-switch and the minimap.

### 🐛 Fixed
- Super+G resetting or doing nothing on repeated presses.
- Widget redactors and applications drifting out of sync while moving.
- Raw `guide.display.widgets.*` label keys in guide settings.
- Quick actions firing while Super+arrows move the desktop.
