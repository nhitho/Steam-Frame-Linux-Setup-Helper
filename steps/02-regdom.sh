# shellcheck shell=bash
# Wi-Fi regulatory domain

step_regdom() {
    title "$(t t_regdom)"
    ensure_cmd iw || return 1

    local current cc def tmp
    current=$(current_regdom)
    info "$(t regdom_current "${current:-$(t unknown)}")"
    if [[ -n $current && $current != 00 ]]; then
        ok "$(t already_set)"
        ask "$(t change_anyway)" n || return 0
    else
        warn "$(t regdom_00)"
    fi

    def=$(locale_country)
    while true; do
        read -rp "$(t regdom_prompt "$def") " cc
        cc=${cc:-$def}; cc=${cc^^}
        [[ $cc =~ ^[A-Z]{2}$ ]] && break
        warn "$(t regdom_invalid)"
    done

    if [[ $FAMILY == arch ]]; then
        # Arch / CachyOS: /etc/conf.d/wireless-regdom (package wireless-regdb)
        [[ -e $ARCH_REGDOM_CONF ]] || pkg_install wireless-regdb || return 1
        tmp=$(mktemp)
        read_file "$ARCH_REGDOM_CONF" | awk -v cc="$cc" '
            /^[[:space:]]*WIRELESS_REGDOM=/ { print "#" $0; next }        # comment out other active entries
            !done && $0 ~ "^#[[:space:]]*WIRELESS_REGDOM=\"" cc "\"" {
                print "WIRELESS_REGDOM=\"" cc "\""; done = 1; next }
            { print }
            END { if (!done) print "WIRELESS_REGDOM=\"" cc "\"" }' > "$tmp"
        install_content "$ARCH_REGDOM_CONF" "$tmp"
        rm -f "$tmp"
    else
        # Fedora / Debian / Ubuntu / Mint: kernel module option for cfg80211
        if [[ $FAMILY == debian && -e /etc/default/crda ]]; then
            tmp=$(mktemp)
            read_file /etc/default/crda | awk -v cc="$cc" '
                /^[[:space:]]*REGDOMAIN=/ { print "REGDOMAIN=" cc; done = 1; next }
                { print } END { if (!done) print "REGDOMAIN=" cc }' > "$tmp"
            install_content /etc/default/crda "$tmp"
            rm -f "$tmp"
        fi
        write_root_file "$MODPROBE_REGDOM_CONF" "options cfg80211 ieee80211_regdom=$cc"
    fi

    info "$(t regdom_apply)"
    run sudo iw reg set "$cc"
    (( DRY_RUN )) || info "$(t regdom_now "$(current_regdom)")"
    warn "$(t regdom_selfmanaged)"
}
