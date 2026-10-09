# shellcheck shell=bash
# Download, show and run Valve's frame-dongle-troubleshoot.sh

step_valve_script() {
    title "$(t t_valve)"
    info "$(t source "$VALVE_SCRIPT_PAGE")"
    local dir file
    dir=$(mktemp -d)
    file="$dir/frame-dongle-troubleshoot.sh"

    if command -v curl >/dev/null; then
        run curl -fL --proto '=https' --tlsv1.2 -o "$file" "$VALVE_SCRIPT_URL" || { err "$(t dl_failed)"; return 1; }
    elif command -v wget >/dev/null; then
        run wget --https-only -O "$file" "$VALVE_SCRIPT_URL" || { err "$(t dl_failed)"; return 1; }
    else
        err "$(t no_dl_tool)"
        return 1
    fi
    (( DRY_RUN )) && return 0

    if head -n1 "$file" | grep -qi '<!doctype\|<html'; then
        err "$(t got_html)"
        return 1
    fi
    info "$(t downloaded "$file" "$(wc -l < "$file")")"
    info "SHA256: $(sha256sum "$file" | cut -d' ' -f1)"
    ask "$(t view_first)" && "${PAGER:-less}" "$file"
    ask "$(t run_sudo)" || { info "$(t still_at "$file")"; return 0; }
    chmod +x "$file"
    sudo "$file"
    info "$(t still_at "$file")"
}
