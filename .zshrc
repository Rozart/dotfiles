#If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# General variables
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh
export ZSH_CUSTOM=~/.oh-my-zsh-custom
#
# Set ZSH theme
export ZSH_THEME="spaceship"
export SPACESHIP_CONFIG="$HOME/.spaceshiprc.zsh"

# Plugins
plugins=(
    emacs
    git
    docker
    ripgrep
    fzf
    zsh-syntax-highlighting
    zsh-autosuggestions
    zsh-completions
    gcloud
    nvm
)

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

source $ZSH/oh-my-zsh.sh

# Additional imports
[ -f ~/.work.zsh ] && source ~/.work.zsh
[ -f ~/.aliases ] && source ~/.aliases
[ -f ~/.api_keys ] && source ~/.api_keys

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH=$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH
export PATH=/usr/local/opt/openssl/bin:$PATH
export PATH=/usr/local/opt/curl/bin:$PATH
export PATH=/usr/local/opt/curl-openssl/bin:$PATH
export PATH=$HOME/.jenv/bin/$PATH
export CLOUDSDK_PYTHON=$(which python2)

export TOOLS=$HOME/Tools

export GCLOUD_HOME=$TOOLS/google-cloud-sdk
export PATH=$GCLOUD_HOME/bin:$PATH
export CLOUDSDK_PYTHON=$(which python3)

export PATH=$TOOLS:$PATH

export EMACS="*term*"

export BAT_THEME="gruvbox-dark"

# For compilers to find zlib you may need to set:
export LDFLAGS="${LDFLAGS} -L/usr/local/opt/zlib/lib"
export CPPFLAGS="${CPPFLAGS} -I/usr/local/opt/zlib/include"
# For pkg-config to find zlib you may need to set:
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}/usr/local/opt/zlib/lib/pkgconfig

# Initialize pyenv
eval "$(pyenv init -)"
# Initialize jenv
eval "$(jenv init -)"

export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh


export PATH="/usr/local/sbin:$PATH"

[ -f ~/.data_engineer ] && source ~/.data_engineer
[ -f ~/.completions ] && source ~/.completions


export PATH="$HOME/.poetry/bin:$PATH"
export PATH="$PATH:/Users/rozart/.foundry/bin"
export PATH="/Users/rozart/.local/share/solana/install/active_release/bin:$PATH"


# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

# pnpm
export PNPM_HOME="/Users/rozart/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
