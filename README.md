# infra-public-edge

Public VPS infrastructure for glitchedmob. Manages a Vultr VPS running k3s with Headscale, deployed via Ansible and managed with Flux GitOps.

## Components

- **tf/** - OpenTofu project: Vultr VPS provisioning, Cloudflare DNS records, AWS SSM parameters
- **ansible/** - Ansible project: k3s bootstrap, Flux GitOps deployment
- **k8s/** - Kubernetes manifests managed by Flux: Headscale, Headplane, cert-manager, external-secrets, reloader

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.11 (version in `tf/.tofu-version`)
- [uv](https://docs.astral.sh/uv/) >= 0.10 (for Ansible tooling)
- AWS credentials (for SSM parameter access)
- Vultr API token
- Cloudflare API token

## Usage

### Terraform

```bash
make tf-init     # Initialize
make tf-plan     # Preview changes
make tf-apply    # Apply changes
make tf-validate # Validate syntax
make tf-format   # Check formatting
```

### Ansible

```bash
make ansible-install   # Install Python deps + Ansible collections
make ansible-bootstrap # Install k3s on the VPS
make ansible-apply     # Deploy Flux and initial manifests
make ansible-lint      # Lint playbooks
```

### Kubernetes

k8s/ manifests are managed by Flux. After initial bootstrap via Ansible, Flux watches this repo and applies changes automatically.

## Apply Order

This repo is step 5 in the glitchedmob infrastructure:

1. `infra-aws-core` - S3 backend
2. `infra-shared` - Shared TF modules
3. `infra-gha` - Reusable GHA workflows
4. `infra-on-prem` - MikroTik + Proxmox
5. **`infra-public-edge`** - This repo
6. `infra-headscale` - Headscale users (depends on this repo's k3s)
