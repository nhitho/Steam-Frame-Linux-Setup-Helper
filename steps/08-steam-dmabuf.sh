# shellcheck shell=bash
# Steam with a PipeWire launch option (tested by Nhitho)

step_steam_dmabuf() {
    title "$(t t_steam)"

    # The user picks the launch option; both are stripped before the chosen one
    # is inserted, so switching between them works too.
    local param
    choose "$(t which_param)" \
        "-pipewire-dmabuf  ($(t steam_opt_dmabuf))" \
        "-pipewire  ($(t steam_opt_plain))" || return 0
    param=${REPLY_CHOICE%% *}

    local -a sources=(
        /usr/share/applications/steam.desktop
        /var/lib/flatpak/exports/share/applications/com.valvesoftware.Steam.desktop
        "$HOME/.local/share/flatpak/exports/share/applications/com.valvesoftware.Steam.desktop"
    )
    local -a found=()
    local src
    for src in "${sources[@]}"; do [[ -e $src ]] && found+=("$src"); done

    if (( ${#found[@]} == 0 )); then
        warn "$(t steam_none)"
        echo "    steam $param"
        return 0
    fi
    choose "$(t which_steam)" "${found[@]}" || return 0
    src=$REPLY_CHOICE

    local -a targets=("$HOME/.local/share/applications/$(basename "$src")")
    [[ -e $HOME/.config/autostart/$(basename "$src") ]] && targets+=("$HOME/.config/autostart/$(basename "$src")")

    local target base tmp
    for target in "${targets[@]}"; do
        # Reuse an existing user copy, otherwise copy the system file
        if [[ -e $target ]]; then base=$target; else base=$src; fi
        if grep -qE "^Exec=.* $param( |\$)" "$base"; then
            ok "$(t dmabuf_present "$target" "$param")"
            continue
        fi
        tmp=$(mktemp)
        awk -v p="$param" '
            /^\[/ { main = ($0 == "[Desktop Entry]") }
            main && /^Exec=/ {
                gsub(/ -?pipewire-dmabuf/, "")   # drop the other option and
                gsub(/ -?pipewire/, "")          # old entries missing the "-"
                if (!sub(/com\.valvesoftware\.Steam/, "& " p))
                    sub(/^Exec=[^ ]+/, "& " p)
            }
            { print }' "$base" > "$tmp"
        info "$(t change_for "$target")"
        diff -u --label "$(t before)" --label "$(t after)" "$base" "$tmp" | sed 's/^/    /'
        if (( DRY_RUN )); then
            warn "$(t dry_nothing)"
        else
            backup_file "$target" nosudo
            mkdir -p "$(dirname "$target")"
            install -m 0644 "$tmp" "$target" && ok "$(t file_written "$target")"
        fi
        rm -f "$tmp"
    done
    command -v update-desktop-database >/dev/null && run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    warn "$(t steam_restart "$param")"
}
