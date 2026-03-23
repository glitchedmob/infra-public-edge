# infra-public-edge

Public VPS infrastructure for glitchedmob. Manages a Vultr VPS running k3s with Headscale, deployed via Ansible and managed with Flux GitOps.

## Scope

- **OpenTofu (`src/tf/`)**: provisions Vultr VPS resources, Cloudflare DNS, and AWS SSM parameters.
- **Ansible (`src/ansible/`)**: runs host automation and cluster bootstrap operations.
- **Kubernetes (`src/k8s/`)**: holds Flux-managed manifests for edge platform services.

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.11 (version in `src/tf/.tofu-version`)
- [uv](https://docs.astral.sh/uv/) >= 0.10 (for Ansible tooling)
- AWS credentials (for SSM parameter access)
- Vultr API token
- Cloudflare API token

## Usage

### Terraform

```bash
make tf-init
make tf-plan
make tf-show ARGS=tfplan
make tf-output
make tf-apply
make tf-validate
make tf-format
make tf-lint-fix
```

### Ansible

```bash
make ansible-install
make ansible PLAYBOOK=site.yml
make ansible-shell HOST=x86-node-01 COMMAND='uname -a'
make ansible-inventory ARGS='--list'
make ansible-lint
make ansible-lint-fix
```

## Operational Notes

- `src/k8s/` manifests are reconciled by Flux after bootstrap.
- CI validates changes; infrastructure apply workflows remain operator-driven.
