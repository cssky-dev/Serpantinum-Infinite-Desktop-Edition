<div align="center">

<img src="./docs/assets/banner.png" alt="Serpantinum Infinite Desktop Edition" width="100%">

**Your favourite desktop is way customized for YOU.**

Built on [Quickshell](https://quickshell.org) · Based on ilyamiro's Serpantinum · Infinite desktop for Hyprland

[Install](#installation) · [Screenshots](#screenshots) · [Infinite desktop](#infinite-desktop) · [Keybinds](#keybinds-hyprland) · [CLI](#cli) · [Docs](#documentation) · [Changelog](./CHANGELOG.md)

</div>

---

## Contents

- [Screenshots](#screenshots)
- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Infinite desktop](#infinite-desktop)
- [Widgets](#widgets)
- [Settings](#settings)
- [CLI](#cli)
- [Supported compositors](#supported-compositors)
- [Repository layout](#repository-layout)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)
- [Notice](#notice)
- [Credits](#credits)

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="./docs/assets/previews/preview-1.png" alt="Visualizer and terminal widgets on the infinite desktop"></td>
    <td width="50%"><img src="./docs/assets/previews/preview-2.png" alt="Visualizer and image widgets over a purple wallpaper"></td>
  </tr>
  <tr>
    <td width="50%"><img src="./docs/assets/previews/preview-3.png" alt="Settings panel with the Welcome tab"></td>
    <td width="50%"><img src="./docs/assets/previews/preview-4.png" alt="Clock and visualizer widgets over a dark wallpaper"></td>
  </tr>
</table>

## Features

- **Infinite desktop**: one large canvas per workspace with animated pan and zoom, marks, tidy and overview
- **Two zoom methods**: resize every app and terminal, or sarods2d-style zoom
- **Widget redactor** with many widget styles, including Iridium variants and a Reminder widget
- **Separate widget layouts** for Tiled and Infinite desktop, switched with `Super + G`
- **Full shell**: bar, dock, launcher, clipboard, notifications, system panel, calendar, media, network and volume popouts
- **Lockscreen** with selectable animations and clock styles
- **Guide settings** as a panel or a standalone window, with a Desktop tab for infinite desktop options
- **Theming** from the wallpaper palette, plus [app theming](./docs/configure/AppTheming.md) for GTK, Qt, terminals and editors
- **Compositor configs** for Hyprland, Niri, Sway and Mango

## Installation

To install, run:

```bash
curl -fsSL install.serpantinum-infinite.dev | bash
```

If that does not work, try:

```bash
bash -c "$(curl -fsSL https://raw.github.com/cssky-dev/Serpantinum-Infinite-Desktop-Edition/install/install.sh)"
```

The installer supports Arch Linux, Fedora, Void Linux and their derivatives. It detects your distribution and uses `pacman`, `dnf` or `xbps`. On NixOS, use the flake in [`flake.nix`](./flake.nix) and the [NixOS guide](./docs/installation/nixos/flake.md).

To update, run the installer again and choose **Update**.

More detail, including Fedora, Void and Arch source builds, is in the [installation docs](./docs/installation/installation.md).

## Quick start

```bash
serpantinumd start             # start the shell daemon
serpantinum settings           # open settings
serpantinum msg toggle launcher
serpantinum restart            # restart the shell
```

Serpantinum is only a desktop shell. It does not manage your keybinds or monitors, so add the keybinds you want from the [compositor guides](#supported-compositors). The Hyprland config in [`compositors/hyprland`](./compositors/hyprland) already includes all infinite desktop binds.

## Infinite desktop

Windows and widgets sit on one large canvas per workspace instead of a fixed screen.

- `Super + G` switches between **Tiled** and **Infinite desktop** mode.
- Each mode keeps its **own widget layout**: `layout.json` for Tiled and `layout-canvas.json` for Infinite desktop, stored per monitor in `~/.local/state/serpantinum/widgets/<monitor>/`.
- Each workspace restores its saved view when you return to it.
- A newly opened app can center the desktop on itself (toggle **Apps switcher when opens** in Settings > Desktop).

> The infinite desktop currently supports **Hyprland only**.

### Keybinds (Hyprland)

| Keys | Action |
| --- | --- |
| `Super + G` | Toggle Tiled / Infinite desktop |
| `Super + Arrows` | Move focus between windows |
| `Super + Tab` | Overview (fit all windows) |
| `Super + Home` | Go home |
| `Super + Shift + T` | Tidy windows |
| `Super + =` / `Super + -` | Zoom in / out |
| `Super + Backspace` | Reset zoom |
| `Super + Scroll` | Zoom in / out |
| `Super + Ctrl + Scroll` | Pan vertically |
| `Super + Page Up / Down` | Pan one page up / down |
| `Super + Alt + Left / Right` | Pan one page left / right |
| `Super + Left mouse` / `Right mouse` | Drag / resize a window |

## Widgets

Open the widget redactor from the Widgets tab in guide settings, or with `serpantinum redactor`.

- Widgets are saved separately for Tiled and Infinite desktop.
- **Delete all widgets** (Settings > Widgets) clears every widget from both modes on every workspace and screen. It asks for a second click to confirm.
- Layouts live in `~/.local/state/serpantinum/widgets/`.

## Settings

```bash
serpantinum settings           # open settings
serpantinum settings theme     # open a specific tab
```

In Settings > General, **Standalone Window** opens settings as its own window instead of the panel.

In panel mode, drag the settings panel by its header (the "Settings" title) to move it anywhere on the screen, including on the infinite desktop.

## CLI

```bash
serpantinum canvas toggle          # Tiled <-> Infinite desktop
serpantinum canvas overview        # fit all windows
serpantinum canvas zoomIn
serpantinum canvas panBy 0 160
serpantinum canvas markSet 1       # save a mark
serpantinum canvas markGo 1        # jump to a mark
serpantinum canvas status
```

Other canvas actions: `enable`, `disable`, `focus <dir>`, `fit`, `zoom <factor>`, `zoomOut`, `zoomReset`, `panPage`, `home`, `tidy`, `arrange <mode>`, `dump`.

Full command list: [client docs](./docs/cli/client.md) and [daemon docs](./docs/cli/daemon.md).

## Supported compositors

| Compositor | Shell | Infinite desktop | Config |
| --- | :---: | :---: | --- |
| Hyprland | Yes | Yes | [guide](./docs/configure/compositors/hyprland.md) |
| Niri | Yes | No | [guide](./docs/configure/compositors/niri.md) |
| Sway | Yes | No | [guide](./docs/configure/compositors/sway.md) |
| Mango | Yes | No | [guide](./docs/configure/compositors/mango.md) |

## Repository layout

| Path | Contents |
| --- | --- |
| `bin/` | `serpantinum` client and `serpantinumd` daemon |
| `src/quickshell/` | Shell UI (QML); `canvas/` holds the infinite desktop |
| `src/scripts/` | Helper scripts |
| `compositors/` | Hyprland, Niri, Sway and Mango configs |
| `install/` | Installer and tests |
| `nix/`, `flake.nix` | Nix packages and modules |
| `packaging/` | AUR PKGBUILDs |
| `docs/` | Documentation |

## Troubleshooting

- **Installer command fails:** try the second install command, or download and run `install/install.sh` from this repository.
- **Shell not running:** start it with `serpantinumd start`, or restart with `serpantinum restart`.
- **Infinite desktop does nothing:** it needs Hyprland. Check that the `serpantinum canvas` keybinds are in your Hyprland config.
- **Widgets missing after a mode switch:** each mode has its own layout. Press `Super + G` to return to the mode where you made them.

## Documentation

- [Overview](./docs/Overview.md)
- [Installation](./docs/installation/installation.md)
- [Configuration](./docs/configure/Configure.md)
- [App theming](./docs/configure/AppTheming.md)
- [Client CLI](./docs/cli/client.md) · [Daemon CLI](./docs/cli/daemon.md)
- [Changelog](./CHANGELOG.md)

## Notice

> **Information:** Serpantinum Infinite Desktop Edition is a Wayland desktop shell built on Quickshell and based on ilyamiro's Serpantinum. The infinite desktop currently supports Hyprland only.

> **Vibecoded with Claude:** this project is vibecoded with Claude. Don't trust the AI slop you see on social media about it - check this README and the docs instead.

## Credits

Based on [ilyamiro's](https://github.com/ilyamiro) Serpantinum. Lockscreen and clock ideas come from Caelestia shell.
