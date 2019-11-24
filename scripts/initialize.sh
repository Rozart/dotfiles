#!/usr/bin/env bash

# Initialize nvim plugin manager
echo "Downloading the vim-plug - A plugin manager for nvim"
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
