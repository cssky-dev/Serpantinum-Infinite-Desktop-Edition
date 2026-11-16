#!/usr/bin/env bash

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig base-devel)
PM_AUDIO_BUILD_PKGS=(base-devel pkgconf pipewire)

pm_prepare_repos() {
    if [ -f /etc/pacman.conf ]; then
        if grep -q "^#\[multilib\]" /etc/pacman.conf; then
            sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
            sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
        fi
    fi
}

pm_bootstrap_install() {
    sudo pacman -Sy --noconfirm --needed "$@"
}

# AUR helper: "yay" or "paru". Chosen in the installer (AUR_HELPER), remembered between runs, and
# falling back to whatever is already installed.
pm_aur_helper() {
    local h="${AUR_HELPER:-}"
    case "$h" in yay|paru) ;; *) h="" ;; esac
    if [[ -z "$h" ]]; then
        if command -v yay &>/dev/null; then h=yay
        elif command -v paru &>/dev/null; then h=paru
        else h=yay; fi
    fi
    echo "$h"
}

pm_bootstrap_helper() {
    local helper pkg
    helper="$(pm_aur_helper)"
    command -v "$helper" &>/dev/null && return 0

    pkg="${helper}-bin"
    local cache_build="${XDG_CACHE_HOME:-"$HOME/.cache"}/serpantinum-${pkg}"
    rm -rf "$cache_build"
    mkdir -p "$cache_build"
    git clone "https://aur.archlinux.org/${pkg}.git" "$cache_build" || return 1
    (cd "$cache_build" && makepkg -si --noconfirm)
    local rc=$?
    rm -rf "$cache_build"
    return $rc
}

pm_full_upgrade() {
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
    sudo pacman -Syyu --noconfirm
}

pm_missing_pkgs() {
    pacman -T "$@" 2>/dev/null || true
}

pm_is_installed() {
    pacman -Q "$1" &>/dev/null
}

pm_install_pkg() {
    local pkg="$1"
    local safe_jobs="$2"
    local helper
    helper="$(pm_aur_helper)"

    if pacman -Si "$pkg" &>/dev/null; then
        sudo pacman -S --noconfirm --needed "$pkg"
    elif command -v "$helper" &>/dev/null; then
        env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" "$helper" -S --noconfirm --needed "$pkg"
    else
        sudo pacman -S --noconfirm --needed "$pkg"
    fi
}

pm_upgrade_quickshell() {
    if sudo pacman -Syu --noconfirm --needed --ask=4 quickshell && quickshell_is_current; then
        return 0
    fi

    local helper
    helper="$(pm_aur_helper)"
    if command -v "$helper" &>/dev/null; then
        "$helper" -S --noconfirm --needed --ask=4 quickshell-git && quickshell_is_current && return 0
    fi
    return 0
}

pm_remove_pkg() {
    sudo pacman -Rns --noconfirm "$1" >/dev/null 2>&1 || true
}

pm_remove_conflicting_pkg() {
    local pkg="$1" helper
    helper="$(pm_aur_helper)"
    if pm_is_installed "$pkg"; then
        if command -v "$helper" &>/dev/null; then
            "$helper" -R --noconfirm "$pkg" 2>/dev/null || sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null || true
        else
            sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null || true
        fi
    fi
}
