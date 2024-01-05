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

function echo_y_n() {
    echo_ask "y/n"
}

function echo_key() {
    echo_ask "key"
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
    if [[ -f "$CONFIG_FILE_PATH" ]]; then
        # shellcheck source=config.ini
        source "$CONFIG_FILE_PATH"
    else
        reset_config
    fi
}

function ask_and_execute() {
    local text="$1"
    local execute_if_yes="$2"
    local execute_if_no="$3"

    echo_sys "$text"
        
    read -e -r -p "$(echo_y_n)" reply
    reply=$(to_lower "$reply")
    if [[ "$reply" == "y" ]] || [[ "$reply" == "yes" ]]; then
        $execute_if_yes
    else
        $execute_if_no
    fi
}

function ask_reset_config() {
    ask_and_execute \
        "Your configurations will be reset to default.\n${TAB}Do you want to proceed? [Yes/No] or Enter to skip." \
        "reset_config" \
        "echo_sys $SYS_ANSWER"
}

function ask_to_reset_api_key() {
    ask_and_execute \
        "Do you want change your OpenAI API key? [Yes/No] or Enter to skip." \
        "ask_openai_api_key" \
        "echo_sys $SYS_ANSWER"
}

function ask_to_reset_model() {
    ask_and_execute \
        "Do you want change your current OpenAI model? [Yes/No] or Enter to skip." \
        "ask_openai_model" \
        "echo_sys $SYS_ANSWER"
}

function remove_empty_lines() {
    local filename="$1"

    sed -i '' -e '/^\s*$/d' "$filename"
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

function save_openai_api_key() {
    local key="$1"
    
    add_config "OPENAI_API_KEY" "$key"
    OPENAI_API_KEY="$key"
    
    echo_sys "Your OpenAI API key has been saved."
}

function save_openai_model() {
    local model="$1"
    
    add_config "OPENAI_MODEL" "$model"
    OPENAI_MODEL="$model"
    
    echo_sys "Your OpenAI model has been saved."
}

function ask_openai_api_key() {
    echo_sys "Please type a valid OpenAI API key to proceed. [Press Enter to skip]"
    read -e -r -p "$(echo_key)" openai_api_key
    
    if [[ -n "$openai_api_key" ]]; then
        delete_config "OPENAI_API_KEY"
        save_openai_api_key "$openai_api_key"
    else 
        echo_sys "$SYS_ANSWER"
    fi
}

function ask_openai_model() {
    echo_sys "Please type a valid OpenAI model. [Press Enter to skip]"
    read -e -r -p "$(echo_ask "mdl")" openai_model
    
    if [[ -n "$openai_model" ]]; then
        delete_config "OPENAI_MODEL"
        save_openai_model "$openai_model"
    else 
        echo_sys "$SYS_ANSWER"
    fi
}

function check_and_save_openai_api_key() {
    if [[ -z "$OPENAI_API_KEY" ]]; then
        ask_openai_api_key
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
    local completion_chunk
    local data_chunk
    local error_chunk
    local openai_error_code
    
    while read -r chunk; do
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

    if [[ -n "$error_chunk" ]]; then
        openai_error_code=$(get_openai_error_code "$error_chunk")
        echo_type "$(get_openai_error_message "$error_chunk") [$openai_error_code]"
        
        if [[ "$openai_error_code" == "invalid_api_key" ]]; then
            echo_sys "Type '/reset-key' to change your OpenAI API key."
        elif [[ "$openai_error_code" == "model_not_found" ]]; then
            echo_sys "Type '/reset-model' to change your OpenAI model."
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
    while IFS= read -r json_message || [[ -n "$json_message" ]]; do
        openai_json_payload=$(
            echo "$openai_json_payload" | jq --argjson json_message "$json_message" '.messages += [$json_message]')
    done < "$HISTORY_FILE_PATH"

    echo "$openai_json_payload"
}

function create_chat_completions() {
    local content="$1"
    local openai_json_payload
    
    openai_json_payload=$(create_openai_payload_from_history "$content")
    curl "$OPENAI_API_URL" \
            --no-buffer \
            --silent \
            --show-error \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer $OPENAI_API_KEY" \
            --data "$openai_json_payload" \
        | handle_chunks
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
        "/help")        help ;;
        "/config")      show_config ;;
        "/reset-all")   ask_reset_config ;;
        "/reset-key")   ask_to_reset_api_key ;;
        "/reset-model") ask_to_reset_model ;;
        "/welcome")     welcome ;;
        "/exit")        handle_exit ;;
        "/history")     show_history ;;
        *)              help ;;
    esac
}

function create_chat() {
    while true
    do
        read -e -r -p "$(echo_you)" user_message
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
    echo "  /help           Show the help menu" 
    echo "  /config         Show the custom configurations" 
    echo "  /reset-all      Reset the configurations to default" 
    echo "  /reset-key      Reset the OpenAI API key"
    echo "  /reset-model    Reset the OpenAI model" 
    echo "  /welcome        Show the welcome message" 
    echo "  /history        Show the conversation history so far as JSON" 
    echo "  /exit           Exit from the application" 
    echo ""
}

function show_history() {
    echo_sys "Here's your conversation history:"
    echo "$CODE_BLOCK_SYMBOL"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
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
    
    if [[ $# -gt 0 ]]; then
        create_chat_completions "$1"
    else
        create_chat
    fi
}

trap "echo; handle_exit" SIGINT SIGTERM

main "$@"
