.PHONY: ssm-list ssm-get ssm-set ssm-sync ssm-delete help

REGION ?= ap-south-1
ENV_FILE ?= .env

export AWS_DEFAULT_REGION=$(REGION)

help:
	@echo "SSM targets:"
	@echo "  make ssm-list                        list all /image-search parameters"
	@echo "  make ssm-get    KEY=FREEPIK_API_KEY   get one parameter value"
	@echo "  make ssm-set    KEY=FREEPIK_API_KEY VALUE=abc123   set one parameter"
	@echo "  make ssm-sync  [ENV_FILE=.env]        sync all keys from env file"
	@echo "  make ssm-delete KEY=FREEPIK_API_KEY   delete one parameter"

ssm-list:
	@./scripts/ssm.sh list

ssm-get:
	@./scripts/ssm.sh get $(KEY)

ssm-set:
	@./scripts/ssm.sh set $(KEY) $(VALUE)

ssm-sync:
	@./scripts/ssm.sh sync --env-file $(ENV_FILE)

ssm-delete:
	@./scripts/ssm.sh delete $(KEY)
