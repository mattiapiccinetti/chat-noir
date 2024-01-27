.PHONY: run test

SHELL := /bin/bash

run:
	@bash main.sh
test:
	@bash test-chat-noir.sh

watch:
	while true; do \
		clear; \
		echo; \
		make test; \
		echo ":::: $$(date "+%Y-%m-%d %H:%M:%S") ::::"; \
		sleep 3; \
	done
