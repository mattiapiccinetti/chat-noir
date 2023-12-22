#!/bin/bash

ESC_SEQUENCE="\033["
RESET_CURSOR_SEQUENCE="\r\033[K"
RESET_COLOR="${ESC_SEQUENCE}0m"
RED="${ESC_SEQUENCE}31m"
GREEN="${ESC_SEQUENCE}32m"
YELLOW="${ESC_SEQUENCE}33m"
BOLD="${ESC_SEQUENCE}1m"


trap "echo -e '\n\n:: Bye!\n'; exit" SIGINT SIGTERM

function _load_settings() {
    [ -f "settings.ini" ] && source "settings.ini" || source "default.ini"
    _check_or_save_api_key
}

function _check_or_save_api_key() {
    if [ -z "$OPENAI_API_KEY" ]; then
        echo
        echo -ne "Type your OpenAI API key: "
        read -r openai_api_key

        echo "OPENAI_API_KEY=\"$openai_api_key\"" >> settings.ini
        echo -e "${BOLD}SYS: ${RESET_COLOR}Your OpenAI API key has been saved."
        echo
        OPENAI_API_KEY=$openai_api_key
    fi
}

function _get_content_from_chunk() {
    local data="$1"
    echo "$1" | jq -c -e "select(.choices[].delta.content != null) | .choices[].delta.content"
}

function _remove_first_last() {
    local data="$1"
    echo "${data:1:${#data}-2}"
}

function _remove_double_quotes() {
    local data="$1"
    echo "${data//\\\"/\"}"

}

function _handle_chunks() {
    while read -r chunk; do
        if [[ $chunk == "data: "* ]]; then
            completion_chunk=${chunk#data: }
            
            if echo "$completion_chunk" | jq -e . >/dev/null 2>&1; then
                reponse=$(_get_content_from_chunk "$completion_chunk") 
                reponse=$(_remove_first_last "$reponse")
                reponse=$(_remove_double_quotes "$reponse")
                
                echo -ne "$reponse"
            fi
        else
            echo -ne "$chunk"
        fi
    done

    echo
}

function _welcome() {
    echo
    echo -e ":: Welcome to ${BOLD}MAYBE-GPT${RESET_COLOR}."
    echo -e ":: This application is made by Peach of Persia."
    echo -e ":: Type \"/help\" to display this text again."
    echo -e ":: Press CTRL+C to exit."
    echo
}

function _create_chat_completions() {
    CONTENT="$1"
    curl $OPENAI_API_URL \
            --no-buffer \
            --silent \
            --show-error \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer $OPENAI_API_KEY" \
            --data "{
                \"model\": \"$OPENAI_MODEL\",
                \"messages\": [
                    {
                        \"role\": \"system\",
                        \"content\": \"$OPENAI_ROLE_SYSTEM_CONTENT\"
                    },
                    {
                        \"role\": \"user\",
                        \"content\": \"$CONTENT\"
                    }
                ],
                \"stream\": true
            }" | _handle_chunks 
}


function _create_chat() {
    _welcome

    while true
    do
        echo -ne "${RED}YOU: ${RESET_COLOR}"
        read -r user_prompt

        case $user_prompt in
        "")
            continue
            ;;
        
        "/help")
            welcome
            ;;
        
        "/exit")
            break
            ;;
        "/model")
            echo $OPENAI_MODEL
            ;;
        
        "/settings")
            cat settings.ini
            echo
            ;;
        
        "/reset-settings")
            cp defaults.ini settings.ini
            echo -e "${BOLD}SYS: ${RESET_COLOR}Your settings have been reset. You need to restart the application."
            ;;
        
        *)  
            echo -ne "${GREEN}GPT: ${RESET_COLOR}"
            _create_chat_completions "$user_prompt"
            ;;
        esac
    done
}

function main() {
    _load_settings

    [ $# -gt 0 ] && _create_chat_completions "$1" || _create_chat
}

main "$@"
