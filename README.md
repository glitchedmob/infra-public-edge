# infra-public-edge

Provisions and operates the LZ public edge platform.

## Scope
- Owns: public edge VPS provisioning, host bootstrap, and edge-hosted services.
- Owns: public DNS entrypoint and edge forwarding paths for `levizitting.com` and `sgf.dev` traffic.

## Structure
- `src/tf/`: Provisions Vultr compute/firewall, Cloudflare DNS records, and AWS SSM parameters.
- `src/ansible/`: Host configuration, application deployment, and Compose service definitions.
- `src/k8s/`: Kubernetes manifests.

## Edge routing model
- Public hostnames resolve to the edge node.
- Traefik on the edge cluster forwards zone traffic to internal workload clusters.
- HTTPS for forwarded zones uses TCP passthrough at the edge; TLS terminates on destination clusters.
- Destination app ingresses are defined in [`glitchedmob/infra-k8s-apps`](https://github.com/glitchedmob/infra-k8s-apps) and [`sgfdevs/infra-k8s-apps`](https://github.com/sgfdevs/infra-k8s-apps).

## DNS model
- Two DNS paths exist for `*.levizitting.com`: **public** (Cloudflare, for internet clients) and **Tailscale split-DNS** (edge CoreDNS, for tailnet clients).
- Public records are managed in [`glitchedmob/infra-dns`](https://github.com/glitchedmob/infra-dns); this repo only owns the edge node A/AAAA and `headscale` CNAME in `src/tf/domains.tf`.
- Tailscale split-DNS is served by edge CoreDNS at `10.255.255.1` (reachable only over Tailscale). Records are managed in `src/ansible/playbooks/compose/coredns/Corefile`. Bootstrap persists the private loopback address in `/etc/network/interfaces.d/private-dns`. Traefik publishes TCP/UDP port 53 on that address only and forwards to CoreDNS inside Docker. The Tailscale playbook advertises `10.255.255.1/32`.

## Run
Deployments require `rsync` on the control machine.

Per-app Resticprofile backup configuration lives beside the [Compose definitions](src/ansible/playbooks/compose).

```bash
make help
make tf-init
make tf-plan
make ansible-install
EDGE_CONNECTION_MODE=public make ansible PLAYBOOK=bootstrap.yml
EDGE_CONNECTION_MODE=public make ansible PLAYBOOK=deploy.yml
EDGE_CONNECTION_MODE=public make ansible PLAYBOOK=tailscale-headscale.yml
```

## Connectivity

Ansible and GitHub Actions reach the edge node over Tailscale by default. The Terraform inventory exposes both `public_ssh_host` and `tailscale_ssh_host`, and `group_vars/all.yml` selects the target based on `EDGE_CONNECTION_MODE` (default: `tailscale`).

- **Tailscale mode** (default): Ansible uses the inventory's Tailscale hostname. GitHub Actions joins Headscale before running playbooks.
- **Public mode**: Set `EDGE_CONNECTION_MODE=public` to target the Vultr public IP instead. GitHub Actions workflows offer a `connectivity-mode` dropdown for manual runs; automated workflows have a commented toggle at the top of the file.

To rebuild the node from scratch, temporarily re-enable public SSH in the Vultr firewall (`src/tf/main.tf`) and switch GitHub Actions to public mode until the node is enrolled in Headscale again.

## Local cluster access
```bash
make cluster-access
make kubectl ARGS='get nodes'
make k9s
```

- `make cluster-access` fetches `/etc/rancher/k3s/k3s.yaml`, writes it to `.local/kube/infra-public-edge.yaml`, and stages the upstream `derailed/k9s` Flux plugin in `.local/k9s/plugins/flux.yaml`.
- The generated kubeconfig uses the edge node's Tailscale hostname for the API server endpoint and TLS server name.
- `make kubectl` and `make k9s` use the staged files in `.local/`; run `make cluster-access` once first and again when you want to refresh them.

## Kubernetes restore
```bash
make cluster-access
make restore APP=headscale SNAPSHOT=162e7a85
make restore APP=uptime-kuma DATE='2026-05-18'
```

- `make restore` suspends the single Flux `public-edge-apps` kustomization, scales the target deployment down, applies the app's manual restore Job, waits for completion, then scales the deployment back up and resumes Flux.
- Set either `SNAPSHOT=<id>` or `DATE='<UTC prefix>'`. If neither is set, the latest snapshot is restored.
- Manual GitHub Actions restores use the same `scripts/restore-app.sh` entrypoint as the local command.
