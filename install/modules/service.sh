#!/usr/bin/env bash

detect_init_system() {
    if [[ -d /run/systemd/system ]] || command -v systemctl &>/dev/null; then
        echo "systemd"
    elif command -v openrc-init &>/dev/null || [[ -d /run/openrc ]]; then
        echo "openrc"
    elif command -v dinit &>/dev/null || [[ -d /etc/dinit.d ]]; then
        echo "dinit"
    elif command -v runit &>/dev/null || [[ -d /run/runit ]]; then
        echo "runit"
    elif command -v s6-svscan &>/dev/null; then
        echo "s6"
    else
        echo "generic"
    fi
}

enable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl enable --now "$svc.service" 2>/dev/null || sudo systemctl enable -f "$svc.service" 2>/dev/null || sudo systemctl enable "$svc.service" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-update add "$svc" default 2>/dev/null || true
            sudo rc-service "$svc" start 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl enable "$svc" 2>/dev/null || sudo dinitctl start "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -d "/etc/sv/$svc" ]; then
                sudo ln -sf "/etc/sv/$svc" /var/service/ 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b add default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

disable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl disable --now "$svc.service" 2>/dev/null || sudo systemctl disable "$svc.service" 2>/dev/null || sudo systemctl disable "$svc" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-service "$svc" stop 2>/dev/null || true
            sudo rc-update del "$svc" default 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl stop "$svc" 2>/dev/null || true
            sudo dinitctl disable "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -L "/var/service/$svc" ] || [ -d "/var/service/$svc" ]; then
                sudo rm -f "/var/service/$svc" 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b del default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

enable_user_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable --now "$svc.service" 2>/dev/null || systemctl --user enable "$svc.service" 2>/dev/null || true
            ;;
        dinit)
            dinitctl --user enable "$svc" 2>/dev/null || dinitctl --user start "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

setup_services() {
    local init_sys
    init_sys=$(detect_init_system)

    if declare -f pm_setup_services >/dev/null; then
        pm_setup_services "$init_sys"
        return 0
    fi

    if [[ "$init_sys" == "systemd" ]]; then
        systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
        systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
    fi

    enable_system_service "NetworkManager" "$init_sys"
    enable_system_service "power-profiles-daemon" "$init_sys"
}

# Without systemd nothing restores the backlight level at boot: install brightnessctl and a
# save-on-shutdown / restore-on-boot service for the running init system (dinit, OpenRC, runit).
setup_brightness_service() {
    local init_sys script
    init_sys=$(detect_init_system)
    [ "$init_sys" = "systemd" ] && return 0

    script="${INSTALL_DIR:-}/setup-brightness.sh"
    if [ ! -f "$script" ]; then
        echo -e "\e[33m[ WARN ]\e[0m setup-brightness.sh not found, skipping the brightness service"
        return 0
    fi

    echo -e "\n\e[36m[ INFO ]\e[0m No systemd ($init_sys): setting up brightness save/restore"
    if sudo sh "$script"; then
        echo -e "\e[32m[ OK ] brightness service ready\e[0m"
    else
        echo -e "\e[33m[ WARN ]\e[0m setup-brightness.sh failed, run it by hand: sudo sh $script"
    fi
}

# Without systemd there are no pipewire user units. Make sure pipewire, wireplumber and
# pipewire-pulse run so that pavucontrol sees PipeWire, and fix what stops it. `serpantinumd
# start` repeats this at every login.
setup_pipewire_session() {
    local init_sys helper
    init_sys=$(detect_init_system)
    [ "$init_sys" = "systemd" ] && return 0

    helper="${SERPANTINUM_DIR:-}/scripts/pipewire_session.sh"
    [ -f "$helper" ] || return 0

    echo -e "\n\e[36m[ INFO ]\e[0m No systemd ($init_sys): checking that PipeWire works with pavucontrol"

    # Without logind there is nobody to hand out access to the sound card
    if ! command -v loginctl &>/dev/null && ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx audio; then
        sudo usermod -aG audio "$USER" 2>/dev/null || true
    fi

    if bash "$helper" ensure; then
        echo -e "\e[32m[ OK ] PipeWire works\e[0m"
    else
        echo -e "\e[33m[ WARN ]\e[0m PipeWire is not answering yet. Log out and back in; Serpantinum starts it at login."
    fi
}

# Shown (and logged) before anything is installed: which init system runs, and what that means.
# systemd needs nothing extra. Without systemd the installer adds the brightness service
# (setup-brightness.sh), a PipeWire session for audio and Bluetooth, and starts the login screen.
init_precheck() {
    local init_sys
    init_sys=$(detect_init_system)
    INIT_SYSTEM="$init_sys"
    if [ "$init_sys" = "systemd" ]; then
        INIT_SUMMARY="systemd detected: nothing extra is needed"
        INIT_NONSYSTEMD=false
    else
        INIT_SUMMARY="no systemd (${init_sys}): brightness service, audio and Bluetooth session will be set up"
        INIT_NONSYSTEMD=true
    fi
    export INIT_SYSTEM INIT_SUMMARY INIT_NONSYSTEMD
    if [ -n "${LOGFILE:-}" ]; then printf 'init system: %s -> %s\n' "$init_sys" "$INIT_SUMMARY" >> "$LOGFILE"; fi
}

# Bluetooth without systemd: the daemon has to be enabled in the running init system.
setup_bluetooth_service() {
    local init_sys
    init_sys=$(detect_init_system)
    [ "$init_sys" = "systemd" ] && return 0
    local svc
    for svc in bluetooth bluetoothd; do
        case "$init_sys" in
            openrc) [ -x "/etc/init.d/$svc" ] || continue ;;
            runit)  [ -d "/etc/sv/$svc" ] || continue ;;
            dinit)  [ -f "/etc/dinit.d/$svc" ] || continue ;;
        esac
        enable_system_service "$svc" "$init_sys"
        echo -e "\e[32m[ OK ] bluetooth service ($svc) enabled\e[0m"
        return 0
    done
}

# Without systemd the login screen is started right here, once everything else is installed.
start_display_manager_now() {
    [ "${OPT_SDDM:-}" = true ] || return 0
    local init_sys
    init_sys=$(detect_init_system)
    [ "$init_sys" = "systemd" ] && return 0   # systemd already started it (enable --now)

    local svc=sddm
    [ "$init_sys" = openrc ] && [ -x /etc/init.d/display-manager ] && svc=display-manager
    echo -e "\n\e[36m[ INFO ]\e[0m Starting the login screen ($svc, $init_sys)"
    case "$init_sys" in
        openrc) sudo rc-service "$svc" start 2>/dev/null || sudo rc-service sddm start 2>/dev/null ;;
        dinit)  sudo dinitctl start sddm 2>/dev/null ;;
        runit)
            [ -d /etc/sv/sddm ] || return 0
            [ -e /var/service/sddm ] || sudo ln -sf /etc/sv/sddm /var/service/ 2>/dev/null
            sleep 1
            sudo sv up sddm 2>/dev/null || sudo sv start sddm 2>/dev/null
            ;;
        s6)     sudo s6-rc -u change sddm 2>/dev/null ;;
        *)      return 0 ;;
    esac
    local rc=$?
    if [ $rc -eq 0 ]; then echo -e "\e[32m[ OK ] login screen started\e[0m"
    else echo -e "\e[33m[ WARN ]\e[0m could not start the login screen, reboot to get it"; fi
    return 0
}
