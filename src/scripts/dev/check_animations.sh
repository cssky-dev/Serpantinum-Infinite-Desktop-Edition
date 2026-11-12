#!/usr/bin/env bash
# Static guard against animations silently going missing again (run before releasing).
# Usage: bash src/scripts/dev/check_animations.sh [path to src/quickshell]
set -u
QS="${1:-$(cd "$(dirname "$0")/../../quickshell" && pwd)}"
fail=0
check() { # description, file, pattern
    if ! grep -q -- "$3" "$QS/$2" 2>/dev/null; then
        echo "FAIL  $1  ($2 is missing: $3)"
        fail=1
    else
        echo "ok    $1"
    fi
}
forbid() { # description, file, pattern
    if grep -q -- "$3" "$QS/$2" 2>/dev/null; then
        echo "FAIL  $1  ($2 still has: $3)"
        fail=1
    else
        echo "ok    $1"
    fi
}

check  "SpringProgress has the opening watchdog"        reusables/behavior/SpringProgress.qml "property Timer kick"
check  "SpringProgress opens through startOpening()"    reusables/behavior/SpringProgress.qml "function startOpening"
if grep -A4 "Component.onCompleted" "$QS/reusables/behavior/SpringProgress.qml" | grep -q "value = 1.0"; then
    echo "FAIL  SpringProgress jumps to its end value on creation"
    fail=1
else
    echo "ok    SpringProgress does not jump on creation"
fi
check  "Launcher entrance watchdog"                     launcher/Launcher.qml "id: introGuard"
check  "Guide entrance watchdog"                        guide/GuidePopup.qml "id: introGuard"
check  "Bar intro watchdog"                             bar/Bar.qml "barWindowRoot.introClock = 1.0"
check  "Wallpaper intro watchdog"                       wallpaper/WallpaperEngine.qml "barWindow.startupFade = 1.0"
check  "Padlock desktop fade in wallpaper mode"         lock/PadlockScreen.qml "id: desktopFade"
check  "Popwave ring starts from the frozen desktop"    lock/PopwaveScreen.qml "introFreezePath"

# every SpringProgress must be bound to an open state
for f in $(grep -rl "SpringProgress {" "$QS" --include=*.qml); do
    n=$(grep -c "SpringProgress {" "$f")
    o=$(grep -A6 "SpringProgress {" "$f" | grep -c "open:")
    if [ "$n" -ne "$o" ]; then
        echo "FAIL  SpringProgress without open: binding in ${f#$QS/}"
        fail=1
    fi
done
[ "$fail" -eq 0 ] && echo "All animation guards in place." || echo "Animation guard check failed."
exit "$fail"
