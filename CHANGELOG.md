<div align="center">

# 📜 Changelog

**Serpantinum Infinite Desktop Edition**

All notable changes are listed here, newest first. Versions follow `version.txt`.

[2.5.4](#254) · [2.5.2](#252) · [2.4.11](#2411) · [2.4.6](#246) · [2.4.5](#245) · [2.4.4](#244) · [2.4.x](#24x-ported-onto-upstream-ilyamiro-241) · [2.3.x](#23x)

</div>

> **Legend:** ✨ Added · 🔧 Changed · 🐛 Fixed · 🪶 Performance · 📝 Notes

---

## 2.5.4

### 🔧 Changed
- **Popwave ring colours now match the Waved lock screen's matugen style.** The ring uses the same sapphire, blue and mauve palette as Waved (matugen primary container + primary) and follows wallpaper and theme changes live, instead of the tertiary/peach band it had before. The sekaipop ring animation itself is unchanged.

### 🐛 Fixed
- **Light / dark mode in Settings → Theme** now applies at once. The shell is recoloured straight from the cached matugen palette (it already holds both schemes) and matugen then runs at normal priority in the background for GTK, Qt and app themes, so there is no waiting and no reload.
- **Standalone window**: turning it off now closes the window and brings Settings back as the panel, on the same tab.
- **Padlock and Popwave lock screens now support the "Wallpaper only" prompt background**, like the Waved lock screen. The frozen desktop is no longer drawn behind the prompt when it is selected.
- Padlock and Popwave reload their wallpaper picture correctly after a wallpaper change (the picture used to stay on the old image).

### ✨ Added
- **Launcher entrance animation** in the style of the Digital Wellbeing intro: result rows rise, fade and settle with a soft overshoot, one after another, for both the app list and the emoji grid.

### 🪶 Performance
- The launcher opens faster (520 ms to 360 ms) and its row intro is shorter (about 400 ms instead of 520 ms).

### 📝 Notes
- Updates still come from `cssky-dev/Serpantinum-Infinite-Desktop-Edition` (`main`, `version.txt`), so publishing this release to that repository makes it show up as an update.

---

## 2.5.2

Ports upstream ilyamiro 2.5.1 (everything since 2.4.3) onto the Infinite Desktop Edition.

### ✨ Added (from upstream 2.5.0 / 2.5.1)
- Dashboard calendar with an animated sun arc, weather and government warning notifications with illustrated cards and a Weather settings tab.
- Timer, Stopwatch and Pomodoro desktop widgets.
- Light/dark mode switch with colour-scheme sync, settings preset import, "hide text" for lyrics widgets.
- Shared surface field: bar, dock, launcher, dashboard, clipboard, OSD, tray menus and quick actions are drawn as one merged glass shape with seamless joins.
- Battery notifications, prompt background option on the lock screen, `serpantinum-core` 0.6.0 pin.

### 🔧 Kept from the Infinite Desktop Edition
- Infinite desktop (Hyprland, Sway), Desktop tab, widget redactor and widget sync, Standalone settings window, Padlock and Popwave lock screens (picker next to the upstream prompt background option), bar and wallpaper startup intros, Quick Actions hiding, CSSKY credits, installer and update URLs.

### 🪶 Performance (low-RAM pass)
- Launcher, Clipboard, Polkit prompt, tray menu and side-music popouts are no longer kept alive for the whole session: they are created when first used and released after a period of inactivity (Launcher/Clipboard 45 s, popouts 20 s, Polkit 2 s).
- The settings UI is no longer pre-built at startup (it was destroyed ~30 s later anyway, only raising peak memory); it is created on first open.
- Idle popup widgets are evicted sooner (checked every 10 s, dropped after 20 s idle) and a garbage collection runs right after eviction.
- Tray menu lists keep a much smaller off-screen delegate cache.

### 🪶 Performance
- The Dashboard window is created only while it is open instead of always being present as a fullscreen overlay.
- Quickshell starts with `MALLOC_ARENA_MAX=2` and an eager malloc trim (overridable) to lower resident memory.
- Icons in the dock, dock settings, presets and Digital Wellbeing are decoded at display size again.
- Widget cache eviction, album-art decode size and the paint-transition low-res mask re-applied on top of upstream.

### 📝 Notes
- TopBar and SideBar now use upstream's surface field instead of the old corner shaders.

---

## 2.4.11

### ✨ Added
- **Lock screen animation picker** in guide settings → Display → Lock screen ("Picks the lockscreen animation you like"). Choose between **Waved** (the existing lock screen, still the default) and **Padlock**.
- **Padlock lock screen** (`PadlockScreen.qml`), based on the Caelestia lock screen: the padlock appears and scales out, then your idle layout (clock) appears. Typing opens your own lock screen layout. After a correct password the padlock appears again, scales out and the background blur goes out. Reuses Serpantinum's own password, fingerprint and attempt-limit handling.
- New `guide.display.lockscreen.animation.*` strings in all 23 languages.

- **Power menu on the Padlock and Popwave lock screens** (suspend, reboot, power off), the same `LockPowerControls` as the Waved lock screen, with the same toggle button and hold-to-confirm buttons.

### 🪶 Performance
- Paint wallpaper transition renders its mask and glow at one texel per cell instead of one per pixel (16x fewer fragments at 1080p, 64x at 4K).

### 🐛 Fixed
- **Popwave lock screen colours** now come from the matugen palette: the ring bands use the matugen primary and tertiary colours (the tertiary band used the dark `tertiary_container`, which made the ring look dull) and the white band is tinted with the primary. They re-colour with a 450 ms fade when the wallpaper or theme changes, and non-matugen themes keep their own pink. The lock picture also reloads when the wallpaper changes.
- **Popwave unlock:** after a correct password (or fingerprint) the ring now always scales out from the centre of the screen and opens the desktop, including when the lock was started with `activateStatic` (before, no ring was drawn there). The unlock ring has its own 950 ms duration and a safety timer so the session can never stay stuck on the lock screen.

- **Dock tab (guide settings):** the app rows in Dock Applications overlapped (name and comment drawn on top of each other and the icon). Each app is now one full-width row with fixed anchors, a single-line elided name and comment, and the remove button on the right, so the text can no longer be squeezed or garbled.

### 🔧 Changed
- Widget redactor fades in and out instead of appearing and disappearing instantly, with a safety timer so it can never get stuck open.

---

## 2.4.6

### ✨ Added
- **Startup intro for the bar.** The bar glides in from its screen edge and the modules follow one after another.
- **Staggered entrance for guide settings rows** whenever a tab is shown (`GuideStagger.qml`).
- New translation strings for the About, Welcome, Dock, Desktop and Digital Wellbeing tabs in all languages.

### 🔧 Changed
- Removed the "Mode" section from the Widgets tab and the notices block from the About tab.
- Icons in the dock, music widgets, presets and Digital Wellbeing are decoded at their display size to save RAM.
- The installer clones and fetches with `--depth 50` so first installs are smaller and faster.

### 🐛 Fixed
- **Screenshot tab:** when the OCR language list finishes loading, the rows now enter with the same slide, fade and soft-settle as every other guide settings tab, and the "Loading languages..." line fades and collapses instead of popping away. The entrance helper no longer mistakes the language list for the scrolling area, so the tab's sections animate on open too.
- **Bar intro:** modules unfold from the middle of the bar outwards with a gentler settle, the bar starts slightly after the wallpaper reveal, and layout animations switch on only once the intro has really finished (before, they switched on about 400 ms too early).
- **Wallpaper:** a soft fade and slow zoom-out reveals the wallpaper each time Serpantinum starts.
- `Nightfox.json` was an empty file, so the Nightfox theme failed to load. It is restored.
- **Translations are complete in all 23 languages.** Every language file now has the same keys: the Autostart tab, installer messages, lock screen, widget style names, quick actions palette, and the strings that were missing from `en.json`.
- Strings that always showed English no matter the language are now translated: app launcher command and calculator hints, bar module style descriptions, bar height (vertical bars), theme editor title, weather notification title, wallpaper history filter, About tab update and changelog buttons, and the location (Auto-detect, Latitude, Longitude, Apply) and wallpaper (Select wallpaper) buttons.

---

## 2.4.5

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
