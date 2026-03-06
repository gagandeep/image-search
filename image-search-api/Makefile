.PHONY: ssm-list ssm-get ssm-set ssm-sync ssm-delete \
        export-jsonl populate-remote help

REGION     ?= ap-south-1
ENV_FILE   ?= .env
JSONL_FILE ?= unsplash_photos.jsonl
SSH_KEY    ?= ~/.ssh/id_rsa
# Set REMOTE_IP when calling populate-remote:  make populate-remote REMOTE_IP=1.2.3.4

export AWS_DEFAULT_REGION=$(REGION)

help:
	@echo "SSM targets:"
	@echo "  make ssm-list                        list all /image-search parameters"
	@echo "  make ssm-get    KEY=FREEPIK_API_KEY   get one parameter value"
	@echo "  make ssm-set    KEY=FREEPIK_API_KEY VALUE=abc123   set one parameter"
	@echo "  make ssm-sync  [ENV_FILE=.env]        sync all keys from env file"
	@echo "  make ssm-delete KEY=FREEPIK_API_KEY   delete one parameter"
	@echo ""
	@echo "Typesense targets:"
	@echo "  make export-jsonl   [JSONL_FILE=unsplash_photos.jsonl]"
	@echo "      Export local Postgres → JSONL dump"
	@echo ""
	@echo "  make populate-remote REMOTE_IP=1.2.3.4  [JSONL_FILE=...] [SSH_KEY=...]"
	@echo "      Upload JSONL to remote EC2 and import into Typesense"

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

export-jsonl:
	python scripts/export_jsonl.py --output $(JSONL_FILE)

populate-remote:
	@test -n "$(REMOTE_IP)" || (echo "ERROR: REMOTE_IP is required.  make populate-remote REMOTE_IP=1.2.3.4" && exit 1)
	@test -f "$(JSONL_FILE)" || $(MAKE) export-jsonl
	@bash scripts/populate_remote.sh $(REMOTE_IP) $(JSONL_FILE) $(SSH_KEY)
