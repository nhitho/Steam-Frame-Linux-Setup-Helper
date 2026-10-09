# shellcheck shell=bash
# File helpers: backup, diff preview, writing, INI editing

declare -A BACKED_UP=()

# Read a file, falling back to sudo if it is not readable
read_file() {
    local file=$1
    [[ -e $file ]] || return 0
    if [[ -r $file ]]; then cat "$file"; else sudo cat "$file"; fi
}

# Create one backup per run: file.bak-YYYYMMDD-HHMMSS
backup_file() {
    local file=$1 use_sudo=${2:-sudo}
    [[ -e $file && -z ${BACKED_UP[$file]:-} ]] || return 0
    local bak
    bak="$file.bak-$(date +%Y%m%d-%H%M%S)"
    if [[ $use_sudo == sudo ]]; then run sudo cp -a "$file" "$bak"; else run cp -a "$file" "$bak"; fi
    BACKED_UP[$file]=1
}

# Write new content (from file $2) to $1 – with diff preview and backup
install_content() {
    local file=$1 newfile=$2
    if [[ -e $file ]] && diff -q <(read_file "$file") "$newfile" >/dev/null; then
        ok "$(t file_uptodate "$file")"
        return 0
    fi
    info "$(t changes_to "$file")"
    diff -u --label "$file ($(t old))" --label "$file ($(t new))" <(read_file "$file") "$newfile" | sed 's/^/    /'
    (( DRY_RUN )) && { warn "$(t dry_nothing)"; return 0; }
    backup_file "$file"
    sudo mkdir -p "$(dirname "$file")" &&
        sudo install -m 0644 "$newfile" "$file" &&
        ok "$(t file_written "$file")"
}

# Replace a file's entire content
write_root_file() {
    local file=$1 content=$2 tmp
    tmp=$(mktemp)
    printf '%s\n' "$content" > "$tmp"
    install_content "$file" "$tmp"
    rm -f "$tmp"
}

# Set one key in an INI file without touching anything else.
# Existing (also commented-out) entries are replaced, missing sections are appended.
ini_set() {
    local file=$1 section=$2 key=$3 value=$4 tmp
    tmp=$(mktemp)
    read_file "$file" | awk -v s="[$section]" -v k="$key" -v v="$value" '
        function flush() { if (insec && !done) { print k "=" v; done = 1 } }
        function blanks() { for (; nb > 0; nb--) print "" }
        /^[[:space:]]*$/ { nb++; next }   # buffer blank lines so new keys land before them
        /^[[:space:]]*\[/ {
            t = $0; gsub(/[[:space:]]/, "", t)
            flush(); blanks()
            insec = (t == s); if (insec) found = 1
            print; next
        }
        insec && $0 ~ "^[[:space:]]*#?[[:space:]]*" k "[[:space:]]*=" {
            blanks()
            if (!done) { print k "=" v; done = 1 }
            next
        }
        { blanks(); print }
        END {
            flush()
            if (!found) { if (NR > 0 && nb == 0) print ""; blanks(); print s; print k "=" v }
            else blanks()
        }
    ' > "$tmp"
    install_content "$file" "$tmp"
    rm -f "$tmp"
}
