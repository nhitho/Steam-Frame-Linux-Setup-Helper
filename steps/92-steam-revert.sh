# shellcheck shell=bash
# Undo step 8 by restoring the backups of Steam's desktop entry

step_steam_revert() {
    title "$(t t_steam_revert)"
    info "$(t steam_revert_intro)"

    # The user copies step 8 writes. The system entry is never touched, so
    # removing a copy is enough to fall back to Steam's own launcher.
    local -a targets=(
        "$HOME/.local/share/applications/steam.desktop"
        "$HOME/.local/share/applications/com.valvesoftware.Steam.desktop"
        "$HOME/.config/autostart/steam.desktop"
        "$HOME/.config/autostart/com.valvesoftware.Steam.desktop"
    )
    local f did=0
    for f in "${targets[@]}"; do
        [[ -e $f || -n $(oldest_backup "$f" 2>/dev/null) ]] || continue
        restore_or_remove "$f" nosudo && did=1
    done

    if (( ! did )); then
        info "$(t revert_none)"
        return 0
    fi
    command -v update-desktop-database >/dev/null &&
        run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    warn "$(t steam_revert_restart)"
}
