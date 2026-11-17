#!/bin/sh
# Installs brightnessctl and sets up a service that saves the backlight brightness on
# shutdown and restores it on boot, for distros WITHOUT systemd.
# Supports dinit (Artix, Chimera-style), OpenRC (Artix, Gentoo, Alpine-style) and runit (Void,
# Artix). Run by the Serpantinum installer on non-systemd systems, or by hand:
#   sudo ./setup-brightness.sh

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo: sudo $0"
    exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
STATE_DIR=/var/lib/brightness

detect_init() {
    pid1="$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')"
    case "$pid1" in
        systemd) echo systemd; return ;;
        dinit) echo dinit; return ;;
        runit|runit-init) echo runit; return ;;
        s6-svscan|s6-linux-init*) echo s6; return ;;
    esac
    if [ -d /run/openrc ] || command -v openrc-init >/dev/null 2>&1; then echo openrc
    elif [ -d /run/runit ] || [ -d /etc/runit ]; then echo runit
    elif command -v dinitctl >/dev/null 2>&1 || [ -d /etc/dinit.d ]; then echo dinit
    elif [ -d /run/systemd/system ]; then echo systemd
    else echo unknown
    fi
}

install_brightnessctl() {
    if command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm brightnessctl
    elif command -v xbps-install >/dev/null 2>&1; then
        xbps-install -Sy brightnessctl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y brightnessctl
    elif command -v emerge >/dev/null 2>&1; then
        emerge --ask=n --noreplace app-misc/brightnessctl
    elif command -v apk >/dev/null 2>&1; then
        apk add brightnessctl
    else
        echo "    Warning: no known package manager, install brightnessctl manually."
    fi
}

INIT_SYSTEM="$(detect_init)"
if [ "$INIT_SYSTEM" = systemd ]; then
    echo "systemd detected: systemd-backlight already saves and restores brightness. Nothing to do."
    exit 0
fi

echo "==> Init system: $INIT_SYSTEM"

echo "==> Installing brightnessctl"
install_brightnessctl

echo "==> Adding $TARGET_USER to the video group"
usermod -aG video "$TARGET_USER"

echo "==> Creating state directory"
mkdir -p "$STATE_DIR"
chown "$TARGET_USER" "$STATE_DIR"

echo "==> Writing save/restore scripts"
cat > /usr/local/bin/brightness-save << 'EOF2'
#!/bin/sh
mkdir -p /var/lib/brightness
level="$(brightnessctl -c backlight get 2>/dev/null)" || exit 0
[ -n "$level" ] && echo "$level" > /var/lib/brightness/level
exit 0
EOF2

cat > /usr/local/bin/brightness-restore << 'EOF2'
#!/bin/sh
[ -s /var/lib/brightness/level ] && brightnessctl -c backlight set "$(cat /var/lib/brightness/level)"
exit 0
EOF2

chmod +x /usr/local/bin/brightness-save /usr/local/bin/brightness-restore

echo "==> Writing $INIT_SYSTEM service"
case "$INIT_SYSTEM" in
    dinit)
        if [ -f /etc/dinit.d/udevd ]; then
            DEPENDS="depends-on = udevd"
        else
            echo "    Warning: /etc/dinit.d/udevd not found, skipping depends-on."
            echo "    Check 'ls /etc/dinit.d' and add the right udev service name manually."
            DEPENDS=""
        fi

        cat > /etc/dinit.d/brightness << EOF2
type = scripted
command = /usr/local/bin/brightness-restore
stop-command = /usr/local/bin/brightness-save
$DEPENDS
restart = false
EOF2

        echo "==> Enabling and starting service"
        dinitctl enable brightness
        dinitctl start brightness || true
        ;;

    openrc)
        cat > /etc/init.d/brightness << 'EOF2'
#!/sbin/openrc-run
description="Restore the backlight brightness on boot and save it on shutdown"

depend() {
    need localmount
    after udev dev
}

start() {
    ebegin "Restoring brightness"
    /usr/local/bin/brightness-restore
    eend 0
}

stop() {
    ebegin "Saving brightness"
    /usr/local/bin/brightness-save
    eend 0
}
EOF2
        chmod +x /etc/init.d/brightness

        echo "==> Enabling and starting service"
        rc-update add brightness default
        rc-service brightness start || true
        ;;

    runit)
        mkdir -p /etc/sv/brightness
        cat > /etc/sv/brightness/run << 'EOF2'
#!/bin/sh
exec 2>&1
/usr/local/bin/brightness-restore
# Stay up so that `finish` runs on shutdown.
exec sleep 2147483647
EOF2
        cat > /etc/sv/brightness/finish << 'EOF2'
#!/bin/sh
/usr/local/bin/brightness-save
EOF2
        chmod +x /etc/sv/brightness/run /etc/sv/brightness/finish

        echo "==> Enabling and starting service"
        if [ -d /var/service ]; then
            SVDIR_LINK=/var/service
        elif [ -d /run/runit/service ]; then
            SVDIR_LINK=/run/runit/service
        elif [ -d /etc/runit/runsvdir/default ]; then
            SVDIR_LINK=/etc/runit/runsvdir/default
        else
            SVDIR_LINK=""
        fi
        if [ -n "$SVDIR_LINK" ]; then
            ln -sf /etc/sv/brightness "$SVDIR_LINK/brightness"
        else
            echo "    Warning: could not find the runit service directory."
            echo "    Link it yourself: ln -s /etc/sv/brightness <your service dir>/"
        fi
        ;;

    *)
        echo "    Warning: no brightness service for '$INIT_SYSTEM' yet."
        echo "    brightnessctl is installed. Call /usr/local/bin/brightness-restore on boot and"
        echo "    /usr/local/bin/brightness-save on shutdown from your init system."
        ;;
esac

# Save the current level right away so the file exists
/usr/local/bin/brightness-save

echo
if [ -s "$STATE_DIR/level" ]; then
    echo "Done. Current saved level: $(cat "$STATE_DIR/level")"
else
    echo "Done. No backlight device found, so there is no level to save yet."
fi
echo "Log out and back in for the video group change to apply."
