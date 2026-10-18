# shellcheck shell=bash
# Undo step 6. There are no backups here: these are packages, so the swaps are
# simply run the other way round.

# Undo one Mesa freeworld driver. Mirrors mesa_to_freeworld: swap back when the
# stock package really exists (up to F43, and Vulkan), otherwise just remove the
# freeworld package, because from F44 on the stock VA support is part of
# mesa-dri-drivers and comes back by itself.
# $1 base name, $2 architecture suffix. Returns 0 only if something was done.
mesa_from_freeworld() {
    local stock="$1$2" fw="$1-freeworld$2"
    rpm -q "$fw" >/dev/null 2>&1 || return 1
    if rpm_pkg_available "$1"; then
        run sudo dnf swap -y "$fw" "$stock" || { warn "$(t swap_failed "$fw")"; return 1; }
    else
        run sudo dnf remove -y "$fw" || { warn "$(t remove_failed "$fw")"; return 1; }
    fi
}

step_fedora_revert() {
    title "$(t t_fedora_revert)"
    if [[ $FAMILY != fedora ]]; then
        info "$(t fedora_only "$DISTRO_NAME")"
        return 0
    fi
    if (( IS_ATOMIC )); then
        warn "$(t fedora_atomic)"
        return 0
    fi
    info "$(t fedora_revert_intro)"

    local p did=0
    if ask "$(t fr_mesa)" n; then
        for p in mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers; do
            mesa_from_freeworld "$p" ""     && did=1
            mesa_from_freeworld "$p" .i686  && did=1
        done
        (( did )) || info "$(t fr_mesa_none)"
    fi

    if ask "$(t fr_ffmpeg)" n; then
        if rpm -q ffmpeg >/dev/null 2>&1; then
            run sudo dnf swap -y ffmpeg ffmpeg-free --allowerasing || warn "$(t swap_failed ffmpeg)"
            did=1
        else
            info "$(t skipped_missing ffmpeg)"
        fi
    fi

    if ask "$(t fr_rpmfusion)" n; then
        local -a repos=()
        for p in rpmfusion-free-release rpmfusion-nonfree-release; do
            rpm -q "$p" >/dev/null 2>&1 && repos+=("$p")
        done
        if (( ${#repos[@]} )); then
            warn "$(t fr_rpmfusion_warn)"
            if ask "$(t continue_anyway)" n; then
                run sudo dnf remove -y "${repos[@]}"
                did=1
            fi
        else
            info "$(t skipped_missing rpmfusion-free-release)"
        fi
    fi

    if (( ! did )); then
        info "$(t revert_none)"
        return 0
    fi
    warn "$(t fr_group_note)"
    info "$(t relogin)"
}
