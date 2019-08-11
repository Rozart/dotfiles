#If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# General variables
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TERM=xterm-256color

# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

# Plugins
plugins=(
    git
    docker
    zsh-syntax-highlighting
    zsh-autosuggestions
    zsh-completions
)

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

source $ZSH/oh-my-zsh.sh

# Additional imports
[ -f ~/.work.zsh ] && source ~/.work.zsh
[ -f ~/.aliases ] && source ~/.aliases

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

autoload -U promptinit; promptinit
prompt pure

export PATH=$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH
export PATH=/usr/local/opt/openssl/bin:$PATH
export PATH=/usr/local/opt/curl/bin:$PATH
export PATH=/usr/local/opt/curl-openssl/bin:$PATH
export CLOUDSDK_PYTHON=$(which python2)

export EMACS="*term*"

export BAT_THEME="gruvbox-dark"

# For compilers to find zlib you may need to set:
export LDFLAGS="${LDFLAGS} -L/usr/local/opt/zlib/lib"
export CPPFLAGS="${CPPFLAGS} -I/usr/local/opt/zlib/include"
# For pkg-config to find zlib you may need to set:
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}/usr/local/opt/zlib/lib/pkgconfig

# Initialize pyenv
eval "$(pyenv init -)"
