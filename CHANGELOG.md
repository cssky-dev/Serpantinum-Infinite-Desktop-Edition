<div align="center">

# 📜 Changelog

**Serpantinum Infinite Desktop Edition**

All notable changes are listed here, newest first. Versions follow `version.txt`.

[2.6.6](#266) · [2.6.5](#265) · [2.6.4](#264) · [2.6.3](#263) · [2.6.2](#262) · [2.5.13](#2513) · [2.5.12](#2512) · [2.5.11](#2511) · [2.5.10](#2510) · [2.5.9](#259) · [2.5.8](#258) · [2.5.7](#257) · [2.5.6](#256) · [2.5.6](#256) · [2.5.4](#254) · [2.5.2](#252) · [2.4.11](#2411) · [2.4.6](#246) · [2.4.5](#245) · [2.4.4](#244) · [2.4.x](#24x-ported-onto-upstream-ilyamiro-241) · [2.3.x](#23x)

</div>

> **Legend:** ✨ Added · 🔧 Changed · 🐛 Fixed · 🪶 Performance · 📝 Notes

---

## 2.6.6

### 🐛 Fixed
- **First keypress did nothing, the second one worked.** The Dashboard (calendar & weather), Launcher, Clipboard and side-music popups are created on demand, and every one of them closed itself on any `Config.settingsLoaded` signal and on any bar position / style / launcher-edge change signal. Both fire spuriously: the signals run during the window's first property evaluation, and `settingsLoaded` fires after *every* settings write (weather, wallpaper, widget state ...). So on a cold open the popup was created and hidden again straight away, and only the next press (window already alive) showed it. A settings reload now only refreshes the popup, and position / style changes close it only after it has settled (500 ms after creation).

---

## 2.6.5

### 🐛 Fixed
- **`Binding loop detected for property "canvasOn"`.** A widget's `canvasOn` read its own window's `screen`, while the window's `visible` depended on `canvasOn` (through `culled`). The screen name and size are now kept in plain properties updated by handlers, so the loop is gone and widgets are no longer re-evaluated mid-animation.
- Launcher no longer logs `Read of .../last_tab.txt failed: File does not exist` on first use.

---

## 2.6.4

### 🐛 Fixed
- **Popups opened as an empty black box and closed with no animation.** The Dashboard, Launcher, Clipboard, Polkit, tray and side-music windows were created by a `LazyLoader` whose `active` depended on a `Timer.running` that the same signal restarted. Quickshell logged `Binding loop detected for property "active"`, so the window could be destroyed and re-created on every open/close (black first frame, wrong position, no exit animation). `active` now follows an explicit flag that is set when the popup opens and cleared by the keep-alive timer.
- `Switch.qml` no longer throws `Cannot read property 'recalculateLayout' of undefined` while its options are being destroyed.

---

## 2.6.3

### 🐛 Fixed
- **Popups interrupted by repeated key presses.** Pressing the launcher, clipboard, calendar & weather or any other widget keybind again while its animation was still running used to reverse or restart the animation half-way. A toggle that arrives during the open/close animation is now ignored (`ScreenToggleController` and `Main.qml`); explicit open/close commands, Escape and click-outside still work at any time.
- **Screenshot animation.** The overlay used to appear as a hard cut: its frozen screenshot was decoded synchronously and its fade-in was disabled for the first frame. It now starts its animation immediately (fade and slight zoom-out of the frozen desktop), decodes the image off the GUI thread, and fades out when closed with Escape, right click or the keybind. A capture still unmaps the overlay instantly so it never ends up in the screenshot.
- **Screenshot keybind speed.** `serpantinum screenshot` (Print, Shift+Print) now skips config and language loading before capturing the screen. Pressing it again while the overlay is open closes the overlay directly instead of capturing the screen a second time.
- **Repeated screenshot presses** no longer toggle the overlay on and off in the middle of its animation.

---

## 2.6.2

### 🐛 Fixed
- **Padlock and Popwave lock screens, "Wallpaper only" prompt background.** Locking with Super + L used to cut straight from the desktop to a bare wallpaper. Padlock now keeps the sharp frozen desktop on top and fades it out while the blurred wallpaper blurs in (and fades it back in while unlocking). Popwave's ring now always grows out of the frozen desktop instead of out of the wallpaper.
- **Animations missing again.** A reveal could end up with no animation when its surface was created already open, or when the animation was stopped by a re-created window:
  - `SpringProgress` (launcher, calendar and weather, clipboard, dock, tray and music popouts) no longer jumps to its end value when created open, it plays the opening spring. A watchdog re-runs the spring if it did not move shortly after opening, and lands on the end value if it still does not, so a popup is never left stuck at zero.
  - Launcher rows, guide settings entrance, bar intro and wallpaper intro each got the same kind of watchdog (replay once, then settle on the end values).

### 🔧 Changed
- New `src/scripts/dev/check_animations.sh` lint: run it before a release. It fails when one of the animation guards above is removed or a `SpringProgress` has no `open:` binding.

---

## 2.5.13

- Shortcuts: one key press now runs one action. `serpantinum` drops an identical `msg` / `canvas` / `screenshot` / `lock` / `redactor` / `reload` command that arrives again within 250 ms (duplicated bind or key event), so a toggle can no longer open and close in the same press. Held-key shortcuts (canvas focus / zoom / pan, volume, brightness) are not affected. Tune with `SERPANTINUM_KEY_DEBOUNCE_MS`, turn off with `SERPANTINUM_NO_DEBOUNCE=1`.

## 2.5.12

- Launcher: the second open/close no longer loses its animation. The surface now stays mapped between presses (empty input region while closed) instead of being re-created every time.
- Hyprland config: Hyprland's own layer fade is off, it was stacking on top of the shell's animations and ghosting the close.
- Calendar & weather: first open after idle used to skip the animation (the reveal jumped to its end value); it now follows the controller like the launcher. Entrance follows the theme (overshoot by border radius) and Liquid Glass (starts smaller, travels further).
- Polkit: persistent surface, per-request reset, Liquid Glass card (GlassFill) and the same theme / Liquid Glass aware entrance.

## 2.5.11

### 🔧 Changed
- **Polkit dialog** now has a full entrance and exit. The backdrop fades in, the glass card rises and settles with a soft overshoot, then the header and the password field follow one after another. Closing plays the same sequence in reverse.
- **Polkit typing and wrong password.** Every keystroke gives the card a small pulse and brightens its rim, and the lock icon pops with it. A wrong password shakes the card and flashes the rim red. A correct one turns the icon into a green check before the dialog closes.
- **Polkit card** is now a blurred glass card (wallpaper blur) instead of a flat one.
- **Wallpaper picker** opens with the list scaling in and the filter bar dropping in with a soft overshoot, and closes faster. Sliding and resizing of items use a smoother 480 ms curve.
- **System panel** blurs in while it opens, like the Network popup.
- **Network and Bluetooth popup** blurs out as it closes (it already blurred in), its open starts a little smaller and the close is 170 ms with an ease-in instead of 85 ms.
- **Bar intro** starts a little later so the wallpaper leads, runs 1.7 s, and the bar settles with a slightly bigger overshoot.

### 🐛 Fixed
- **Polkit did not cover the bar.** The window respected the bar's reserved space; it now ignores it and covers the whole screen, bar included.

---

## 2.5.10

### 🐛 Fixed
- **Infinite desktop blur on apps and terminals.** The blur controller in `CanvasEngine.qml` was rewritten:
  - It reads your real Hyprland blur values (xray, size, passes, vibrancy, brightness, contrast, noise, rounding) each time the canvas becomes active, instead of caching them once for the whole session. Changes you make in your Hyprland config are picked up on the next activation.
  - It no longer acts before those values are known. Before, the first movement after activation was skipped, and the values could be read while they were already modified.
  - Liquid Glass off restores **your own** blur values exactly. Before, it applied fixed values (size 8, brightness 0.9, contrast 0.95) that dimmed blurred terminals and apps and did not match `settings.lua`.
  - The original blur values are saved to `~/.local/state/serpantinum/canvas/blur-base.json` while the canvas is active and restored on shell exit, on reload and after a crash. A shell that died mid-movement used to leave blur stuck in xray with fewer passes.
  - The settle back from the light blur used during movement waits for the move, drag or glide to finish and scales with the Apps speed slider (at least 480 ms), so blur no longer pops back while a window is still travelling.
  - Zooming now keeps the light blur on for the whole zoom, not only while panning.
  - `canvas.blurMotion` (default `true`) can turn the light blur off. `canvas.blurBudget` still caps the blur cost while moving.

### 🔧 Changed
- **System panel** rows slide in with a soft overshoot and a wider stagger (the panel itself uses a smooth out-quint slide), and the exit is shorter and staggered the same way in reverse.
- **Calendar** cards (calendar and weather) now scale in with a gentle overshoot, the clock overshoot is calmer, and month / day switches use smoother curves.
- **Bars** reveal and hide with direction-aware curves: a soft overshoot when auto-hide brings the bar back, a quick ease-in when it hides. Layout changes use a 340 ms out-quint curve.
- **Wallpaper intro** is slower and softer: 900 ms fade, and a zoom from 111 % that settles over 2.4 s.
- **Guide settings** open with a sidebar and content that settle with a small overshoot, and close a little faster.

---

## 2.5.9

### 🔧 Changed
- **Popwave ring first colour follows dark / light mode.** In dark mode the first band is the theme's own dark colour, in light mode it is white. It changes live (450 ms fade) when you switch the mode in Settings -> Theme. The other two bands keep Waved's mauve / blue palette.

---

## 2.5.8

### 🐛 Fixed
- **Keybinds that needed a second press.** Every keybind script sent its IPC command to the shell once and threw the error away, so a press that arrived while the shell was not ready (just started, still loading, or its `main` / `lock` / `redactor` target not registered yet) was silently lost. They now go through a shared helper (`src/scripts/ipc.sh`) that waits up to about 3 s for the shell and retries only on "not ready" errors, never on a real handler error, so a toggle can't fire twice. Covers `msg` (launcher, clipboard, music, system, wallpaper, calendar, network, volume, settings, workspaces), `lock`, `redactor`, `screenshot`, `canvas` and `ipc`.
- `serpantinum msg ...` and `serpantinum canvas ...` no longer run the full start-up of the CLI (config, language loading, jq) when the daemon is already running, so a press reaches the shell right away.
- **Hyprland: `Super+L` was marked as repeating**, so holding the key for a moment fired the lock command several times and the extra activations fought each other. It is a normal bind now.
- **Sway: black screen after (re)installing.** `compositors/sway/config` included `config/...`, but the files ship in `configDir/` (a folder can't share the name of the `config` file), so every include failed and `serpantinumd start` never ran. The includes now point to `configDir/`. The installer also moves aside an old `~/.config/sway/config/` folder, which would otherwise make the copy of the new `config` file fail.

---

## 2.5.7

### 🐛 Fixed
- **Launcher closed instantly with no animation.** On close the launcher reset its row animation and reloaded the app list straight away, which blanked every row and shrank the card in one frame before the close animation could play. The reset now runs after the card has finished closing, so the rows stay put while it collapses.
- **Launcher open showed a washed-out empty card for a few frames** before any text appeared. The content now follows the card (it fades in as the card grows and fades out as it collapses) and the row stagger starts a few milliseconds after the card begins to open.

### 🔧 Changed
- Launcher close is now 240 ms (260 ms centred) with an in-out ease instead of 150 ms with a late, sudden drop. `SpringProgress` gained an optional `closeEasing` (default unchanged, so nothing else is affected).

---

## 2.5.6

### 🔧 Changed
- **Padlock and Popwave now blur in exactly like the Waved lock screen**, on both the frozen desktop and the "Wallpaper only" background: same blur strength (0.72 on the clock, 1.0 once the login UI is open), same saturation / contrast / brightness lift, same crust dimmer, and a 600 ms ease. Padlock blurs out again on unlock; Popwave blurs in with the ring as it grows and out as the ring opens the desktop.
- **Popwave ring first colour** is now the neutral silver-white of the Serpantinum black and white theme (theme text colour with a touch of sapphire) instead of the cyan-ish sapphire. The other two bands keep Waved's mauve / blue palette.
- **Launcher entrance animation** reworked in the style of the Digital Wellbeing intro, but better: the search bar drops in first, then the tab switch, then the result / emoji rows, each rising, fading and settling with a soft overshoot. It follows the theme (rounder themes settle with a bouncier overshoot) and Liquid Glass (starts slightly smaller and travels further, and the glass highlight slides in with it).

### 🪶 Performance
- Lock screen blur (Waved, Padlock, Popwave) runs on a half-size texture, a quarter of the pixels per frame, with the radius halved so it looks identical.
- Waved stops re-rendering its backdrop copies once the intro is over and the picture is idle (they stay live for video backgrounds, while typing and while unlocking).
- Padlock only renders the card shadow while the card is visible.

---

## 2.5.6

### 🔧 Changed
- **Padlock and Popwave now blur in exactly like the Waved lock screen**, on both the frozen desktop and the "Wallpaper only" background: same blur strength (0.72 on the clock, 1.0 once the login UI is open), same saturation / contrast / brightness lift, same crust dimmer, and a 600 ms ease. Padlock blurs out again on unlock; Popwave blurs in with the ring as it grows and out as the ring opens the desktop.
- **Popwave ring first colour** is now the neutral silver-white of the Serpantinum black and white theme (theme text colour with a touch of sapphire) instead of the cyan-ish sapphire. The other two bands keep Waved's mauve / blue palette.
- **Launcher entrance animation** reworked in the style of the Digital Wellbeing intro, but better: the search bar drops in first, then the tab switch, then the result / emoji rows, each rising, fading and settling with a soft overshoot. It follows the theme (rounder themes settle with a bouncier overshoot) and Liquid Glass (starts slightly smaller and travels further, and the glass highlight slides in with it).

### 🪶 Performance
- Lock screen blur (Waved, Padlock, Popwave) runs on a half-size texture, a quarter of the pixels per frame, with the radius halved so it looks identical.
- Waved stops re-rendering its backdrop copies once the intro is over and the picture is idle (they stay live for video backgrounds, while typing and while unlocking).
- Padlock only renders the card shadow while the card is visible.

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
