#!/usr/bin/env bash
# Clipboard history recorder that does not depend on any init system or compositor autostart.
#
#   clipboard_watch.sh ensure   start `wl-paste --watch cliphist store` for text and images
#                               when they are not running yet (default)
#   clipboard_watch.sh stop     stop the recorders this script started
#   clipboard_watch.sh status   exit 0 when both recorders run
#
# The compositor configs (Hyprland, Sway, niri, mango) already start the same two commands, but
# that is the only place that does. On systems without systemd (OpenRC, runit, dinit, s6, ...)
# a config that was not deployed by the installer, a different compositor, or a session that
# starts late all end in an empty clipboard history. `serpantinumd start` and the clipboard
# window call `ensure`, so the history is recorded wherever the shell runs.
# Recorders that the compositor already started are detected and left alone.

CW_QUIET="${CW_QUIET:-true}"

cw_log() { [ "$CW_QUIET" = true ] || echo -e "$@"; }

cw_runtime_dir() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        if [ -d "/run/user/$(id -u)" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        else
            export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
            mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
        fi
    fi
}

cw_pidfile() { echo "${XDG_RUNTIME_DIR}/serpantinum-clipboard.pids"; }

# Wayland socket of the running session. WAYLAND_DISPLAY is missing when this runs from an
# init-system service instead of the compositor, so look for the socket ourselves.
cw_find_display() {
    local sock
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        case "$WAYLAND_DISPLAY" in
            /*) [ -S "$WAYLAND_DISPLAY" ] && return 0 ;;
            *)  [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && return 0 ;;
        esac
    fi
    for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
        [ -S "$sock" ] || continue
        export WAYLAND_DISPLAY="${sock##*/}"
        return 0
    done
    return 1
}

cw_wait_display() {
    local i
    for i in $(seq 1 60); do
        cw_find_display && return 0
        sleep 0.25
    done
    return 1
}

# Is a recorder for this mime type ("text" or "image") already running for this user?
cw_running() {
    local kind="$1" pid args
    for pid in $(pgrep -u "$(id -u)" -x wl-paste 2>/dev/null); do
        args="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
        case "$args" in
            *"--type $kind"*"--watch"*"cliphist"*"store"*) return 0 ;;
            *"-t $kind"*"--watch"*"cliphist"*"store"*) return 0 ;;
        esac
    done
    return 1
}

cw_start() {
    local kind="$1" pid
    cw_running "$kind" && return 0
    # wl-paste --watch ends when the compositor goes away, so it never outlives the session.
    # setsid keeps it out of the process group of whoever called this script.
    if setsid -f wl-paste --type "$kind" --watch cliphist store >/dev/null 2>&1 </dev/null; then
        :
    else
        ( setsid wl-paste --type "$kind" --watch cliphist store >/dev/null 2>&1 </dev/null & )
    fi
    sleep 0.2
    pid="$(pgrep -u "$(id -u)" -n -x wl-paste 2>/dev/null)"
    [ -n "$pid" ] && echo "$pid" >> "$(cw_pidfile)"
    cw_running "$kind"
}

cw_ensure() {
    cw_runtime_dir
    if ! command -v wl-paste >/dev/null 2>&1; then
        cw_log "  wl-paste is missing, install wl-clipboard for the clipboard history"
        return 1
    fi
    if ! command -v cliphist >/dev/null 2>&1; then
        cw_log "  cliphist is missing, install it for the clipboard history"
        return 1
    fi

    # Nothing to do when both recorders already run (started by the compositor config or by us).
    if cw_running text && cw_running image; then
        cw_log "  clipboard history is already being recorded"
        return 0
    fi

    if ! cw_wait_display; then
        cw_log "  no Wayland session found, clipboard history not started"
        return 1
    fi

    cw_start text
    cw_start image
    if cw_running text; then
        cw_log "  clipboard history is recording"
        return 0
    fi
    cw_log "  could not start the clipboard recorder"
    return 1
}

cw_stop() {
    cw_runtime_dir
    local file pid
    file="$(cw_pidfile)"
    [ -f "$file" ] || return 0
    while read -r pid; do
        [ -n "$pid" ] || continue
        # Only wl-paste processes, never a pid that was reused by something else.
        if [ "$(tr -d '\0' < "/proc/$pid/comm" 2>/dev/null)" = "wl-paste" ]; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done < "$file"
    rm -f "$file"
}

cw_status() {
    cw_runtime_dir
    cw_running text && cw_running image
}

case "${1:-ensure}" in
    ensure) cw_ensure ;;
    stop)   cw_stop ;;
    status) cw_status ;;
    *)      echo "usage: ${0##*/} ensure|stop|status" >&2; exit 2 ;;
esac
