#!/usr/bin/env bash

# If not running interactively, don't do anything
case $- in
  *i*) ;;
  *) return ;;
esac
[ -z "$PS1" ] && return

# set default umask
umask 002

# Build PATH and put /usr/local/bin before existing PATH
export PATH="/usr/local/bin:${PATH}:/usr/local/sbin:${HOME}/bin:${HOME}/.local/bin"

### SOURCE BASH PLUGINS ###

# Locations containing files *.bash to be sourced to your environment
configFileLocations=(
  "${HOME}/dotfiles/shell"
  "${HOME}/dotfiles-private/shell"
)

# Set a shell variable so we can customize the config files
currentShell="$(ps -p $$ | tail -n 1 | awk -F' ' '{print $4}' | sed 's/-//g')"

for configFileLocation in "${configFileLocations[@]}"; do
  if [ -d "${configFileLocation}" ]; then
    while read -r configFile; do
      source "${configFile}"
    done < <(find "${configFileLocation}" \
      -maxdepth 1 \
      -type f \
      -name '*.bash' \
      -o -name '*.sh' \
      | sort)
  fi
done

unset currentShell

# Always list directory contents upon 'cd'.
# (Somehow this always failed when I put it in a sourced file)
cd() {
  builtin cd "$@"
  ll
}
