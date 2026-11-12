#!/usr/bin/env bash
# Shared IPC helper for every script a keybind runs.
#
# A bare `quickshell ipc call ...` fails (and the callers throw the error away) whenever the shell
# is not ready to answer yet: it was just (re)started by `serpantinum`, it is still loading its
# windows, or the `main` / `lock` / `redactor` target is not registered yet. For a keybind that
# means "the first press does nothing and the second one works". This waits for the shell for up
# to ~3 s and only retries on those "not ready" errors, never on a real error from the handler,
# so a toggle can never fire twice.
#
#   qs_ipc_call <target> <function> [args...]
qs_ipc_call() {
    local qml="${MAIN_QML:-}"
    local tries=0 max="${QS_IPC_TRIES:-30}" out rc
    local -a base=(quickshell)
    [ -n "$qml" ] && base+=(-p "$qml")

    while :; do
        out="$("${base[@]}" ipc call "$@" 2>&1)"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            [ -n "$out" ] && printf '%s\n' "$out"
            return 0
        fi
        tries=$((tries + 1))
        if [ "$tries" -ge "$max" ] || ! [[ "$out" =~ ([Nn]o\ (running\ )?instance|[Cc]ould\ not\ (connect|find)|[Cc]onnection\ refused|[Ff]ailed\ to\ connect|[Nn]o\ such\ file|[Tt]arget) ]]; then
            [ -n "$out" ] && printf '%s\n' "$out" >&2
            return "$rc"
        fi
        sleep 0.1
    done
}
