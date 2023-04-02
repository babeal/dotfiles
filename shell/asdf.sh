
# ASDF Package Manager
# supposefly --prefix asdf requires ruby which makes it slow where --prefix is fast
local pkg_root=$(brew --prefix)
[[ -s "$pkg_root/opt/asdf/libexec/asdf.sh" ]] && source "$pkg_root/opt/asdf/libexec/asdf.sh"