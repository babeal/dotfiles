# shellcheck shell=bash disable=SC1090
# Starship prompt — bash and zsh, with per-shell init caching
command -v starship >/dev/null 2>&1 || return 0

_starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
mkdir -p "$_starship_cache"

if [ -n "$ZSH_VERSION" ]; then
    _starship_init_file="$_starship_cache/init_zsh.sh"
    _starship_shell="zsh"
elif [ -n "$BASH_VERSION" ]; then
    _starship_init_file="$_starship_cache/init_bash.sh"
    _starship_shell="bash"
else
    unset _starship_cache
    return 0
fi

# Regenerate if missing or older than 7 days
_starship_stale=""
[ -f "$_starship_init_file" ] && _starship_stale="$(find "$_starship_init_file" -mtime +7 2>/dev/null)"
if [ ! -f "$_starship_init_file" ] || [ -n "$_starship_stale" ]; then
    starship init "$_starship_shell" --print-full-init > "$_starship_init_file"
fi

. "$_starship_init_file"
unset _starship_cache _starship_init_file _starship_shell _starship_stale
