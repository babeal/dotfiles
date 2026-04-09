# shellcheck shell=bash disable=SC1090,SC1091
command -v pnpm >/dev/null 2>&1 || return 0

if [ -n "$ZSH_VERSION" ]; then
    _pnpm_comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
    # Regenerate if missing or pnpm binary is newer than completion file
    if [ ! -f "$_pnpm_comp_dir/_pnpm" ] || [ "$(command -v pnpm)" -nt "$_pnpm_comp_dir/_pnpm" ]; then
        pnpm completion zsh >| "$_pnpm_comp_dir/_pnpm" 2>/dev/null &
    fi
    unset _pnpm_comp_dir

elif [ -n "$BASH_VERSION" ]; then
    _pnpm_comp_dir="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
    mkdir -p "$_pnpm_comp_dir"
    # Regenerate if missing or pnpm binary is newer than completion file
    if [ ! -f "$_pnpm_comp_dir/pnpm" ] || [ "$(command -v pnpm)" -nt "$_pnpm_comp_dir/pnpm" ]; then
        pnpm completion bash > "$_pnpm_comp_dir/pnpm"
    fi
    # Only source explicitly if bash-completion v2 isn't already managing this directory
    [ "${BASH_COMPLETION_VERSINFO[0]:-0}" -lt 2 ] && [ -f "$_pnpm_comp_dir/pnpm" ] && . "$_pnpm_comp_dir/pnpm"
    unset _pnpm_comp_dir
fi
