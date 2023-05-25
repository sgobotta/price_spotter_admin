.PHONY: setup test

ENV_FILE ?= .env

# add env variables if needed
ifneq (,$(wildcard ${ENV_FILE}))
	include ${ENV_FILE}
    export
endif

export GREEN=\033[0;32m
export NOFORMAT=\033[0m

# ------------------------------------------------------------------------------
# Commands
#

default: help

#❓ help: @ Displays this message
help: SHELL:=/bin/bash
help:
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(firstword $(MAKEFILE_LIST))| tr -d '#'  | awk 'BEGIN {FS = ":.*?@ "}; {printf "${GREEN}%-30s${NOFORMAT} %s\n", $$1, $$2}'|

#📦 setup: @ Installs dependencies and set up database for dev and test envs
setup: SHELL:=/bin/bash
setup:
	MIX_ENV=dev mix setup
	MIX_ENV=test mix setup

#💻 server: @ Starts a server with an interactive elixir shell.
server: SHELL:=/bin/bash
server:
	@iex -S mix phx.server

#🧪 test: @ Runs all test suites
test: SHELL:=/bin/bash
test:
	@mix test
