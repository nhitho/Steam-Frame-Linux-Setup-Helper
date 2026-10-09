# shellcheck shell=bash
# Disable Wi-Fi power saving

step_powersave() {
    title "$(t t_powersave)"
    ensure_cmd iw || return 1

    local -a ifaces
    mapfile -t ifaces < <(wifi_interfaces)
    if (( ${#ifaces[@]} == 0 )); then
        warn "$(t no_wifi)"
    else
        local -a labels=()
        local i drv
        for i in "${ifaces[@]}"; do
            drv=$(basename "$(readlink -f "/sys/class/net/$i/device/driver" 2>/dev/null)" 2>/dev/null)
            labels+=("$i  ($(iw dev "$i" get power_save 2>/dev/null | awk -F': ' '{print $2}'), $(t driver): ${drv:-?})")
        done
        labels+=("$(t all)")
        if choose "$(t which_iface)" "${labels[@]}"; then
            local -a targets
            if [[ $REPLY_CHOICE == "$(t all)" ]]; then targets=("${ifaces[@]}"); else targets=("${REPLY_CHOICE%% *}"); fi
            for i in "${targets[@]}"; do
                run sudo iw dev "$i" set power_save off && ok "$(t ps_off_temp "$i")"
            done
        fi
    fi

    if ask "$(t ps_persist_ask)"; then
        # 2 = disable (NetworkManager, applies to all Wi-Fi connections)
        write_root_file "$NM_POWERSAVE_CONF" "[connection]
wifi.powersave=2"
        # iwd: disable power save for all drivers
        ini_set "$IWD_MAIN_CONF" DriverQuirks PowerSaveDisable '*'
        info "$(t ps_persist_note)"
    fi
}
