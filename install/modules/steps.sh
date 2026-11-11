#!/usr/bin/env bash
# =============================================================================
#  Install / update pipeline, split into steps.
#  The card UI (tui.sh) runs each step in a background subshell and shows the
#  progress; the classic text installer just calls them one after another.
#  Return codes:  0 ok  ·  10 done with a warning  ·  20 skipped  ·  other = failed
# =============================================================================

STEP_IDS=(prepare packages daemons shell sddm wallpapers config services finish)
STEP_LABEL=("System snapshot" "Packages" "Daemons" "Shell files" "Login screen" "Wallpapers" "Configuration" "Services" "Finishing up")
STEP_DEST=("backup and migration" "dependencies" "ski, audio, gamma, core" "~/.local/share/serpantinum" "SDDM theme" "wallpaper pack" "~/.config/serpantinum" "init services" "version state")
STEP_WEIGHT=(1 10 6 3 2 3 1 1 1)

# A one-line result for the final screen (no-op outside the card UI)
if ! declare -f tui_note >/dev/null; then tui_note() { :; }; fi

step_prepare() {
    if [ "$ENABLE_TELEMETRY" = true ] && [ -f "$MODULES_DIR/telemetry.sh" ]; then
        bash "$MODULES_DIR/telemetry.sh" --mode init --version "$TARGET_VERSION" --id "$TELEMETRY_ID" --enabled "$ENABLE_TELEMETRY"
    fi

    if [[ "$INSTALL_STATE" == "legacy" ]]; then
        migrate_legacy "${SELECTED_COMPOSITORS[@]}"
        tui_note "legacy setup migrated"
    elif [[ "$INSTALL_STATE" == "fresh" || "$IS_REINSTALL" == true ]]; then
        backup_compositors "${SELECTED_COMPOSITORS[@]}"
        tui_note "compositor configs backed up"
    fi
}

step_packages() {
    install_dependencies "$INSTALL_STATE" "$IS_REINSTALL" "${SELECTED_COMPOSITORS[@]}"
    if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
        tui_note "${#FAILED_PKGS[@]} not installed: ${FAILED_PKGS[*]}"
        return 10
    fi
}

step_daemons() {
    install_ski
    install_audio_daemon
    install_gamma_daemon
    install_core_daemon
}

step_shell() {
    deploy_package "$PROJECT_ROOT" "$OLD_COMMIT" "$TARGET_COMMIT" "$IS_REINSTALL" "$INSTALL_STATE" "${SELECTED_COMPOSITORS[@]}"
}

step_sddm() {
    setup_sddm "$PROJECT_ROOT" "$INSTALL_STATE" "$IS_REINSTALL"
}

# The wallpaper repository is downloaded in the background while packages install
WP_PREFETCH_FILE=""
wallpapers_prefetch_start() {
    [ -n "$WP_PREFETCH_FILE" ] && return 0
    WP_PREFETCH_FILE=$(mktemp)
    (
        if wallpapers_sync >> "${LOGFILE:-/dev/null}" 2>&1; then echo ok; else echo fail; fi > "$WP_PREFETCH_FILE"
    ) &
}

step_wallpapers() {
    if [ -n "$WP_PREFETCH_FILE" ]; then
        local waited=0
        while [ ! -s "$WP_PREFETCH_FILE" ] && [ "$waited" -lt 600 ]; do
            sleep 0.2; waited=$(( waited + 1 ))
        done
        [ "$(cat "$WP_PREFETCH_FILE" 2>/dev/null)" = ok ] && export WALLPAPERS_SYNCED=1
    fi
    install_wallpapers "$INSTALL_FULL_WALLPAPERS"
}

step_config() {
    local wallpaper_dir
    wallpaper_dir=$(get_wallpaper_dir)
    init_serpantinum_config "$PROJECT_ROOT" "$wallpaper_dir" "$INSTALL_STATE" "$IS_REINSTALL"
    configure_ski_defaults
}

step_services() {
    setup_services
    hand_over_from_easyeffects
}

step_finish() {
    write_version_state "$TARGET_VERSION" "$TARGET_COMMIT" "$TELEMETRY_ID" "$ENABLE_TELEMETRY" "${SELECTED_COMPOSITORS[*]}" "$OPT_SDDM" "$SDDM_WAYLAND" "$INSTALL_FULL_WALLPAPERS"

    if [[ "$INSTALL_STATE" == "legacy" || "$INSTALL_STATE" == "fresh" || "$IS_REINSTALL" == true ]]; then
        rm -f "$HOME/.local/state/serpantinum/first_launch.done" "$HOME/.local/state/quickshell/first_launch.done"
    fi

    if [ -f "$MODULES_DIR/telemetry.sh" ]; then
        bash "$MODULES_DIR/telemetry.sh" --mode done --version "$TARGET_VERSION" --old-version "$OLD_VERSION" --install-state "$INSTALL_STATE" --compositor "${SELECTED_COMPOSITORS[*]}" --id "$TELEMETRY_ID" --enabled "$ENABLE_TELEMETRY" --failed "${FAILED_PKGS[*]}"
    fi
}

run_steps_classic() {
    local id
    for id in "${STEP_IDS[@]}"; do
        "step_${id}"
    done
}
