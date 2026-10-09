# shellcheck shell=bash
# NetworkManager with iwd backend (+ revert)

step_iwd_backend() {
    title "$(t t_iwd_backend)"
    if ! command -v nmcli >/dev/null; then
        err "$(t nm_missing)"
        return 1
    fi
    info "$(t backend_current "$(nm_wifi_backend)")"

    if ! command -v iwctl >/dev/null && [[ ! -x /usr/lib/iwd/iwd && ! -x /usr/libexec/iwd ]]; then
        info "$(t iwd_missing)"
        pkg_install iwd || return 1
    fi

    write_root_file "$NM_BACKEND_CONF" "[device]
wifi.backend=iwd
wifi.iwd.autoconnect=false"

    run sudo systemctl enable iwd.service

    warn "$(t nm_restart_warn)"
    warn "$(t nm_restart_warn2)"
    if ask "$(t nm_restart_ask)"; then
        run sudo systemctl restart iwd.service
        run sudo systemctl restart NetworkManager.service
        ok "$(t restarted_backend "$(nm_wifi_backend)")"
    else
        info "$(t after_reboot)"
    fi
}

step_iwd_backend_revert() {
    title "$(t t_revert)"
    if [[ ! -e $NM_BACKEND_CONF ]]; then
        info "$(t revert_nothing "$NM_BACKEND_CONF")"
        return 0
    fi
    read_file "$NM_BACKEND_CONF" | sed 's/^/    /'
    ask "$(t revert_ask)" n || return 0
    backup_file "$NM_BACKEND_CONF"
    run sudo rm -f "$NM_BACKEND_CONF"
    ask "$(t revert_disable_iwd)" && run sudo systemctl disable --now iwd.service
    ask "$(t nm_restart_now)" && run sudo systemctl restart NetworkManager.service
}
