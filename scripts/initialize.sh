#!/usr/bin/env bash

# Create a temp directory
temp_dir=~/scripts/.temp
mkdir -p $temp_dir

printf "\n"

# Initialize nvim plugin manager
printf "Downloading the vim-plug - A plugin manager for nvim\n"
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

printf "\n"

# Initialize styles for Firefox
firefox_profile_dir=~/Library/ApplicationSupport/Firefox/Profiles/default-firefox-profile/
printf "Copying Firefox style settings\n"
mkdir -p $firefox_profile_dir/chrome
cp ~/scripts/resources/userChrome.css ~/Library/ApplicationSupport/Firefox/Profiles/default-firefox-profile/chrome/userChrome.css
printf "After it's done: \n" 
printf "1. Open Firefox\n"
printf "2. Go to 'about:config'\n"
printf "3. Search for 'toolkit.legacyUserProfileCustomizations.stylesheets'\n"
printf "4. Double-click to change it's value to 'true'\n"

printf "\n"

# Install Dash - documentation explorer
dash_app_path=$HOME/Applications/Dash.app
if [ -d $dash_app_path ]; then
  printf "Dash.app already exists in ~/Applications\n"
else
  dash_download_url=https://london.kapeli.com/downloads/v5/Dash.zip
  wget $dash_download_url -O $temp_dir/Dash.zip
  unzip $temp_dir/Dash.zip -d $temp_dir/
  mv $temp_dir/Dash.app $dash_app_path
fi


# Remove the temp directory
rm -rf $temp_dir
