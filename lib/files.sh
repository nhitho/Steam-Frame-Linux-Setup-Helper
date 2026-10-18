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
# An existing backup is never overwritten: two runs within the same second
# would otherwise collide and lose the older state. A counter is appended,
# which keeps the plain name sorting first, so it stays the oldest one.
backup_file() {
    local file=$1 use_sudo=${2:-sudo}
    [[ -e $file && -z ${BACKED_UP[$file]:-} ]] || return 0
    local stamp bak n=1
    stamp=$(date +%Y%m%d-%H%M%S)
    bak="$file.bak-$stamp"
    while [[ -e $bak ]]; do bak="$file.bak-$stamp-$((n++))"; done
    if [[ $use_sudo == sudo ]]; then run sudo cp -a "$file" "$bak"; else run cp -a "$file" "$bak"; fi
    BACKED_UP[$file]=1
}

# Oldest backup of a file, i.e. the state before this script first touched it.
# The .bak-YYYYMMDD-HHMMSS suffix sorts chronologically, so the glob's first
# match is the oldest one.
oldest_backup() {
    local f
    for f in "$1".bak-*; do
        [[ -e $f ]] && { echo "$f"; return 0; }
    done
    return 1
}

# Undo a change: restore the oldest backup, or remove the file if the script
# created it (no backup exists because there was nothing to back up).
# Pass "nosudo" as $2 for files in the user's home, like backup_file does.
restore_or_remove() {
    local file=$1 use_sudo=${2:-sudo} bak
    if bak=$(oldest_backup "$file"); then
        info "$(t restore_from "$bak")"
        diff -u --label "$file ($(t new))" --label "$bak ($(t old))" \
            <(read_file "$file") <(read_file "$bak") | sed 's/^/    /'
        (( DRY_RUN )) && { warn "$(t dry_nothing)"; return 0; }
        if [[ $use_sudo == sudo ]]; then run sudo cp -a "$bak" "$file"; else run cp -a "$bak" "$file"; fi &&
            ok "$(t restored "$file")"
    elif [[ -e $file ]]; then
        info "$(t remove_created "$file")"
        (( DRY_RUN )) && { warn "$(t dry_nothing)"; return 0; }
        if [[ $use_sudo == sudo ]]; then run sudo rm -f "$file"; else run rm -f "$file"; fi &&
            ok "$(t removed "$file")"
    else
        info "$(t revert_nothing "$file")"
        return 1
    fi
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

# Replace a file's entire content: write_root_file FILE LINE...
# One argument per line, so callers stay indented instead of having to break
# a multi-line string at column 0.
write_root_file() {
    local file=$1 tmp
    shift
    tmp=$(mktemp)
    printf '%s\n' "$@" > "$tmp"
    install_content "$file" "$tmp"
    rm -f "$tmp"
}

# Transform INI text on stdin: set SECTION KEY VALUE, leave everything else.
# An existing entry (also a commented-out one) is replaced in place, a missing
# section is appended.
ini_apply() {
    awk -v s="[$1]" -v k="$2" -v v="$3" '
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
    '
}

# Rewrite a file through a filter: filter_file FILE CMD [ARG...]
# The current content goes to CMD's stdin, its stdout becomes the new content,
# shown as a diff and backed up like any other change.
filter_file() {
    local file=$1 tmp
    shift
    tmp=$(mktemp)
    read_file "$file" | "$@" > "$tmp"
    install_content "$file" "$tmp"
    rm -f "$tmp"
}

# Set one or more keys in an INI file:
#   ini_set FILE SECTION KEY VALUE [SECTION KEY VALUE]...
# All keys are applied before the file is written, so several keys in the same
# file produce a single diff and a single write instead of one per key.
ini_set() {
    local file=$1 cur new
    shift
    cur=$(mktemp); new=$(mktemp)
    read_file "$file" > "$cur"
    while (( $# >= 3 )); do
        ini_apply "$1" "$2" "$3" < "$cur" > "$new"
        cp -f "$new" "$cur"
        shift 3
    done
    if (( $# )); then
        err "ini_set: $file: incomplete SECTION KEY VALUE triple"
        rm -f "$cur" "$new"
        return 1
    fi
    install_content "$file" "$cur"
    rm -f "$cur" "$new"
}
