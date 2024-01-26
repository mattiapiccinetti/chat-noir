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
        if [[ "$actual" == "$expected" ]]; then
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

function always_true() {
    return 0
}

function always_false() {
    return 1
}

echo
echo ":: Running tests $0"
echo

assert_that echo "foo bar baz" | is_equal_to "foo bar baz"
assert_true always_true
assert_false alway_false

echo