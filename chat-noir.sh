#!/bin/bash

APPLICATION_NAME="CHAT-NOIR"
APPLICATION_VERSION="0.0.1"

DEFAULT_CONFIG_FILENAME="defaults.ini"
CONFIG_FILENAME="config.ini"
MESSAGE_HISTORY=".history.jsonl"
LAST_MESSAGE_BUFFER=".last_message.tmp"
FAKE_OPENAI_RESPONSE_FILENAME=".fake_openai_response"

CURL_WRITE_OUT_PREFIX="http_code:"
CODE_BLOCK_SYMBOL="\`\`\`"
SYS_MESSAGE_NOOP="Ok."
SYS_MESSAGE_DONE="Done."

ESC_SEQUENCE="\033["
RESET_COLOR="${ESC_SEQUENCE}0m"
GREEN="${ESC_SEQUENCE}32m"
MAGENTA="${ESC_SEQUENCE}35m"
YELLOW="${ESC_SEQUENCE}33m"
BOLD="${ESC_SEQUENCE}1m"

function map() {
    local function_name="$1"
    
    while IFS= read -r -e parameter; do
        $function_name "$parameter"
    done
}

function has_no_blanks() {
    if [[ "$1" =~ " " ]]; then
        return 1
    fi
}

function is_not_empty() {
    if [[ -z "$1" ]]; then
        return 1
    fi
}

function remove_empty_lines() {
    sed -i '' -e '/^\s*$/d' "$1"
}

function to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

function to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

function remove_first_char() {
    local data="$1"
    
    if is_not_empty "$data"; then
        echo "${data:1}"
    else
        echo "$data"
    fi
}

function remove_last_char() {
    local data="$1"
    
    if is_not_empty "$data"; then
        echo "${data:0:${#data} - 1}"
    else
        echo "$data"
    fi
}

function unescape_double_quotes() {
    local data="$1"

    echo "${data//\\\"/\"}"
}

function is_valid_json() {
    if ! echo "$1" | jq -e . >/dev/null 2>&1; then
        return 1
    fi
}

function is_last_chunk() {
    if [[ ! "$completion_chunk" == "[DONE]" ]]; then
        return 1
    fi
}

function append_newline() {
    echo -ne "\n"
}

function is_error() {
    if [[ "$1" != "$CURL_WRITE_OUT_PREFIX 4"* ]]; then
        return 1
    fi
}

function is_data() {
    if [[ "$1" != "data: "* ]]; then
        return 1
    fi
}

function delete_file() {
    local filename="$1"
    
    [[ -f "$filename" ]] && rm "$filename"
}

function echo_you() {
    echo -ne "${GREEN}YOU: ${RESET_COLOR}"
}

function echo_gpt() {
    echo -ne "${MAGENTA}GPT: ${RESET_COLOR}"
}

function echo_sys() {
    echo -ne "${BOLD}SYS: ${RESET_COLOR}"
    echo_type "$1"
}

function echo_ask() {
    local content="$1"

    content=$(to_upper "${content:0:3}")
    echo -ne "${YELLOW}$content: ${RESET_COLOR}"
}

function echo_type() {
    local text=$1
    local delay=${2:-0.001}

    if [[ "$delay" == "0" ]]; then
        echo -ne "$text"
    else
        for (( i=0; i<${#text}; i++ )); do 
            if [[ "${text:$i:1}" == "\\" ]]; then
                echo -ne "${text:$i:2}";
                ((i++))
            else
                echo -ne "${text:$i:1}";
            fi

            sleep "$delay"
        done
    fi

    echo
}

function show_config() {
    echo_sys "Here's your configuration:"
    echo "$CODE_BLOCK_SYMBOL"
    cat "$CONFIG_FILENAME"
    echo "$CODE_BLOCK_SYMBOL"
}

function clean_env_config() {
    local filename="$1"
    local old_IFS=$IFS

    while IFS='=' read -r key _ ; do
        is_not_empty "$key" && unset "$key"
    done < "$filename"

    IFS=$old_IFS
}

function reset_config() {
    clean_env_config "$CONFIG_FILENAME"
    cp "$DEFAULT_CONFIG_FILENAME" "$CONFIG_FILENAME"
    load_config
}

function reset_openai_api_key() {
    delete_config "OPENAI_API_KEY"
    unset "OPENAI_API_KEY"
    load_config
}

function reset_openai_model() {
    default_value=$(get_default_config "OPENAI_MODEL")
    delete_config "OPENAI_MODEL" 
    add_config "OPENAI_MODEL" "$default_value"
    load_config
}

function load_config() {
    if [[ -f "$CONFIG_FILENAME" ]]; then
        # shellcheck source=config.ini
        source "$CONFIG_FILENAME"
    else
        reset_config
    fi
}

function ask() {
    local text="$1"
    
    echo_sys "$text"    
    read -e -r -p "$(echo_ask "y/n")" reply
    reply=$(to_lower "$reply")
    if [[ "$reply" != "y" ]] && [[ "$reply" != "yes" ]]; then
        return 1
    fi
}

function ask_reset_config() {
    # shellcheck disable=SC2015
    ask "Do you want to reset all your configurations to default? [Yes/No] or Enter to skip." \
        && reset_config \
        && echo_sys "$SYS_MESSAGE_DONE" \
        || echo_sys "$SYS_MESSAGE_NOOP"
}

function ask_reset_api_key() {
    # shellcheck disable=SC2015
    ask "Do you want to reset the OpenAI API key? [Yes/No] or Enter to skip." \
        && reset_openai_api_key \
        && echo_sys "$SYS_MESSAGE_DONE" \
        || echo_sys "$SYS_MESSAGE_NOOP"
}

function ask_reset_model() {
    # shellcheck disable=SC2015
    ask "Do you want to reset the OpenAI model to default? [Yes/No] or Enter to skip." \
        && reset_openai_model \
        && echo_sys "$SYS_MESSAGE_DONE" \
        || echo_sys "$SYS_MESSAGE_NOOP"
}

function get_config() {
    local name="$1"
    local filename="$2"
    local key_value

    key_value=$(grep -i "$name" "$filename")
    if [[ -n "$key_value" ]]; then
        echo "$key_value" \
            | cut -d "=" -f2 \
            | map remove_first_char \
            | map remove_last_char
    else
        return 1
    fi
}

function get_default_config() {
    get_config "$1" "$DEFAULT_CONFIG_FILENAME"
}

function get_custom_config() {
    get_config "$1" "$CONFIG_FILENAME"
}

function add_config() {
    local name="$1"
    local value="$2"

    echo -e "\n$name=\"$value\"\n" >> "$CONFIG_FILENAME"
    remove_empty_lines "$CONFIG_FILENAME"
}

function delete_config() {
    local name="$1"
    
    sed -i '' "/^$name/d" "$CONFIG_FILENAME"
}

function input_config() {
    local config_key_name="$1"
    local config_friendly_name="$2"
    
    echo_sys "Please type a valid $config_friendly_name to proceed. [Press Enter to skip]"
    read -e -r -p "$(echo_ask "cfg")" value
    
    if is_not_empty "$value"; then
        if has_no_blanks "$value"; then
            config_key_name=$(to_upper "$config_key_name")
            delete_config "$config_key_name"
            add_config "$config_key_name" "$value"
            eval "$config_key_name=$value"
        else
            echo_sys "$config_friendly_name cannot contain blank spaces."
            return 1
        fi
    else
        return 1
    fi
}

function set_openai_api_key() {
    # shellcheck disable=SC2015
    input_config "OPENAI_API_KEY" "OpenAI API key" \
        && echo_sys "$SYS_MESSAGE_DONE" \
        || echo_sys "$SYS_MESSAGE_NOOP"
}

function set_openai_model() {
    # shellcheck disable=SC2015
    input_config "OPENAI_MODEL" "OpenAI model" \
        &&  echo_sys "$SYS_MESSAGE_DONE" \
        || echo_sys "$SYS_MESSAGE_NOOP"
}

function check_and_save_openai_api_key() {
    [[ -z "$OPENAI_API_KEY" ]] && set_openai_api_key
}

function get_data_content_from_chunk() {
    echo "$1" | jq -c -e "select(.choices[].delta.content != null) | .choices[].delta.content"
}

function echo_completion_chunk() {
    echo "$1" \
        | map get_data_content_from_chunk \
        | map remove_first_char \
        | map remove_last_char \
        | map unescape_double_quotes \
        | map "echo -ne"
}

function get_openai_error_message() {
    echo "$1" | jq -c -e -r "select(.error.message != null) | .error.message" 
}

function get_openai_error_code() {
    echo "$1" | jq -c -e -r "select(.error.code != null) | .error.code" 
}

function get_suggestion() {
    local openai_error_code="$1"
    
    case "$openai_error_code" in
        "invalid_api_key")  echo "Type \"/set key\" to change your OpenAI API key." ;;
        "model_not_found")  echo "Type \"/set model\" to change your OpenAI model." ;;
        *)                  echo "Type \"/help\" for more information." ;;
    esac
}

function handle_openai_error() {
    local error_chunk="$1"
    
    get_openai_error_message "$error_chunk" \
        | map echo_type

    get_openai_error_code "$error_chunk" \
        | map get_suggestion \
        | map echo_sys
}

function handle_openai_response() {
    local response_chunk="$1"
    local completion_chunk
    
    if is_data "$response_chunk"; then
        completion_chunk=${response_chunk#data: }
        
        if is_valid_json "$completion_chunk"; then
            echo_completion_chunk "$completion_chunk"
        elif is_last_chunk "$completion_chunk"; then
            append_newline
        fi
    elif is_error "$response_chunk"; then
        handle_openai_error "$full_response"
    else
        full_response+="$response_chunk"
    fi
}

function welcome() {
    echo
    echo -e "  :: Welcome to ${BOLD}$APPLICATION_NAME $APPLICATION_VERSION${RESET_COLOR}."
    echo -e "  :: Type \"/help\" for more information."
    echo -e "  :: Press CTRL+C to exit."
    echo
}

function create_json_message() {
    local role="$1"
    local content="$2"

    jq -c -n --arg ROLE "$role" --arg CONTENT "$content" '{"role": $ROLE, "content": $CONTENT}'
}

function create_user_json_message() {
    local content="$1"
    
    create_json_message "user" "$content"
}

function save_message_to_history() {
    local role="$1"
    local content="$2"
    
    create_json_message "$role" "$content" | jq -c >> "$MESSAGE_HISTORY"
}

function save_user_message() {
    save_message_to_history "user" "$1"
}

function save_assistant_message() {
    save_message_to_history "assistant" "$1"
}

function flush_last_message_buffer() {
    truncate -s 0 "$LAST_MESSAGE_BUFFER"
}

function create_base_openai_payload() {
    local openai_model="$1"
    local openai_role_system_content="$2"
    
    jq -n -c \
        --arg OPENAI_MODEL "$openai_model" \
        --arg OPENAI_ROLE_SYSTEM_CONTENT "$openai_role_system_content" \
        '{"model": $OPENAI_MODEL, "messages": [{"role":"system", "content": $OPENAI_ROLE_SYSTEM_CONTENT}], "stream": true}'
}

function append_openai_json_message() {
    local base_openai_json_payload="$1"
    local json_message="$2"

    echo "$base_openai_json_payload" \
        | jq -c --argjson json_message "$json_message" '.messages += [$json_message]'
}

function create_openai_payload_from_history() {
    local content="$1"
    local openai_json_payload
    local last_user_json_message

    openai_json_payload=$(create_base_openai_payload "$OPENAI_MODEL" "$OPENAI_ROLE_SYSTEM_CONTENT")
    if [[ -f "$MESSAGE_HISTORY" ]]; then
        while IFS= read -r json_message || is_not_empty "$json_message"; do
            openai_json_payload=$(append_openai_json_message "$openai_json_payload" "$json_message")
        done < "$MESSAGE_HISTORY"
    fi

    last_user_json_message=$(create_user_json_message "$content")
    openai_json_payload=$(append_openai_json_message "$openai_json_payload" "$last_user_json_message")

    echo "$openai_json_payload" | jq -c .
}

function create_chat_completions() {
    local content="$1"
    
    if [[ "$OFFLINE_MODE" == true ]]; then 
        fake_openai_request | map handle_openai_response
    else    
        create_openai_payload_from_history "$content" \
            | map make_openai_request \
            | map handle_openai_response
    fi
}

function make_openai_request() {
    local payload="$1"
    
    curl "$OPENAI_API_URL" \
                --no-buffer \
                --silent \
                --show-error \
                --write-out "${CURL_WRITE_OUT_PREFIX} %{http_code}\n" \
                --header "Content-Type: application/json" \
                --header "Authorization: Bearer $OPENAI_API_KEY" \
                --data "$payload"
}

function fake_openai_request() {
    cat "$FAKE_OPENAI_RESPONSE_FILENAME"
}

function get_openai_response() {
    local content=$1
    
    echo_gpt
    create_chat_completions "$content" | tee -a "$LAST_MESSAGE_BUFFER"
    save_user_message "$content" 
    save_assistant_message "$(<"$LAST_MESSAGE_BUFFER")"
    flush_last_message_buffer
}

function handle_commands() {
    local command="$1"
    
    case "$command" in
        "/help")            help ;;
        "/welcome")         welcome ;;
        "/config")          show_config ;; 
        "/set key")         set_openai_api_key ;;
        "/set model")       set_openai_model ;; 
        "/reset key")       ask_reset_api_key ;;
        "/reset model")     ask_reset_model ;;
        "/reset all")       ask_reset_config ;;
        "/history")         show_history ;;
        "/clear history")   clear_history ;;
        "/exit")            handle_exit ;;
        *)                  help ;;
    esac
}

function create_chat() {
    [[ "$OFFLINE_MODE" == true ]] && echo_sys "The offline mode is enabled."
    
    while true
    do
        read -r -p "$(echo_you)" user_message
        case "$user_message" in
            "")     continue ;;
            "/"*)   handle_commands "$user_message" ;;
            *)      get_openai_response "$user_message" ;;
        esac
    done
}

function help() {
    echo_sys "Here's the list of commands:"
    echo 
    echo "  /help             Show the help menu"
    echo "  /welcome          Show the welcome message"
    echo "  /config           Show the custom configurations"
    echo 
    echo "  /set key          Set the OpenAI API key"
    echo "  /set model        Set the OpenAI API model"
    echo
    echo "  /reset key        Reset the OpenAI API key to default"
    echo "  /reset model      Reset the OpenAI model to default"
    echo "  /reset all        Reset the configurations to default"    
    echo 
    echo "  /history          Show the conversation history"
    echo "  /clear history    Clear the conversation history"
    echo "  /exit             Exit from the application"
    echo 
}

function show_history() {
    echo_sys "Here's your conversation history:"
    echo "$CODE_BLOCK_SYMBOL"
    
    while IFS= read -r line || is_not_empty "$line"; do
        case "$(echo "$line" | jq -r ".role")" in
            "user")         role="YOU" ;;
            "assistant")    role="GPT" ;;
            *)              role="???" ;;
        esac
        
    echo "$role: $(echo "$line" | jq -r ".content")"
    done < "$MESSAGE_HISTORY"
    
    echo "$CODE_BLOCK_SYMBOL"
}

function clear_history() {
    truncate -s 0 "$MESSAGE_HISTORY"
}

function init() {
    delete_file "$MESSAGE_HISTORY"
    delete_file "$LAST_MESSAGE_BUFFER"
    load_config
    check_and_save_openai_api_key
}

function handle_exit() {
    echo_sys "Bye!"
    exit 0
}

trap "echo; handle_exit" SIGINT SIGTERM

function main() {
    welcome
    init
    create_chat
}
