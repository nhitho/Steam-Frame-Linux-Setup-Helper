# shellcheck shell=bash
# Internationalisation: texts live in lang/<code>.lang (format key=value).
# en.lang is the base; other languages only override their own keys,
# so missing translations automatically fall back to English.
# New language: copy lang/en.lang to lang/<code>.lang and translate it.

LANG_DIR="$SCRIPT_DIR/lang"
UI_LANG=
declare -A M=()

# Available languages = files in lang/, English first
mapfile -t SUPPORTED_LANGS < <(
    echo en
    for _f in "$LANG_DIR"/*.lang; do
        _f=${_f##*/}; _f=${_f%.lang}
        [[ $_f != en ]] && echo "$_f"
    done
)
unset _f

# Get a translated text: t KEY [printf arguments …]
# Values use %s for arguments. Where a language needs a value in a position of
# its own choosing, the text carries a named token instead, like {min}, which
# the caller substitutes — bash's printf has no positional %1$s arguments.
t() {
    local key=$1; shift
    # shellcheck disable=SC2059
    printf -- "${M[$key]:-$key}" "$@"
}

# Read lang/xx.lang; comments (#) and blank lines are skipped
read_lang_file() {
    local file=$1 line key value
    [[ -r $file ]] || return 1
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line =~ ^[[:space:]]*(#|$) || $line != *=* ]] && continue
        key=${line%%=*}; key=${key//[[:space:]]/}
        value=${line#*=}
        value=${value%"${value##*[![:space:]]}"}   # strip trailing whitespace
        M[$key]=$value
    done < "$file"
}

load_lang() {
    UI_LANG=$1
    M=()
    read_lang_file "$LANG_DIR/en.lang"
    [[ $UI_LANG == en ]] || read_lang_file "$LANG_DIR/$UI_LANG.lang"
}

lang_supported() {
    local l
    for l in "${SUPPORTED_LANGS[@]}"; do [[ $l == "$1" ]] && return 0; done
    return 1
}

# Derive the language from the environment (de_DE.UTF-8 → de), else English
detect_lang() {
    local l=${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}
    l=${l%%_*}; l=${l%%.*}; l=${l,,}
    if lang_supported "$l"; then echo "$l"; else echo en; fi
}

# Country code the locale implies (de_AT.UTF-8 → AT), empty if it implies none
locale_country() {
    local l=${LC_ALL:-${LANG:-}} cc
    cc=${l#*_}; cc=${cc%%[.@]*}
    [[ $l == *_* && $cc =~ ^[A-Za-z]{2}$ ]] && echo "${cc^^}"
}

choose_language() {
    local current=$UI_LANG i n
    echo
    t choose_lang; echo
    for i in "${!SUPPORTED_LANGS[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" \
            "$(sed -n 's/^lang_name=//p' "$LANG_DIR/${SUPPORTED_LANGS[i]}.lang")"
    done
    while true; do
        read -rp "$(t lang_keep "$(t lang_name)") " n
        [[ -z $n ]] && break
        if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#SUPPORTED_LANGS[@]} )); then
            current=${SUPPORTED_LANGS[n - 1]}
            break
        fi
    done
    load_lang "$current"
}
