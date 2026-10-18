#!/usr/bin/env bash
# =============================================================================
#  Steam Frame – Linux Setup Helper
#
#  Interactive script that applies the known tweaks for the Steam Frame
#  (Wi-Fi dongle, iwd, firewall, audio, Steam launch option).
#
#  Distributions: Arch Linux, CachyOS (and other Arch derivatives),
#                 Fedora, Debian, Ubuntu, Linux Mint (and other Debian derivatives)
#  Languages:     every file in lang/ (en, de, es, fr, pt, zh, ja)
#
#  Layout:  lib/    shared functions (output, files, system, i18n)
#           steps/  one script per menu entry
#           lang/   translations (key=value)
#
#  Sources: Linux VR Adventures, Nhitho, DasChaos, Valve (Steam / SteamVR-for-Linux)
#
#  Usage:   ./steam-frame-setup.sh [--dry-run] [--lang en|de|es|fr|pt|zh|ja]
#  Run as a normal user – sudo is only used when needed.
# =============================================================================

set -uo pipefail

# On Debian-based systems iw / ufw live in /usr/sbin, which is not always in PATH
PATH="$PATH:/usr/sbin:/sbin"

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

VALVE_SCRIPT_URL="https://raw.githubusercontent.com/ValveSoftware/SteamVR-for-Linux/f4d917f7d8e17ab72a81ab20c9d7d6b2173fab80/frame-dongle-troubleshoot.sh"
VALVE_SCRIPT_PAGE="https://github.com/ValveSoftware/SteamVR-for-Linux/blob/f4d917f7d8e17ab72a81ab20c9d7d6b2173fab80/frame-dongle-troubleshoot.sh"

NM_BACKEND_CONF="/etc/NetworkManager/conf.d/wifi_backend.conf"
NM_POWERSAVE_CONF="/etc/NetworkManager/conf.d/wifi-powersave-off.conf"
IWD_MAIN_CONF="/etc/iwd/main.conf"
ARCH_REGDOM_CONF="/etc/conf.d/wireless-regdom"
MODPROBE_REGDOM_CONF="/etc/modprobe.d/cfg80211-regdom.conf"
CRDA_CONF="/etc/default/crda"

DRY_RUN=0

if [[ ! -d $SCRIPT_DIR/lib || ! -d $SCRIPT_DIR/steps || ! -f $SCRIPT_DIR/lang/en.lang ]]; then
    echo "Error: lib/, steps/ or lang/en.lang missing next to $0" >&2
    exit 1
fi
for _f in "$SCRIPT_DIR"/lib/*.sh "$SCRIPT_DIR"/steps/*.sh; do
    # shellcheck disable=SC1090
    source "$_f"
done
unset _f

# Menu entries: key|text key|function
#   ""        blank line
#   "#|key|"  group heading, not selectable
MENU=(
    "#|g_diag|"
    "1|m1|step_diagnose"
    ""
    "#|g_wifi|"
    "2|m2|step_regdom"
    "3|m3|step_iwd_backend"
    "4|m4|step_powersave"
    "5|m5|step_iwd_tuning"
    "r|mR|step_wifi_revert"
    ""
    "#|g_system|"
    "6|m6|step_fedora_multimedia"
    "7|m7|step_audio"
    "m|mM|step_fedora_revert"
    ""
    "#|g_steam|"
    "8|m8|step_steam_dmabuf"
    "s|mS|step_steam_revert"
    ""
    "#|g_network|"
    "9|m9|step_firewall"
    "10|m10|step_trusted_zone"
    ""
    "#|g_tools|"
    "11|m11|step_valve_script"
    ""
    "l|mL|choose_language"
    "0|m0|"
)

menu_header() {
    local text line
    text="  $(t menu_title)  "
    printf -v line '%*s' "$(str_width "$text")" ''
    line=${line// /═}
    printf '\n%s╔%s╗\n║%s║\n╚%s╝%s\n' "$C_CYAN" "$line" "$text" "$line" "$C_RESET"
    printf '  %s: %s%s%s' "$(t system)" "$C_BOLD" "$DISTRO_NAME" "$C_RESET"
    (( DRY_RUN )) && printf '   %s[DRY-RUN]%s' "$C_YELLOW" "$C_RESET"
    printf '\n\n'
}

menu() {
    local choice entry key label fn found
    while true; do
        menu_header
        for entry in "${MENU[@]}"; do
            [[ -z $entry ]] && { echo; continue; }
            IFS='|' read -r key label fn <<< "$entry"
            if [[ $key == '#' ]]; then
                printf '  %s%s %s%s\n' "$C_BOLD" "$(t g_prefix)" "$(t "$label")" "$C_RESET"
                continue
            fi
            printf '  %2s) %s\n' "${key^^}" "$(t "$label")"
        done
        echo
        read -rp "$(t choice) " choice
        choice=${choice,,}
        [[ $choice == q ]] && choice=0

        found=0
        for entry in "${MENU[@]}"; do
            IFS='|' read -r key label fn <<< "$entry"
            [[ -n $entry && $key != '#' && $key == "$choice" ]] && { found=1; break; }
        done
        if (( ! found )); then
            warn "$(t invalid)"
            continue
        fi
        case $choice in
            0) t bye; echo; exit 0 ;;
            l) "$fn"; continue ;;
        esac
        "$fn"
        pause
    done
}

main() {
    local lang_arg= show_help=0
    load_lang "$(detect_lang)"

    while (( $# )); do
        case $1 in
            -n|--dry-run) DRY_RUN=1 ;;
            -l|--lang)    lang_arg=${2:-}; shift ;;
            --lang=*)     lang_arg=${1#*=} ;;
            -h|--help)    show_help=1 ;;
            *)            err "$(t unknown_opt "$1")"; exit 1 ;;
        esac
        shift
    done

    if [[ -n $lang_arg ]]; then
        if ! lang_supported "$lang_arg"; then
            err "$(t bad_lang "$lang_arg" "${SUPPORTED_LANGS[*]}")"
            exit 1
        fi
        load_lang "$lang_arg"
    fi
    (( show_help )) && { t usage "$0" "$(IFS='|'; echo "${SUPPORTED_LANGS[*]}")"; exit 0; }
    if [[ -z $lang_arg && -t 0 ]]; then
        choose_language
    fi

    if (( EUID == 0 )); then
        err "$(t no_root)"
        exit 1
    fi
    command -v sudo >/dev/null || { err "$(t need_sudo)"; exit 1; }

    detect_distro
    if [[ $FAMILY == unknown ]]; then
        warn "$(t unsupported "$DISTRO_NAME")"
        ask "$(t continue_anyway)" n || exit 1
    fi

    if (( ! DRY_RUN )); then
        info "$(t sudo_info)"
        sudo -v || { err "$(t sudo_failed)"; exit 1; }
    fi
    menu
}

main "$@"
