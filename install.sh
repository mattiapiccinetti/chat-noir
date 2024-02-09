#!/bin/sh

set -e

DIR_NAME="chat-noir"
RAW_GITHUB_URL="https://raw.githubusercontent.com/mattiapiccinetti/chat-noir/main"

echo
echo "- Creating local folder"
mkdir -p "$DIR_NAME"

echo "- Downloading"
curl \
    --silent \
    --output "$DIR_NAME/chat-noir.sh" "$RAW_GITHUB_URL/chat-noir.sh" \
    --output "$DIR_NAME/main.sh" "$RAW_GITHUB_URL/main.sh" \
    --output "$DIR_NAME/defaults.ini" "$RAW_GITHUB_URL/defaults.ini"

echo "- Applying permissions"
chmod +x "$DIR_NAME/main.sh"

echo "- Symlinking (password may be required)"
sudo ln -sf "$(pwd)/$DIR_NAME/main.sh" "/usr/local/bin/chat-noir"

echo
echo ":: CHAT-NOIR has been installed into '$(pwd)/$DIR_NAME'."
echo
echo ":: Type 'chat-noir' to start."
echo
