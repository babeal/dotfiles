#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

# shellcheck disable=SC2016
declare -r DOTFILES_LOGO='
             /$$             /$$      /$$$$$$  /$$ /$$                    
            | $$            | $$     /$$__  $$|__/| $$                    
        /$$$$$$$  /$$$$$$  /$$$$$$  | $$  \__/ /$$| $$  /$$$$$$   /$$$$$$$
       /$$__  $$ /$$__  $$|_  $$_/  | $$$$    | $$| $$ /$$__  $$ /$$_____/
      | $$  | $$| $$  \ $$  | $$    | $$_/    | $$| $$| $$$$$$$$|  $$$$$$ 
      | $$  | $$| $$  | $$  | $$ /$$| $$      | $$| $$| $$_____/ \____  $$
      |  $$$$$$$|  $$$$$$/  |  $$$$/| $$      | $$| $$|  $$$$$$$ /$$$$$$$/
       \_______/ \______/    \___/  |__/      |__/|__/ \_______/|_______/ 
'

declare -r DOTFILES_REPO_URL="https://github.com/babeal/dotfiles"
declare -r BRANCH_NAME="${BRANCH_NAME:-main}"


function is_ci() {
    "${CI:-false}"
}

function is_tty() {
    [ -t 0 ]
}

function is_not_tty() {
    ! is_tty
}

function is_ci_or_not_tty() {
    is_ci || is_not_tty
}

function at_exit() {
    AT_EXIT+="${AT_EXIT:+$'\n'}"
    AT_EXIT+="${*?}"
    # shellcheck disable=SC2064
    trap "${AT_EXIT}" EXIT
}

function get_os_type() {
    uname
}

function keepalive_sudo_linux() {
    # Might as well ask for password up-front, right?
    echo "Checking for \`sudo\` access which may request your password."
    sudo -v

    # Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

function keepalive_sudo_macos() {
    # ref. https://github.com/reitermarkus/dotfiles/blob/master/.sh#L85-L116
    (
        builtin read -r -s -p "Password: " </dev/tty
        builtin echo "add-generic-password -U -s 'dotfiles' -a '${USER}' -w '${REPLY}'"
    ) | /usr/bin/security -i
    printf "\n"
    at_exit "
                echo -e '\033[0;31mRemoving password from Keychain …\033[0m'
                /usr/bin/security delete-generic-password -s 'dotfiles' -a '${USER}'
            "
    SUDO_ASKPASS="$(/usr/bin/mktemp)"
    at_exit "
                echo -e '\033[0;31mDeleting SUDO_ASKPASS script …\033[0m'
                /bin/rm -f '${SUDO_ASKPASS}'
            "
    {
        echo "#!/bin/sh"
        echo "/usr/bin/security find-generic-password -s 'dotfiles' -a '${USER}' -w"
    } >"${SUDO_ASKPASS}"

    /bin/chmod +x "${SUDO_ASKPASS}"
    export SUDO_ASKPASS

    if ! /usr/bin/sudo -A -kv 2>/dev/null; then
        echo -e '\033[0;31mIncorrect password.\033[0m' 1>&2
        exit 1
    fi
}

function keepalive_sudo() {

    local ostype
    ostype="$(get_os_type)"

    if [ "${ostype}" == "Darwin" ]; then
        keepalive_sudo_macos
    elif [ "${ostype}" == "Linux" ]; then
        keepalive_sudo_linux
    else
        echo "Invalid OS type: ${ostype}" >&2
        exit 1
    fi
}

# function set_rc_files() {
#     echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
#     echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.zshrc
# }

function is_homebrew_exists() {
    command -v brew &>/dev/null
}

function initialize_os_macos() {
    # Install Homebrew if needed.
    if ! is_homebrew_exists; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

function initialize_os_linux() {
    # Install Homebrew if needed.
    if ! is_homebrew_exists; then
        sudo apt-get update -q
        sudo apt-get install -y build-essential procps curl file git

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}

function install_packages() {
    # Install Chezmoi
    if ! command -v chezmoi &>/dev/null; then
        brew install chezmoi
    fi
}

function initialize_os_env() {
    local ostype
    ostype="$(get_os_type)"

    if [ "${ostype}" == "Darwin" ]; then
        initialize_os_macos
    elif [ "${ostype}" == "Linux" ]; then
        initialize_os_linux
    else
        echo "Invalid OS type: ${ostype}" >&2
        exit 1
    fi
    install_packages
}

function run_chezmoi() {
    local chezmoi_cmd
    chezmoi_cmd="$(command -v chezmoi)"

    if is_ci_or_not_tty; then
        no_tty_option="--no-tty" # /dev/tty is not available (especially in the CI)
    else
        no_tty_option="" # /dev/tty is available OR not in the CI
    fi

    local source_dir="${HOME}/.local/share/chezmoi"

    if [ -d "${source_dir}" ] && [ -n "$(ls -A "${source_dir}" 2>/dev/null)" ]; then
        # Source dir is pre-populated (e.g. rsync'd for testing).
        # Use chezmoi init without a URL — mirrors setup-parallels.sh.
        # chezmoi will create an empty .git in the source dir if needed (harmless).

        # the `age` command requires a tty, but there is no tty in the github actions.
        # Therefore, it is currently difficult to decrypt the files encrypted with `age` in this workflow.
        # I decided to temporarily remove the encrypted target files from chezmoi's control.
        if is_ci_or_not_tty; then
            find "${source_dir}" -type f -name "encrypted_*" -exec rm -fv {} +
        fi

        "${chezmoi_cmd}" init --apply --force ${no_tty_option}
    else
        # Fresh install — clone from remote (standard production path).
        "${chezmoi_cmd}" init "${DOTFILES_REPO_URL}" \
            --force \
            --branch "${BRANCH_NAME}" \
            --use-builtin-git true \
            ${no_tty_option}

        if is_ci_or_not_tty; then
            find "$(${chezmoi_cmd} source-path)" -type f -name "encrypted_*" -exec rm -fv {} +
        fi

        "${chezmoi_cmd}" apply ${no_tty_option}
    fi
}

function initialize_dotfiles() {

    if ! is_ci_or_not_tty; then
        # - /dev/tty of the github workflow is not available.
        # - We can use password-less sudo in the github workflow.
        # Therefore, skip the sudo keep alive function.
        keepalive_sudo
    fi
    run_chezmoi
}

function restart_shell() {

    # Restart shell if specified "bash -c $(curl -L {URL})"
    # not restart:
    #   curl -L {URL} | bash
    if [ -p /dev/stdin ]; then
        echo "Now continue with Rebooting your shell"
    else
        echo "Restarting your shell..."
        exec /bin/zsh --login
    fi
}

function main() {
    echo "${DOTFILES_LOGO}"

    initialize_os_env
    initialize_dotfiles

    # restart_shell # Disabled because the at_exit function does not work properly.
}

main
