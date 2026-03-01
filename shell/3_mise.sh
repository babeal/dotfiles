if mise_bin="$(command -v mise 2>/dev/null)"; then
    if [[ -n ${BASH} ]]; then
        eval "$("$mise_bin" activate bash)"
    elif [[ -n ${ZSH_NAME} ]]; then
        eval "$("$mise_bin" activate zsh)"
    fi
fi



