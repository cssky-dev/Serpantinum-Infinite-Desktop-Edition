### 2.7.1
- added(lock): video wallpaper support on the Padlock and Popwave lock screens (`.mp4`, `.mkv`, `.mov`, `.webm`, desktop wallpaper or custom lock background), like the Waved lock screen. Works with both prompt backgrounds: with "Wallpaper" the video blurs in under the frozen desktop fade, with "Desktop" the frozen still covers the video only during the intro, the login UI and the unlock.
- fix(launcher): from the second open on, Esc, arrows and typing went to the window below. The surface stays mapped between presses and only `focusable` was toggled, so the compositor never gave the keyboard back. The launcher now takes exclusive keyboard focus on every open and releases it as it starts to close.
- perf(canvas): Super+G acts on the cached window snapshot when no window event is pending, instead of first running `hyprctl` twice. `canvas enable` / `canvas disable` use the same path.
- perf(cli): `serpantinum canvas ...` and the key-press guard start with fewer forks (no `dirname` subshells, no `mkdir` when the guard directory exists).
- fix(shell): fixed all warnings Quickshell logged about itself.

### 2.6.6
- fix(popups): first keypress did nothing and the second one worked. Dashboard (calendar & weather), Launcher, Clipboard and side-music popups closed themselves on every `Config.settingsLoaded` signal and on every bar position / style / launcher-edge change signal, and both fire spuriously (during the window's first property evaluation, and after every settings write). A settings reload now only refreshes the popup, and position / style changes close it only after it has settled (500 ms after creation).

### 2.6.5
- fix(canvas): `Binding loop detected for property "canvasOn"`. A widget's `canvasOn` read its own window's `screen` while the window's `visible` depended on `canvasOn`. Screen name and size are now plain properties updated by handlers, so widgets are no longer re-evaluated mid-animation.
- fix(launcher): no more `Read of .../last_tab.txt failed: File does not exist` on first use.

### 2.6.4
- fix(popups): Dashboard, Launcher, Clipboard, Polkit, tray and side-music windows opened as an empty black box and closed with no animation. Their `LazyLoader` `active` depended on a `Timer.running` that the same signal restarted (`Binding loop detected for property "active"`), so the window could be re-created on every open / close. `active` now follows an explicit flag set on open and cleared by the keep-alive timer.
- fix(ui): `Switch.qml` no longer throws `Cannot read property 'recalculateLayout' of undefined` while its options are being destroyed.

### 2.6.3
- fix(popups): pressing a launcher, clipboard, calendar & weather or other widget keybind again during its animation no longer reverses or restarts it. A toggle that arrives mid-animation is ignored (`ScreenToggleController`, `Main.qml`); explicit open / close, Escape and click-outside still work at any time.
- fix(screenshot): the overlay no longer appears as a hard cut. It starts its fade and slight zoom-out at once, decodes the frozen screenshot off the GUI thread, and fades out on Escape, right click or the keybind. A capture still unmaps the overlay instantly so it never ends up in the screenshot.
- perf(screenshot): `serpantinum screenshot` (Print, Shift+Print) skips config and language loading before capturing. Pressing it while the overlay is open closes the overlay instead of capturing a second time.
- fix(screenshot): repeated presses no longer toggle the overlay on and off mid-animation.

### 2.6.2
- fix(lock): Padlock and Popwave with the "Wallpaper only" prompt background used to cut from the desktop straight to a bare wallpaper on Super + L. Padlock keeps the sharp frozen desktop on top and fades it out while the blurred wallpaper blurs in (and back in on unlock). Popwave's ring always grows out of the frozen desktop.
- fix(animations): `SpringProgress` (launcher, calendar and weather, clipboard, dock, tray and music popouts) no longer jumps to its end value when created open; it plays the opening spring. A watchdog re-runs the spring if it did not move, and lands on the end value if it still does not.
- fix(animations): launcher rows, guide settings entrance, bar intro and wallpaper intro each got the same watchdog (replay once, then settle on the end values).
- added(dev): `src/scripts/dev/check_animations.sh` lint, to run before a release. It fails when one of the animation guards is removed or a `SpringProgress` has no `open:` binding.

### 2.5.13
- fix(shortcuts): one key press runs one action. `serpantinum` drops an identical `msg` / `canvas` / `screenshot` / `lock` / `redactor` / `reload` command that arrives again within 250 ms, so a toggle can no longer open and close in the same press. Held-key shortcuts (canvas focus / zoom / pan, volume, brightness) are not affected. Tune with `SERPANTINUM_KEY_DEBOUNCE_MS`, turn off with `SERPANTINUM_NO_DEBOUNCE=1`.

### 2.5.12
- fix(launcher): the second open / close no longer loses its animation. The surface stays mapped between presses (empty input region while closed) instead of being re-created every time.
- fix(hyprland): Hyprland's own layer fade is off; it stacked on the shell's animations and ghosted the close.
- fix(calendar): first open after idle used to skip the animation; it now follows the controller like the launcher. Entrance follows the theme (overshoot by border radius) and Liquid Glass (starts smaller, travels further).
- changed(polkit): persistent surface, per-request reset, Liquid Glass card (GlassFill) and the same theme / Liquid Glass aware entrance.

### 2.5.11
- changed(polkit): full entrance and exit. The backdrop fades in, the glass card rises with a soft overshoot, then the header and password field follow. Closing plays it in reverse.
- changed(polkit): every keystroke pulses the card and brightens its rim, and the lock icon pops. A wrong password shakes the card and flashes the rim red; a correct one turns the icon into a green check before closing.
- changed(polkit): the card is now a blurred glass card (wallpaper blur) instead of a flat one.
- changed(wallpaper): the picker opens with the list scaling in and the filter bar dropping in with a soft overshoot, and closes faster. Item sliding and resizing use a smoother 480 ms curve.
- changed(syspanel): the system panel blurs in while it opens, like the Network popup.
- changed(network): the Network and Bluetooth popup blurs out as it closes, opens a little smaller, and closes in 170 ms with an ease-in instead of 85 ms.
- changed(bar): the intro starts a little later so the wallpaper leads, runs 1.7 s, and settles with a slightly bigger overshoot.
- fix(polkit): the dialog now ignores the bar's reserved space and covers the whole screen, bar included.

### 2.5.10
- fix(canvas): rewrote the blur controller in `CanvasEngine.qml` so apps and terminals no longer get a broken blur on the infinite desktop.
- fix(canvas): it reads your real Hyprland blur values (xray, size, passes, vibrancy, brightness, contrast, noise, rounding) each time the canvas becomes active, instead of caching them once per session.
- fix(canvas): it no longer acts before those values are known (the first movement after activation used to be skipped, and values could be read while already modified).
- fix(canvas): Liquid Glass off restores your own blur values exactly, instead of fixed values (size 8, brightness 0.9, contrast 0.95) that dimmed blurred terminals and apps.
- fix(canvas): the original blur values are saved to `~/.local/state/serpantinum/canvas/blur-base.json` while the canvas is active and restored on shell exit, reload and after a crash. A shell that died mid-movement used to leave blur stuck in xray with fewer passes.
- fix(canvas): the settle back from the light blur waits for the move, drag or glide to finish and scales with the Apps speed slider (at least 480 ms). Zooming keeps the light blur on for the whole zoom, not only while panning.
- added(canvas): `canvas.blurMotion` (default `true`) turns the light blur off. `canvas.blurBudget` still caps the blur cost while moving.
- changed(syspanel): rows slide in with a soft overshoot and a wider stagger (the panel uses a smooth out-quint slide), and the exit is shorter and staggered in reverse.
- changed(calendar): cards scale in with a gentle overshoot, the clock overshoot is calmer, and month / day switches use smoother curves.
- changed(bar): reveal and hide use direction-aware curves (soft overshoot when auto-hide brings the bar back, quick ease-in when it hides). Layout changes use a 340 ms out-quint curve.
- changed(wallpaper): the intro is slower and softer: 900 ms fade and a zoom from 111 % that settles over 2.4 s.
- changed(settings): guide settings open with a sidebar and content that settle with a small overshoot, and close a little faster.

### 2.5.9
- changed(lock): the Popwave ring's first colour follows dark / light mode. Dark mode uses the theme's own dark colour, light mode white, with a live 450 ms fade when switching in Settings -> Theme. The other two bands keep Waved's mauve / blue palette.

### 2.5.8
- fix(shortcuts): keybinds that needed a second press. Every keybind script sent its IPC command once and threw the error away, so a press while the shell was not ready was lost. They now go through a shared helper (`src/scripts/ipc.sh`) that waits up to about 3 s and retries only on "not ready" errors, never on a real handler error. Covers `msg` (launcher, clipboard, music, system, wallpaper, calendar, network, volume, settings, workspaces), `lock`, `redactor`, `screenshot`, `canvas` and `ipc`.
- perf(cli): `serpantinum msg ...` and `serpantinum canvas ...` no longer run the full CLI start-up (config, language loading, jq) when the daemon is already running.
- fix(hyprland): `Super+L` was marked as repeating, so holding it fired the lock command several times. It is a normal bind now.
- fix(sway): black screen after (re)installing. `compositors/sway/config` included `config/...` but the files ship in `configDir/`, so every include failed and `serpantinumd start` never ran. The includes now point to `configDir/`, and the installer moves aside an old `~/.config/sway/config/` folder.

### 2.5.7
- fix(launcher): it closed instantly with no animation. On close it reset its row animation and reloaded the app list straight away, blanking every row. The reset now runs after the card has finished closing.
- fix(launcher): open showed a washed-out empty card for a few frames. Content now follows the card (fades in as it grows, out as it collapses) and the row stagger starts a few milliseconds after the card begins to open.
- changed(launcher): close is now 240 ms (260 ms centred) with an in-out ease instead of 150 ms with a late, sudden drop. `SpringProgress` gained an optional `closeEasing` (default unchanged).

### 2.5.6
- changed(lock): Padlock and Popwave blur in exactly like the Waved lock screen, on both the frozen desktop and the "Wallpaper only" background: same blur strength (0.72 on the clock, 1.0 once the login UI is open), same saturation / contrast / brightness lift, same crust dimmer and 600 ms ease. Padlock blurs out on unlock; Popwave blurs in with the ring and out as the ring opens the desktop.
- changed(lock): the Popwave ring's first colour is now the neutral silver-white of the Serpantinum black and white theme instead of cyan-ish sapphire. The other two bands keep Waved's mauve / blue palette.
- changed(launcher): entrance animation reworked in the style of the Digital Wellbeing intro: the search bar drops in first, then the tab switch, then the result / emoji rows, each rising, fading and settling with a soft overshoot. Follows the theme (rounder themes bounce more) and Liquid Glass (starts smaller, travels further, glass highlight slides in).
- perf(lock): lock screen blur (Waved, Padlock, Popwave) runs on a half-size texture with the radius halved, so it looks identical for a quarter of the pixels.
- perf(lock): Waved stops re-rendering its backdrop copies once the intro is over and the picture is idle (they stay live for video backgrounds, while typing and while unlocking).
- perf(lock): Padlock only renders the card shadow while the card is visible.

### 2.5.4
- changed(lock): Popwave ring colours match the Waved lock screen's matugen style (sapphire, blue and mauve; matugen primary container + primary) and follow wallpaper and theme changes live. The sekaipop ring animation is unchanged.
- fix(theme): light / dark mode in Settings -> Theme applies at once. The shell is recoloured from the cached matugen palette, and matugen then runs at normal priority in the background for GTK, Qt and app themes.
- fix(settings): turning off the Standalone window closes it and brings Settings back as the panel, on the same tab.
- added(lock): Padlock and Popwave support the "Wallpaper only" prompt background; the frozen desktop is no longer drawn behind the prompt when it is selected.
- fix(lock): Padlock and Popwave reload their wallpaper picture after a wallpaper change (it used to stay on the old image).
- added(launcher): entrance animation in the style of the Digital Wellbeing intro: result rows rise, fade and settle with a soft overshoot, for both the app list and the emoji grid.
- perf(launcher): opens faster (520 ms to 360 ms) and its row intro is shorter (about 400 ms instead of 520 ms).
- note(updates): updates still come from `cssky-dev/Serpantinum-Infinite-Desktop-Edition` (`main`, `version.txt`), so publishing a release there makes it show up as an update.

### 2.5.2
- note(upstream): ports upstream ilyamiro 2.5.1 (everything since 2.4.3) onto the Infinite Desktop Edition.
- added(dashboard): calendar with an animated sun arc, weather and government warning notifications with illustrated cards, and a Weather settings tab (from upstream 2.5.0 / 2.5.1).
- added(widgets): Timer, Stopwatch and Pomodoro desktop widgets (from upstream).
- added(theme): light / dark mode switch with colour-scheme sync, settings preset import, "hide text" for lyrics widgets (from upstream).
- added(shell): shared surface field; bar, dock, launcher, dashboard, clipboard, OSD, tray menus and quick actions are drawn as one merged glass shape with seamless joins (from upstream).
- added(shell): battery notifications, prompt background option on the lock screen, `serpantinum-core` 0.6.0 pin (from upstream).
- changed(edition): kept from the Infinite Desktop Edition: infinite desktop (Hyprland, Sway), Desktop tab, widget redactor and widget sync, Standalone settings window, Padlock and Popwave lock screens (picker next to the upstream prompt background option), bar and wallpaper startup intros, Quick Actions hiding, CSSKY credits, installer and update URLs.
- perf(memory): Launcher, Clipboard, Polkit prompt, tray menu and side-music popouts are created when first used and released after inactivity (Launcher / Clipboard 45 s, popouts 20 s, Polkit 2 s).
- perf(memory): the settings UI is no longer pre-built at startup; it is created on first open.
- perf(memory): idle popup widgets are evicted sooner (checked every 10 s, dropped after 20 s idle) and a garbage collection runs right after eviction.
- perf(memory): tray menu lists keep a much smaller off-screen delegate cache.
- perf(dashboard): the Dashboard window is created only while it is open instead of always being a fullscreen overlay.
- perf(memory): Quickshell starts with `MALLOC_ARENA_MAX=2` and an eager malloc trim (overridable) to lower resident memory.
- perf(icons): icons in the dock, dock settings, presets and Digital Wellbeing are decoded at display size again.
- perf(memory): widget cache eviction, album-art decode size and the paint-transition low-res mask re-applied on top of upstream.
- note(bar): TopBar and SideBar now use upstream's surface field instead of the old corner shaders.

### 2.4.11
- added(lock): lock screen animation picker in guide settings -> Display -> Lock screen. Choose between Waved (the existing lock screen, still the default) and Padlock.
- added(lock): Padlock lock screen (`PadlockScreen.qml`), based on the Caelestia lock screen: the padlock appears and scales out, then your idle layout (clock) appears. Typing opens your own lock screen layout. After a correct password the padlock appears again, scales out and the blur goes out. Reuses Serpantinum's password, fingerprint and attempt-limit handling.
- added(i18n): new `guide.display.lockscreen.animation.*` strings in all 23 languages.
- added(lock): power menu (suspend, reboot, power off) on the Padlock and Popwave lock screens, the same `LockPowerControls` as Waved, with the same toggle button and hold-to-confirm buttons.
- perf(wallpaper): the paint transition renders its mask and glow at one texel per cell instead of one per pixel (16x fewer fragments at 1080p, 64x at 4K).
- fix(lock): Popwave colours come from the matugen palette: ring bands use matugen primary and tertiary (the tertiary band used the dark `tertiary_container` and looked dull) and the white band is tinted with the primary. They re-colour with a 450 ms fade when the wallpaper or theme changes; non-matugen themes keep their own pink. The lock picture also reloads on wallpaper change.
- fix(lock): Popwave unlock: after a correct password (or fingerprint) the ring always scales out from the screen centre and opens the desktop, including when started with `activateStatic`. The unlock ring has its own 950 ms duration and a safety timer so the session can never stay stuck on the lock screen.
- fix(dock): the app rows in Dock Applications overlapped. Each app is now one full-width row with fixed anchors, a single-line elided name and comment, and the remove button on the right.
- changed(redactor): the widget redactor fades in and out instead of appearing instantly, with a safety timer so it can never get stuck open.

### 2.4.6
- added(bar): startup intro. The bar glides in from its screen edge and the modules follow one after another.
- added(settings): staggered entrance for guide settings rows whenever a tab is shown (`GuideStagger.qml`).
- added(i18n): new translation strings for the About, Welcome, Dock, Desktop and Digital Wellbeing tabs in all languages.
- changed(settings): removed the "Mode" section from the Widgets tab and the notices block from the About tab.
- perf(icons): icons in the dock, music widgets, presets and Digital Wellbeing are decoded at display size to save RAM.
- changed(installer): clones and fetches with `--depth 50` so first installs are smaller and faster.
- fix(screenshot): when the OCR language list finishes loading, rows enter with the same slide, fade and soft-settle as other settings tabs, and the "Loading languages..." line fades and collapses. The entrance helper no longer mistakes the language list for the scrolling area.
- fix(bar): modules unfold from the middle outwards with a gentler settle, the bar starts slightly after the wallpaper reveal, and layout animations switch on only once the intro has finished (they used to switch on about 400 ms too early).
- fix(wallpaper): a soft fade and slow zoom-out reveals the wallpaper each time Serpantinum starts.
- fix(theme): `Nightfox.json` was an empty file, so the Nightfox theme failed to load. It is restored.
- fix(i18n): translations are complete in all 23 languages. Every file has the same keys (Autostart tab, installer messages, lock screen, widget style names, quick actions palette, and strings that were missing from `en.json`).
- fix(i18n): strings that always showed English are translated: launcher command and calculator hints, bar module style descriptions, bar height (vertical bars), theme editor title, weather notification title, wallpaper history filter, About tab update and changelog buttons, location (Auto-detect, Latitude, Longitude, Apply) and wallpaper (Select wallpaper) buttons.

### 2.4.5
- added(sway): Sway support for the Infinite desktop. The canvas engine drives Sway through its IPC (`swaymsg`), with Super+G, zoom, pan, overview, tidy and marks in the default Sway config. The widget redactor snaps to apps on Sway as well.
- added(sway): `src/scripts/canvas/sway.py`, a small helper that translates Sway's tree and outputs for the canvas engine.
- changed(widgets): "Delete all widgets" is a single click; the "Click again to confirm" step and the trash icon were removed.
- changed(settings): the guide settings panel keeps its dragged position when the layout recalculates.
- changed(settings): "Hyprland only" labels in the Desktop tab now read "Hyprland and Sway only".
- perf(settings): guide settings no longer preload every tab after opening. Loaded tabs are released 20 seconds after settings close (was 10 minutes).
- perf(memory): settings and wallpaper panels are no longer created at startup. Cached panels (settings, wallpaper picker, system panel and others) are destroyed after about 45 seconds hidden and recreated on demand.
- note(settings): the first search in settings loads all tabs once to build the index, so that first search can take a moment.
- note(sway): Sway has no cursor-position query, so zoom on Sway is anchored to the centre of the focused output.
- note(sway): on multi-monitor Sway setups, floating windows that leave their output are handed to the neighbouring output by Sway; the Infinite desktop works best with one canvas monitor.

### 2.4.4
- added(settings): "Standalone Window" option in Settings > General opens guide settings as its own window instead of the panel.
- added(settings): plain text in the Widgets tab explaining how to switch between Tiled and Infinite desktop mode.
- added(widgets): "Delete all widgets" in guide settings > Widgets clears every widget from both Tiled and Infinite desktop on every workspace and screen (with a confirm click).
- added(settings): the guide settings panel can be dragged by its header, including on the infinite desktop.
- added(docs): new banner and screenshots in the README.
- changed(settings): every guide settings tab uses the same style as the Desktop tab.
- perf(settings): guide settings are lighter and faster, with no gradients.
- changed(dock): section captions are hidden while the dock is disabled.
- fix(dock): blank Dock tab in guide settings (Quickshell error).
- fix(settings): Quickshell warnings in guide settings and the infinite desktop.
- fix(canvas): widgets disappearing after Super+G between Tiled and Infinite desktop. Each mode keeps its own layout (`layout.json` for Tiled, `layout-canvas.json` for Infinite desktop).
- fix(canvas): accidental dragging of apps and widgets on the desktop.

### 2.4.x (ported onto upstream ilyamiro 2.4.1)
- added(canvas): Infinite desktop and custom features ported onto the updated upstream.
- added(widgets): "Delete all widgets" clears both Tiled and Infinite desktop on every workspace.
- added(settings): Desktop tab in guide settings, translated for all languages.
- added(canvas): two selectable scroll-zoom methods: resize every app and terminal, or sarods2d-style zoom.
- added(canvas): "Apps switcher when opens" toggle; a newly opened app centers the desktop.
- added(hyprland): spring-based Hyprland animation config (`settings.lua`).
- changed(redactor): widget redactors follow the apps speed slider so they stay in sync with apps.
- changed(polkit): improved typing and wrong-password animations.
- perf(shell): Quickshell RAM and CPU reduced.
- fix(settings): blank Desktop tab in guide settings.
- fix(settings): missing guide settings tabs and labels; stray `//` comments removed.
- fix(canvas): apps jumping back to their last position after move or resize.

### 2.3.x
- added(canvas): Infinite desktop for Hyprland with animated zoom in / out, Super+arrow navigation, marks, tidy and overview.
- added(cli): `serpantinum canvas <action>` commands.
- added(widgets): Iridium style variants for widgets (except notes, user, github, visualizer) and a Reminder widget.
- added(lock): lockscreen animation picker and Caelestia-style clock variants.
- added(canvas): scroll zoom over applications and widget redactors without resizing them.
- added(canvas): Super+G toggles Tiled and Infinite desktop; widgets fade out and back in, and each workspace restores its saved view.
- removed(canvas): parallax wallpaper, endless dragging, hover-to-switch and the minimap.
- fix(canvas): Super+G resetting or doing nothing on repeated presses.
- fix(canvas): widget redactors and applications drifting out of sync while moving.
- fix(settings): raw `guide.display.widgets.*` label keys in guide settings.
- fix(canvas): quick actions firing while Super+arrows move the desktop.
