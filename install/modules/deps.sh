#!/usr/bin/env bash

SUPPORTED_DISTROS=(
    "arch"
    "endeavouros"
    "manjaro"
    "cachyos"
    "garuda"
    "arcolinux"
    "archcraft"
    "artix"
    "blackarch"
    "rebornos"
    "mabox"
    "blendos"
    "parch"
    "parchlinux"
    "biglinux"
    "archlabs"
    "archman"
    "alci"
    "bluestar"
    "archbang"
    "archex"
    "archstrike"
    "athena"
    "athenaos"
    "chimeraos"
    "ctlos"
    "crystal"
    "hefftorlinux"
    "instantos"
    "nyarch"
    "obarun"
    "hyperbola"
    "parabola"
    "salientos"
    "snal"
    "steamos"
    "holo"
    "stormos"
    "tearch"
    "xerolinux"
    "axyl"
    "omarchy"
)

# Packages are installed in categories, one installer step each, so the progress screen and
# the log show what is being installed. REQUIRED_PKGS stays the union of all of them.
PKG_CATEGORY_IDS=(core audio system media terminal fonts)
PKG_CATEGORY_LABEL_core="Shell and Qt"
PKG_CATEGORY_LABEL_audio="Audio"
PKG_CATEGORY_LABEL_system="System services"
PKG_CATEGORY_LABEL_media="Media and tools"
PKG_CATEGORY_LABEL_terminal="Terminal"
PKG_CATEGORY_LABEL_fonts="Font packages"

PKGS_core=(
    "quickshell" "matugen" "qt6-wayland" "qt6-multimedia" "qt6ct" "qt5ct"
    "wl-clipboard" "cliphist" "jq" "file" "python" "grim" "satty"
    "xdg-desktop-portal-gtk" "adwaita-icon-theme" "adw-gtk-theme"
)
PKGS_audio=(
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "libpulse"
    "pavucontrol" "playerctl" "cava"
)
PKGS_system=(
    "bluez" "networkmanager" "power-profiles-daemon" "ddcutil"
)
PKGS_media=(
    "ffmpeg" "imagemagick" "fastfetch" "zbar" "tesseract" "tesseract-data-eng"
    "gpu-screen-recorder" "wf-recorder"
)
PKGS_terminal=("kitty")
PKGS_fonts=("ttf-jetbrains-mono" "noto-fonts" "noto-fonts-emoji" "noto-fonts-cjk")

REQUIRED_PKGS=()
for _cat in "${PKG_CATEGORY_IDS[@]}"; do
    _arr="PKGS_${_cat}[@]"
    REQUIRED_PKGS+=("${!_arr}")
done
unset _cat _arr

# Packages that depend on the init system. Without systemd nothing restores the backlight
# level at boot, so brightnessctl comes with the setup-brightness.sh service (see service.sh).
init_extra_pkgs() {
    local init_sys
    init_sys="$(detect_init_system)"
    if [ "$init_sys" != "systemd" ]; then
        echo "brightnessctl"
    fi
}

FAILED_PKGS=()
PKG_PREP_MARK="${TMPDIR:-/tmp}/serpantinum-pkgprep.$$"
rm -f "$PKG_PREP_MARK"

suppress_tty_sleep() {
    setterm -blank 0 -powerdown 0 2>/dev/null || true
    printf '\033[9;0]' 2>/dev/null || true
}

check_supported_os() {
    if [ "$EUID" -eq 0 ]; then
        echo "$(t "installer.os.error_root")" >&2
        exit 1
    fi

    if [ -f /etc/os-release ]; then
        local DETECTED_OS
        DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

        for os in "${SUPPORTED_DISTROS[@]}"; do
            if [ "$DETECTED_OS" = "$os" ]; then
                return 0
            fi
        done

        if declare -f pm_supports_os >/dev/null && pm_supports_os; then
            return 0
        fi

        echo "$(t "installer.os.error_unsupported" "os=$DETECTED_OS")"
        exit 1
    else
        echo "$(t "installer.os.error_not_found")"
        exit 1
    fi
}

bootstrap_repos() {
    suppress_tty_sleep
    pm_prepare_repos
}

bootstrap_tools() {
    local missing=()
    for tool in "${PM_BOOTSTRAP_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        pm_bootstrap_install "${missing[@]}"
    fi
}

bootstrap_helper() {
    declare -f pm_bootstrap_helper >/dev/null && pm_bootstrap_helper
}

# Arch only: which AUR helper to use (yay or paru). Saved choice, then an already installed one, then yay.
init_aur_helper() {
    [[ "${PM_NAME:-}" == pacman ]] || { AUR_HELPER=""; return 0; }
    local saved
    saved="$(get_saved_value AUR_HELPER "")"
    case "$saved" in yay|paru) AUR_HELPER="$saved"; return 0 ;; esac
    if command -v yay &>/dev/null; then AUR_HELPER=yay
    elif command -v paru &>/dev/null; then AUR_HELPER=paru
    else AUR_HELPER=yay; fi
}

toggle_aur_helper() {
    [[ "$AUR_HELPER" == yay ]] && AUR_HELPER=paru || AUR_HELPER=yay
}

# Classic installer: everything in one go.  The card UI runs the three parts
# as separate, visible steps (see tui_system_update).
# The AUR helper is NOT prepared here any more: the person picks yay or paru in the installer menu
# first, and install_dependencies() builds the chosen one right before it needs it.
bootstrap_installer_deps() {
    bootstrap_repos
    bootstrap_tools
}

install_fonts() {
    local target_fonts_dir="$HOME/.local/share/fonts/IosevkaNerdFont"
    if [ ! -d "$target_fonts_dir" ] || [ -z "$(ls -A "$target_fonts_dir" 2>/dev/null | grep -i "\.ttf")" ]; then
        local font_cache="${XDG_CACHE_HOME:-"$HOME/.cache"}/serpantinum-fonts"
        mkdir -p "$font_cache" "$target_fonts_dir"
        echo -e "\n\e[36m[ INFO ]\e[0m Downloading Iosevka Nerd Font..."
        if curl -# -L --connect-timeout 15 --retry 3 "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip" -o "$font_cache/Iosevka.zip"; then
            if [ -f "$font_cache/Iosevka.zip" ]; then
                echo -e "\e[36m[ INFO ]\e[0m Unpacking fonts..."
                unzip -qo "$font_cache/Iosevka.zip" -d "$font_cache/" 2>/dev/null || true
                mv "$font_cache"/*.ttf "$target_fonts_dir/" 2>/dev/null || true
                rm -f "$target_fonts_dir/"*Mono*.ttf 2>/dev/null || true
                sudo mkdir -p /usr/share/fonts/IosevkaNerdFont
                sudo cp -r "$target_fonts_dir/"* /usr/share/fonts/IosevkaNerdFont/ 2>/dev/null || true
            fi
        else
            echo -e "\e[33m[ WARN ]\e[0m Failed to download fonts, skipping..."
        fi
        rm -rf "$font_cache"
    fi

    find "$HOME/.local/share/fonts" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$HOME/.local/share/fonts" -type d -exec chmod 755 {} \; 2>/dev/null || true

    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    fi
}

# kitty comes from the terminal package step and uses JetBrains Mono (the default). A config that an
# earlier Serpantinum version switched to CookieRun is put back; a font the person chose is left alone.
setup_kitty_cookierun() { setup_kitty_font; }
setup_kitty_font() {
    local conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/kitty" conf shipped
    if ! command -v kitty &>/dev/null; then
        tui_note "kitty is not installed"
        return 10
    fi
    mkdir -p "$conf_dir"
    conf="$conf_dir/kitty.conf"
    shipped="${PROJECT_ROOT:-}/config/kitty/kitty.conf"
    if [ ! -f "$conf" ]; then
        if [ -f "$shipped" ]; then cp "$shipped" "$conf"; else printf 'font_family    Jetbrains Mono\n' > "$conf"; fi
        echo "kitty.conf created with JetBrains Mono"
    elif grep -qE '^[[:space:]]*font_family[[:space:]]+CookieRun[[:space:]]*$' "$conf"; then
        sed -i -E 's/^([[:space:]]*font_family[[:space:]]+)CookieRun[[:space:]]*$/\1Jetbrains Mono/' "$conf"
        sed -i '/^# Nerd Font icons for CookieRun$/,+1d' "$conf"
        echo "kitty.conf: font_family put back to JetBrains Mono"
    else
        echo "kitty.conf left as it is"
    fi
    tui_note "kitty uses JetBrains Mono"
}

configure_qt_environment() {
    local icon_theme="Adwaita"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local qtct conf

    for qtct in qt5ct qt6ct; do
        conf="$config_home/$qtct/$qtct.conf"
        mkdir -p "$config_home/$qtct/colors" 2>/dev/null || continue
        if [ ! -f "$conf" ]; then
            printf '[Appearance]\nicon_theme=%s\n' "$icon_theme" > "$conf"
        elif grep -q '^icon_theme=.\+' "$conf"; then
            :
        elif grep -q '^icon_theme=' "$conf"; then
            sed -i "s|^icon_theme=.*|icon_theme=$icon_theme|" "$conf"
        elif grep -q '^\[Appearance\]' "$conf"; then
            sed -i "/^\[Appearance\]/a icon_theme=$icon_theme" "$conf"
        else
            printf '\n[Appearance]\nicon_theme=%s\n' "$icon_theme" >> "$conf"
        fi
    done

    local env_dir="$config_home/environment.d"
    local env_file="$env_dir/serpantinum-qt.conf"
    if [ -f "$env_file" ] \
        || { [ -z "${QT_QPA_PLATFORMTHEME:-}" ] && ! grep -rqs '^QT_QPA_PLATFORMTHEME=' "$env_dir" 2>/dev/null; }; then
        mkdir -p "$env_dir"
        printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' > "$env_file"
    fi
}

# Kept for older callers
configure_qt_icon_theme() { configure_qt_environment; }

compositor_package_name() {
    case "$1" in
        mango) echo "mangowm" ;;
        *) echo "$1" ;;
    esac
}

find_sddm_binary() {
    local name="$1" dir
    local IFS=:
    for dir in ${SDDM_SEARCH_PATH:-/usr/local/bin:/usr/bin:/bin}; do
        if [ -x "$dir/$name" ]; then
            echo "$dir/$name"
            return 0
        fi
    done
    return 1
}

sddm_has_xorg() {
    find_sddm_binary Xorg >/dev/null || find_sddm_binary X >/dev/null
}

sddm_packages() {
    printf '%s\n' sddm qt6-declarative qt6-svg "${PM_SDDM_EXTRA_PKGS[@]}"
    if [ "$SDDM_WAYLAND" = true ] \
        && ! find_sddm_binary kwin_wayland >/dev/null \
        && ! find_sddm_binary weston >/dev/null \
        && ! sddm_has_xorg; then
        echo weston
    fi
}

MIN_QUICKSHELL_VERSION="0.3.0"

quickshell_version() {
    quickshell --version 2>/dev/null | sed -n 's/^[Qq]uickshell \([0-9][0-9.]*\).*/\1/p' | head -n 1
}

quickshell_is_current() {
    local version
    version="$(quickshell_version)"
    [ -n "$version" ] && [ "$(printf '%s\n%s\n' "$MIN_QUICKSHELL_VERSION" "$version" | sort -V | head -n 1)" = "$MIN_QUICKSHELL_VERSION" ]
}

ensure_quickshell_version() {
    command -v quickshell >/dev/null 2>&1 || return 0
    quickshell_is_current && return 0

    echo -e "\n\e[33m  $(t "installer.deps.quickshell_outdated" "version=$(quickshell_version)" "minimum=$MIN_QUICKSHELL_VERSION")\e[0m"
    if declare -f pm_upgrade_quickshell >/dev/null; then pm_upgrade_quickshell || true; fi
    hash -r

    if ! quickshell_is_current; then
        echo -e "\n\e[31m  $(t "installer.deps.quickshell_still_old" "minimum=$MIN_QUICKSHELL_VERSION")\e[0m"
    fi
}

# Package list of one category. The "system" category also gets the init dependent packages
# (brightnessctl without systemd), "core" gets the compositors, "core" or "system" gets SDDM.
category_packages() {
    local cat="$1" arr pkg comp
    arr="PKGS_${cat}[@]"
    for pkg in "${!arr}"; do printf '%s\n' "$pkg"; done
    case "$cat" in
        core)
            for comp in "${SELECTED_COMPOSITORS[@]}"; do compositor_package_name "$comp"; done
            ;;
        system)
            init_extra_pkgs
            if [ "$OPT_SDDM" = true ]; then sddm_packages; fi
            for pkg in "${PM_EXTRA_PKGS[@]}"; do printf '%s\n' "$pkg"; done
            ;;
    esac
}

# Once per run, before the first category: conflicting packages, the system upgrade and the AUR helper.
prepare_package_manager() {
    # Every step runs in its own subshell, so "already done" lives in a file (named after the installer's PID)
    [ -e "$PKG_PREP_MARK" ] && return 0
    local install_state="${INSTALL_STATE:-}" is_reinstall="${IS_REINSTALL:-}"
    pm_remove_conflicting_pkg "quickshell-git"
    if [[ ("$install_state" == "fresh" || "$install_state" == "legacy") && "$is_reinstall" != "true" \
        && "${SYSTEM_UPGRADED:-0}" != "1" ]]; then
        pm_full_upgrade
    fi
    bootstrap_helper || echo -e "\n\e[33m[ WARN ]\e[0m AUR helper could not be installed, AUR packages may fail"
    : > "$PKG_PREP_MARK"
}

install_category() {
    local cat="$1" label_var="PKG_CATEGORY_LABEL_$1" label
    label="${!label_var}"
    local target_list=() pkg
    while IFS= read -r pkg; do [[ -n "$pkg" ]] && target_list+=("$pkg"); done < <(category_packages "$cat")

    echo -e "\n\e[36m[ INFO ]\e[0m ${label}: ${#target_list[@]} packages"

    local MISSING_PKGS=() missing_raw
    missing_raw=$(pm_missing_pkgs "${target_list[@]}")
    while IFS= read -r pkg; do [[ -n "$pkg" ]] && MISSING_PKGS+=("$pkg"); done <<< "$missing_raw"

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        echo -e "\e[32m  ${label}: everything is installed\e[0m"
        return 0
    fi

    prepare_package_manager
    echo -e "\e[33m  ${label}: ${#MISSING_PKGS[@]} to install (${MISSING_PKGS[*]})\e[0m"

    local SAFE_JOBS=$(( $(nproc) / 2 ))
    [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1
    [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4

    if declare -f pm_install_batch >/dev/null; then
        pm_install_batch "${MISSING_PKGS[@]}"
        MISSING_PKGS=("${PM_BATCH_LEFT[@]}")
    fi

    local failed_here=()
    for pkg in "${MISSING_PKGS[@]}"; do
        echo -e "\e[34m::\e[0m \e[1m$(t "installer.deps.installing_pkg" "pkg=$pkg")\e[0m"
        if pm_install_pkg "$pkg" "$SAFE_JOBS"; then
            echo -e "\e[32m[ OK ] $(t "installer.deps.install_ok" "pkg=$pkg")\e[0m"
        else
            echo -e "\e[31m[ FAILED ] $(t "installer.deps.install_failed" "pkg=$pkg")\e[0m"
            FAILED_PKGS+=("$pkg"); failed_here+=("$pkg")
        fi
    done

    [ "$cat" = core ] && ensure_quickshell_version
    if [ ${#failed_here[@]} -gt 0 ]; then
        tui_note "${#failed_here[@]} not installed: ${failed_here[*]}"
        return 10
    fi
    tui_note "${#target_list[@]} packages ready"
}

# Kept for callers that install everything in one go
install_dependencies() {
    local cat rc=0
    for cat in "${PKG_CATEGORY_IDS[@]}"; do install_category "$cat" || rc=$?; done
    return $rc
}
