
# ASDF Package Manager

if command -v brew &>/dev/null; then
    # supposefly --prefix asdf requires ruby which makes it slow where --prefix is fast
    local pkg_root=$(brew --prefix)
    [[ -s "$pkg_root/opt/asdf/libexec/asdf.sh" ]] && source "$pkg_root/opt/asdf/libexec/asdf.sh"
elif [[ -s "~/.asdf/asdf.sh" ]]; then
    source ~/.asdf/asdf.sh
    if [[ -n ${BASH} ]]; then
        source ~/.asdf/completions/asdf.bash
    elif [[ -n ${ZSH_NAME} ]]; then
        # add directory to fpath if needed
        :
    fi
fi