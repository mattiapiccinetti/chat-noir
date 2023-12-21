#!/bin/bash

clear

ESC_SEQUENCE="\033["
RESET_CURSOR_SEQUENCE="\r\033[K"
RESET_COLOR="${ESC_SEQUENCE}0m"
RED="${ESC_SEQUENCE}31m"
GREEN="${ESC_SEQUENCE}32m"
YELLOW="${ESC_SEQUENCE}33m"
BOLD="${ESC_SEQUENCE}1m"

conversation_id=$(uuidgen)

trap "echo -e '\n\n:: Your CONVERSATION_ID was ${YELLOW}$conversation_id${RESET_COLOR}\n'; exit" SIGINT SIGTERM

echo_type() {
    local text=$1
    local delay=0.001

    for (( i=0; i<${#text}; i++ )); do echo -n "${text:$i:1}";
        sleep $delay
    done

    echo
}

echo_welcome() {
    local id=$1

    echo
    echo -e ":: Welcome to ${BOLD}MAYBE-GPT${RESET_COLOR}."
    echo -e ":: This application is made by Peach of Persia."
    echo -e ":: Type \"/help\" to display this text again."
    echo -e ":: Press CTRL + C to exit."
    echo
    echo -e ":: Your CONVERSATION_ID is ${YELLOW}$id${RESET_COLOR}"
    echo
}

echo_welcome "$conversation_id"

while true
do
    echo -ne "${RED}YOU: ${RESET_COLOR}"
    read -r user_prompt

    if [ -z "$user_prompt" ]; then
        continue
    elif [ "$user_prompt" = "/help" ]; then
        echo_welcome "$conversation_id"
    else
        echo -ne "${GREEN}GPT:${RESET_COLOR} ..."

        timeout=10
        response=$(curl https://api.openai.com/v1/chat/completions \
            --silent \
            --request POST \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer $OPENAI_API_KEY" \
            --max-time $timeout \
            -d "{
                \"model\": \"gpt-3.5-turbo\",
                \"messages\": [{\"role\": \"user\", \"content\": \"$user_prompt\"}],
                \"temperature\": 0.7
            }"
        )
        
        exit_code=$?
        echo -ne "${RESET_CURSOR_SEQUENCE}"
        echo -ne "${GREEN}GPT:${RESET_COLOR} "

        if [ "$exit_code" -eq 28 ]; then
            echo_type "A timeout error has occurred. Please try again later."
        elif [ "$exit_code" -eq 7 ]; then
            echo_type "A connection error has occurred. Please try again later."
        else
            echo_type "$(echo "$response" | jq -r '.choices[].message.content')"
        fi
    fi
done
