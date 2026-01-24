# Chezmoi Makefile
# Usage:
#   make diff                    - Show differences between source and destination
#   make diff FLAGS="--reverse"  - Show differences with reversed output
#   make sync                    - Apply changes (with confirmation)
#   make apply                   - Apply changes without confirmation
#   make apply FLAGS="--dry-run" - Preview apply without making changes
#   make status                  - Show chezmoi status
#   make update                  - Pull and apply changes from remote

SHELL := /bin/bash

# Load .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default chezmoi flags (can be overridden in .env)
CHEZMOI_FLAGS ?=
CHEZMOI_DIFF_FLAGS ?=
CHEZMOI_APPLY_FLAGS ?=

.PHONY: help diff sync apply status update init add edit

help: ## Show this help message
	@echo "Chezmoi Management Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration:"
	@echo "  Copy .env.example to .env and customize as needed"

diff: ## Show differences (usage: make diff FLAGS="--reverse")
	chezmoi diff $(CHEZMOI_FLAGS) $(CHEZMOI_DIFF_FLAGS) $(FLAGS)

sync: ## Apply changes interactively (shows diff first, asks for confirmation)
	@echo "=== Changes to be applied ==="
	@chezmoi diff $(CHEZMOI_FLAGS) $(CHEZMOI_DIFF_FLAGS) $(FLAGS) || true
	@echo ""
	@read -p "Apply these changes? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		chezmoi apply $(CHEZMOI_FLAGS) $(CHEZMOI_APPLY_FLAGS) $(FLAGS) -v; \
		echo "Changes applied successfully!"; \
	else \
		echo "Aborted."; \
	fi

apply: ## Apply changes without confirmation (usage: make apply FLAGS="--dry-run")
	chezmoi apply $(CHEZMOI_FLAGS) $(CHEZMOI_APPLY_FLAGS) $(FLAGS) -v

status: ## Show chezmoi status
	chezmoi status $(CHEZMOI_FLAGS)

update: ## Pull latest changes from remote and apply
	chezmoi update $(CHEZMOI_FLAGS) -v

init: ## Initialize chezmoi (first-time setup)
	chezmoi init $(CHEZMOI_FLAGS)

add: ## Add a file to chezmoi (usage: make add FILE=/path/to/file)
ifndef FILE
	$(error FILE is not set. Usage: make add FILE=/path/to/file)
endif
	chezmoi add $(CHEZMOI_FLAGS) $(FILE)

edit: ## Edit chezmoi config
	chezmoi edit-config $(CHEZMOI_FLAGS)

verify: ## Verify chezmoi templates
	chezmoi execute-template < /dev/null
	@echo "Templates OK"

doctor: ## Run chezmoi doctor
	chezmoi doctor

managed: ## List all managed files
	chezmoi managed $(CHEZMOI_FLAGS)

unmanaged: ## List unmanaged files in home directory
	chezmoi unmanaged $(CHEZMOI_FLAGS)
