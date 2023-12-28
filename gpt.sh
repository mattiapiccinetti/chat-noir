#!/bin/bash

ESC_SEQUENCE="\033["
RESET_CURSOR_SEQUENCE="\r\033[K"
RESET_COLOR="${ESC_SEQUENCE}0m"
RED="${ESC_SEQUENCE}31m"
GREEN="${ESC_SEQUENCE}32m"
YELLOW="${ESC_SEQUENCE}33m"
BOLD="${ESC_SEQUENCE}1m"
CONFIG_FILE_PATH="config.ini"

function _echo_you() {
    echo -ne "${RED}YOU:${RESET_COLOR} $1"
}

function _echo_gpt() {
    echo -ne "${GREEN}GPT:${RESET_COLOR} $1"
}

function _echo_sys() {
    echo -e "${BOLD}SYS:${RESET_COLOR} $(_echo_type "$1")"
}

function _echo_type() {
    local text=$1
    local delay=0.001

    for (( i=0; i<${#text}; i++ )); do 
        echo -n "${text:$i:1}";
        sleep $delay
    done

    echo
}

_clean_env_config() {
    local file_path="$1"
    local old_IFS=$IFS

    while IFS='=' read -r key _ ; do
        [ -n "$key" ] && unset "$key"
    done < "$file_path"

    IFS=$old_IFS
}

function _reset_config() {
    _clean_env_config $CONFIG_FILE_PATH 
    cp defaults.ini $CONFIG_FILE_PATH

    _echo_sys "Your configurations have been reset."
    
    _init
}

function _load_config() {
    [ -f "$CONFIG_FILE_PATH" ] && source "$CONFIG_FILE_PATH" || _reset_config
}

function _remove_empty_lines() {
    local filename="$1"

    sed -i '' -e '/^\s*$/d' "$filename"
}

function _add_config() {
    local name="$1"
    local value="$2"

    echo -e "\n$name=\"$value\"\n" >> $CONFIG_FILE_PATH
}

function _check_or_save_api_key() {
    if [ -z "$OPENAI_API_KEY" ]; then
        _echo_sys "Type your OpenAI API key."
        _echo_you "" 
        read -r openai_api_key

        _add_config "OPENAI_API_KEY" "$openai_api_key" && \
        _remove_empty_lines "$CONFIG_FILE_PATH" && \
        _echo_sys "Your OpenAI API key has been saved."
    fi
    
    _load_config
}

function _get_data_content_from_chunk() {
    local data="$1"
    echo "$data" | jq -c -e "select(.choices[].delta.content != null) | .choices[].delta.content"
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
    local not_data_chunk=""

    while read -r chunk; do
        if [[ $chunk == "data: "* ]]; then
            completion_chunk=${chunk#data: }
            
            if echo "$completion_chunk" | jq -e . >/dev/null 2>&1; then
                response=$(_get_data_content_from_chunk "$completion_chunk") 
                response=$(_remove_first_last "$response")
                response=$(_remove_double_quotes "$response")
                
                echo -ne "$response"
            fi
        else
            not_data_chunk+="$chunk"
        fi
    done

    error_message=$(echo "$not_data_chunk" | jq -c -e "select(.error.message != null) | .error.message")
    clean_error_message=$(_remove_first_last "$error_message")
    
    _echo_type "$clean_error_message"
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
    local content="$1"

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
                        \"content\": \"$content\"
                    }
                ],
                \"stream\": true
            }" | _handle_chunks 
}


function _create_chat() {
    while true
    do
        _echo_you ""
        read -r user_prompt

        case $user_prompt in
        "")
            continue
            ;;
        
        "/help")
            _welcome
            ;;
        
        "/exit")
            _exit
            break
            ;;

        "/config")
            _echo_sys "Here's your configuration:"
            _echo_type "\`\`\`"
            _echo_type "$(cat $CONFIG_FILE_PATH)"
            _echo_type "\`\`\`"
            ;;
        
        "/reset")
            _reset_config
            ;;
        
        *)  
            _echo_gpt ""
            _create_chat_completions "$user_prompt"
            ;;
        esac
    done
}

function _help() {
    echo "not implemented"
    exit 1
}

function _init() {
    _load_config
    _check_or_save_api_key
}

function _exit() {
    _echo_sys "Bye!"
    exit;
}

function main() {
    _welcome
    _init && [ $# -gt 0 ] && _create_chat_completions "$1" || _create_chat
}

trap "echo; _exit" SIGINT SIGTERM

main "$@"