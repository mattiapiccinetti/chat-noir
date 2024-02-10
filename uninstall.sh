#!/bin/bash

set -e

ABSOLUTE_SCRIPT_PATH=$(readlink -f "/usr/local/bin/chat-noir")
ABSOLUTE_SCRIPT_DIR=$(dirname -- "$ABSOLUTE_SCRIPT_PATH")

echo
echo " - Deleting local folder"
rm -rf "$ABSOLUTE_SCRIPT_DIR"

echo " - Removing symlink (password may be required)"
sudo rm /usr/local/bin/chat-noir

echo
echo " CHAT-NOIR has been uninstalled. Thanks for trying it out."
echo
