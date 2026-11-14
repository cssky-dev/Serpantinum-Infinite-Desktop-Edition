#!/usr/bin/env bash

# Gentoo / Portage backend.
#
# Package specs in PM_PKG_MAP are Portage atoms. Alternatives are separated by
# "|" and the first one that exists in an enabled repository wins. An atom may
# carry a :slot or [use] dependency. Packages that are not in ::gentoo are
# looked up in GURU, which is enabled only when something needs it.

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig xz)

PM_EXTRA_PKGS=(
    jetbrains-mono fontawesome xdg-user-dirs xdg-utils xwayland-satellite xwayland
    dbus polkit xdg-desktop-portal
)
PM_SDDM_EXTRA_PKGS=()
PM_SDDM_CURSOR_FIX=true
PM_AUDIO_BUILD_PKGS=(gcc make pkg-config pipewire)

# Wayland greeter only when there is no Xorg to fall back on.
if command -v Xorg &>/dev/null || command -v X &>/dev/null; then
    PM_SDDM_WAYLAND_DEFAULT=false
else
    PM_SDDM_WAYLAND_DEFAULT=true
fi

GENTOO_VDB="${GENTOO_VDB:-/var/db/pkg}"
GENTOO_USE_FILE="/etc/portage/package.use/serpantinum"
GENTOO_SDDM_SESSION_WRAPPER="/usr/local/share/serpantinum/sddm-wayland-session"

declare -A PM_PKG_MAP=(
    [fzf]="app-shells/fzf"
    [jq]="app-misc/jq"
    [curl]="net-misc/curl"
    [git]="dev-vcs/git"
    [pciutils]="sys-apps/pciutils"
    [unzip]="app-arch/unzip"
    [fontconfig]="media-libs/fontconfig"
    [xz]="app-arch/xz-utils"
    [kitty]="x11-terms/kitty"
    [zbar]="media-gfx/zbar"
    [tesseract]="app-text/tesseract"
    [tesseract-data-eng]="app-text/tessdata_fast|app-text/tessdata_best"
    [wl-clipboard]="gui-apps/wl-clipboard"
    [qt6-multimedia]="dev-qt/qtmultimedia:6"
    [cliphist]="gui-apps/cliphist|app-misc/cliphist"
    [ddcutil]="app-misc/ddcutil"
    [bluez]="net-wireless/bluez"
    [networkmanager]="net-misc/networkmanager"
    [pipewire]="media-video/pipewire"
    [wireplumber]="media-video/wireplumber"
    [pipewire-pulse]="media-video/pipewire[sound-server]"
    [pipewire-alsa]="media-video/pipewire[pipewire-alsa]"
    [libpulse]="media-libs/libpulse"
    [python]="dev-lang/python"
    [imagemagick]="media-gfx/imagemagick"
    [file]="sys-apps/file"
    [ffmpeg]="media-video/ffmpeg"
    [fastfetch]="app-misc/fastfetch"
    [quickshell]="gui-apps/quickshell"
    [grim]="gui-apps/grim"
    [playerctl]="media-sound/playerctl"
    [satty]="gui-apps/satty"
    [xdg-desktop-portal-gtk]="sys-apps/xdg-desktop-portal-gtk"
    [power-profiles-daemon]="sys-power/power-profiles-daemon"
    [qt6-wayland]="dev-qt/qtwayland:6"
    [qt6ct]="gui-apps/qt6ct"
    [qt5ct]="gui-apps/qt5ct"
    [adwaita-icon-theme]="x11-themes/adwaita-icon-theme"
    [gpu-screen-recorder]="media-video/gpu-screen-recorder|gui-apps/gpu-screen-recorder"
    [wf-recorder]="gui-apps/wf-recorder"
    [adw-gtk-theme]="x11-themes/adw-gtk3|x11-themes/adw-gtk-theme"
    [hyprland]="gui-wm/hyprland"
    [niri]="gui-wm/niri"
    [sway]="gui-wm/sway"
    [mangowm]="gui-wm/mangowc|gui-wm/mangowm"
    [sddm]="x11-misc/sddm"
    [weston]="dev-libs/weston"
    [qt6-declarative]="dev-qt/qtdeclarative:6"
    [qt6-svg]="dev-qt/qtsvg:6"
    [jetbrains-mono]="media-fonts/jetbrains-mono"
    [fontawesome]="media-fonts/fontawesome"
    [xdg-user-dirs]="x11-misc/xdg-user-dirs"
    [xdg-utils]="x11-misc/xdg-utils"
    [xwayland-satellite]="gui-apps/xwayland-satellite"
    [xwayland]="x11-base/xwayland"
    [dbus]="sys-apps/dbus"
    [polkit]="sys-auth/polkit"
    [xdg-desktop-portal]="sys-apps/xdg-desktop-portal"
    [gcc]="sys-devel/gcc"
    [make]="dev-build/make|sys-devel/make"
    [pkg-config]="virtual/pkgconfig"
    [gdm]="gnome-base/gdm"
    [lightdm]="x11-misc/lightdm"
    [lxdm]="lxde-base/lxdm"
    [greetd]="gui-libs/greetd"
)

# A binary on PATH counts as installed (source builds, ~/.local/bin).
declare -A PM_BIN_MAP=(
    [quickshell]="quickshell"
    [satty]="satty"
    [cliphist]="cliphist"
    [gpu-screen-recorder]="gpu-screen-recorder"
    [xwayland-satellite]="xwayland-satellite"
    [hyprland]="Hyprland"
    [niri]="niri"
    [sway]="sway"
    [mangowm]="mango"
)

# Installed from a release tarball, always.
declare -A PM_RELEASE_MAP=(
    [matugen]="https://github.com/InioX/matugen/releases/download/v4.2.0/matugen-4.2.0-x86_64.tar.gz"
)

# Installed from a release tarball only when no ebuild can be found.
declare -A PM_RELEASE_FALLBACK=(
    [satty]="https://github.com/gabm/Satty/releases/latest/download/satty-x86_64-unknown-linux-gnu.tar.gz"
    [adw-gtk-theme]="lassekongo83/adw-gtk3"
)

PM_MATUGEN_MIN_MAJOR=4
PM_MATUGEN_REPO="InioX/matugen"

GENTOO_REPO_NAMES=()
GENTOO_REPO_PATHS=()
GENTOO_REPOS_LOADED=0

# Gentoo has no sudo by default. When it is missing, ask for the root password
# once (su) and keep a small root helper running for the length of the
# installation. A "sudo" shim placed first in PATH sends every privileged
# command to it, so no further prompts appear. The helper only accepts requests
# from this user, through a directory only this user can open, and exits when
# the installer does.
gentoo_root_helper_script() {
    cat <<'HELPER'
#!/bin/bash
D="$1"; U="$2"; P="$3"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ "$4" != "loop" ]; then
    setsid nohup bash "$0" "$D" "$U" "$P" loop >/dev/null 2>&1 < /dev/null &
    echo $! > "$D/pid"
    exit 0
fi
exec 3<>"$D/req"
while [ -d "/proc/$P" ]; do
    read -r -t 2 -u 3 id || continue
    [ "$id" = quit ] && break
    f="$D/r.$id"
    [ -f "$f" ] && [ "$(stat -c %u "$f")" = "$U" ] || continue
    cmd=""
    . "$f"
    ( eval "$cmd" ) <"$f.in" >"$f.out" 2>"$f.err"
    echo $? > "$D/r.$id.done"
done
rm -rf "$D"
HELPER
}

gentoo_sudo_shim_script() {
    cat <<'SHIM'
#!/bin/bash
D="@DIR@"
pid="$(cat "$D/pid" 2>/dev/null)"
if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
    echo "sudo: the root session has ended; run the installer again" >&2
    exit 1
fi
while [ $# -gt 0 ]; do
    case "$1" in
        -p|-u|-g) shift 2 ;;
        --) shift; break ;;
        -*) shift ;;
        *) break ;;
    esac
done
[ $# -gt 0 ] || exit 0
id="$$.$RANDOM"
f="$D/r.$id"
printf 'cmd=%q\n' "$(printf '%q ' "$@")" > "$f"
mkfifo "$f.in" "$f.out" "$f.err" "$f.done"
echo "$id" > "$D/req"
cat < "$f.out" &
po=$!
cat < "$f.err" >&2 &
pe=$!
if [ -t 0 ]; then
    : > "$f.in" &
else
    cat <&0 > "$f.in" &
fi
pi=$!
read -r rc < "$f.done"
wait "$po" "$pe"
kill "$pi" 2>/dev/null
rm -f "$f" "$f.in" "$f.out" "$f.err" "$f.done"
exit "${rc:-1}"
SHIM
}

gentoo_start_root_session() {
    local dir
    dir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/serpantinum-root.XXXXXX")" || return 1
    chmod 700 "$dir"
    mkfifo "$dir/req"
    mkdir -p "$dir/bin"
    gentoo_root_helper_script > "$dir/helper.sh"
    gentoo_sudo_shim_script | sed "s|@DIR@|$dir|" > "$dir/bin/sudo"
    chmod 700 "$dir/helper.sh"
    chmod 755 "$dir/bin/sudo"
    echo -e "\e[36m[ INFO ]\e[0m sudo was not found. Enter the root password to continue (asked once)."
    if ! su root -c "bash '$dir/helper.sh' '$dir' '$(id -u)' '$$'"; then
        rm -rf "$dir"
        return 1
    fi
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$dir/pid" ] && break
        sleep 0.2
    done
    [ -s "$dir/pid" ] || { rm -rf "$dir"; return 1; }
    export PATH="$dir/bin:$PATH"
}

if [ -n "${SERPANTINUM_INSTALLER:-}" ] && [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
    if ! command -v su &>/dev/null || ! gentoo_start_root_session; then
        echo -e "\e[31m[ ERROR ]\e[0m Could not get root access. Check the root password, or install sudo (as root: emerge --ask app-admin/sudo)." >&2
        exit 1
    fi
fi

pm_supports_os() {
    [ -f /etc/os-release ] || return 1
    local id like
    id=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    like=$(awk -F= '/^ID_LIKE=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    case " $id $like " in
        *" gentoo "*) return 0 ;;
    esac
    return 1
}

pm_resolve_name() {
    echo "${PM_PKG_MAP[$1]:-$1}"
}

# ---------------------------------------------------------------- atoms ----

gentoo_atom_base() {
    local a="${1%%\[*}"
    a="${a%%:*}"
    echo "$a"
}

gentoo_atom_installed() {
    local atom="$1" base cat name
    base="$(gentoo_atom_base "$atom")"
    [[ "$base" == */* ]] || return 1
    if [[ "$atom" == *[\[:]* ]]; then
        command -v portageq &>/dev/null || return 1
        portageq has_version / "$atom" 2>/dev/null
        return
    fi
    cat="${base%%/*}"
    name="${base##*/}"
    compgen -G "$GENTOO_VDB/$cat/$name-[0-9]*" >/dev/null
}

gentoo_spec_installed() {
    local alt
    while IFS= read -r alt; do
        [ -n "$alt" ] || continue
        gentoo_atom_installed "$alt" && return 0
    done < <(tr '|' '\n' <<< "$1")
    return 1
}

gentoo_bin_installed() {
    local bin="${PM_BIN_MAP[$1]:-}"
    [ -n "$bin" ] || return 1
    command -v "$bin" &>/dev/null || [ -x "$HOME/.local/bin/$bin" ]
}

gentoo_release_installed() {
    case "$1" in
        adw-gtk-theme)
            local dir
            for dir in /usr/share/themes "${XDG_DATA_HOME:-$HOME/.local/share}/themes" "$HOME/.themes"; do
                [ -d "$dir/adw-gtk3" ] && return 0
            done
            return 1
            ;;
        satty|matugen)
            command -v "$1" &>/dev/null || [ -x "$HOME/.local/bin/$1" ]
            ;;
        *)
            return 1
            ;;
    esac
}

pm_is_installed() {
    local pkg="$1"
    if [ "$pkg" = "matugen" ]; then
        pm_matugen_ok
        return
    fi
    gentoo_spec_installed "$(pm_resolve_name "$pkg")" && return 0
    gentoo_bin_installed "$pkg"
}

pm_missing_pkgs() {
    local pkg
    for pkg in "$@"; do
        if [ "$pkg" = "matugen" ]; then
            pm_matugen_ok || echo "$pkg"
            continue
        fi
        if gentoo_spec_installed "$(pm_resolve_name "$pkg")"; then
            continue
        fi
        if gentoo_bin_installed "$pkg"; then
            continue
        fi
        if [ -n "${PM_RELEASE_FALLBACK[$pkg]:-}" ] && gentoo_release_installed "$pkg"; then
            continue
        fi
        echo "$pkg"
    done
}

# -------------------------------------------------------------- repos ------

gentoo_load_repos() {
    local force="${1:-0}" repo path
    [ "$force" = 1 ] || [ "$GENTOO_REPOS_LOADED" = 0 ] || return 0
    GENTOO_REPO_NAMES=()
    GENTOO_REPO_PATHS=()
    if command -v portageq &>/dev/null; then
        for repo in $(portageq get_repos / 2>/dev/null); do
            path="$(portageq get_repo_path / "$repo" 2>/dev/null)"
            [ -d "$path" ] || continue
            GENTOO_REPO_NAMES+=("$repo")
            GENTOO_REPO_PATHS+=("$path")
        done
    else
        for path in /var/db/repos/*/; do
            [ -d "$path" ] || continue
            GENTOO_REPO_NAMES+=("$(basename "$path")")
            GENTOO_REPO_PATHS+=("${path%/}")
        done
    fi
    GENTOO_REPOS_LOADED=1
}

gentoo_repo_has() {
    local base="$1" path
    for path in "${GENTOO_REPO_PATHS[@]}"; do
        [ -d "$path/$base" ] && return 0
    done
    return 1
}

gentoo_repo_enabled() {
    local name
    for name in "${GENTOO_REPO_NAMES[@]}"; do
        [ "$name" = "$1" ] && return 0
    done
    return 1
}

# First alternative of a package whose category/name exists in an enabled repo.
# Reads the repo cache, so call gentoo_load_repos in the parent shell first.
gentoo_pick_atom() {
    local spec alt
    spec="$(pm_resolve_name "$1")"
    while IFS= read -r alt; do
        [ -n "$alt" ] || continue
        if gentoo_repo_has "$(gentoo_atom_base "$alt")"; then
            echo "$alt"
            return 0
        fi
    done < <(tr '|' '\n' <<< "$spec")
    return 1
}

gentoo_enable_guru() {
    gentoo_load_repos
    gentoo_repo_enabled guru && return 0

    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.deps.enabling_repo" "repo=guru")"
    if [ ! -f /usr/share/eselect/modules/repository.eselect ]; then
        gentoo_emerge app-eselect/eselect-repository || return 1
    fi
    sudo eselect repository enable guru || return 1
    sudo emaint sync -r guru || return 1
    gentoo_load_repos 1
    gentoo_repo_enabled guru
}

# ------------------------------------------------------------ emerge -------

gentoo_emerge_base_opts() {
    printf '%s\n' --ask=n --quiet-build=y --autounmask=y --autounmask-continue=y
}

# Autounmask writes keyword / USE / license changes under /etc/portage. They
# can land as ._cfg files, so merge pending ones in that directory only.
gentoo_merge_portage_config() {
    command -v etc-update &>/dev/null || return 0
    sudo etc-update --automode -5 /etc/portage >/dev/null 2>&1 || true
}

gentoo_emerge() {
    local opts rc
    mapfile -t opts < <(gentoo_emerge_base_opts)
    gentoo_seed_use
    sudo emerge "${opts[@]}" --noreplace "$@"
    rc=$?
    gentoo_merge_portage_config
    return "$rc"
}

gentoo_emerge_update() {
    local opts rc
    mapfile -t opts < <(gentoo_emerge_base_opts)
    sudo emerge "${opts[@]}" --update "$@"
    rc=$?
    gentoo_merge_portage_config
    return "$rc"
}

# USE flags Serpantinum needs from PipeWire (pulse server and ALSA routing).
gentoo_seed_use() {
    local line="media-video/pipewire sound-server pipewire-alsa bluetooth"
    if [ -d /etc/portage/package.use ]; then
        [ -f "$GENTOO_USE_FILE" ] && return 0
        printf '# Added by the Serpantinum installer\n%s\n' "$line" | sudo tee "$GENTOO_USE_FILE" >/dev/null
    elif [ -f /etc/portage/package.use ]; then
        grep -qF "$line" /etc/portage/package.use 2>/dev/null && return 0
        printf '\n# Added by the Serpantinum installer\n%s\n' "$line" | sudo tee -a /etc/portage/package.use >/dev/null
    else
        sudo mkdir -p /etc/portage/package.use || return 0
        printf '# Added by the Serpantinum installer\n%s\n' "$line" | sudo tee "$GENTOO_USE_FILE" >/dev/null
    fi
}

# --------------------------------------------------- pm interface ---------

pm_prepare_repos() {
    true
}

pm_bootstrap_install() {
    local names=() tool atom
    for tool in "$@"; do
        atom="$(pm_resolve_name "$tool" | cut -d'|' -f1)"
        gentoo_atom_installed "$atom" && continue
        names+=("$atom")
    done
    [ ${#names[@]} -gt 0 ] || return 0
    gentoo_emerge "${names[@]}"
}

pm_bootstrap_helper() {
    true
}

# Only refreshes the Portage tree. A world upgrade on Gentoo can take hours and
# rebuild half the system, so it is left to the user.
pm_full_upgrade() {
    local gentoo_path stamp
    echo -e "\n\e[36m[ INFO ]\e[0m Synchronizing the Portage tree..."
    gentoo_path="$(portageq get_repo_path / gentoo 2>/dev/null)"
    stamp="${gentoo_path:-/var/db/repos/gentoo}/metadata/timestamp.chk"
    if [ -n "$(find "$stamp" -mmin -1440 2>/dev/null)" ]; then
        echo -e "\e[32m  The Portage tree was synced within the last day\e[0m"
        return 0
    fi
    sudo emerge --sync --quiet || sudo emerge-webrsync || true
    GENTOO_REPOS_LOADED=0
}

# ---------------------------------------------------- release binaries -----

pm_install_release_binary() {
    local url="$1" binary="$2"
    local bin_dir="$HOME/.local/bin"
    local tmp found
    [ "$(uname -m)" = "x86_64" ] || return 1
    tmp="$(mktemp -d)"
    mkdir -p "$bin_dir"
    if curl -fsSL --connect-timeout 15 --retry 3 "$url" -o "$tmp/pkg.tar.gz" && tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"; then
        found="$(find "$tmp" -type f -name "$binary" | head -n 1)"
        if [ -n "$found" ]; then
            install -m 0755 "$found" "$bin_dir/$binary"
            rm -rf "$tmp"
            return 0
        fi
    fi
    rm -rf "$tmp"
    return 1
}

pm_github_asset_url() {
    local repo="$1" pattern="$2"
    curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | jq -r --arg re "$pattern" '[.assets[] | select(.name | test($re))][0].browser_download_url // empty' 2>/dev/null
}

pm_matugen_major() {
    local bin="$1" ver
    [ -x "$bin" ] || return 1
    ver="$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)"
    [ -n "$ver" ] || return 1
    echo "${ver%%.*}"
}

pm_matugen_ok() {
    local bin major
    for bin in "$HOME/.local/bin/matugen" "$(command -v matugen 2>/dev/null)"; do
        [ -n "$bin" ] || continue
        major="$(pm_matugen_major "$bin")" || continue
        [ "$major" -ge "$PM_MATUGEN_MIN_MAJOR" ] && return 0
    done
    return 1
}

pm_matugen_release_url() {
    local url
    url="$(curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/$PM_MATUGEN_REPO/releases/latest" 2>/dev/null \
        | jq -r '[.assets[] | select(.name | test("x86_64\\.tar\\.gz$"))][0].browser_download_url // empty' 2>/dev/null)"
    echo "${url:-${PM_RELEASE_MAP[matugen]}}"
}

pm_install_matugen() {
    pm_install_release_binary "$(pm_matugen_release_url)" matugen || return 1
    pm_matugen_ok
}

gentoo_install_adw_gtk_release() {
    local repo="${PM_RELEASE_FALLBACK[adw-gtk-theme]}" url tmp status=1
    url="$(pm_github_asset_url "$repo" '\.tar\.xz$')"
    [ -n "$url" ] || return 1
    tmp="$(mktemp -d)"
    if curl -fsSL --connect-timeout 15 --retry 3 "$url" -o "$tmp/${url##*/}"; then
        mkdir -p "$tmp/out"
        if tar -xJf "$tmp/${url##*/}" -C "$tmp/out" && [ -d "$tmp/out/adw-gtk3" ]; then
            sudo mkdir -p /usr/share/themes \
                && sudo cp -r "$tmp/out/." /usr/share/themes/ \
                && sudo chmod -R a+rX /usr/share/themes/adw-gtk3* \
                && status=0
        fi
    fi
    rm -rf "$tmp"
    return "$status"
}

gentoo_install_fallback() {
    case "$1" in
        satty) pm_install_release_binary "${PM_RELEASE_FALLBACK[satty]}" satty ;;
        adw-gtk-theme) gentoo_install_adw_gtk_release ;;
        *) return 1 ;;
    esac
}

# ----------------------------------------------------------- installs ------

pm_install_batch() {
    PM_BATCH_LEFT=("$@")
    local batch=() atoms=() rest=() pkg atom
    gentoo_load_repos
    for pkg in "$@"; do
        if [ -n "${PM_RELEASE_MAP[$pkg]:-}" ]; then
            rest+=("$pkg")
            continue
        fi
        if atom="$(gentoo_pick_atom "$pkg")" && [ -n "$atom" ]; then
            batch+=("$pkg")
            atoms+=("$atom")
        else
            rest+=("$pkg")
        fi
    done
    [ ${#atoms[@]} -gt 0 ] || return 0
    if gentoo_emerge --keep-going "${atoms[@]}"; then
        for pkg in "${batch[@]}"; do
            echo -e "\n\e[32m[ OK ] $(t "installer.deps.install_ok" "pkg=$pkg")\e[0m"
        done
        PM_BATCH_LEFT=("${rest[@]}")
    fi
}

pm_install_pkg() {
    local pkg="$1" atom=""

    if [ "$pkg" = "matugen" ]; then
        pm_install_matugen
        return
    fi

    gentoo_load_repos
    atom="$(gentoo_pick_atom "$pkg")" || atom=""
    if [ -z "$atom" ] && gentoo_enable_guru; then
        atom="$(gentoo_pick_atom "$pkg")" || atom=""
    fi

    if [ -z "$atom" ]; then
        if [ -n "${PM_RELEASE_FALLBACK[$pkg]:-}" ]; then
            gentoo_install_fallback "$pkg"
            return
        fi
        return 1
    fi

    if gentoo_emerge "$atom"; then
        return 0
    fi
    if [ -n "${PM_RELEASE_FALLBACK[$pkg]:-}" ]; then
        gentoo_install_fallback "$pkg"
        return
    fi
    return 1
}

pm_remove_pkg() {
    true
}

pm_remove_conflicting_pkg() {
    true
}

pm_upgrade_quickshell() {
    local atom path live=""
    gentoo_load_repos
    atom="$(gentoo_pick_atom quickshell)" || atom=""
    if [ -z "$atom" ] && gentoo_enable_guru; then
        atom="$(gentoo_pick_atom quickshell)" || atom=""
    fi
    [ -n "$atom" ] || return 0

    gentoo_emerge_update "$atom" || true
    quickshell_is_current && return 0

    for path in "${GENTOO_REPO_PATHS[@]}"; do
        if [ -f "$path/gui-apps/quickshell/quickshell-9999.ebuild" ]; then
            live="=gui-apps/quickshell-9999"
            break
        fi
    done
    [ -n "$live" ] && { gentoo_emerge_update "$live" || true; }
    return 0
}

# ---------------------------------------------------------- services -------

gentoo_openrc_add() {
    local svc="$1" level="${2:-default}"
    [ -e "/etc/init.d/$svc" ] || return 0
    sudo rc-update add "$svc" "$level" 2>/dev/null || true
}

gentoo_netifrc_active() {
    command -v rc-update &>/dev/null || return 1
    rc-update show default 2>/dev/null | grep -qE '^[[:space:]]*net\.[a-z0-9]+'
}

# Display managers run through one init script, selected in its conf.d file.
gentoo_openrc_display_manager() {
    local svc="$1" init conf
    if [ -e /etc/init.d/display-manager ]; then
        init="display-manager"
    elif [ -e /etc/init.d/xdm ]; then
        init="xdm"
    else
        init="display-manager"
    fi
    conf="/etc/conf.d/$init"
    sudo mkdir -p /etc/conf.d
    if sudo grep -q '^DISPLAYMANAGER=' "$conf" 2>/dev/null; then
        sudo sed -i "s|^DISPLAYMANAGER=.*|DISPLAYMANAGER=\"$svc\"|" "$conf"
    else
        printf 'DISPLAYMANAGER="%s"\n' "$svc" | sudo tee -a "$conf" >/dev/null
    fi
    # Enabled for the next boot only: starting it now would take over the screen.
    gentoo_openrc_add "$init" default
}

pm_enable_display_manager() {
    local svc="$1" init_sys="$2"
    case "$init_sys" in
        systemd)
            sudo systemctl enable --force "$svc.service" 2>/dev/null || true
            ;;
        openrc)
            gentoo_openrc_display_manager "$svc"
            ;;
        *)
            enable_system_service "$svc" "$init_sys"
            ;;
    esac
}

pm_disable_display_manager() {
    local svc="$1" init_sys="$2"
    case "$init_sys" in
        systemd)
            sudo systemctl disable "$svc.service" 2>/dev/null || true
            ;;
        openrc)
            # Replaced when sddm is written to the display-manager conf.d file.
            true
            ;;
        *)
            disable_system_service "$svc" "$init_sys"
            ;;
    esac
}

pm_setup_services() {
    local init_sys="$1"
    case "$init_sys" in
        systemd)
            systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
            systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
            enable_system_service "bluetooth" "$init_sys"
            enable_system_service "NetworkManager" "$init_sys"
            enable_system_service "power-profiles-daemon" "$init_sys"
            ;;
        openrc)
            gentoo_openrc_add elogind boot
            gentoo_openrc_add dbus default
            gentoo_openrc_add bluetooth default
            if gentoo_netifrc_active; then
                echo -e "\e[33m[ WARN ]\e[0m netifrc (net.*) services are enabled, so NetworkManager was not added to the default runlevel. Switch over when you are ready: rc-update del net.<iface> default && rc-update add NetworkManager default"
            else
                gentoo_openrc_add NetworkManager default
            fi
            gentoo_openrc_add power-profiles-daemon default
            ;;
        *)
            enable_system_service "NetworkManager" "$init_sys"
            enable_system_service "power-profiles-daemon" "$init_sys"
            ;;
    esac
}

# Without systemd there are no user units, so sessions started from SDDM get
# their D-Bus session bus and PipeWire from this wrapper.
pm_configure_sddm_session() {
    local conf="$1"
    local default_cmd="/usr/share/sddm/scripts/wayland-session"

    if declare -f detect_init_system >/dev/null && [ "$(detect_init_system)" = "systemd" ]; then
        return 0
    fi

    sudo mkdir -p "$(dirname "$GENTOO_SDDM_SESSION_WRAPPER")" || return 0
    sudo tee "$GENTOO_SDDM_SESSION_WRAPPER" >/dev/null <<EOF
#!/bin/sh
if [ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session "\$0" "\$@"
fi
if ! pgrep -u "\$(id -u)" -x pipewire >/dev/null 2>&1; then
    if command -v gentoo-pipewire-launcher >/dev/null 2>&1; then
        gentoo-pipewire-launcher restart >/dev/null 2>&1 &
    elif command -v pipewire >/dev/null 2>&1; then
        pipewire >/dev/null 2>&1 &
        command -v wireplumber >/dev/null 2>&1 && wireplumber >/dev/null 2>&1 &
        command -v pipewire-pulse >/dev/null 2>&1 && pipewire-pulse >/dev/null 2>&1 &
    fi
fi
if [ -x $default_cmd ]; then
    exec $default_cmd "\$@"
fi
exec "\$@"
EOF
    sudo chmod 755 "$GENTOO_SDDM_SESSION_WRAPPER"

    if grep -q '^\[Wayland\]' "$conf"; then
        sudo sed -i "/^\[Wayland\]/a SessionCommand=$GENTOO_SDDM_SESSION_WRAPPER" "$conf"
    else
        printf '\n[Wayland]\nSessionCommand=%s\n' "$GENTOO_SDDM_SESSION_WRAPPER" | sudo tee -a "$conf" >/dev/null
    fi
}
