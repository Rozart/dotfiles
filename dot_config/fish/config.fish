if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Internal-only variables
set OPEN_SSL_BIN /usr/local/opt/openssl/bin
set CURL_BIN /usr/local/opt/curl/bin
set CURL_OPENSSL_BIN /usr/local/opt/curl-openssl/bin

set BIN $HOME/bin
set LOCAL_BIN /usr/local/bin
set SBIN /usr/local/sbin
set HOMEBREW_BIN /opt/homebrew/bin
set TOOLS $HOME/Tools

# Only export PATH
set -gx PATH \
    $BIN \
    $LOCAL_BIN \
    $SBIN \
    $HOMEBREW_BIN \
    $TOOLS \
    $OPEN_SSL_BIN \
    $CURL_BIN \
    $CURL_OPENSSL_BIN \
    $PATH

# General variables
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx EDITOR nvim
set -gx EMACS /opt/homebrew/bin/emacs

set -fx FZF_DEFAULT_COMMAND 'fd --type file'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND

set -gx LDFLAGS "$LDFLAGS -L/usr/local/opt/zlib/lib"
set -gx CPPFLAGS "$CPPFLAGS -I/usr/local/opt/zlib/include"
set -gx PKG_CONFIG_PATH "$PKG_CONFIG_PATH /usr/local/opt/zlib/lib/pkgconfig"

set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml

fish_vi_key_bindings
set fish_greeting

set -gx GITCONFIG_WORK ~/.config/git/.gitconfig_work
set -gx GITCONFIG_PRIVATE ~/.config/git/.gitconfig_private

if test -f ~/.api_keys
    source ~/.api_keys
end

if test -f ~/.aliases
    source ~/.aliases
end

zoxide init fish | source
starship init fish | source
~/.local/bin/mise activate fish | source
