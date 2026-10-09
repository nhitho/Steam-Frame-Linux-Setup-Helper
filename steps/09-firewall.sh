# shellcheck shell=bash
# Firewall rules for Steam Remote Play / SteamVR (source: Steam)

step_firewall() {
    title "$(t t_firewall)"
    local did=0

    if firewalld_active; then
        did=1
        info "$(t firewalld_active)"
        if firewall-cmd --get-services 2>/dev/null | tr ' ' '\n' | grep -qx steam-streaming; then
            run sudo firewall-cmd --permanent --add-service=steam-streaming
        else
            warn "$(t fw_no_service)"
            run sudo firewall-cmd --permanent --add-port=27031-27036/udp --add-port=27036-27037/tcp
        fi
        run sudo firewall-cmd --permanent --add-port=10401-10403/udp
        run sudo firewall-cmd --reload
        ok "$(t firewalld_done)"
    fi

    if ufw_installed; then
        did=1
        local status
        # Dry run must not prompt for a password: only use cached sudo credentials
        if (( DRY_RUN )); then
            status=$(sudo -n ufw status 2>/dev/null | head -n1)
        else
            status=$(sudo ufw status 2>/dev/null | head -n1)
        fi
        info "$(t ufw_found "${status:-$(t unknown)}")"
        if [[ $status != *active* || $status == *inactive* ]]; then
            warn "$(t ufw_inactive)"
            ask "$(t add_anyway)" || return 0
        fi
        run sudo ufw allow 27031:27036/udp comment 'Steam Remote Play'
        run sudo ufw allow 27036:27037/tcp comment 'Steam Remote Play'
        run sudo ufw allow 10401:10403/udp comment 'Steam VR'
        run sudo ufw reload
        run sudo ufw status verbose
    fi

    if (( ! did )); then
        info "$(t fw_not_needed)"
        [[ $FAMILY == fedora ]] && warn "$(t fw_fedora_hint)"
    fi
}
