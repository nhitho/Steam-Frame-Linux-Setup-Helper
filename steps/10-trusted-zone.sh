# shellcheck shell=bash
# Move the Steam Frame connection profile into firewalld zone 'trusted'

step_trusted_zone() {
    title "$(t t_trusted)"
    if ! command -v nmcli >/dev/null; then
        err "$(t nmcli_missing)"
        return 1
    fi
    if ! firewalld_active; then
        warn "$(t trusted_nofw)"
        ask "$(t set_anyway)" n || return 0
    fi

    local -a profiles
    mapfile -t profiles < <(nmcli -g NAME connection show 2>/dev/null | grep -i '^frame')
    if (( ${#profiles[@]} == 0 )); then
        warn "$(t no_frame)"
        ask "$(t choose_all)" n || return 0
        mapfile -t profiles < <(nmcli -g NAME connection show 2>/dev/null)
    fi
    choose "$(t which_profile)" "${profiles[@]}" || return 0
    local name=$REPLY_CHOICE

    info "$(t current_zone "$(nmcli -g connection.zone connection show "$name" 2>/dev/null || echo '?')")"
    run sudo nmcli connection modify "$name" connection.zone trusted || return 1
    ask "$(t reactivate "$name")" && run sudo nmcli connection up "$name"
    ok "$(t zone_done "$name")"
}
