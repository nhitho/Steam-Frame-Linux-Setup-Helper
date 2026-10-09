# shellcheck shell=bash
# Audio: PipeWire-Pulse (source: Linux VR Adventures)

step_audio() {
    title "$(t t_audio)"
    local server
    server=$(audio_server)
    if [[ $server == *PipeWire* ]]; then
        ok "$(t pw_running "$server")"
        ask "$(t reinstall)" n || return 0
    else
        info "$(t audio_current "${server:-$(t unknown)}")"
    fi

    case $FAMILY in
        arch)   warn "$(t pacman_pulse)"
                pkg_install pipewire-pulse wireplumber ;;
        fedora) pkg_install pipewire-pulseaudio wireplumber ;;
        debian) pkg_install pipewire-pulse wireplumber ;;
        *)      err "$(t unknown_distro)"; return 1 ;;
    esac || return 1

    if systemctl --user is-enabled --quiet pulseaudio.service 2>/dev/null ||
       systemctl --user is-active --quiet pulseaudio.service 2>/dev/null; then
        info "$(t pulse_disable)"
        run systemctl --user disable --now pulseaudio.service pulseaudio.socket
    fi
    run systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
    (( DRY_RUN )) || info "$(t audio_now "$(audio_server)")"
    info "$(t relogin)"
}
