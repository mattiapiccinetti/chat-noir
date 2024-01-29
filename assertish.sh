#!/bin/bash

set -e

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

    return 1
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