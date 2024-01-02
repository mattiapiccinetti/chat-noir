#!/bin/bash

APPLICATION_NAME="CHAT-NOIR"
APPLICATION_VERSION="0.0.1"
DEFAULT_CONFIG_FILE_PATH="defaults.ini"
CONFIG_FILE_PATH="config.ini"
HISTORY_FILE_PATH="history.jsonl"

ESC_SEQUENCE="\033["
RESET_CURSOR_SEQUENCE="\r${ESC_SEQUENCE}K"
RESET_COLOR="${ESC_SEQUENCE}0m"
RED="${ESC_SEQUENCE}31m"
GREEN="${ESC_SEQUENCE}32m"
BLUE="${ESC_SEQUENCE}0;34m"
CYAN="${ESC_SEQUENCE}36m"
MAGENTA="${ESC_SEQUENCE}35m"
YELLOW="${ESC_SEQUENCE}33m"
BOLD="${ESC_SEQUENCE}1m"

function echo_you() {
    echo -ne "${RED}YOU:${RESET_COLOR} $1"
}

function echo_gpt() {
    echo -ne "${GREEN}GPT:${RESET_COLOR} $1"
}

function echo_sys() {
    local custom_tab="     "

    for parameter in "$@"; do
        if [[ "$parameter" == "$1" ]]; then
            echo -ne "${BOLD}SYS:${RESET_COLOR} "
            echo_type "$1"
        else
            echo_type "$custom_tab$parameter"
        fi
    done
}

function echo_yes_no() {
    echo -ne "${MAGENTA}Y/N:${RESET_COLOR} "
    echo_type "$1"
}

function echo_key() {
    echo -e "${MAGENTA}KEY:${RESET_COLOR} $1"
}

function echo_type() {
    local text=$1
    local delay=${2:-0.001}

    for (( i=0; i<${#text}; i++ )); do 
        if [[ "${text:$i:1}" == "\\" ]]; then
            echo -ne "${text:$i:2}";
            ((i++))
        else
            echo -n "${text:$i:1}";
        fi

        sleep $delay
    done

    echo
}

function echo_config() {
    local delay="0.0001"

    echo_sys "Here's your configuration:"
    echo_type "\`\`\`" $delay
    echo_type "$(cat $CONFIG_FILE_PATH)" $delay
    echo_type "\`\`\`" $delay
}

function clean_env_config() {
    local file_path="$1"
    local old_IFS=$IFS

    while IFS='=' read -r key _ ; do
        [[ -n "$key" ]] && unset "$key"
    done < "$file_path"

    IFS=$old_IFS
}

function reset_config() {
    clean_env_config $CONFIG_FILE_PATH 
    cp "$DEFAULT_CONFIG_FILE_PATH" $CONFIG_FILE_PATH
    load_config        
    
    echo_sys "Your configurations have been reset to default."
}

function load_config() {
    [[ -f "$CONFIG_FILE_PATH" ]] && source "$CONFIG_FILE_PATH" || reset_config
}

function ask_to_reset_config() {
    echo_sys \
        "Your configurations will be reset to default." \
        "Do you want to proceed? [Yes/No] or Enter to skip."
    read -e -r -p "$(echo_yes_no)" reply

    reply=$(to_lower "$reply")
    ([[ "$reply" == "y" ]] || [[ "$reply" == "yes" ]]) \
        && reset_config \
        || echo_sys "Ok, no prob."
}

function remove_empty_lines() {
    local filename="$1"

    sed -i '' -e '/^\s*$/d' "$filename"
}

function to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

function add_config() {
    local name="$1"
    local value="$2"

    echo -e "\n$name=\"$value\"\n" >> $CONFIG_FILE_PATH
    remove_empty_lines "$CONFIG_FILE_PATH"
}

function check_and_save_openai_api_key() {
    if [[ -z "$OPENAI_API_KEY" ]]; then
        echo_sys \
            "It seems you haven't entered your OpenAI API key yet." \
            "Please type a valid API key to proceed. [Press Enter to skip]"
         
        read -e -r -p "$(echo_key)" openai_api_key

        if [[ -n "$openai_api_key" ]]; then
            add_config "OPENAI_API_KEY" "$openai_api_key"
            echo_sys "Your OpenAI API key has been saved."
            
            OPENAI_API_KEY="$openai_api_key"
        else
            echo_sys "Ok, no prob."
        fi
    fi
}

function get_data_content_from_chunk() {
    echo "$1" | jq -c -e "select(.choices[].delta.content != null) | .choices[].delta.content"
}

function remove_first_last() {
    local data="$1"
    
    echo "${data:1:${#data}-2}"
}

function remove_double_quotes() {
    local data="$1"

    echo "${data//\\\"/\"}"
}

function echo_completion_chunk() {
    local completion_chunk="$1"
    local response

    response=$(get_data_content_from_chunk "$completion_chunk") 
    response=$(remove_first_last "$response")
    response=$(remove_double_quotes "$response")
    
    echo -ne "$response"
}

function get_openai_error_message() {
    local error_message
    
    error_message=$(echo "$1" | jq -c -e "select(.error.message != null) | .error.message")
    error_message=$(remove_first_last "$error_message")
    echo "$error_message"
}

function get_openai_error_code() {
    local error_code
    
    error_code=$(echo "$1" | jq -c -e "select(.error.code != null) | .error.code")
    error_code=$(remove_first_last "$error_code")

    echo "$error_code"
}

function handle_chunks() {
    local data_chunk
    local error_response

    while read -r chunk; do
        if [[ $chunk == "data: "* ]]; then
            completion_chunk=${chunk#data: }
            
            if echo "$completion_chunk" | jq -e . >/dev/null 2>&1; then
                data_chunk+=$(echo_completion_chunk "$completion_chunk")
                echo_completion_chunk "$completion_chunk"
            fi
        else
            error_response+="$chunk"
        fi
    done

    if [[ -n "$error_response" ]]; then
        echo_type "$(get_openai_error_message "$error_response")"
        
        if [[ "$(get_openai_error_code "$error_response")" == "invalid_api_key" ]]; then
            echo_sys "Type '/reset' to reset all configurations and add a new one."
        fi
    else
        echo ""
        save_message_to_history "assistant" "$data_chunk"
    fi
}

function welcome() {
    echo
    echo -e "  :: Welcome to ${BOLD}$APPLICATION_NAME $APPLICATION_VERSION${RESET_COLOR}."
    echo -e "  :: This application is made by Peach of Persia."
    echo -e "  :: Type \"/help\" for more information."
    echo -e "  :: Press CTRL+C to exit."
    echo
}

function create_json_message() {
    local role="$1"
    local content="$2"

    jq -c -n --arg ROLE "$role" --arg CONTENT "$content" '{"role": $ROLE, "content": $CONTENT}'
}

function save_message_to_history() {
    local role="$1"
    local content="$2"
    
    echo "$(create_json_message "$role" "$content")" | jq -c >> "$HISTORY_FILE_PATH"
}

function create_openai_payload_from_history() {
    local content="$1"
    local openai_json_payload=$(jq -n \
            --arg OPENAI_MODEL "$OPENAI_MODEL" \
            --arg OPENAI_ROLE_SYSTEM_CONTENT "$OPENAI_ROLE_SYSTEM_CONTENT" \
            '{"model": $OPENAI_MODEL, "messages": [], "stream": true}')

    save_message_to_history "user" "$content"
    
    while IFS= read -r json_message || [[ -n "$json_message" ]]; do
        openai_json_payload=$(
            echo "$openai_json_payload" \
                | jq --argjson json_message "$json_message" '.messages += [$json_message]')
    done < "$HISTORY_FILE_PATH"

    echo "$openai_json_payload"
}

function create_chat_completions() {
    local content="$1"
    local openai_json_payload=$(create_openai_payload_from_history "$content")

    curl $OPENAI_API_URL \
            --no-buffer \
            --silent \
            --show-error \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer $OPENAI_API_KEY" \
            --data "$openai_json_payload" \
        | handle_chunks
}

function get_openai_response() {
    local prompt=$1
    
    check_and_save_openai_api_key
    echo_gpt ""
    create_chat_completions "$prompt"
}

function create_chat() {
    while true
    do
        read -e -r -p "$(echo_you)" user_prompt

        case $user_prompt in
        "")         continue ;;
        "/help")    help ;;
        "/config")  echo_config ;;
        "/reset")   ask_to_reset_config ;;
        "/welcome") welcome ;;
        "/exit")    handle_exit ;;
        "/history") show_history ;;
        *)          get_openai_response "$user_prompt" ;;
        esac
    done
}

function help() {
    local delay="0.0001"
    
    echo_sys "Here's the list of commands:"
    
    echo_type ""
    echo_type "  /help          Show the help menu" $delay
    echo_type "  /config        Show the custom configurations" $delay
    echo_type "  /reset         Reset the configurations to default" $delay
    echo_type "  /welcome       Show the welcome message" $delay
    echo_type "  /history       Show the conversation history so far as JSON" $delay
    echo_type "  /exit          Exit from the application" $delay
    echo_type ""
}

function show_history() {
    echo_sys "Here's your conversation history:"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        echo_type "$line"    
    done < "$HISTORY_FILE_PATH"    
}

function clear_history() {
    truncate -s 0 "$HISTORY_FILE_PATH"
}

function init() {
    clear_history
    save_message_to_history "system" "$OPENAI_ROLE_SYSTEM_CONTENT"
    load_config
    check_and_save_openai_api_key
}

function handle_exit() {
    echo_sys "Bye!"
    exit 0
}

function main() {
    welcome
    init
    
    [[ $# -gt 0 ]] && create_chat_completions "$1" || create_chat
}

trap "echo; handle_exit" SIGINT SIGTERM

main "$@"
