# shellcheck shell=bash
# Download and run Valve's frame-dongle-troubleshoot.sh

step_valve_script() {
    title "$(t t_valve)"
    info "$(t source "$VALVE_SCRIPT_PAGE")"
    ensure_cmd wget || return 1

    # Own empty directory per run, so nothing else in /tmp is touched
    local dir file
    dir=$(mktemp -d)
    file="$dir/frame-dongle-troubleshoot.sh"

    run wget --https-only -O "$file" "$VALVE_SCRIPT_URL" || { err "$(t dl_failed)"; return 1; }
    (( DRY_RUN )) && return 0

    info "$(t downloaded "$file" "$(wc -l < "$file")")"
    ask "$(t view_first)" && "${PAGER:-less}" "$file"
    if ask "$(t valve_run)"; then
        run bash "$file"
        ufw_installed && info "$(t valve_ufw_hint "$file")"
    fi
    info "$(t still_at "$file")"
}
