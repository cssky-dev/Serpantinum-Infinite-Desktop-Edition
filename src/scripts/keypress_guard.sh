#!/usr/bin/env bash
# One key press, one action.
#
# Every Serpantinum shortcut is a Hyprland bind that runs `serpantinum <something>`. When the same
# press reaches us twice (a bind that is registered twice, a duplicated key event, a second config
# that also sources the keybinds) a toggle opens and closes straight away, so the shortcut looks like
# it "needs two presses" or just flashes. This drops an identical command that arrives again within a
# short window, before it ever reaches the shell.
#
#   sp_guard <serpantinum args...>   returns 1 when the call is a duplicate and must be ignored
#
# Tunables: SERPANTINUM_KEY_DEBOUNCE_MS (default 250), SERPANTINUM_NO_DEBOUNCE=1 turns it off.
# Held-key shortcuts (canvas focus / zoomIn / zoomOut / panBy, volume, brightness) are never guarded,
# they are meant to repeat.
sp_guard() {
    [[ "${SERPANTINUM_NO_DEBOUNCE:-0}" == "1" ]] && return 0

    local arg
    for arg in "$@"; do
        [[ "$arg" == "-h" || "$arg" == "--help" ]] && return 0
    done

    case "$1" in
        msg)
            [[ -n "$2" ]] || return 0
            ;;
        canvas)
            case "$2" in
                ""|focus|zoomIn|zoomOut|panBy|status) return 0 ;;
            esac
            ;;
        screenshot|lock|redactor|reload) ;;
        *) return 0 ;;
    esac

    local window_ms="${SERPANTINUM_KEY_DEBOUNCE_MS:-250}"
    [[ "$window_ms" =~ ^[0-9]+$ ]] || window_ms=250

    local dir="${XDG_RUNTIME_DIR:-/tmp}/serpantinum-keys"
    mkdir -p "$dir" 2>/dev/null || return 0

    local id="$*"
    id="${id//[^A-Za-z0-9]/_}"
    local stamp="$dir/${id:0:120}"

    # Serialize concurrent identical calls: whoever takes the lock first wins, the other one sees
    # the fresh stamp. If flock is missing or fails we let the call through rather than block it.
    local fd
    exec {fd}>"$stamp.lock" 2>/dev/null || return 0
    if ! flock -w 1 "$fd" 2>/dev/null; then
        exec {fd}>&-
        return 0
    fi

    local now last=0
    if [[ -n "$EPOCHREALTIME" ]]; then
        now="${EPOCHREALTIME/[.,]/}"
    else
        now="$(( $(date +%s%N) / 1000 ))"
    fi
    [[ -r "$stamp" ]] && read -r last <"$stamp"
    [[ "$last" =~ ^[0-9]+$ ]] || last=0

    if (( now - last < window_ms * 1000 )); then
        exec {fd}>&-
        return 1
    fi

    printf '%s\n' "$now" >"$stamp" 2>/dev/null
    exec {fd}>&-
    return 0
}
