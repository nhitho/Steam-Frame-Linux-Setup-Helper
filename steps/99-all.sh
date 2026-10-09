# shellcheck shell=bash
# Run all recommended steps in sequence

step_all() {
    title "$(t t_all)"
    info "$(t ask_each)"
    local -a steps=(
        "step_regdom|m2"
        "step_iwd_backend|m3"
        "step_powersave|m4"
        "step_iwd_tuning|m5"
    )
    [[ $FAMILY == fedora ]] && steps+=("step_fedora_multimedia|m6")
    steps+=(
        "step_audio|m7"
        "step_steam_dmabuf|m8"
        "step_firewall|m9"
        "step_trusted_zone|m10"
        "step_usb_autosuspend|m12"
    )
    local entry
    for entry in "${steps[@]}"; do
        echo
        if ask "$(t run_step "${C_BOLD}$(t "${entry#*|}")${C_RESET}")"; then
            "${entry%%|*}" || warn "$(t step_failed)"
        fi
    done
    echo
    ok "$(t all_done)"
}
