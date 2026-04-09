# shellcheck shell=bash disable=SC1090,SC1091
command -v uv >/dev/null 2>&1 || return 0

if [ -n "$ZSH_VERSION" ]; then
    _uv_comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
    # Regenerate if missing or uv binary is newer than completion file
    if [ ! -f "$_uv_comp_dir/_uv" ] || [ "$(command -v uv)" -nt "$_uv_comp_dir/_uv" ]; then
        uv generate-shell-completion zsh >| "$_uv_comp_dir/_uv" 2>/dev/null &
    fi
    unset _uv_comp_dir

elif [ -n "$BASH_VERSION" ]; then
    _uv_comp_dir="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
    mkdir -p "$_uv_comp_dir"
    # Regenerate if missing or uv binary is newer than completion file
    if [ ! -f "$_uv_comp_dir/uv" ] || [ "$(command -v uv)" -nt "$_uv_comp_dir/uv" ]; then
        uv generate-shell-completion bash > "$_uv_comp_dir/uv"
    fi
    # Only source explicitly if bash-completion v2 isn't already managing this directory
    [ "${BASH_COMPLETION_VERSINFO[0]:-0}" -lt 2 ] && [ -f "$_uv_comp_dir/uv" ] && . "$_uv_comp_dir/uv"
    unset _uv_comp_dir
fi
