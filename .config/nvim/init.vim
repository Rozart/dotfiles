" NeoVim configuration

call plug#begin('~/.local/share/nvim/plugged')

" Surround stuff
Plug 'tpope/vim-surround'

" Vim start screen
Plug 'mhinz/vim-startify'

" Fuzzy search
Plug '/usr/local/opt/fzf'

" Goyo - distraction free writing
Plug 'junegunn/goyo.vim'

" Gruvbox Theme
Plug 'morhetz/gruvbox'

" Python Mode
Plug 'python-mode/python-mode', { 'branch': 'develop' }

Plug 'mattn/calendar-vim'

call plug#end()

" Enable line numbers
set number

# Set colors and the theme
set termguicolors
colorscheme gruvbox 

" Map the leader key to SPACE
let mapleader="\<SPACE>"

" Set other variables
let g:python3_host_prog = '~/.pyenv/versions/neovim3/bin/python'
let g:pymode_python = 'python3'

