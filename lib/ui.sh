# shellcheck shell=bash
# Output, prompts and command execution

if [[ -t 1 ]]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
else
    C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_CYAN=
fi

info()  { printf '%s[i]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()   { printf '%s[✗]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
title() { printf '\n%s%s== %s ==%s\n' "$C_BOLD" "$C_CYAN" "$*" "$C_RESET"; }

# Terminal display width of a string (CJK characters take two columns)
str_width() {
    local w
    w=$(printf '%s' "$1" | wc -L 2>/dev/null)
    echo "${w:-${#1}}"
}

# "Label   value" row – pads by display width, not bytes (umlauts, accents, CJK)
label() {
    local text=$1 value=$2 pad
    pad=$(( 30 - $(str_width "$text") )); (( pad < 1 )) && pad=1
    printf '  %s%*s%s\n' "$text" "$pad" '' "$value"
}

pause() { read -rp "$(t pause)" _; }

# ask "question" [y|n]  -> 0 = yes, 1 = no
ask() {
    local question=$1 default=${2:-y} answer hint w
    [[ $default == y ]] && hint=$(t hint_yes) || hint=$(t hint_no)
    while true; do
        read -rp "$question $hint " answer
        answer=${answer,,}
        [[ -z $answer ]] && { [[ $default == y ]]; return; }
        for w in $(t yes_words); do [[ $answer == "$w" ]] && return 0; done
        for w in $(t no_words);  do [[ $answer == "$w" ]] && return 1; done
    done
}

# Print and execute a command (dry run: print only)
run() {
    printf '%s  $ %s%s\n' "$C_DIM" "$(printf '%q ' "$@")" "$C_RESET"
    (( DRY_RUN )) && return 0
    "$@"
}

# Pick one entry from a list; result in REPLY_CHOICE and REPLY_INDEX
choose() {
    local prompt=$1; shift
    local -a items=("$@")
    REPLY_CHOICE=; REPLY_INDEX=
    (( ${#items[@]} )) || return 1
    if (( ${#items[@]} == 1 )); then
        REPLY_CHOICE=${items[0]}; REPLY_INDEX=0
        info "$prompt $REPLY_CHOICE"
        return 0
    fi
    echo "$prompt"
    local i n
    for i in "${!items[@]}"; do printf '  %2d) %s\n' "$((i + 1))" "${items[i]}"; done
    printf '   0) %s\n' "$(t cancel)"
    while true; do
        read -rp "$(t choice) " n
        [[ $n == 0 ]] && return 1
        if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#items[@]} )); then
            REPLY_CHOICE=${items[n - 1]}; REPLY_INDEX=$((n - 1))
            return 0
        fi
    done
}
