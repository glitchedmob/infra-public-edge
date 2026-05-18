.PHONY: help tf-init tf-plan tf-show tf-output tf-apply tf-validate tf-format tf-lint-fix tf-providers-lock \
        ansible ansible-shell ansible-install ansible-inventory ansible-lint ansible-lint-fix \
        cluster-access kubectl k9s

TF_DIR := src/tf
ANSIBLE_DIR := src/ansible
ENVRC := $(CURDIR)/.envrc
LOCAL_DIR := $(CURDIR)/.local
KUBECONFIG_PATH := $(LOCAL_DIR)/kube/infra-public-edge.yaml
K9S_CONFIG_DIR := $(LOCAL_DIR)/k9s
K9S_PLUGIN_DIR := $(K9S_CONFIG_DIR)/plugins
FLUX_K9S_PLUGIN_URL := https://raw.githubusercontent.com/derailed/k9s/master/plugins/flux.yaml
SHELL := bash

help:
	@echo "OpenTofu commands:"
	@echo "  Init:              make tf-init [ARGS='-backend=false']"
	@echo "  Plan:              make tf-plan [ARGS='-out=tfplan -destroy']"
	@echo "  Show:              make tf-show ARGS=<planfile>"
	@echo "  Output:            make tf-output [ARGS='-json']"
	@echo "  Apply:             make tf-apply [ARGS='-auto-approve tfplan']"
	@echo "  Validate:          make tf-validate"
	@echo "  Format check:      make tf-format"
	@echo "  Format fix:        make tf-lint-fix"
	@echo "  Providers lock:    make tf-providers-lock"
	@echo ""
	@echo "Ansible commands:"
	@echo "  Install deps:      make ansible-install"
	@echo "  Run playbook:      make ansible PLAYBOOK=playbook.yml [ARGS='-v']"
	@echo "  Inventory:         make ansible-inventory [ARGS='--list']"
	@echo "  Shell command:     make ansible-shell HOST=host COMMAND='cmd' [ARGS='-v']"
	@echo "  Lint:              make ansible-lint"
	@echo "  Lint fix:          make ansible-lint-fix"
	@echo ""
	@echo "Local Kubernetes commands:"
	@echo "  Setup local access: make cluster-access"
	@echo "  kubectl helper:    make kubectl ARGS='get nodes'"
	@echo "  k9s helper:        make k9s"

# --- OpenTofu ---

tf-init:
	@source .envrc 2>/dev/null || true && cd $(TF_DIR) && tofu init $(ARGS)

tf-plan:
	@source .envrc 2>/dev/null || true && cd $(TF_DIR) && tofu plan $(ARGS)

tf-show:
	@source .envrc 2>/dev/null || true && cd $(TF_DIR) && tofu show $(ARGS)

tf-output:
	@source .envrc 2>/dev/null || true && cd $(TF_DIR) && tofu output $(ARGS)

tf-apply:
	@source .envrc 2>/dev/null || true && cd $(TF_DIR) && tofu apply $(ARGS)

tf-validate:
	@source .envrc 2>/dev/null || true && cd $(TF_DIR) && tofu validate

tf-format:
	@cd $(TF_DIR) && tofu fmt -check -recursive

tf-lint-fix:
	@cd $(TF_DIR) && tofu fmt -recursive

tf-providers-lock:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu providers lock \
		-platform=darwin_amd64 \
		-platform=darwin_arm64 \
		-platform=linux_amd64 \
		-platform=linux_arm64 \
		-platform=windows_amd64

# --- Ansible ---

ansible:
	@[ -n "$(PLAYBOOK)" ] || (echo "Error: PLAYBOOK required" && exit 1)
	@source .envrc 2>/dev/null || true && cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/$(PLAYBOOK) $(ARGS)

ansible-install:
	@cd $(ANSIBLE_DIR) && uv sync --locked && uv run ansible-galaxy collection install -r requirements.yml

ansible-shell:
	@[ -n "$(HOST)" ] || (echo "Error: HOST required (e.g., x86-node-01)" && exit 1)
	@[ -n "$(COMMAND)" ] || (echo "Error: COMMAND required (e.g., 'uname -a')" && exit 1)
	@source .envrc 2>/dev/null || true && cd $(ANSIBLE_DIR) && uv run ansible $(HOST) -m shell -a "$(COMMAND)" $(ARGS)

ansible-inventory:
	@source .envrc 2>/dev/null || true && cd $(ANSIBLE_DIR) && uv run ansible-inventory $(ARGS)

ansible-lint:
	@cd $(ANSIBLE_DIR) && uv run ansible-lint

ansible-lint-fix:
	@cd $(ANSIBLE_DIR) && uv run ansible-lint --fix

cluster-access:
	@mkdir -p "$(dir $(KUBECONFIG_PATH))" "$(K9S_PLUGIN_DIR)"
	@curl -fsSL "$(FLUX_K9S_PLUGIN_URL)" -o "$(K9S_PLUGIN_DIR)/flux.yaml"
	@source .envrc 2>/dev/null || true && cd $(ANSIBLE_DIR) && uv run ansible-playbook playbooks/local-kubeconfig.yml -e kubeconfig_output_path="$(KUBECONFIG_PATH)"


kubectl:
	@KUBECONFIG="$(KUBECONFIG_PATH)" kubectl $(ARGS)

k9s:
	@KUBECONFIG="$(KUBECONFIG_PATH)" K9S_CONFIG_DIR="$(K9S_CONFIG_DIR)" k9s $(ARGS)
