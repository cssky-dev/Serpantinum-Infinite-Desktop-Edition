#!/usr/bin/env bash

set -e

setterm -blank 0 -powerdown 0 2>/dev/null || true
printf '\033[9;0]' 2>/dev/null || true

for _arg in "$@"; do [ "$_arg" = "--plain" ] && export SERPANTINUM_PLAIN=1; done

RAW_SLUG="${REPO_SLUG:-cssky-dev/Serpantinum-Infinite-Desktop-Edition}"
REPO_SLUG="$(printf '%s' "$RAW_SLUG" | tr -d '\r\n\t ' | sed 's/[^a-zA-Z0-9_\/-]//g')"
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-installer"
export REPO_SLUG
export SERPANTINUM_INSTALLER=1

if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    INSTALL_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    PROJECT_ROOT="$(dirname "$INSTALL_DIR")"
else
    INSTALL_DIR=""
    PROJECT_ROOT=""
fi

if [[ -z "$PROJECT_ROOT" || ! -f "$PROJECT_ROOT/install/modules/deps.sh" || ! -d "$PROJECT_ROOT/src" ]]; then
    if ! command -v git &>/dev/null; then
        if command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm --needed git
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y git
        elif command -v xbps-install &>/dev/null; then
            sudo xbps-install -Suy xbps || true
            sudo xbps-install -Sy git
        elif command -v emerge &>/dev/null; then
            if command -v sudo &>/dev/null; then
                sudo emerge --ask=n --noreplace dev-vcs/git
            else
                su root -c "emerge --ask=n --noreplace dev-vcs/git"
            fi
        fi
    fi
    if [ ! -d "$CACHE_BASE/.git" ]; then
        rm -rf "$CACHE_BASE"
        mkdir -p "$CACHE_BASE"
        git clone --depth 50 --single-branch --no-tags "https://github.com/${REPO_SLUG}.git" "$CACHE_BASE"
    else
        git -C "$CACHE_BASE" remote set-url origin "https://github.com/${REPO_SLUG}.git" 2>/dev/null || true
        git -C "$CACHE_BASE" fetch --depth 50 --no-tags origin 2>/dev/null || true
        git -C "$CACHE_BASE" reset --hard origin/HEAD 2>/dev/null || git -C "$CACHE_BASE" reset --hard origin/main 2>/dev/null || git -C "$CACHE_BASE" reset --hard origin/master 2>/dev/null || true
    fi
    INSTALL_DIR="$CACHE_BASE/install"
    PROJECT_ROOT="$CACHE_BASE"
fi

export SERPANTINUM_DIR="$PROJECT_ROOT/src"
export I18N_DIR="$PROJECT_ROOT/src/assets/languages"

MODULES_DIR="$INSTALL_DIR/modules"

source "$PROJECT_ROOT/src/scripts/i18n.sh"
source "$MODULES_DIR/pm.sh"
source "$MODULES_DIR/deps.sh"
source "$MODULES_DIR/ski.sh"
source "$MODULES_DIR/daemons.sh"
source "$MODULES_DIR/audio.sh"
source "$MODULES_DIR/gamma.sh"
source "$MODULES_DIR/core.sh"
source "$MODULES_DIR/state.sh"
source "$MODULES_DIR/migrate.sh"
source "$MODULES_DIR/deploy.sh"
source "$MODULES_DIR/version.sh"
source "$MODULES_DIR/config.sh"
source "$MODULES_DIR/service.sh"
source "$MODULES_DIR/ui.sh"
source "$MODULES_DIR/tui.sh"
source "$MODULES_DIR/steps.sh"

TELEMETRY_ID=$(get_telemetry_id)
ENABLE_TELEMETRY=$(get_telemetry_enabled)
OPT_SDDM=$(get_saved_preference OPT_SDDM "$OPT_SDDM")
SDDM_WAYLAND=$(get_saved_preference SDDM_WAYLAND "$SDDM_WAYLAND")
INSTALL_FULL_WALLPAPERS=$(get_saved_preference INSTALL_FULL_WALLPAPERS "$INSTALL_FULL_WALLPAPERS")

check_supported_os

USE_TUI=false
if tui_enabled; then USE_TUI=true; fi

if $USE_TUI; then
    set +e
    tui_begin
    tui_system_update
    tui_status "Preparing" "Reading your current setup"
else
    bootstrap_installer_deps
fi

INSTALL_STATE=$(detect_install_state)
OLD_VERSION=$(get_installed_version)
TARGET_VERSION=$(get_target_version "$PROJECT_ROOT" "$REPO_SLUG")
TARGET_COMMIT=$(get_target_commit "$PROJECT_ROOT" "$REPO_SLUG")
OLD_COMMIT=$(get_installed_commit)

init_compositor_detection

if $USE_TUI; then
    tui_workflow
    if [ $? -ne 0 ]; then
        ui_stop
        echo "Cancelled."
        exit 0
    fi
else
    run_installer_ui
fi

if $USE_TUI; then
    tui_finish_flow
    exit 0
fi

set -e
run_steps_classic
draw_completion_screen "$TARGET_VERSION" "$TARGET_COMMIT"
