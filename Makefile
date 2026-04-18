-include .env
export

.PHONY: up setup deploy init apply start stop status destroy ssh

up: setup
	@set -a && . ./.env && set +a && $(MAKE) deploy

setup:
	@env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_DEFAULT_REGION bash scripts/bootstrap.sh

deploy: init apply

init:
	terraform init

apply:
	terraform apply -auto-approve

start:
	@bash scripts/server.sh start

stop:
	@bash scripts/server.sh stop

status:
	@bash scripts/server.sh status

destroy:
	terraform destroy -auto-approve
	@env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_DEFAULT_REGION bash scripts/teardown.sh

ssh:
	@eval $$(terraform output -raw ssm_command)
