
# ASDF Package Manager
local asdfInstall="/usr/local/opt/asdf" # $(brew --prefix asdf)
[[ -s "$asdfInstall/asdf.sh" ]] && source "$asdfInstall/asdf.sh"
[[ -s "$asdfInstall/etc/completions/asdf.bash" ]] && source "$asdfInstall/etc/completions/asdf.bash"