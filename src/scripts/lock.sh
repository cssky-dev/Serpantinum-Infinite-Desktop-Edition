#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
qs_ensure_cache "lock"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/ipc.sh"

case "$1" in
    --static) action="activateStatic" ;;
    --reauth) action="restartAuth" ;;
    *) action="activate" ;;
esac

qs_ipc_call lock "$action"
