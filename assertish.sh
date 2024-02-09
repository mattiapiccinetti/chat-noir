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
    local max_parameters_length=50

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
            echo "PASS|$function_name|$parameters"
        else
            echo "FAIL|$function_name|$parameters|$expected|$actual"
        fi
    done
}

function is_empty() {
    while IFS="|" read -r -e function_name parameters actual; do
        if [[ -z "$(strip_colors "$actual")" ]]; then
            echo "PASS|$function_name|$parameters"
        else
            echo "FAIL|$function_name|$parameters|empty|$actual"
        fi
    done
}

function assert_true() {
    local function_name="$1"

    shift
    if $function_name "$@" >/dev/null 2>&1; then
        echo "PASS|$function_name|$*"
    else
        echo "FAIL|$function_name|$*|true|false"
    fi
}

function assert_false() {
    local function_name="$1"

    shift
    if ! $function_name "$@" >/dev/null 2>&1; then
        echo "PASS|$function_name|$*"
    else
        echo "FAIL|$function_name|$*|false|true"
    fi
}

function assert_empty() {
    local function_name="$1"
    local actual
    
    shift
    actual="$($function_name "$@")"
    if [[ -z "$actual" ]]; then
        echo "PASS|$function_name|$*"
    else
        echo "FAIL|$function_name|$parameters|empty|$actual"
    fi
}

function get_test_functions_from_file() {
    local filename="$1"

    grep -E '^function test_[^}]*{' "$filename" \
        | sed 's/function //' \
        | sed 's/(.*$//'
}

function run_tests() {
    local test_filename="$0"
    local test_pass_count=0
    local test_fail_count=0
    
    local test_fn_result
    local test_fn_full_name
    
    for test_fn_name in $(get_test_functions_from_file "$test_filename"); do
        test_fn_result=$(eval "$test_fn_name")
        test_fn_full_name="$test_filename::$test_fn_name"

        if [[ "$(echo "$test_fn_result" | grep -c -e '^FAIL')" -gt 0 ]]; then    
            ((test_fail_count++))
            
            fail "$test_fn_full_name"
            while IFS="|" read -e -r _ fn_name parameters expected actual; do
                echo -e "     $fn_name($parameters) -> Expected '$expected' but was '$actual'"
            done <<< "$(echo "$test_fn_result" | grep -e '^FAIL')"
        else
            ((test_pass_count++))
            pass "$test_fn_full_name"
        fi
    done

    echo
    echo "$(bold "PASS"): $test_pass_count"
    echo "$(bold "FAIL"): $test_fail_count"
    echo
}