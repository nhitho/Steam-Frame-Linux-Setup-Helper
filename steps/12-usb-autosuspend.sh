# shellcheck shell=bash
# Permanently disable USB autosuspend (kernel parameter usbcore.autosuspend=-1 via GRUB)

GRUB_DEFAULT_FILE="/etc/default/grub"
USB_PARAM="usbcore.autosuspend=-1"
USB_SYSFS="/sys/module/usbcore/parameters/autosuspend"

# Edit GRUB_CMDLINE_LINUX_DEFAULT: add | remove
# Any other usbcore.autosuspend value is replaced.
grub_cmdline_edit() {
    local mode=$1
    read_file "$GRUB_DEFAULT_FILE" | awk -v p="$USB_PARAM" -v mode="$mode" '
        /^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=/ && !done {
            val = substr($0, index($0, "=") + 1)
            q = substr(val, 1, 1)
            if (q == "\"" || q == "\047") { val = substr(val, 2); sub(/["\047][[:space:]]*$/, "", val) }
            else q = "\""
            n = split(val, a, /[[:space:]]+/); out = ""
            for (i = 1; i <= n; i++)
                if (a[i] != "" && a[i] !~ /^usbcore\.autosuspend=/) out = out (out == "" ? "" : " ") a[i]
            if (mode == "add") out = out (out == "" ? "" : " ") p
            print "GRUB_CMDLINE_LINUX_DEFAULT=" q out q
            done = 1; next
        }
        { print }
        END { if (!done && mode == "add") print "GRUB_CMDLINE_LINUX_DEFAULT=\"" p "\"" }'
}

# Regenerate the GRUB configuration (Fedora: BLS entries via grubby)
grub_regenerate() {
    local mode=$1
    info "$(t usb_regen)"
    if [[ $FAMILY == fedora ]] && command -v grubby >/dev/null; then
        if [[ $mode == add ]]; then
            run sudo grubby --update-kernel=ALL --args="$USB_PARAM"
        else
            run sudo grubby --update-kernel=ALL --remove-args="usbcore.autosuspend"
        fi
    elif command -v update-grub >/dev/null; then
        run sudo update-grub
    elif command -v grub2-mkconfig >/dev/null; then
        run sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    elif command -v grub-mkconfig >/dev/null; then
        run sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        err "$(t grub_no_tool)"
        return 1
    fi
}

step_usb_autosuspend() {
    title "$(t t_usb)"
    info "$(t usb_info)"
    local current loader mode=add tmp
    current=$(cat "$USB_SYSFS" 2>/dev/null)
    info "$(t usb_current "${current:-?}")"

    loader=$(detect_bootloader)
    if [[ $loader == grub ]]; then
        if grep -qE "^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=.*${USB_PARAM//./\\.}" "$GRUB_DEFAULT_FILE"; then
            ok "$(t usb_grub_already "$USB_PARAM")"
            ask "$(t usb_remove_ask)" n || mode=
        fi
        if [[ -n $mode ]]; then
            tmp=$(mktemp)
            grub_cmdline_edit "$mode" > "$tmp"
            install_content "$GRUB_DEFAULT_FILE" "$tmp"
            rm -f "$tmp"
            grub_regenerate "$mode" && warn "$(t usb_reboot)"
        fi
    else
        warn "$(t usb_no_grub "$loader")"
        case $loader in
            limine)       info "$(t usb_hint_limine "$USB_PARAM")" ;;
            sdboot-manage) info "$(t usb_hint_sdboot "$USB_PARAM")" ;;
            systemd-boot) info "$(t usb_hint_systemdboot "$USB_PARAM")" ;;
            *)            info "$(t usb_hint_other "$USB_PARAM")" ;;
        esac
    fi

    # Effective immediately until reboot (applies to newly plugged-in devices)
    if [[ $current != -1 && -e $USB_SYSFS ]] && ask "$(t usb_now_ask)"; then
        run sudo sh -c "echo -1 > $USB_SYSFS" && info "$(t usb_now_note)"
    fi
}
