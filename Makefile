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

#🐳 docker.build: @ Build the price_spotter_app docker image
docker.build:
	@cp ./devops/builder/Dockerfile ./
	@docker build ./ -t price_spotter_app
	@rm ./Dockerfile

#🐳 docker.stop: @ Stop the price_spotter_app docker instance
docker.stop:
	@docker stop price_spotter_app || true

#🐳 docker.delete: @ Delete the price_spotter_app docker instance
docker.delete:
	@docker rm price_spotter_app || true

#🐳 docker.run: @ Run the price_spotter_app docker instance
docker.run:
	@docker run --name price_spotter_app --network price_spotter_devops_default -p 5000:5000 --env-file .env.prod price_spotter_app

#🐳 docker.connect: @ Connect to the price_spotter_app running container
docker.connect:
	@docker exec -it price_spotter_app /bin/bash

#🐳 docker.release: @ Re-create a docker image and run it
docker.release: docker.stop docker.delete docker.build docker.run

#❓ help: @ Displays this message
help: SHELL:=/bin/bash
help:
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(firstword $(MAKEFILE_LIST))| tr -d '#'  | awk 'BEGIN {FS = ":.*?@ "}; {printf "${GREEN}%-30s${NOFORMAT} %s\n", $$1, $$2}'|

#💻 server: @ Starts a server with an interactive elixir shell.
server: SHELL:=/bin/bash
server:
	@iex -S mix phx.server

#📦 setup: @ Installs dependencies and set up database for dev and test envs
setup: SHELL:=/bin/bash
setup:
	MIX_ENV=dev mix setup
	MIX_ENV=test mix setup

#🧪 test: @ Runs all test suites
test: SHELL:=/bin/bash
test:
	@mix test

#📙 translations: @ Extract new untranslated phrases and merge translations to avaialble languages. This command uses fuzzy auto-generated transaltions, it generally needs a manual update to each language afterwards.
translations: SHELL:=/bin/bash
translations:
	@mix gettext.extract
	@mix gettext.merge priv/gettext --locale es_AR
	@mix gettext.merge priv/gettext --locale en
