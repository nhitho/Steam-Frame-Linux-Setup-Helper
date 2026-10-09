# shellcheck shell=bash
# Distribution, packages, network, firewall, bootloader

DISTRO_ID=unknown
DISTRO_NAME=unknown
FAMILY=unknown
IS_ATOMIC=0
APT_UPDATED=0

# Sets DISTRO_ID, DISTRO_NAME, FAMILY (arch | fedora | debian | unknown) and IS_ATOMIC
detect_distro() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID=${ID:-unknown}
        DISTRO_NAME=${PRETTY_NAME:-$DISTRO_ID}
        local ids=" ${ID:-} ${ID_LIKE:-} "
        case $ids in
            *" arch "*|*" cachyos "*|*" manjaro "*|*" endeavouros "*) FAMILY=arch ;;
            *" fedora "*|*" rhel "*|*" nobara "*)                     FAMILY=fedora ;;
            *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*)      FAMILY=debian ;;
        esac
    fi
    [[ -e /run/ostree-booted ]] && IS_ATOMIC=1
}

pkg_install() {
    case $FAMILY in
        arch)
            run sudo pacman -S --needed "$@" ;;
        fedora)
            if (( IS_ATOMIC )); then
                warn "$(t atomic_layer)"
                run sudo rpm-ostree install --idempotent "$@"
            else
                run sudo dnf install -y "$@"
            fi ;;
        debian)
            if (( ! APT_UPDATED )); then run sudo apt-get update && APT_UPDATED=1; fi
            run sudo apt-get install -y "$@" ;;
        *)
            err "$(t install_manually "$*")"; return 1 ;;
    esac
}

# Make sure a command exists, otherwise offer to install its package
ensure_cmd() {
    local cmd=$1 pkg=${2:-$1}
    command -v "$cmd" >/dev/null && return 0
    warn "$(t not_installed "$cmd")"
    if ask "$(t install_now "$pkg")"; then
        pkg_install "$pkg" || return 1
        (( DRY_RUN )) && return 0
        command -v "$cmd" >/dev/null
    else
        return 1
    fi
}

wifi_interfaces() {
    command -v iw >/dev/null || return 0
    iw dev 2>/dev/null | awk '$1 == "Interface" { print $2 }'
}

# Global regulatory domain, e.g. "DE" or "00"
current_regdom() {
    iw reg get 2>/dev/null | awk '
        /^global/                  { g = 1; next }
        /^country/ && (g || !seen) { sub(":", "", $2); print $2; exit }
        /^phy/                     { seen = 1 }'
}

nm_wifi_backend() {
    local b
    b=$(cat /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/conf.d/*.conf 2>/dev/null |
        awk -F= '/^[[:space:]]*wifi\.backend[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); v = $2 } END { print v }')
    echo "${b:-$(t backend_default)}"
}

audio_server() { pactl info 2>/dev/null | awk -F': ' '/^Server Name/ {print $2}'; }

firewalld_active() { command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; }
ufw_installed()    { command -v ufw >/dev/null; }

# Detect bootloader: grub | limine | sdboot-manage | systemd-boot | unknown
detect_bootloader() {
    if [[ -e /etc/default/grub ]] &&
       { command -v update-grub || command -v grub-mkconfig || command -v grub2-mkconfig; } >/dev/null 2>&1; then
        echo grub
    elif [[ -e /etc/default/limine ]] || command -v limine-update >/dev/null; then
        echo limine
    elif [[ -e /etc/sdboot-manage.conf ]]; then
        echo sdboot-manage
    elif [[ -d /boot/loader/entries || -d /efi/loader/entries || -d /boot/efi/loader/entries ]]; then
        echo systemd-boot
    else
        echo unknown
    fi
}
