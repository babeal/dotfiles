# shellcheck shell=bash disable=SC1090,SC1091
command -v mise >/dev/null 2>&1 || return 0

if [ -n "$ZSH_VERSION" ]; then
    eval "$(mise activate zsh)"

    _mise_comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
    # Regenerate if missing or mise binary is newer than completion file
    if [ ! -f "$_mise_comp_dir/_mise" ] || [ "$(command -v mise)" -nt "$_mise_comp_dir/_mise" ]; then
        mise completions zsh >| "$_mise_comp_dir/_mise" 2>/dev/null &
    fi
    unset _mise_comp_dir

elif [ -n "$BASH_VERSION" ]; then
    eval "$(mise activate bash)"

    _mise_comp_dir="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
    mkdir -p "$_mise_comp_dir"
    # Regenerate if missing or mise binary is newer than completion file
    if [ ! -f "$_mise_comp_dir/mise" ] || [ "$(command -v mise)" -nt "$_mise_comp_dir/mise" ]; then
        mise completions bash > "$_mise_comp_dir/mise"
    fi
    # Only source explicitly if bash-completion v2 isn't already managing this directory
    [ "${BASH_COMPLETION_VERSINFO[0]:-0}" -lt 2 ] && [ -f "$_mise_comp_dir/mise" ] && . "$_mise_comp_dir/mise"
    unset _mise_comp_dir
fi
