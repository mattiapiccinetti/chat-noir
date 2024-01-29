#!/bin/bash

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
    local function_name="$1"
    local parameters="$2"
    local max_parameters_length

    max_parameters_length=50
    if ((${#parameters} > "$max_parameters_length")); then
        echo -e "$(green "PASS") $(bold "$function_name")(${parameters:0:max_parameters_length} ...)"
    else
        echo -e "$(green "PASS") $(bold "$function_name")($parameters)"
    fi
}

function fail() {
    local function_name="$1"
    local parameters="$2"
    local reason="$3"

    max_parameters_length=50
    if ((${#parameters} > "$max_parameters_length")); then
        parameters="${parameters:0:max_parameters_length} ..."
    fi
    
    if [[ -n "$reason" ]]; then
        echo -e "$(red "FAIL") $(bold "$function_name")($parameters) -> $reason"
    else
        echo -e "$(red "FAIL") $(bold "$function_name")($parameters)"
    fi
}

function assert_that() {
    local function_name="$1"
    local parameters

    shift
    actual=$("$function_name" "$@")
    for parameter in "$@"; do
        parameters+="$parameter, "
    done

    echo "$function_name|${parameters%, }|$actual"
}

function is_equal_to() {
    local expected="$1"
    
    while IFS="|" read -r -e function_name parameters actual; do
        if [[ "$(strip_colors "$actual")" == "$(strip_colors "$expected")" ]]; then
            pass "$function_name" "$parameters"
        else
            fail "$function_name" "$parameters" "Expected $(bold "'$expected'") but was $(bold "'$actual'")"
        fi
    done
}

function assert_true() {
    local function_name="$1"

    shift
    if $function_name "$@" >/dev/null 2>&1; then
        pass "$function_name" "$@"
    else
        fail "$function_name" "$@" "Expected $(bold "'true'") but was $(bold "'false'")"
    fi
}

function assert_false() {
    local function_name="$1"

    shift
    if ! $function_name "$@" >/dev/null 2>&1; then
        pass "$function_name" "$@"
    else
        fail "$function_name" "$@" "Expected $(bold "'false'") but was $(bold "'true'")"
    fi
}

function assert_empty() {
    local function_name="$1"
    local actual
    
    shift
    actual="$($function_name "$@")"
    if [[ -z "$actual" ]]; then
        pass "$function_name" "$@"
    else
        fail "$function_name" "$@" "Expected $(bold "empty") but was $(bold "'$actual'")"
    fi
}