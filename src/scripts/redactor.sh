#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
qs_ensure_cache "widgets"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/ipc.sh"

TARGET_MON="${1:-}"
SELECTED_ID="${2:-}"

if [ -n "$TARGET_MON" ] && [ -n "$SELECTED_ID" ]; then
    qs_ipc_call redactor open "$TARGET_MON" "$SELECTED_ID"
elif [ -n "$TARGET_MON" ]; then
    qs_ipc_call redactor open "$TARGET_MON" ""
else
    qs_ipc_call redactor activate
fi
