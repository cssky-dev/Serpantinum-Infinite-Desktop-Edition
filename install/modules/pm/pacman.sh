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

# AUR helper: "paru", "yay" or "both". Chosen in the installer (AUR_HELPER), remembered between runs,
# and falling back to whatever is already installed. With "both", paru builds the packages and yay
# is the fallback when paru fails.
pm_aur_helpers_wanted() {   # one helper per line, in the order they are built
    case "${AUR_HELPER:-}" in
        both)      echo paru; echo yay ;;
        paru|yay)  echo "$AUR_HELPER" ;;
        *)
            if command -v yay &>/dev/null; then echo yay
            elif command -v paru &>/dev/null; then echo paru
            else echo yay; fi ;;
    esac
}

pm_aur_helper() {   # the helper that is used first
    local h
    h="$(pm_aur_helpers_wanted | head -n1)"
    if [[ "${AUR_HELPER:-}" == both ]]; then
        command -v paru &>/dev/null && h=paru || { command -v yay &>/dev/null && h=yay; }
    fi
    echo "$h"
}

pm_aur_helper_chain() {   # helpers to try for one package: the chosen one first, then the other for "both"
    local first
    first="$(pm_aur_helper)"
    echo "$first"
    if [[ "${AUR_HELPER:-}" == both ]]; then
        [[ "$first" == paru ]] && echo yay || echo paru
    fi
}

pm_build_helper() {   # pm_build_helper paru|yay  - builds <helper>-bin from the AUR, full log on screen
    local helper="$1" pkg="${1}-bin"
    command -v "$helper" &>/dev/null && return 0
    local cache_build="${XDG_CACHE_HOME:-"$HOME/.cache"}/serpantinum-${pkg}"
    echo -e "\n\e[36m[ INFO ]\e[0m Installing the AUR helper ${helper} (${pkg})"
    rm -rf "$cache_build"
    mkdir -p "$cache_build"
    echo -e "\e[34m::\e[0m Cloning https://aur.archlinux.org/${pkg}.git"
    git clone "https://aur.archlinux.org/${pkg}.git" "$cache_build" || return 1
    echo -e "\e[34m::\e[0m Building ${pkg} with makepkg"
    (cd "$cache_build" && makepkg -si --noconfirm)
    local rc=$?
    rm -rf "$cache_build"
    if (( rc == 0 )); then echo -e "\e[32m[ OK ] ${helper} installed\e[0m"
    else echo -e "\e[31m[ FAILED ] ${helper} could not be installed\e[0m"; fi
    return $rc
}

pm_bootstrap_helper() {   # builds every helper the person picked that is not installed yet
    local h rc=0
    for h in $(pm_aur_helpers_wanted); do
        pm_build_helper "$h" || rc=1
    done
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

    if pacman -Si "$pkg" &>/dev/null; then
        sudo pacman -S --noconfirm --needed "$pkg"
        return $?
    fi
    for helper in $(pm_aur_helper_chain); do
        command -v "$helper" &>/dev/null || continue
        env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" "$helper" -S --noconfirm --needed "$pkg" && return 0
        echo -e "\e[33m[ WARN ]\e[0m ${helper} could not install ${pkg}"
    done
    sudo pacman -S --noconfirm --needed "$pkg"
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
