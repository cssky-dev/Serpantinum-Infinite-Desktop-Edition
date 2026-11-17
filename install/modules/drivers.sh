#!/usr/bin/env bash
# Drivers in the installer: detect the GPUs and CPU, let the person pick, install the minimal set
# through src/scripts/drivers.sh (Mesa + Vulkan / VA-API, CPU microcode, NVIDIA driver).

DRIVER_TARGETS=()      # selected targets: intel amd nvidia cpu
DRV_KEYS=(); DRV_LABEL=(); DRV_DETAIL=(); DRV_DONE=()
DRV_DETECTED=false

drivers_script() { echo "${SERPANTINUM_DIR:-}/scripts/drivers.sh"; }

drivers_detect() {
    DRV_KEYS=(); DRV_LABEL=(); DRV_DETAIL=(); DRV_DONE=()
    DRV_DETECTED=true
    local script json
    script="$(drivers_script)"
    [ -f "$script" ] && command -v jq >/dev/null 2>&1 || return 0
    json="$(bash "$script" detect 2>/dev/null)" || return 0
    [ -n "$json" ] || return 0

    local vendor name inst title seen=" "
    while IFS=$'\t' read -r vendor name inst; do
        [ -n "$vendor" ] || continue
        case "$vendor" in intel|amd|nvidia) ;; *) continue ;; esac
        [[ "$seen" == *" $vendor "* ]] && continue
        seen+="$vendor "
        case "$vendor" in intel) title=Intel ;; amd) title=AMD ;; nvidia) title=NVIDIA ;; esac
        DRV_KEYS+=("$vendor"); DRV_LABEL+=("$title graphics"); DRV_DETAIL+=("$name"); DRV_DONE+=("$inst")
    done < <(jq -r '.gpus[] | [.vendor, .name, (.installed|tostring)] | @tsv' <<< "$json")

    local cv cname cinst
    cv="$(jq -r '.cpu.vendor' <<< "$json")"
    cname="$(jq -r '.cpu.name' <<< "$json")"
    cinst="$(jq -r '.cpu.installed|tostring' <<< "$json")"
    if [ "$cv" = intel ] || [ "$cv" = amd ]; then
        DRV_KEYS+=("cpu"); DRV_LABEL+=("CPU microcode"); DRV_DETAIL+=("$cname"); DRV_DONE+=("$cinst")
    fi
}

drivers_selected() { local t; for t in "${DRIVER_TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done; return 1; }

drivers_toggle() {
    local key="$1" t new=()
    if drivers_selected "$key"; then
        for t in "${DRIVER_TARGETS[@]}"; do [ "$t" = "$key" ] || new+=("$t"); done
        DRIVER_TARGETS=("${new[@]}")
    else
        DRIVER_TARGETS+=("$key")
    fi
}

drivers_summary() {
    if [ ${#DRIVER_TARGETS[@]} -eq 0 ]; then echo "none"; else (IFS=,; echo "${DRIVER_TARGETS[*]}"); fi
}

# --drivers=auto|intel,amd,nvidia,cpu|none  (classic installer and scripts)
drivers_from_arg() {
    local arg="$1" t
    case "$arg" in
        none|"") DRIVER_TARGETS=() ;;
        auto)
            drivers_detect
            DRIVER_TARGETS=()
            for t in "${!DRV_KEYS[@]}"; do [ "${DRV_DONE[t]}" = true ] || DRIVER_TARGETS+=("${DRV_KEYS[t]}"); done
            ;;
        *) IFS=, read -ra DRIVER_TARGETS <<< "$arg" ;;
    esac
}

step_drivers() {
    if [ ${#DRIVER_TARGETS[@]} -eq 0 ]; then
        tui_note "no drivers selected"
        return 20
    fi
    local t failed=() rc script
    script="$(drivers_script)"
    [ -f "$script" ] || { tui_note "drivers.sh not found"; return 10; }
    for t in "${DRIVER_TARGETS[@]}"; do
        echo -e "\n\e[36m[ INFO ]\e[0m driver: $t"
        if bash "$script" install "$t"; then
            echo -e "\e[32m[ OK ] $t\e[0m"
        else
            echo -e "\e[31m[ FAILED ] $t\e[0m"; failed+=("$t")
        fi
    done
    if [ ${#failed[@]} -gt 0 ]; then
        tui_note "not installed: ${failed[*]}"
        return 10
    fi
    tui_note "installed: ${DRIVER_TARGETS[*]} (reboot to load)"
}
