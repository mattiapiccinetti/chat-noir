#!/bin/bash

set -e

source "assertish.sh"
source "chat-noir.sh"

function test_has_no_blanks() {
    assert_true has_no_blanks 'ThisTextHasNoBlanks'
    assert_false has_no_blanks 'This Text Has Blanks'
    assert_true has_no_blanks ''
    assert_true has_no_blanks 
}

function test_is_not_empty() {
    assert_true is_not_empty 'foo bar'
    assert_false is_not_empty ''
    assert_false is_not_empty
}

function test_to_lower() {
    assert_that to_lower 'FOO BAR' | is_equal_to 'foo bar'
    assert_empty to_lower ''
}

function test_to_upper() {
    assert_that to_upper 'foo bar' | is_equal_to 'FOO BAR'
    assert_empty to_upper ''
}

function test_remove_first_char() {
    assert_that remove_first_char 'foo bar' | is_equal_to 'oo bar'
    assert_empty remove_first_char ''
}

function test_remove_last_char() {
    assert_that remove_last_char 'foo bar' | is_equal_to 'foo ba'
    assert_empty remove_last_char ''
}

function test_unescape_double_quotes() {
    assert_that unescape_double_quotes 'foo \"bar\" baz' | is_equal_to 'foo "bar" baz'
    assert_empty unescape_double_quotes ''
}

function test_is_valid_json() {
    assert_true is_valid_json '{"foo":"bar"}'
    assert_true is_valid_json '{}'
    assert_true is_valid_json ''
    assert_false is_valid_json 'foo bar'
}

function test_is_error() {
    assert_true is_error 'http_code: 404'
    assert_false is_error 'foo bar'
    assert_false is_error ''
}

function test_is_data() {
    assert_true is_data 'data: {}'
    assert_false is_data 'foo bar'
    assert_false is_data ''
}

function test_echo_you() {
    assert_that echo_you | is_equal_to 'YOU: '
}

function test_echo_gpt() {
    assert_that echo_gpt | is_equal_to 'GPT: '
}

function test_echo_sys() {
    assert_that echo_sys | is_equal_to 'SYS: '
    assert_that echo_sys 'foo bar' | is_equal_to 'SYS: foo bar'
}

function test_echo_ask() {
    assert_that echo_ask | is_equal_to ': '
    assert_that echo_ask 'foo' | is_equal_to 'FOO: '
    assert_that echo_ask 'this is a long message' | is_equal_to 'THI: '
}

function test_echo_type() {
    assert_that echo_type 'foo bar' | is_equal_to 'foo bar'
    assert_empty echo_type
}

function test_get_default_config() {
    assert_that get_default_config 'FOO' | is_equal_to ''
    assert_that get_default_config 'OPENAI_API_URL' | is_equal_to 'https://api.openai.com/v1/chat/completions'
    assert_that get_default_config 'OPENAI_MODEL' | is_equal_to 'gpt-3.5-turbo'
    assert_that get_default_config 'OPENAI_ROLE_SYSTEM_CONTENT' | is_equal_to 'You are a helpful assistant.'
}

function test_get_data_content_from_chunk() {
    assert_that get_data_content_from_chunk '{"choices":[{"delta":{"content":"foo bar"}}]}' | is_equal_to '"foo bar"'
}

function test_echo_completion_chunk() {
    assert_that echo_completion_chunk '{"choices":[{"delta":{"content":"foo \"bar\" baz"}}]}' | is_equal_to 'foo "bar" baz'
}

function test_get_openai_error_message() {
    assert_that get_openai_error_message '{"error":{"message":"something went wrong"}}' | is_equal_to 'something went wrong'
}

function test_get_openai_error_code() {
    assert_that get_openai_error_code '{"error":{"code":"foo_error_code"}}' | is_equal_to 'foo_error_code'
}

function test_get_suggestion() {
    assert_that get_suggestion | is_equal_to 'Type "/help" for more information.'
    assert_that get_suggestion '' | is_equal_to 'Type "/help" for more information.'
    assert_that get_suggestion 'invalid_api_key' | is_equal_to 'Type "/set key" to change your OpenAI API key.'
    assert_that get_suggestion 'model_not_found' | is_equal_to 'Type "/set model" to change your OpenAI model.'
}

function test_handle_openai_response() {
    assert_empty handle_openai_response
    assert_empty handle_openai_response ''
    assert_empty handle_openai_response 'foo bar'
    assert_that handle_openai_response 'data: {"choices":[{"delta":{"content":"foo bar"}}]}' | is_equal_to 'foo bar'
}

function test_create_json_message() {
    assert_that create_json_message 'john doe' 'foo bar baz' | is_equal_to '{"role":"john doe","content":"foo bar baz"}'
}

function test_create_user_json_message() {
    assert_that create_user_json_message 'foo bar baz' | is_equal_to '{"role":"user","content":"foo bar baz"}'
}

function test_create_base_openai_payload() {
    assert_that create_base_openai_payload 'foo' 'bar baz' \
        | is_equal_to '{"model":"foo","messages":[{"role":"system","content":"bar baz"}],"stream":true}'
}

function test_append_openai_json_message() {
    local base_openai_payload
    local user_json_message
    local expected
    
    base_openai_payload="$(create_base_openai_payload "foo model" "foo content")"
    user_json_message="$(create_user_json_message "Who am I?")"
    expected='{"model":"foo model","messages":[{"role":"system","content":"foo content"},{"role":"user","content":"Who am I?"}],"stream":true}'

    assert_that append_openai_json_message "$base_openai_payload" "$user_json_message" | is_equal_to "$expected"
}

function run_tests() {
    local test_filename="$0"
    
    echo ":: Running tests in '$0'"
    echo

    functions=$(grep -E 'function test_[^}]*{' "$test_filename" \
        | sed 's/function //' \
        | sed 's/(.*$//') 
    
    for fn in $functions; do
        $fn
    done
}

run_tests "$0"
