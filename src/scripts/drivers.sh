#!/usr/bin/env bash
# Serpantinum driver helper.
#   drivers.sh detect            JSON describing CPU, GPUs and what is installed
#   drivers.sh install <target>  install the minimal packages (target: intel | amd | nvidia | cpu | all)
#   drivers.sh install-terminal <target>   same, inside a terminal window (asks for sudo there)
#
# Minimal on purpose: Mesa + the Vulkan/VA-API driver of the GPU, and the CPU microcode.
# No control panels, no OpenCL / CUDA stacks, no 32-bit libraries.

set -u

pm_name() {
    if command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v xbps-install >/dev/null 2>&1; then echo xbps
    elif command -v emerge >/dev/null 2>&1; then echo portage
    else echo unknown; fi
}
PM="$(pm_name)"

pkg_installed() {
    case "$PM" in
        pacman) pacman -Qq "$1" >/dev/null 2>&1 ;;
        dnf) rpm -q "$1" >/dev/null 2>&1 ;;
        xbps) xbps-query "$1" >/dev/null 2>&1 ;;
        portage) command -v qlist >/dev/null 2>&1 && qlist -I "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

cpu_vendor() {
    case "$(awk -F': *' '/^vendor_id/{print $2; exit}' /proc/cpuinfo 2>/dev/null)" in
        GenuineIntel) echo intel ;;
        AuthenticAMD) echo amd ;;
        *) echo unknown ;;
    esac
}

# Package list for a target on the running package manager
packages_for() {
    local target="$1"
    case "$PM:$target" in
        pacman:intel)  echo "mesa vulkan-intel intel-media-driver" ;;
        pacman:amd)    echo "mesa vulkan-radeon libva-mesa-driver" ;;
        pacman:nvidia)
            if pacman -Qq linux >/dev/null 2>&1; then echo "nvidia-open nvidia-utils"
            else echo "nvidia-open-dkms nvidia-utils"; fi ;;
        pacman:cpu)
            [ "$(cpu_vendor)" = intel ] && echo "intel-ucode"
            [ "$(cpu_vendor)" = amd ] && echo "amd-ucode" ;;

        dnf:intel)     echo "mesa-dri-drivers mesa-vulkan-drivers intel-media-driver" ;;
        dnf:amd)       echo "mesa-dri-drivers mesa-vulkan-drivers linux-firmware" ;;
        dnf:nvidia)    echo "akmod-nvidia" ;;
        dnf:cpu)
            [ "$(cpu_vendor)" = intel ] && echo "microcode_ctl"
            [ "$(cpu_vendor)" = amd ] && echo "amd-ucode-firmware" ;;

        xbps:intel)    echo "mesa-dri vulkan-loader mesa-vulkan-intel intel-media-driver" ;;
        xbps:amd)      echo "mesa-dri vulkan-loader mesa-vulkan-radeon linux-firmware-amd" ;;
        xbps:nvidia)   echo "nvidia" ;;
        xbps:cpu)
            [ "$(cpu_vendor)" = intel ] && echo "intel-ucode"
            [ "$(cpu_vendor)" = amd ] && echo "linux-firmware-amd" ;;

        portage:intel) echo "media-libs/mesa" ;;
        portage:amd)   echo "media-libs/mesa sys-kernel/linux-firmware" ;;
        portage:nvidia) echo "x11-drivers/nvidia-drivers" ;;
        portage:cpu)
            [ "$(cpu_vendor)" = intel ] && echo "sys-firmware/intel-microcode"
            [ "$(cpu_vendor)" = amd ] && echo "sys-kernel/linux-firmware" ;;
        *) echo "" ;;
    esac
}


target_installed() {
    local pkgs p
    pkgs="$(packages_for "$1")"
    [ -n "$pkgs" ] || return 1
    for p in $pkgs; do
        if [ "$PM" = portage ]; then
            command -v qlist >/dev/null 2>&1 && qlist -I "$p" >/dev/null 2>&1 || return 1
        else
            pkg_installed "$p" || return 1
        fi
    done
    return 0
}

detect_gpus() {
    command -v lspci >/dev/null 2>&1 || return 0
    lspci -nn 2>/dev/null | grep -Ei 'vga compatible|3d controller|display controller' | while IFS= read -r line; do
        local vendor="other" name id
        case "$line" in
            *"[8086:"*) vendor=intel ;;
            *"[1002:"*) vendor=amd ;;
            *"[10de:"*) vendor=nvidia ;;
        esac
        name="${line#*: }"
        name="$(printf '%s' "$name" | sed -E 's/ \[[0-9a-f]{4}:[0-9a-f]{4}\]//; s/ \(rev [0-9a-f]+\)//')"
        printf '%s\t%s\n' "$vendor" "$name"
    done
}

cmd_detect() {
    local gpus_json="[]" vendor name
    while IFS=$'\t' read -r vendor name; do
        [ -n "$vendor" ] || continue
        local ok=false
        [ "$vendor" != other ] && target_installed "$vendor" && ok=true
        gpus_json="$(jq -c --arg v "$vendor" --arg n "$name" --argjson ok "$ok" --arg p "$(packages_for "$vendor")" \
            '. + [{vendor:$v, name:$n, installed:$ok, packages:($p|split(" ")|map(select(length>0)))}]' <<< "$gpus_json")"
    done < <(detect_gpus)

    local cv cok=false
    cv="$(cpu_vendor)"
    [ "$cv" != unknown ] && target_installed cpu && cok=true

    local nv_loaded=false
    [ -d /sys/module/nvidia ] && nv_loaded=true

    jq -nc \
        --arg pm "$PM" \
        --arg cpu_name "$(awk -F': *' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null)" \
        --arg cpu_vendor "$cv" \
        --argjson cpu_installed "$cok" \
        --arg cpu_pkgs "$(packages_for cpu)" \
        --argjson nvidia_loaded "$nv_loaded" \
        --argjson gpus "$gpus_json" \
        '{pm:$pm, cpu:{name:$cpu_name, vendor:$cpu_vendor, installed:$cpu_installed, packages:($cpu_pkgs|split(" ")|map(select(length>0)))}, nvidia_module_loaded:$nvidia_loaded, gpus:$gpus}'
}

install_pkgs() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -gt 0 ] || { echo "Nothing to install for this system."; return 0; }
    echo ":: ${PM}: ${pkgs[*]}"
    case "$PM" in
        pacman) sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
        dnf)    sudo dnf install -y "${pkgs[@]}" ;;
        xbps)   sudo xbps-install -Sy "${pkgs[@]}" ;;
        portage) sudo emerge --ask=n --noreplace "${pkgs[@]}" ;;
        *) echo "Unsupported package manager."; return 1 ;;
    esac
}

cmd_install() {
    local target="${1:-}" pkgs=() t
    case "$target" in
        intel|amd|nvidia|cpu) ;;
        all) ;;
        *) echo "usage: drivers.sh install intel|amd|nvidia|cpu|all" >&2; return 2 ;;
    esac
    if [ "$target" = all ]; then
        while IFS=$'\t' read -r vendor _; do
            case "$vendor" in intel|amd|nvidia) for t in $(packages_for "$vendor"); do pkgs+=("$t"); done ;; esac
        done < <(detect_gpus)
        for t in $(packages_for cpu); do pkgs+=("$t"); done
    else
        for t in $(packages_for "$target"); do pkgs+=("$t"); done
    fi
    # duplicates out
    mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | awk 'NF && !seen[$0]++')

    if [ "$PM" = dnf ] && [ "$target" = nvidia ] && ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        echo "The NVIDIA driver on Fedora comes from RPM Fusion (nonfree)."
        echo "Enable it first: https://rpmfusion.org/Configuration"
        return 1
    fi

    install_pkgs "${pkgs[@]}"
    local rc=$?
    if [ $rc -eq 0 ]; then
        echo
        echo "Done. Reboot to load the new driver / microcode."
    fi
    return $rc
}

cmd_install_terminal() {
    local target="${1:-all}" self term
    self="$(readlink -f "${BASH_SOURCE[0]}")"
    for term in kitty foot alacritty xterm; do
        command -v "$term" >/dev/null 2>&1 || continue
        case "$term" in
            kitty)     exec kitty --class serpantinum-drivers --title "Serpantinum drivers" bash -c "\"$self\" install $target; echo; read -rp 'Press Enter to close' _" ;;
            foot)      exec foot --title "Serpantinum drivers" bash -c "\"$self\" install $target; echo; read -rp 'Press Enter to close' _" ;;
            alacritty) exec alacritty --title "Serpantinum drivers" -e bash -c "\"$self\" install $target; echo; read -rp 'Press Enter to close' _" ;;
            xterm)     exec xterm -T "Serpantinum drivers" -e bash -c "\"$self\" install $target; echo; read -rp 'Press Enter to close' _" ;;
        esac
    done
    echo "No terminal found" >&2
    return 1
}

case "${1:-}" in
    detect) cmd_detect ;;
    install) shift; cmd_install "$@" ;;
    install-terminal) shift; cmd_install_terminal "$@" ;;
    *) echo "usage: drivers.sh detect | install <intel|amd|nvidia|cpu|all> | install-terminal <target>" >&2; exit 2 ;;
esac
