# shellcheck shell=bash
# Download and run Valve's frame-dongle-troubleshoot.sh

# SHA256 of the pinned version (v0.5). VALVE_SCRIPT_URL pins the matching
# commit, so this value only changes when that commit is bumped. To move to a
# newer version, review it, then update the commit in steam-frame-setup.sh and
# this hash together:  sha256sum frame-dongle-troubleshoot.sh
VALVE_SHA256="bf93a0362be53b67f40da587a4edf8803685ebd3b518873df814bc75486a5235"

step_valve_script() {
    title "$(t t_valve)"
    info "$(t source "$VALVE_SCRIPT_PAGE")"
    ensure_cmd wget || return 1

    # Own empty directory per run, so nothing else in /tmp is touched
    local dir file sum
    dir=$(mktemp -d)
    file="$dir/frame-dongle-troubleshoot.sh"

    run wget --https-only -O "$file" "$VALVE_SCRIPT_URL" || { err "$(t dl_failed)"; return 1; }
    (( DRY_RUN )) && return 0

    info "$(t downloaded "$file" "$(wc -l < "$file")")"

    sum=$(sha256sum "$file" | cut -d' ' -f1)
    if [[ $sum == "$VALVE_SHA256" ]]; then
        ok "$(t valve_sum_ok)"
        ask "$(t view_first)" && "${PAGER:-less}" "$file"
        if ask "$(t valve_run)"; then
            run bash "$file"
            ufw_installed && info "$(t valve_ufw_hint "$file")"
        fi
        info "$(t still_at "$file")"
    else
        err "$(t valve_sum_bad)"
        info "$(t valve_sum_detail "$VALVE_SHA256" "$sum")"
        return 1
    fi

}
