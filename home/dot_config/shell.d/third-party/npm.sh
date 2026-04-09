# shellcheck shell=bash disable=SC1090,SC1091
command -v npm >/dev/null 2>&1 || return 0

if [ -n "$ZSH_VERSION" ]; then
    # npm completion outputs a single script that handles bash, zsh (compdef), and old zsh (compctl).
    # compdef is not available here (compinit runs after shell.d), so it falls back to compctl-style completion.
    _npm_comp_file="${XDG_DATA_HOME:-$HOME/.local/share}/npm-completion.sh"
    if [ ! -f "$_npm_comp_file" ] || [ "$(command -v npm)" -nt "$_npm_comp_file" ]; then
        npm completion >| "$_npm_comp_file"
    fi
    [ -f "$_npm_comp_file" ] && . "$_npm_comp_file"
    unset _npm_comp_file

elif [ -n "$BASH_VERSION" ]; then
    _npm_comp_dir="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
    mkdir -p "$_npm_comp_dir"
    if [ ! -f "$_npm_comp_dir/npm" ] || [ "$(command -v npm)" -nt "$_npm_comp_dir/npm" ]; then
        npm completion > "$_npm_comp_dir/npm"
    fi
    [ "${BASH_COMPLETION_VERSINFO[0]:-0}" -lt 2 ] && [ -f "$_npm_comp_dir/npm" ] && . "$_npm_comp_dir/npm"
    unset _npm_comp_dir
fi
