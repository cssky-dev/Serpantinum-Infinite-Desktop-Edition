#!/usr/bin/env bash
# Qt environment shared by every Quickshell process of the shell (serpantinumd and
# `serpantinum launch|ipc`). Sourced, or run directly to see what was detected:
#     bash qt_env.sh            -> prints "<zone> (<source>)" or "ok (system zone is fine)"
#
# Qt prints "Unable to determine system time zone" when it cannot map the machine to an IANA zone:
# /etc/localtime is missing, is a plain copy of a zone file, or does not point into a zoneinfo
# directory. That depends on the distribution and init system, not on the shell, so the zone is
# looked up from every place the common ones keep it and exported as TZ only when Qt needs it.
# A TZ set by the user is never touched.
#
# Sources, in this order (first hit wins):
#   1. /etc/localtime is a link into a zoneinfo directory   -> nothing to do (systemd, dinit, runit,
#                                                              openrc, s6, NixOS ... when it is set up)
#   2. timedatectl                                           (systemd)
#   3. /etc/timezone                                         (Debian, Ubuntu, Gentoo openrc, Alpine)
#   4. TIMEZONE= / ZONE= in /etc/rc.conf, /etc/conf.d/clock, /etc/sysconfig/clock,
#      /etc/sysconfig/timezone, /etc/default/timezone        (Void runit, Gentoo, RHEL, SUSE, ...)
#   5. /etc/localtime is a plain file or a link outside zoneinfo: the zoneinfo file with the same
#      content                                               (Artix dinit/s6, Slackware, Alpine, ...)
#   6. the zone saved for the weather location in the shell settings
#   7. UTC (what libc already uses when a system has no zone configured)
#
# Test overrides: SERPANTINUM_TZ_ETC (default /etc), SERPANTINUM_ZONEINFO_DIRS (colon list).

_qt_env_tz_valid() {
    local z="$1" d
    [ -n "$z" ] || return 1
    case "$z" in *..*|/*|*[[:space:]]*) return 1 ;; esac
    local IFS=:
    local dirs=0
    for d in $_QT_ENV_ZI; do
        [ -d "$d" ] || continue
        dirs=1
        [ -f "$d/$z" ] && return 0
    done
    # No zoneinfo directory to check against: accept the name as given.
    [ "$dirs" = 0 ]
}

_qt_env_conf_zone() {
    # Prints the value of TIMEZONE= or ZONE= from a shell-style config file.
    local f="$1" v
    [ -r "$f" ] || return 1
    v="$(sed -n -E 's/^[[:space:]]*(TIMEZONE|ZONE)[[:space:]]*=[[:space:]]*["'\'']?([^"'\''#[:space:]]+).*/\2/p' "$f" 2>/dev/null | head -n 1)"
    [ -n "$v" ] || return 1
    printf '%s' "$v"
}

# Prints "<zone> <source>" and returns 0 when TZ has to be set, prints nothing and returns 1 when
# the system zone is already usable by Qt.
serpantinum_detect_tz() {
    local etc="${SERPANTINUM_TZ_ETC:-/etc}"
    _QT_ENV_ZI="${SERPANTINUM_ZONEINFO_DIRS:-/usr/share/zoneinfo:/usr/share/lib/zoneinfo:/usr/lib/zoneinfo:/etc/zoneinfo:/var/db/zoneinfo}"
    local real="" z="" f d

    # 1. a link into a zoneinfo directory already works
    if [ -L "$etc/localtime" ]; then
        real="$(readlink -f "$etc/localtime" 2>/dev/null)"
        case "$real" in */zoneinfo/*) return 1 ;; esac
    elif [ -f "$etc/localtime" ]; then
        real="$etc/localtime"
    fi

    # 2. systemd
    if command -v timedatectl >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            z="$(timeout 2 timedatectl show -p Timezone --value 2>/dev/null)"
        else
            z="$(timedatectl show -p Timezone --value 2>/dev/null)"
        fi
        _qt_env_tz_valid "$z" && { printf '%s timedatectl' "$z"; return 0; }
    fi

    # 3. /etc/timezone
    if [ -r "$etc/timezone" ]; then
        z="$(head -n 1 "$etc/timezone" 2>/dev/null | tr -d '[:space:]')"
        _qt_env_tz_valid "$z" && { printf '%s /etc/timezone' "$z"; return 0; }
    fi

    # 4. distribution config files
    for f in rc.conf conf.d/clock sysconfig/clock sysconfig/timezone default/timezone; do
        z="$(_qt_env_conf_zone "$etc/$f")" || continue
        _qt_env_tz_valid "$z" && { printf '%s /etc/%s' "$z" "$f"; return 0; }
    done

    # 5. the zoneinfo file that has the same content as /etc/localtime
    if [ -n "$real" ] && [ -f "$real" ]; then
        local size
        size="$(wc -c < "$real" 2>/dev/null | tr -d '[:space:]')"
        if [ -n "$size" ]; then
            local IFS=:
            for d in $_QT_ENV_ZI; do
                [ -d "$d" ] || continue
                while IFS= read -r f; do
                    if cmp -s "$f" "$real" 2>/dev/null; then
                        printf '%s localtime-copy' "${f#"$d"/}"
                        return 0
                    fi
                done < <(find "$d" -type f -size "${size}c" \
                             ! -path '*/posix/*' ! -path '*/right/*' ! -name 'posixrules' ! -name 'localtime' \
                             ! -name '*.tab' ! -name '*.zi' ! -name 'leapseconds' ! -name 'tzdata*' 2>/dev/null | sort)
            done
        fi
    fi

    # 6. the zone detected for the weather location
    local cfg="${QS_SETTINGS:-$HOME/.config/serpantinum/settings.json}"
    if [ -r "$cfg" ]; then
        if command -v jq >/dev/null 2>&1; then
            z="$(jq -r '.general.location.timezone // empty' "$cfg" 2>/dev/null)"
        else
            z="$(grep -o '"timezone"[[:space:]]*:[[:space:]]*"[^"]*"' "$cfg" 2>/dev/null | head -n 1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')"
        fi
        _qt_env_tz_valid "$z" && { printf '%s location-setting' "$z"; return 0; }
    fi

    # 7. nothing configured: libc uses UTC here, Qt just needs to be told
    printf 'UTC fallback'
    return 0
}

serpantinum_qt_env() {
    if [ -z "${TZ-}" ]; then
        local out zone
        if out="$(serpantinum_detect_tz)"; then
            zone="${out%% *}"
            [ -n "$zone" ] && export TZ="$zone"
        fi
    fi
    # Every control draws its own background; the Basic style avoids "The current style does not
    # support customization" under a platform style. Users can override it.
    export QT_QUICK_CONTROLS_STYLE="${QT_QUICK_CONTROLS_STYLE-Basic}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if [ -n "${TZ-}" ]; then
        echo "$TZ (TZ set by you)"
    elif out="$(serpantinum_detect_tz)"; then
        echo "${out%% *} (${out#* })"
    else
        echo "ok (system zone is fine)"
    fi
fi
