# shellcheck shell=bash
# Wi-Fi regulatory domain

# Arch / CachyOS: enable WIRELESS_REGDOM="XX" in /etc/conf.d/wireless-regdom.
# The file ships every country as a commented-out line, so the matching one is
# uncommented; any entry already active for another country is commented out.
# stdin -> stdout.
regdom_apply_arch() {
    awk -v want="WIRELESS_REGDOM=\"$1\"" '
        /^[[:space:]]*WIRELESS_REGDOM=/     { print "#" $0; next }
        !found && /^#/ && index($0, want)   { print want; found = 1; next }
        { print }
        END { if (!found) print want }
    '
}

# Debian / Ubuntu / Mint: set REGDOMAIN= in /etc/default/crda (stdin -> stdout).
# The first assignment is replaced, any further one dropped.
regdom_apply_crda() {
    awk -v want="REGDOMAIN=$1" '
        /^[[:space:]]*REGDOMAIN=/ { if (!found) { print want; found = 1 } next }
        { print }
        END { if (!found) print want }
    '
}

# Ask for a two-letter country code. $1 is the default for an empty answer,
# or empty to require an answer. Prints the code.
read_regdom() {
    local def=$1 cc
    while true; do
        if [[ -n $def ]]; then
            read -rp "$(t regdom_prompt "$def") " cc
            cc=${cc:-$def}
        else
            read -rp "$(t regdom_prompt_any) " cc
        fi
        cc=${cc^^}
        [[ $cc =~ ^[A-Z]{2}$ ]] && { echo "$cc"; return 0; }
        warn "$(t regdom_invalid)" >&2
    done
}

step_regdom() {
    title "$(t t_regdom)"
    ensure_cmd iw || return 1

    local current cc def
    current=$(current_regdom)
    info "$(t regdom_current "${current:-$(t unknown)}")"
    if [[ -n $current && $current != 00 ]]; then
        ok "$(t already_set)"
        ask "$(t change_anyway)" n || return 0
    else
        warn "$(t regdom_00)"
    fi

    # Offer the obvious candidates instead of only a free-text prompt. The
    # parallel acts[] array says what the chosen entry means.
    local -a opts=() acts=() known=()
    def=$(locale_country)
    mapfile -t known < <(available_regdoms)

    [[ -n $def ]] && { opts+=("$def  ($(t regdom_from_locale))"); acts+=("$def"); }
    if [[ -n $current && $current != 00 && $current != "$def" ]]; then
        opts+=("$current  ($(t regdom_keep_current))"); acts+=("$current")
    fi
    opts+=("$(t regdom_enter)"); acts+=(ASK)
    (( ${#known[@]} )) && { opts+=("$(t regdom_show_all "${#known[@]}")"); acts+=(LIST); }

    choose "$(t regdom_which)" "${opts[@]}" || return 0
    case ${acts[REPLY_INDEX]} in
        LIST)
            printf '%s\n' "${known[@]}" | column -c 72 2>/dev/null ||
                printf '%s\n' "${known[@]}" | paste -sd' '
            cc=$(read_regdom "$def") ;;
        ASK) cc=$(read_regdom "$def") ;;
        *)   cc=${acts[REPLY_INDEX]} ;;
    esac

    # A code the local database does not know will simply not be applied
    if (( ${#known[@]} )) && ! printf '%s\n' "${known[@]}" | grep -qx "$cc"; then
        warn "$(t regdom_unknown "$cc")"
        ask "$(t continue_anyway)" n || return 0
    fi
    info "$(t regdom_chosen "$cc")"

    if [[ $FAMILY == arch ]]; then
        [[ -e $ARCH_REGDOM_CONF ]] || pkg_install wireless-regdb || return 1
        filter_file "$ARCH_REGDOM_CONF" regdom_apply_arch "$cc"
    else
        # Kernel module option, which every distribution understands
        [[ $FAMILY == debian && -e $CRDA_CONF ]] &&
            filter_file "$CRDA_CONF" regdom_apply_crda "$cc"
        write_root_file "$MODPROBE_REGDOM_CONF" "options cfg80211 ieee80211_regdom=$cc"
    fi

    info "$(t regdom_apply)"
    run sudo iw reg set "$cc"
    (( DRY_RUN )) || info "$(t regdom_now "$(current_regdom)")"
    warn "$(t regdom_selfmanaged)"
}
