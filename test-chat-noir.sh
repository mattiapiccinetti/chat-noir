#!/bin/bash

source "$(dirname "$0")/chat-noir.sh"

function green() {
    echo -e "\033[32m${1}\033[0m"
}

function red() {
    echo -e "\033[31m${1}\033[0m"
}

function bold() {
    echo -e "\033[1m${1}\033[0m"
}

function strip_colors() {
  echo "$1" | sed -r "s/\x1B\[[0-9;]*[JKmsu]//g"
}

function pass() {
    echo -e "$(green "PASS") ${1}"
}

function fail() {
    local function_name="$1"
    local reason="$2"
    
    if [[ -n "$reason" ]]; then
        echo -e "$(red "FAIL") ${1} -> $reason"
    else
        echo -e "$(red "FAIL") ${1}"
    fi
}

function assert_that() {
    local function_name="$1"

    shift
    actual=$("$function_name" "$@")
    echo "$function_name|$actual"
}

function is_equal_to() {
    local expected="$1"
    
    while IFS="|" read -r -e function_name actual; do
        if [[ "$(strip_colors "$actual")" == "$(strip_colors "$expected")" ]]; then
            pass "$function_name"
        else
            fail "$function_name" "Expected $(bold "'$expected'") but was $(bold "'$actual'")"
        fi
    done
}

function assert_true() {
    local function_name="$1"

    shift
    if $function_name "$@" >/dev/null 2>&1; then
        pass "$function_name"
    else
        fail "$function_name" "Expected $(bold "'true'") but was $(bold "'false'")"
    fi
}

function assert_false() {
    local function_name="$1"

    shift
    if ! $function_name "$@" >/dev/null 2>&1; then
        pass "$function_name"
    else
        fail "$function_name" "Expected $(bold "'false'") but was $(bold "'true'")"
    fi
}

function assert_empty() {
    local function_name="$1"
    local actual
    
    shift
    actual="$($function_name "$@")"
    if [[ -z "$actual" ]]; then
        pass "$function_name"
    else
        fail "$function_name" "Expected $(bold "empty") but was $(bold "'$actual'")"
    fi
}

echo
echo ":: Running tests $0"
echo

assert_true has_no_blanks 'ThisTextHasNoBlanks'
assert_false has_no_blanks 'This Text Has Blanks'
assert_true has_no_blanks ''
assert_true has_no_blanks 

assert_true is_not_empty 'foo bar'
assert_false is_not_empty ''
assert_false is_not_empty

assert_that to_lower 'FOO BAR' | is_equal_to 'foo bar'
assert_empty to_lower ''

assert_that to_upper 'foo bar' | is_equal_to 'FOO BAR'
assert_empty to_upper ''

assert_that remove_first_char 'foo bar' | is_equal_to 'oo bar'
assert_empty remove_first_char ''

assert_that remove_last_char 'foo bar' | is_equal_to 'foo ba'
assert_empty remove_last_char ''

assert_that unescape_double_quotes 'foo \"bar\" baz' | is_equal_to 'foo "bar" baz'
assert_empty unescape_double_quotes ''

assert_true is_valid_json '{"foo":"bar"}'
assert_true is_valid_json '{}'
assert_true is_valid_json ''
assert_false is_valid_json 'foo bar'

assert_true is_error 'http_code: 404'
assert_false is_error 'foo bar'
assert_false is_error ''

assert_true is_data 'data: {}'
assert_false is_data 'foo bar'
assert_false is_data ''

assert_that echo_you | is_equal_to 'YOU: '

assert_that echo_gpt | is_equal_to 'GPT: '

assert_that echo_sys | is_equal_to 'SYS: '
assert_that echo_sys 'foo bar' | is_equal_to 'SYS: foo bar'

assert_that echo_ask | is_equal_to ': '
assert_that echo_ask 'foo' | is_equal_to 'FOO: '
assert_that echo_ask 'this is a long message' | is_equal_to 'THI: '

assert_that echo_type 'foo bar' | is_equal_to 'foo bar'
assert_empty echo_type

assert_empty get_default_config 'FOO'
assert_that get_default_config 'OPENAI_API_URL' | is_equal_to 'https://api.openai.com/v1/chat/completions'
assert_that get_default_config 'OPENAI_MODEL' | is_equal_to 'gpt-3.5-turbo'
assert_that get_default_config 'OPENAI_ROLE_SYSTEM_CONTENT' | is_equal_to 'You are a helpful assistant.'

assert_that get_data_content_from_chunk '{"choices":[{"delta":{"content":"foo bar"}}]}' | is_equal_to '"foo bar"'

assert_that echo_completion_chunk '{"choices":[{"delta":{"content":"foo \"bar\" baz"}}]}' | is_equal_to 'foo "bar" baz'

assert_that get_openai_error_message '{"error":{"message":"something went wrong"}}' | is_equal_to 'something went wrong'
assert_that get_openai_error_code '{"error":{"code":"foo_error_code"}}' | is_equal_to 'foo_error_code'

assert_that get_suggestion | is_equal_to 'Type "/help" for more information.'
assert_that get_suggestion '' | is_equal_to 'Type "/help" for more information.'
assert_that get_suggestion 'invalid_api_key' | is_equal_to 'Type "/set key" to change your OpenAI API key.'
assert_that get_suggestion 'model_not_found' | is_equal_to 'Type "/set model" to change your OpenAI model.'

assert_empty handle_openai_response
assert_empty handle_openai_response ''
assert_empty handle_openai_response 'foo bar'
assert_that handle_openai_response 'data: {"choices":[{"delta":{"content":"foo bar"}}]}' | is_equal_to 'foo bar'

assert_that create_json_message 'john doe' 'foo bar baz' | is_equal_to '{"role":"john doe","content":"foo bar baz"}'

assert_that create_user_json_message 'foo bar baz' | is_equal_to '{"role":"user","content":"foo bar baz"}'

assert_that create_base_openai_payload 'foo' 'bar baz' \
    | is_equal_to '{"model":"foo","messages":[{"role":"system","content":"bar baz"}],"stream":true}'

assert_that append_openai_json_message "$(create_base_openai_payload "foo model" "foo content")" "$(create_user_json_message "Who am I?")" \
    | is_equal_to '{"model":"foo model","messages":[{"role":"system","content":"foo content"},{"role":"user","content":"Who am I?"}],"stream":true}'

echo