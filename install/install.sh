#!/usr/bin/env bash

set -e

setterm -blank 0 -powerdown 0 2>/dev/null || true
printf '\033[9;0]' 2>/dev/null || true

for _arg in "$@"; do
    [ "$_arg" = "--plain" ] && export SERPANTINUM_PLAIN=1
    case "$_arg" in --drivers=*) export SERPANTINUM_DRIVERS_ARG="${_arg#--drivers=}" ;; esac
done

RAW_SLUG="${REPO_SLUG:-cssky-dev/Serpantinum-Infinite-Desktop-Edition}"
REPO_SLUG="$(printf '%s' "$RAW_SLUG" | tr -d '\r\n\t ' | sed 's/[^a-zA-Z0-9_\/-]//g')"
REPO_BRANCH="${SERPANTINUM_BRANCH:-master}"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-installer"
# One clone per repository. An old clone of another repo (the original Serpantinum) is never
# reused, which is what made this script start the wrong installer before.
CACHE_BASE="$CACHE_ROOT/$(printf '%s' "$REPO_SLUG" | tr '/' '_')"
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
    # Started through `curl ... | bash` or `bash -c "$(curl ...)"`: this file is not inside a
    # checkout. Fetch the repository, then run the installer that belongs to it.
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
    if ! command -v git &>/dev/null; then
        echo "git is required and could not be installed. Install git and run this again." >&2
        exit 1
    fi

    REPO_URL="https://github.com/${REPO_SLUG}.git"
    export GIT_TERMINAL_PROMPT=0

    # Clone left by an older installer that shared one folder between repositories
    if [ -d "$CACHE_ROOT/.git" ]; then
        rm -rf "$CACHE_ROOT"
    fi
    mkdir -p "$CACHE_ROOT"

    fresh_clone() {
        rm -rf "$CACHE_BASE"
        git clone --depth 50 --single-branch --no-tags --branch "$REPO_BRANCH" "$REPO_URL" "$CACHE_BASE"
    }

    if [ -d "$CACHE_BASE/.git" ] \
        && [ "$(git -C "$CACHE_BASE" config --get remote.origin.url 2>/dev/null)" = "$REPO_URL" ] \
        && git -C "$CACHE_BASE" fetch --depth 50 --no-tags origin "+refs/heads/${REPO_BRANCH}:refs/remotes/origin/${REPO_BRANCH}" \
        && git -C "$CACHE_BASE" reset --hard "origin/${REPO_BRANCH}" >/dev/null; then
        git -C "$CACHE_BASE" clean -fdq 2>/dev/null || true
    elif ! fresh_clone; then
        echo "Could not download ${REPO_URL} (branch ${REPO_BRANCH}). Check your connection and run this again." >&2
        exit 1
    fi

    if [ ! -f "$CACHE_BASE/install/install.sh" ] || [ ! -f "$CACHE_BASE/install/modules/deps.sh" ]; then
        echo "${REPO_URL} (branch ${REPO_BRANCH}) does not contain the Serpantinum installer." >&2
        exit 1
    fi

    # Run the installer that came with this checkout. Reading the keyboard from the terminal
    # keeps the card UI working when this script was piped into bash.
    if [ -t 0 ]; then
        exec bash "$CACHE_BASE/install/install.sh" "$@"
    elif ( exec < /dev/tty ) 2>/dev/null; then
        exec bash "$CACHE_BASE/install/install.sh" "$@" < /dev/tty
    else
        exec bash "$CACHE_BASE/install/install.sh" "$@"
    fi
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
source "$MODULES_DIR/drivers.sh"
source "$MODULES_DIR/steps.sh"

TELEMETRY_ID=$(get_telemetry_id)
ENABLE_TELEMETRY=$(get_telemetry_enabled)
OPT_SDDM=$(get_saved_preference OPT_SDDM "$OPT_SDDM")
SDDM_WAYLAND=$(get_saved_preference SDDM_WAYLAND "$SDDM_WAYLAND")
INSTALL_FULL_WALLPAPERS=$(get_saved_preference INSTALL_FULL_WALLPAPERS "$INSTALL_FULL_WALLPAPERS")

init_aur_helper
export AUR_HELPER

check_supported_os
init_precheck
[ -n "${SERPANTINUM_DRIVERS_ARG:-}" ] && drivers_from_arg "$SERPANTINUM_DRIVERS_ARG"

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
    choose_aur_helper_classic
    run_installer_ui
fi

if $USE_TUI; then
    tui_finish_flow
    exit 0
fi

set -e
echo -e "\e[36m[ INFO ]\e[0m $INIT_SUMMARY"
run_steps_classic
draw_completion_screen "$TARGET_VERSION" "$TARGET_COMMIT"
start_display_manager_now
