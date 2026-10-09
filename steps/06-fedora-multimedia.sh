# shellcheck shell=bash
# Fedora: RPM Fusion, multimedia, Mesa freeworld (source: DasChaos)

step_fedora_multimedia() {
    title "$(t t_fedora)"
    if [[ $FAMILY != fedora ]]; then
        info "$(t fedora_only "$DISTRO_NAME")"
        return 0
    fi
    if (( IS_ATOMIC )); then
        warn "$(t fedora_atomic)"
        warn "$(t fedora_atomic2)"
        return 0
    fi

    local ver p
    ver=$(rpm -E %fedora)

    info "$(t fedora_s1)"
    if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
        ok "$(t rpmfusion_ok)"
    else
        run sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$ver.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$ver.noarch.rpm" || return 1
    fi

    info "$(t fedora_s2)"
    run sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    run sudo dnf group install -y multimedia
    run sudo dnf update -y @multimedia --setopt=install_weakdeps=False --exclude=PackageKit-gstreamer-plugin

    info "$(t fedora_s3)"
    for p in mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers; do
        run sudo dnf swap -y "$p" "$p-freeworld" || warn "$(t swap_failed "$p")"
    done
    for p in mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers; do
        if rpm -q "$p.i686" >/dev/null 2>&1; then
            run sudo dnf swap -y "$p.i686" "$p-freeworld.i686" || warn "$(t swap_failed "$p.i686")"
        else
            info "$(t skipped_missing "$p.i686")"
        fi
    done
    ok "$(t fedora_done)"
}
