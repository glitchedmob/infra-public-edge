.PHONY: help tf-init tf-plan tf-show tf-output tf-apply tf-validate tf-format tf-lint-fix \
        ansible ansible-install ansible-inventory ansible-lint ansible-lint-fix

TF_DIR := tf
ANSIBLE_DIR := ansible
ENVRC := $(CURDIR)/.envrc
SHELL := bash

help:
	@echo "OpenTofu commands:"
	@echo "  Init:              make tf-init"
	@echo "  Plan:              make tf-plan"
	@echo "  Show:              make tf-show ARGS=<planfile>"
	@echo "  Output:            make tf-output [ARGS='-json']"
	@echo "  Apply:             make tf-apply"
	@echo "  Validate:          make tf-validate"
	@echo "  Format check:      make tf-format"
	@echo "  Format fix:        make tf-lint-fix"
	@echo ""
	@echo "Ansible commands:"
	@echo "  Install deps:      make ansible-install"
	@echo "  Run playbook:      make ansible PLAYBOOK=playbook.yml [ARGS='-v']"
	@echo "  Inventory:         make ansible-inventory [ARGS='--list']"
	@echo "  Lint:              make ansible-lint"
	@echo "  Lint fix:          make ansible-lint-fix"

# --- OpenTofu ---

tf-init:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu init

tf-plan:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu plan

tf-show:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu show $(ARGS)

tf-output:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu output $(ARGS)

tf-apply:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu apply

tf-validate:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu validate

tf-format:
	@cd $(TF_DIR) && tofu fmt -check -recursive

tf-lint-fix:
	@cd $(TF_DIR) && tofu fmt -recursive

# --- Ansible ---

ansible:
	@[ -n "$(PLAYBOOK)" ] || (echo "Error: PLAYBOOK required" && exit 1)
	@cd $(ANSIBLE_DIR) && source "$(ENVRC)" && uv run ansible-playbook playbooks/$(PLAYBOOK) $(ARGS)

ansible-install:
	@cd $(ANSIBLE_DIR) && uv sync --locked && uv run ansible-galaxy collection install -r requirements.yml

ansible-inventory:
	@cd $(ANSIBLE_DIR) && source "$(ENVRC)" && uv run ansible-inventory $(ARGS)

ansible-lint:
	@cd $(ANSIBLE_DIR) && uv run ansible-lint

ansible-lint-fix:
	@cd $(ANSIBLE_DIR) && uv run ansible-lint --fix
