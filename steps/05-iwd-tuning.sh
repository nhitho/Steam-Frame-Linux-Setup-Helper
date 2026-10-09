# shellcheck shell=bash
# iwd roaming threshold / periodic scanning

step_iwd_tuning() {
    title "$(t t_iwd_tuning)"
    info "$(t iwd_tuning_info)"
    if [[ $(nm_wifi_backend) != iwd ]] && ! systemctl is-enabled --quiet iwd 2>/dev/null; then
        warn "$(t iwd_inactive)"
        ask "$(t write_anyway)" || return 0
    fi

    ini_set "$IWD_MAIN_CONF" General RoamThreshold -100
    ini_set "$IWD_MAIN_CONF" General RoamThreshold5G -100
    ini_set "$IWD_MAIN_CONF" Scan DisablePeriodicScan true

    if systemctl is-active --quiet iwd 2>/dev/null; then
        warn "$(t iwd_restart_warn)"
        ask "$(t iwd_restart_ask)" && run sudo systemctl restart iwd.service
    fi
}
