# Saner Defaults
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias grep='grep --color=always'
alias cd..='cd ../'
alias ..='cd ../'
alias ...='cd ../../'
alias .3='cd ../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../../'
alias .6='cd ../../../../../../'
alias ~="cd ~"
alias kill='kill -9'
alias ax='chmod a+x'                      # system: make file executable
alias path='echo -e ${PATH//:/\\n}'       # system: Echo all executable Paths
alias shfmt="shfmt -ci -bn -i 2"          # dev: Preferred shellformat implementation
alias sc='shellcheck --exclude=2001,2148' # dev: Preferred shellcheck implementation


# Prefer `bat` over `cat` when installed
[[ "$(command -v bat)" ]] \
    && alias cat="bat"

# Prefer `htop` over `top` when installed
[[ "$(command -v htop)" ]] \
    && alias top="htop"

# Rebuild current shell environment when changes are made to dotfiles
if [[ -n ${BASH} ]]; then
    alias sourcea='source ${HOME}/.bash_profile' # system: Source .bash_profile or .zshrc
elif [[ -n ${ZSH_NAME} ]]; then
    alias sourcea='source ${HOME}/.zshrc' # system: Source .bash_profile or .zshrc
fi

