# shellcheck shell=bash
# Undo the Wi-Fi fixes (steps 2-5) by restoring the backups this script made

step_wifi_revert() {
    title "$(t t_revert)"
    info "$(t revert_intro)"

    local did=0

    # One entry per file, because that is what the backups cover.
    # /etc/iwd/main.conf holds both the power-save quirk and the roaming/scan
    # settings, so it is offered as a single item.
    if ask "$(t r_backend)" n; then
        restore_or_remove "$NM_BACKEND_CONF" && did=1
        ask "$(t revert_disable_iwd)" && run sudo systemctl disable --now iwd.service
    fi

    if ask "$(t r_powersave)" n; then
        restore_or_remove "$NM_POWERSAVE_CONF" && did=1
    fi

    if ask "$(t r_iwdconf)" n; then
        restore_or_remove "$IWD_MAIN_CONF" && did=1
    fi

    if ask "$(t r_regdom)" n; then
        # Which file holds it depends on the distribution, so try all of them
        local f hit=0
        for f in "$MODPROBE_REGDOM_CONF" "$ARCH_REGDOM_CONF" "$CRDA_CONF"; do
            [[ -e $f || -n $(oldest_backup "$f" 2>/dev/null) ]] || continue
            hit=1
            restore_or_remove "$f" && did=1
        done
        (( hit )) || info "$(t revert_nothing "$MODPROBE_REGDOM_CONF")"
    fi

    if (( ! did )); then
        info "$(t revert_none)"
        return 0
    fi

    ask "$(t nm_restart_now)" && {
        systemctl is-active --quiet iwd 2>/dev/null && run sudo systemctl restart iwd.service
        run sudo systemctl restart NetworkManager.service
    }
    warn "$(t revert_reboot)"
}
