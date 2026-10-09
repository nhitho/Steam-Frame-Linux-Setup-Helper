# shellcheck shell=bash
# System info / diagnostics

step_diagnose() {
    title "$(t t_diag)"
    label "$(t l_distro)" "$DISTRO_NAME ($DISTRO_ID → $FAMILY)"
    (( IS_ATOMIC )) && label "" "$(t l_atomic)"
    label "$(t l_kernel)" "$(uname -r)"
    label "$(t l_bootloader)" "$(detect_bootloader)"
    label "$(t l_usb)" "$(t usb_value "$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)")"

    if command -v iw >/dev/null; then
        label "$(t l_regdom)" "$(current_regdom)"
    else
        label "$(t l_regdom)" "$(t iw_missing)"
    fi

    label "$(t l_backend)" "$(nm_wifi_backend)"
    label "$(t l_iwd)" "$(systemctl is-active iwd 2>/dev/null)"

    local ifc
    for ifc in $(wifi_interfaces); do
        label "$(t l_powersave "$ifc")" "$(iw dev "$ifc" get power_save 2>/dev/null | awk -F': ' '{print $2}')"
    done

    if [[ -e $IWD_MAIN_CONF ]]; then
        echo "  $IWD_MAIN_CONF:"
        read_file "$IWD_MAIN_CONF" | sed 's/^/      /'
    else
        label "$(t l_iwdconf)" "$(t not_present)"
    fi

    if firewalld_active; then
        label "$(t l_firewall)" "$(t fw_firewalld "$(firewall-cmd --get-default-zone 2>/dev/null)")"
    elif ufw_installed; then
        local st
        st=$(sudo -n ufw status 2>/dev/null | head -n1)
        label "$(t l_firewall)" "$(t fw_ufw "${st:-$(t fw_needsudo)}")"
    else
        label "$(t l_firewall)" "$(t fw_none)"
    fi

    command -v pactl >/dev/null && label "$(t l_audio)" "$(audio_server)"

    if command -v nmcli >/dev/null; then
        local frames
        frames=$(nmcli -g NAME connection show 2>/dev/null | grep -i '^frame' | paste -sd ',')
        label "$(t l_frame)" "${frames:-$(t none_found)}"
    fi

    local f found=
    for f in ~/.local/share/applications/steam.desktop ~/.local/share/applications/com.valvesoftware.Steam.desktop; do
        [[ -e $f ]] && grep -qE '^Exec=.* -pipewire-dmabuf( |$)' "$f" && found=$f
    done
    label "$(t l_dmabuf)" "${found:-$(t not_set)}"
}
