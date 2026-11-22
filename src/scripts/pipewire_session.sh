#!/usr/bin/env bash
# PipeWire for sessions without systemd user units (OpenRC, runit, dinit, s6, ...).
#
#   pipewire_session.sh ensure   start pipewire, wireplumber and pipewire-pulse when they are
#                                not running, and fix what keeps pavucontrol from seeing them
#   pipewire_session.sh check    only report; exit 0 when pavucontrol will see PipeWire
#
# With systemd the user units do all of this, so it exits without doing anything there.
# Used by the installer and by `serpantinumd start`.

PW_QUIET="${PW_QUIET:-false}"

pw_log() { [ "$PW_QUIET" = true ] || echo -e "$@"; }

pw_has_systemd() {
    [ -d /run/systemd/system ]
}

pw_running() {
    pgrep -u "$(id -u)" -x "$1" >/dev/null 2>&1
}

pw_runtime_dir() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        if [ -d "/run/user/$(id -u)" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        else
            export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
            mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
        fi
    fi
}

# What pavucontrol (and every PulseAudio client) asks: "Server Name: ... on PipeWire x.y.z"
pw_pulse_is_pipewire() {
    command -v pactl >/dev/null 2>&1 || return 1
    pactl info 2>/dev/null | grep -qi 'pipewire'
}

pw_has_sink() {
    [ -n "$(pactl list short sinks 2>/dev/null | head -n 1)" ]
}

# A real PulseAudio daemon owns the socket pipewire-pulse needs, so pavucontrol would talk to it.
pw_stop_pulseaudio() {
    pgrep -u "$(id -u)" -x pulseaudio >/dev/null 2>&1 || return 0
    pw_log "  stopping PulseAudio, it conflicts with pipewire-pulse"
    pulseaudio --kill >/dev/null 2>&1 || true
    pkill -u "$(id -u)" -x pulseaudio >/dev/null 2>&1 || true
    sleep 0.3
}

pw_start() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 || return 1
    pw_running "$name" && return 0
    setsid -f "$name" >/dev/null 2>&1 </dev/null || { "$name" >/dev/null 2>&1 </dev/null & }
}

pw_wait_for_pulse() {
    local i
    for i in $(seq 1 40); do
        pw_pulse_is_pipewire && return 0
        sleep 0.25
    done
    return 1
}

pw_check() {
    pw_has_systemd && return 0
    pw_runtime_dir
    pw_running pipewire && pw_running wireplumber && pw_pulse_is_pipewire
}

pw_ensure() {
    pw_has_systemd && return 0
    pw_runtime_dir

    if pw_check && pw_has_sink; then
        pw_log "  PipeWire is already running and pavucontrol sees it"
        return 0
    fi

    pw_stop_pulseaudio

    # Order matters: the graph first, then the session manager, then the Pulse socket.
    if ! command -v pipewire >/dev/null 2>&1; then
        pw_log "  pipewire is not installed"
        return 1
    fi
    pw_start pipewire
    sleep 0.5
    pw_start wireplumber || pw_log "  wireplumber is missing, install it so devices show up"
    pw_start pipewire-pulse || pw_log "  pipewire-pulse is missing, pavucontrol needs it"

    if pw_wait_for_pulse; then
        # wireplumber needs a moment to create the sinks
        local i
        for i in 1 2 3 4 5 6; do pw_has_sink && break; sleep 0.5; done
        if pw_has_sink; then
            pw_log "  PipeWire works: pavucontrol sees it and an output device is available"
        else
            pw_log "  PipeWire answers, but there is no output device. Is your user in the audio group?"
        fi
        return 0
    fi

    pw_log "  pavucontrol still does not see PipeWire (pactl info has no PipeWire server)"
    return 1
}

case "${1:-}" in
    ensure) pw_ensure ;;
    check)  pw_check ;;
    "")     : ;;
    *)      echo "usage: ${0##*/} ensure|check" >&2; exit 2 ;;
esac
