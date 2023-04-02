#!/usr/bin/env bash

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return ;;
esac
[ -z "$PS1" ] && return

# Location of this repository
REPO_ROOT="${HOME}/dev"

# Locations containing files *.bash to be sourced to your environment
configFileLocations=(
    "${REPO_ROOT}/dotfiles/shell"
    "${REPO_ROOT}/dotfiles-private/shell"
)

# set default umask
umask 002

# Build PATH
_myPaths=(
    "${HOME}/.local/bin"
    "/usr/local/bin"
    "/opt/homebrew/bin"
    "${HOME}/bin"
)

for _path in "${_myPaths[@]}"; do
    if [[ -d ${_path} ]]; then
        if ! printf "%s" "${_path}" | grep -q "${PATH}"; then
            PATH="${_path}:${PATH}"
        fi
    fi
done

### SOURCE BASH PLUGINS ###

for configFileLocation in "${configFileLocations[@]}"; do
    if [ -d "${configFileLocation}" ]; then
        while read -r configFile; do
            # shellcheck disable=SC1090
            source "${configFile}"
        done < <(find "${configFileLocation}" \
            -maxdepth 1 \
            -type f \
            -name '*.bash' \
            -o -name '*.sh' \
            | sort)
    fi
done

# Always list directory contents upon 'cd'.
# (Somehow this always failed when I put it in a sourced file)
cd() {
    builtin cd "$@" || return
    ll
}

if [ -f "${HOME}/.dotfiles.local" ]; then
    # shellcheck disable=SC1091
    source "${HOME}/.dotfiles.local"
fi
