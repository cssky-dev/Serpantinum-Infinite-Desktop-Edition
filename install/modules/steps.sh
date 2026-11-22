#!/usr/bin/env bash

STEP_IDS=(prepare aurhelper pkg_core pkg_audio pkg_system pkg_media pkg_terminal pkg_fonts drivers fonts daemons shell sddm wallpapers config terminal qt services finish)
STEP_LABEL=("System snapshot" "AUR helper" "Shell and Qt" "Audio" "System services" "Media and tools" "Terminal" "Font packages" "Drivers" "Fonts" "Daemons" "Shell files" "Login screen" "Wallpapers" "Configuration" "Kitty font" "Qt theming" "Services" "Finishing up")
STEP_DEST=("backup and migration" "paru, yay or both" "quickshell, matugen, qt6" "pipewire, wireplumber, pavucontrol" "bluez, NetworkManager, power profiles" "ffmpeg, cava, recorders, OCR" "kitty" "JetBrains Mono, Noto" "GPU drivers, CPU microcode" "Iosevka Nerd Font, font cache" "ski, audio, gamma, core" "~/.local/share/serpantinum" "SDDM theme" "wallpaper pack" "~/.config/serpantinum" "kitty.conf, JetBrains Mono" "qt5ct + qt6ct" "init services" "version state")
STEP_WEIGHT=(1 5 4 3 2 3 1 2 4 3 6 3 2 3 1 1 1 1 1)

if ! declare -f tui_note >/dev/null; then tui_note() { :; }; fi

step_prepare() {
    if [ "$ENABLE_TELEMETRY" = true ] && [ -f "$MODULES_DIR/telemetry.sh" ]; then
        bash "$MODULES_DIR/telemetry.sh" --mode init --version "$TARGET_VERSION" --id "$TELEMETRY_ID" --enabled "$ENABLE_TELEMETRY"
    fi

    if [[ "$INSTALL_STATE" == "legacy" ]]; then
        migrate_legacy "${SELECTED_COMPOSITORS[@]}"
        tui_note "legacy setup migrated"
    elif [[ "$INSTALL_STATE" == "fresh" || "$IS_REINSTALL" == true ]]; then
        backup_compositors "${SELECTED_COMPOSITORS[@]}"
        tui_note "compositor configs backed up"
    fi
}

# Arch only. Builds the AUR helper(s) the person picked (paru, yay or both) before any package is
# installed. The card installer switches to a big live build log while this step runs and goes back
# to the normal install screen when it is done. Other distributions skip it.
step_aurhelper() {
    [[ "${PM_NAME:-}" == pacman ]] || return 20
    prepare_package_manager
    local h missing=() ready=()
    for h in $(pm_aur_helpers_wanted); do
        if command -v "$h" &>/dev/null; then ready+=("$h"); else missing+=("$h"); fi
    done
    if (( ${#missing[@]} )); then
        tui_note "could not install: ${missing[*]}"
        return 10
    fi
    tui_note "${ready[*]} ready"
}

# Hide the AUR helper step where it does not apply, so it is not listed as skipped
prune_aur_step() {
    [[ "${PM_NAME:-}" == pacman ]] && return 0
    local i ids=() lab=() dest=() w=()
    for (( i = 0; i < ${#STEP_IDS[@]}; i++ )); do
        [[ "${STEP_IDS[i]}" == aurhelper ]] && continue
        ids+=("${STEP_IDS[i]}"); lab+=("${STEP_LABEL[i]}"); dest+=("${STEP_DEST[i]}"); w+=("${STEP_WEIGHT[i]}")
    done
    STEP_IDS=("${ids[@]}"); STEP_LABEL=("${lab[@]}"); STEP_DEST=("${dest[@]}"); STEP_WEIGHT=("${w[@]}")
}

pkg_step() {
    local rc=0
    install_category "$1" || rc=$?
    return $rc
}
step_pkg_core()     { pkg_step core; }
step_pkg_audio()    { pkg_step audio; }
step_pkg_system()   { pkg_step system; }
step_pkg_media()    { pkg_step media; }
step_pkg_terminal() { pkg_step terminal; }
step_pkg_fonts()    { pkg_step fonts; }

step_fonts() {
    local rc=0
    install_fonts || true
    # JetBrains Mono and the Noto fonts come from the package list (the font packages step)
    if command -v fc-cache &>/dev/null; then
        fc-cache -f >/dev/null 2>&1 || true
    fi
    if command -v fc-list &>/dev/null && ! fc-list : family 2>/dev/null | grep -qi 'JetBrains Mono'; then
        tui_note "JetBrains Mono is not installed"
        rc=10
    else
        tui_note "fonts ready"
    fi
    return $rc
}

step_daemons() {
    install_ski
    install_audio_daemon
    install_gamma_daemon
    install_core_daemon
}

step_shell() {
    deploy_package "$PROJECT_ROOT" "$OLD_COMMIT" "$TARGET_COMMIT" "$IS_REINSTALL" "$INSTALL_STATE" "${SELECTED_COMPOSITORS[@]}"
}

step_sddm() {
    setup_sddm "$PROJECT_ROOT" "$INSTALL_STATE" "$IS_REINSTALL"
}

WP_PREFETCH_FILE=""
wallpapers_prefetch_start() {
    [ -n "$WP_PREFETCH_FILE" ] && return 0
    WP_PREFETCH_FILE=$(mktemp)
    (
        if wallpapers_sync >> "${LOGFILE:-/dev/null}" 2>&1; then echo ok; else echo fail; fi > "$WP_PREFETCH_FILE"
    ) &
}

step_wallpapers() {
    if [ -n "$WP_PREFETCH_FILE" ]; then
        local waited=0
        while [ ! -s "$WP_PREFETCH_FILE" ] && [ "$waited" -lt 600 ]; do
            sleep 0.2; waited=$(( waited + 1 ))
        done
        [ "$(cat "$WP_PREFETCH_FILE" 2>/dev/null)" = ok ] && export WALLPAPERS_SYNCED=1
    fi
    install_wallpapers "$INSTALL_FULL_WALLPAPERS"
}

step_config() {
    local wallpaper_dir
    wallpaper_dir=$(get_wallpaper_dir)
    init_serpantinum_config "$PROJECT_ROOT" "$wallpaper_dir" "$INSTALL_STATE" "$IS_REINSTALL"
    migrate_default_font
    configure_ski_defaults
}

step_terminal() {
    setup_kitty_font
}

step_qt() {
    configure_qt_environment
    tui_note "QT_QPA_PLATFORMTHEME=qt6ct"
}

step_services() {
    setup_services
    setup_brightness_service
    setup_pipewire_session
    setup_bluetooth_service
    hand_over_from_easyeffects
}

step_finish() {
    write_version_state "$TARGET_VERSION" "$TARGET_COMMIT" "$TELEMETRY_ID" "$ENABLE_TELEMETRY" "${SELECTED_COMPOSITORS[*]}" "$OPT_SDDM" "$SDDM_WAYLAND" "$INSTALL_FULL_WALLPAPERS" "$AUR_HELPER"

    if [[ "$INSTALL_STATE" == "legacy" || "$INSTALL_STATE" == "fresh" || "$IS_REINSTALL" == true ]]; then
        rm -f "$HOME/.local/state/serpantinum/first_launch.done" "$HOME/.local/state/quickshell/first_launch.done"
    fi

    if [ -f "$MODULES_DIR/telemetry.sh" ]; then
        bash "$MODULES_DIR/telemetry.sh" --mode done --version "$TARGET_VERSION" --old-version "$OLD_VERSION" --install-state "$INSTALL_STATE" --compositor "${SELECTED_COMPOSITORS[*]}" --id "$TELEMETRY_ID" --enabled "$ENABLE_TELEMETRY" --failed "${FAILED_PKGS[*]}"
    fi
}

# Classic (plain terminal) installer: numbered step headers, a result per step, a summary at the end.
# A step that fails does not stop the others; failures are listed at the end and in FAILED_STEPS.
FAILED_STEPS=()
run_steps_classic() {
    local i n=${#STEP_IDS[@]} id label rc t0 t1 cols line
    local -a res=() dur=()
    cols=$(tput cols 2>/dev/null || echo 80); (( cols > 100 )) && cols=100; (( cols < 40 )) && cols=40
    line=$(printf '%*s' "$cols" '' | tr ' ' '-')
    [ -n "${INIT_SUMMARY:-}" ] && echo -e "\e[36m[ INFO ]\e[0m ${INIT_SUMMARY}"

    for (( i = 0; i < n; i++ )); do
        id="${STEP_IDS[i]}"; label="${STEP_LABEL[i]}"
        echo -e "\n\e[36m${line}\e[0m"
        echo -e "\e[1m[$(( i + 1 ))/${n}] ${label}\e[0m  \e[2m${STEP_DEST[i]}\e[0m"
        echo -e "\e[36m${line}\e[0m"
        t0=$SECONDS; rc=0
        "step_${id}" || rc=$?
        t1=$SECONDS; dur[i]=$(( t1 - t0 ))
        case $rc in
            0)  res[i]=ok;   echo -e "\e[32m[ OK ] ${label} (${dur[i]}s)\e[0m" ;;
            10) res[i]=warn; echo -e "\e[33m[ WARN ] ${label}: finished with warnings (${dur[i]}s)\e[0m" ;;
            20) res[i]=skip; echo -e "\e[2m[ SKIP ] ${label}\e[0m" ;;
            *)  res[i]=fail; FAILED_STEPS+=("$label"); echo -e "\e[31m[ FAILED ] ${label} (exit ${rc})\e[0m" ;;
        esac
    done

    echo -e "\n\e[36m${line}\e[0m\n\e[1mSummary\e[0m"
    for (( i = 0; i < n; i++ )); do
        case ${res[i]} in
            ok)   printf '  \e[32m%-6s\e[0m %-24s %4ss\n' "ok" "${STEP_LABEL[i]}" "${dur[i]}" ;;
            warn) printf '  \e[33m%-6s\e[0m %-24s %4ss\n' "warn" "${STEP_LABEL[i]}" "${dur[i]}" ;;
            skip) printf '  \e[2m%-6s\e[0m %-24s\n' "skip" "${STEP_LABEL[i]}" ;;
            fail) printf '  \e[31m%-6s\e[0m %-24s %4ss\n' "FAILED" "${STEP_LABEL[i]}" "${dur[i]}" ;;
        esac
    done
    echo
}
