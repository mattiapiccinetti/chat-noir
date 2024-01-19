#!/bin/bash

readonly APPLICATION_NAME="CHAT-NOIR"
readonly APPLICATION_VERSION="0.0.1"
readonly DEFAULT_CONFIG_FILE_PATH="defaults.ini"
readonly CONFIG_FILE_PATH="config.ini"
readonly HISTORY_FILE_PATH="history.jsonl"

readonly CODE_BLOCK_SYMBOL="\`\`\`"
readonly ESC_SEQUENCE="\033["
readonly RESET_COLOR="${ESC_SEQUENCE}0m"
readonly CYAN="${ESC_SEQUENCE}36m"
readonly MAGENTA="${ESC_SEQUENCE}35m"
readonly YELLOW="${ESC_SEQUENCE}33m"
readonly BOLD="${ESC_SEQUENCE}1m"
readonly SYS_ANSWER="Ok."
readonly TAB="     "

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

function echo_you() {
    echo -ne "${CYAN}YOU: ${RESET_COLOR}"
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
    cat $CONFIG_FILE_PATH
    echo "$CODE_BLOCK_SYMBOL"
}

function clean_env_config() {
    local file_path="$1"
    local old_IFS=$IFS

    while IFS='=' read -r key _ ; do
        is_not_empty "$key" && unset "$key"
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
    if [[ -f "$CONFIG_FILE_PATH" ]]; then
        # shellcheck source=config.ini
        source "$CONFIG_FILE_PATH"
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
    ask "Your configurations will be reset to default.\n${TAB}Do you want to proceed? [Yes/No] or Enter to skip." \
        && reset_config \
        || echo_sys "$SYS_ANSWER"    
}

function ask_reset_api_key() {
    # shellcheck disable=SC2015
    ask "Do you want to change the OpenAI API key? [Yes/No] or Enter to skip." \
        && input_openai_api_key \
        || echo_sys "$SYS_ANSWER"
}

function ask_reset_model() {
    # shellcheck disable=SC2015
    ask "Do you want to change the OpenAI model? [Yes/No] or Enter to skip." \
        && input_openai_model \
        || echo_sys "$SYS_ANSWER"
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

function add_config() {
    local name="$1"
    local value="$2"

    echo -e "\n$name=\"$value\"\n" >> "$CONFIG_FILE_PATH"
    remove_empty_lines "$CONFIG_FILE_PATH"
}

function delete_config() {
    local name="$1"
    
    sed -i '' "/^$name/d" "$CONFIG_FILE_PATH"
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

function input_openai_api_key() {
    if input_config "OPENAI_API_KEY" "OpenAI API key"; then
        echo_sys "Your OpenAI API key has been saved."
    fi
}

function input_openai_model() {
    if input_config "OPENAI_MODEL" "OpenAI model"; then
        echo_sys "Your OpenAI model has been saved."
    fi
}

function check_and_save_openai_api_key() {
    if [[ -z "$OPENAI_API_KEY" ]]; then
        input_openai_api_key
    fi
}

function get_data_content_from_chunk() {
    echo "$1" | jq -c -e "select(.choices[].delta.content != null) | .choices[].delta.content"
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
    
    if [[ "$openai_error_code" == "invalid_api_key" ]]; then
        echo "Type '/reset-key' to change your OpenAI API key."
    elif [[ "$openai_error_code" == "model_not_found" ]]; then
        echo "Type '/reset-model' to change your OpenAI model."
    fi
}

function handle_openai_chunks() {
    local completion_chunk
    local data_chunk
    local error_chunk
    local openai_error_message
    local openai_error_code
    
    while IFS= read -r chunk; do
        if [[ $chunk == "data: "* ]]; then
            completion_chunk=${chunk#data: }
            if echo "$completion_chunk" | jq -e . >/dev/null 2>&1; then
                data_chunk+=$(echo_completion_chunk "$completion_chunk")
                echo_completion_chunk "$completion_chunk"
            fi
        else
            error_chunk+="$chunk"
        fi
    done

    if is_not_empty "$error_chunk"; then
        openai_error_code=$(get_openai_error_code "$error_chunk")
        openai_error_message=$(get_openai_error_message "$error_chunk")
        
        echo_type "$openai_error_message [$openai_error_code]"
        echo_sys "$(get_suggestion "$openai_error_code")"
    else
        echo ""
        save_message_to_history "assistant" "$data_chunk"
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

    jq \
        -c \
        -n \
        --arg ROLE "$role" \
        --arg CONTENT "$content" \
        '{"role": $ROLE, "content": $CONTENT}'
}

function save_message_to_history() {
    local role="$1"
    local content="$2"
    
    create_json_message "$role" "$content" | jq -c >> "$HISTORY_FILE_PATH"
}

function get_base_openai_payload() {
    jq \
        -n \
        --arg OPENAI_MODEL "$OPENAI_MODEL" \
        --arg OPENAI_ROLE_SYSTEM_CONTENT "$OPENAI_ROLE_SYSTEM_CONTENT" \
        '{"model": $OPENAI_MODEL, "messages": [{"role":"system", "content": $OPENAI_ROLE_SYSTEM_CONTENT}], "stream": true}'
}

function create_openai_payload_from_history() {
    local content="$1"
    local openai_json_payload
    
    openai_json_payload=$(get_base_openai_payload)
    while IFS= read -r json_message || is_not_empty "$json_message"; do
        openai_json_payload=$(
            echo "$openai_json_payload" | jq --argjson json_message "$json_message" '.messages += [$json_message]')
    done < "$HISTORY_FILE_PATH"

    echo "$openai_json_payload" | jq -c .
}

function create_chat_completions() {
    local content="$1"
    
    if [[ "$OFFLINE_MODE" == true ]]; then 
        fake_openai_request | handle_openai_chunks
    else    
        create_openai_payload_from_history "$content" \
            | map make_openai_request \
            | handle_openai_chunks
    fi
}

function make_openai_request() {
    local payload="$1"
    
    curl "$OPENAI_API_URL" \
                --no-buffer \
                --silent \
                --show-error \
                --header "Content-Type: application/json" \
                --header "Authorization: Bearer $OPENAI_API_KEY" \
                --data "$payload"
}

function fake_openai_request() {
    cat "fake_openai_response"
}

function get_openai_response() {
    local content=$1
    
    save_message_to_history "user" "$content"
    echo_gpt ""
    create_chat_completions "$content"
}

function handle_commands() {
    local command="$1"
    
    case "$command" in
        "/help")            help ;;
        "/config")          show_config ;;
        "/reset-all")       ask_reset_config ;;
        "/reset-key")       ask_reset_api_key ;;
        "/reset-model")     ask_reset_model ;;
        "/welcome")         welcome ;;
        "/exit")            handle_exit ;;
        "/history")         show_history ;;
        "/clear-history")   clear_history && echo_sys "Done." ;;
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
    echo ""
    echo "  /help             Show the help menu"
    echo "  /welcome          Show the welcome message"
    echo "  /config           Show the custom configurations"
    echo "  /reset-key        Reset the OpenAI API key"
    echo "  /reset-model      Reset the OpenAI model"
    echo "  /reset-all        Reset the configurations to default"    
    echo "  /history          Show the conversation history"
    echo "  /clear-history    Clear the conversation history"
    echo "  /exit             Exit from the application"
    echo ""
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
    done < "$HISTORY_FILE_PATH"
    
    echo "$CODE_BLOCK_SYMBOL"
}

function clear_history() {
    truncate -s 0 "$HISTORY_FILE_PATH"
}

function init() {
    clear_history
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
    create_chat
}

trap "echo; handle_exit" SIGINT SIGTERM

main "$@"
