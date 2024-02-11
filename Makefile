.PHONY: run test watch install

SHELL := /bin/bash

run:
	@bash main.sh

test:
	@bash chat-noir-test.sh

watch:
	while true; do \
		clear; \
		echo; \
		make test; \
		echo ":::: $$(date "+%Y-%m-%d %H:%M:%S") ::::"; \
		sleep 3; \
	done

install:
	apt-get update
	apt-get install -y curl jq