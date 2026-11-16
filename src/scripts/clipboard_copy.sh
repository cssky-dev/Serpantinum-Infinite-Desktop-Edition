#!/usr/bin/env bash
# Put one clipboard history entry back on the clipboard.
#
#   clipboard_copy.sh <id> [--pin <cache-dir>]
#
# Replaces the old inline `cliphist decode | wl-copy` one-liner. It sets the right mime type for
# images (wl-copy only guesses it, and without `file` it falls back to text), works the same on
# every init system and compositor, and only re-pins the new entry when a new entry really
# appeared. When the recorder is not running nothing new shows up in cliphist, and pinning
# "the newest entry" would have pinned an unrelated clip.

id="$1"
shift

case "$id" in
    ''|*[!0-9]*) echo "clipboard_copy: invalid id" >&2; exit 2 ;;
esac

command -v cliphist >/dev/null 2>&1 || { echo "clipboard_copy: cliphist is missing" >&2; exit 1; }
command -v wl-copy >/dev/null 2>&1 || { echo "clipboard_copy: wl-copy is missing (wl-clipboard)" >&2; exit 1; }

pin=false
cache_dir=""
if [ "$1" = "--pin" ]; then
    pin=true
    cache_dir="$2"
fi

head_id() { cliphist list 2>/dev/null | head -n 1 | awk '{print $1}'; }

old_head=""
$pin && old_head="$(head_id)"

tmp="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/serpantinum-clip.XXXXXX")" || exit 1
trap 'rm -f "$tmp"' EXIT

cliphist decode "$id" > "$tmp" 2>/dev/null || exit 1
[ -s "$tmp" ] || exit 1

mime=""
if command -v file >/dev/null 2>&1; then
    mime="$(file --brief --mime-type "$tmp" 2>/dev/null)"
fi

# wl-copy reads all of stdin before it forks into the background, so removing the file after is safe.
case "$mime" in
    image/*) wl-copy --type "$mime" < "$tmp" ;;
    *)       wl-copy < "$tmp" ;;
esac || exit 1

if $pin && [ -n "$cache_dir" ] && command -v serpantinum-core >/dev/null 2>&1; then
    for _ in 1 2 3 4 5 6 7 8; do
        sleep 0.15
        new_head="$(head_id)"
        if [ -n "$new_head" ] && [ "$new_head" != "$old_head" ]; then
            serpantinum-core clipboard pin "$new_head" --cache-dir "$cache_dir"
            break
        fi
    done
fi
exit 0
