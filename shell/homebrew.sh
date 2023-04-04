if command -v brew &>/dev/null; then

    # Don't send analytics data
    export HOMEBREW_NO_ANALYTICS=1

    # Set homebrew paths for GNU utilities
    _homebrewPaths=(
        "/opt/homebrew/opt/coreutils/libexec/gnubin"
        "/opt/homebrew/opt/findutils/libexec/gnubin"
        "/opt/homebrew/opt/gnu-getopt/bin"
        "/opt/homebrew/opt/gnu-sed/libexec/gnubin"
        "/opt/homebrew/opt/gnu-tar/libexec/gnubin"
        "/opt/homebrew/opt/grep/libexec/gnubin"
        "/usr/local/opt/coreutils/libexec/gnubin"
        "/usr/local/opt/findutils/libexec/gnubin"
        "/usr/local/opt/gnu-getopt/bin"
        "/usr/local/opt/gnu-sed/libexec/gnubin"
        "/usr/local/opt/gnu-tar/libexec/gnubin"
        "/usr/local/opt/grep/libexec/gnubin"
        "/usr/local/sbin"
    )

    for _path in "${_homebrewPaths[@]}"; do
        if [[ -d ${_path} ]]; then
            if ! printf "%s" "${_path}" | grep -q "${PATH}"; then
                PATH="${_path}:${PATH}"
            fi
        fi
    done

    local brew_root
    brew_root=$(brew --repository)

    if [[ -e "${brew_root}/bin/brew" ]]; then
        eval "$(${brew_root}/bin/brew shellenv)"
    fi

    if [[ -n ${BASH} ]] && [ -f "/usr/local/etc/profile.d/bash_completion.sh" ]; then
        source "/usr/local/etc/profile.d/bash_completion.sh"
    fi

    if [ -f "$(brew --repository)/bin/src-hilite-lesspipe.sh" ]; then
        export LESSOPEN
        LESSOPEN="| $(brew --repository)/bin/src-hilite-lesspipe.sh %s"
        export LESS=' -R -z-4'
    fi

    # /Applications is now the default but leaving this for posterity
    export HOMEBREW_CASK_OPTS="--appdir=/Applications"

    # Fix common typo
    alias brwe='brew'

fi
