#!/usr/bin/env bash
# qs-mem.sh - where does Quickshell's RAM go?
# Run it while btop shows ~619MB:   bash qs-mem.sh
# Then paste the whole output back to Claude.

pid="$(pgrep -f 'quickshell.*(Shell|Bar)\.qml' | head -n1)"
[ -z "$pid" ] && pid="$(pgrep -x quickshell | head -n1)"
[ -z "$pid" ] && { echo "quickshell is not running"; exit 1; }

echo "== quickshell pid $pid =="
grep -E 'VmRSS|RssAnon|RssFile|RssShmem|Threads' "/proc/$pid/status"
echo
echo "(RssAnon = heap/QML/JS/textures in RAM, RssFile = mapped libs/fonts, RssShmem = wayland shm buffers)"

echo
echo "== top mappings by resident size (MB) =="
awk '
  /^[0-9a-f]+-[0-9a-f]+ / { name = ($6 == "" ? "[anon]" : $6) }
  /^Rss:/ { rss[name] += $2 }
  END { for (n in rss) printf "%8.1f  %s\n", rss[n] / 1024, n }
' "/proc/$pid/smaps" | sort -rn | head -n 15

echo
echo "== layer-shell surfaces (each fullscreen one holds screen-sized buffers) =="
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl layers 2>/dev/null | grep -E 'Layer level|namespace' | sed 's/^\s*//'
else
  echo "hyprctl not found"
fi

echo
echo "== child processes of quickshell =="
ps --ppid "$pid" -o pid,rss,comm 2>/dev/null | awk 'NR==1 || $2 > 5000'
