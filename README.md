# infra-public-edge

Public VPS infrastructure for glitchedmob. Manages a Vultr VPS running k3s with Headscale, deployed via Ansible and managed with Flux GitOps.

## Components

- **src/tf/** - OpenTofu project: Vultr VPS provisioning, Cloudflare DNS records, AWS SSM parameters
- **src/ansible/** - Ansible project: k3s bootstrap, Flux GitOps deployment
- **src/k8s/** - Kubernetes manifests managed by Flux: Headscale, Headplane, cert-manager, external-secrets, reloader

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.11 (version in `src/tf/.tofu-version`)
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

src/k8s/ manifests are managed by Flux. After initial bootstrap via Ansible, Flux watches this repo and applies changes automatically.
