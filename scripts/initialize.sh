#!/usr/bin/env bash

# Initialize nvim plugin manager
echo "Downloading the vim-plug - A plugin manager for nvim"
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

firefox_profile_dir=~/Library/ApplicationSupport/Firefox/Profiles/default-firefox-profile/
echo "Copying Firefox style settings"
mkdir -p $firefox_profile_dir/chrome
cp ~/scripts/resources/userChrome.css ~/Library/ApplicationSupport/Firefox/Profiles/default-firefox-profile/chrome/userChrome.css
echo "After it's done: "
echo "1. Open Firefox"
echo "2. Go to 'about:config'"
echo "3. Search for 'toolkit.legacyUserProfileCustomizations.stylesheets'"
echo "4. Double-click to change it's value to 'true'"
