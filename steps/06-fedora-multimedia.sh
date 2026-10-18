# shellcheck shell=bash
# Fedora: RPM Fusion, multimedia, Mesa freeworld (source: DasChaos)

# Switch one Mesa driver to its freeworld variant. Which way that works
# depends on the Fedora release, so it is decided from the actual state:
#   * no freeworld package in the repos  -> nothing to do (VDPAU from F44 on)
#   * stock package installed            -> swap it (up to F43, and Vulkan)
#   * stock name only a virtual provide  -> install alongside (VA from F44 on)
# $1 base name, $2 architecture suffix ("" or ".i686"), $3 "install" to allow
# the install path; for .i686 only what is already installed is touched.
mesa_to_freeworld() {
    local stock="$1$2" fw="$1-freeworld$2" mode=${3:-swap}
    if ! rpm_pkg_available "$1-freeworld"; then
        [[ -z $2 ]] && info "$(t fedora_no_freeworld "$1-freeworld")"
        return 0
    fi
    if rpm -q "$fw" >/dev/null 2>&1; then
        ok "$(t fedora_fw_present "$fw")"
    elif rpm -q "$stock" >/dev/null 2>&1; then
        run sudo dnf swap -y "$stock" "$fw" || warn "$(t swap_failed "$stock")"
    elif [[ $mode == install ]]; then
        run sudo dnf install -y "$fw" || warn "$(t install_failed "$fw")"
    else
        info "$(t skipped_missing "$stock")"
    fi
}

# The Mesa part of step 6, kept separate so it can be run and tested on its own
fedora_mesa_freeworld() {
    local p
    for p in mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers; do
        mesa_to_freeworld "$p" ""      install
        mesa_to_freeworld "$p" .i686
    done
}

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

    local ver
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
    fedora_mesa_freeworld
    ok "$(t fedora_done)"
}
