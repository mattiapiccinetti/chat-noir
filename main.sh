#!/bin/bash

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")

source "$SCRIPT_DIR/chat-noir.sh"

main "$@"
