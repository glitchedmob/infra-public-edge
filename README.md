# infra-public-edge

Provisions and operates the LZ public edge platform. Production runs on node 1 with Kubernetes; node 2 is being prepared to run Docker Compose.

## Scope
- Owns: public edge VPS provisioning, host bootstrap, and edge-hosted services.
- Owns: public DNS entrypoint and edge forwarding paths for `levizitting.com` and `sgf.dev` traffic.

## Structure
- `src/tf/`: Provisions Vultr compute/firewall, Cloudflare DNS records, and AWS SSM parameters.
- `src/ansible/`: Bootstraps Docker and deploys Compose applications on node 2. Legacy playbooks still manage node 1.
- `src/compose/`: Traefik, Headscale, Headplane, and Uptime Kuma for node 2.
- `src/k8s/`: Existing production Kubernetes manifests for node 1.

## Edge routing model
- Public hostnames resolve to the edge node (`x86-vps-node-01.levizitting.com`).
- Traefik on the edge cluster forwards zone traffic to internal workload clusters.
- HTTPS for forwarded zones uses TCP passthrough at the edge; TLS terminates on destination clusters.
- Destination app ingresses are defined in [`glitchedmob/infra-k8s-apps`](https://github.com/glitchedmob/infra-k8s-apps) and [`sgfdevs/infra-k8s-apps`](https://github.com/sgfdevs/infra-k8s-apps).

## DNS model
- Two DNS paths exist for `*.levizitting.com`: **public** (Cloudflare, for internet clients) and **Tailscale split-DNS** (edge CoreDNS, for tailnet clients).
- Public records are managed in [`glitchedmob/infra-dns`](https://github.com/glitchedmob/infra-dns); this repo only owns the edge node A/AAAA and `headscale` CNAME in `src/tf/domains.tf`.
- Tailscale split-DNS is served by edge CoreDNS at `10.255.255.1` (reachable only over Tailscale). Records for that CoreDNS server are managed in `src/k8s/infrastructure/coredns/coredns-custom-configmap.yaml`.

## Run
```bash
make help
make tf-init
make tf-plan
make ansible-install
EDGE_CONNECTION_MODE=public make ansible PLAYBOOK=bootstrap.yml
EDGE_CONNECTION_MODE=public make ansible PLAYBOOK=deploy.yml
```

## Compose applications

`deploy.yml` targets only `x86-vps-node-02`. It creates app-owned data directories, reads the existing Headplane cookie secret from SSM without logging it, renders configuration, and starts the Compose project in `/opt/infra-public-edge`. Run bootstrap first. Config and secret changes restart the affected services; Compose handles image and service-definition changes. Health checks live in Compose.

The four services share a Docker bridge network. Only Traefik's HTTP/HTTPS ports and Headscale's UDP STUN port are published. Traefik uses file-based routing and HTTP-01 certificates, without Docker socket access. Headplane stays at `https://headscale.levizitting.com/admin`; Kuma stays at `https://uptime.levizitting.com`.

All application processes run as non-root, with a read-only root filesystem, dropped capabilities, and `no-new-privileges`. Docker itself remains rootful, so this does not introduce rootless Docker's networking overhead. Data ownership is Headscale `10001:10001`, Headplane `10002:10002`, Traefik `10003:10003`, and Kuma `1000:1000`.

- Headplane can administer Headscale through its API. Editing Headscale's configuration or DNS records stays in Ansible, not the UI.
- Kuma permits ordinary ping through `ping_group_range`. It retains `NET_RAW` in the capability bounding set because the image's capability-marked ping binary otherwise fails to execute. The non-root Node process has no effective capabilities, and `no-new-privileges` prevents gaining them through execution. Its optional DNS cache cannot start its root helper; disable that setting in Kuma. Without the cache, repeated system-resolver lookups may cost more DNS traffic and latency. The slim image has no local browser, and this setup does not permit runtime package installation or Docker socket monitoring.
- `restart: unless-stopped` restarts exited processes. Docker health checks mark unhealthy services but do not restart a process that is still running.

This playbook does not migrate existing databases, change public DNS, or replace node 1's routing. HTTP-01 certificate issuance requires both public A and AAAA traffic to reach node 2. Until cutover, do not expect trusted certificates there. Preserve application data and Headscale identity keys during the later migration; deployment does not copy or reset them. Restored files must have the ownership listed above.

Backups, DNS forwarding, zone forwarding, and Tailscale configuration are not part of this deployment yet. Node 1's Kubernetes files, `apply.yml`, and existing automation remain intact while it serves production. The manual workflow offers `deploy.yml`; new Compose changes do not trigger an automatic deployment.

Check the Compose definitions locally with `docker compose -f src/compose/compose.yaml config --quiet`.

## Connectivity

Ansible and GitHub Actions reach the edge node over Tailscale by default. The Terraform inventory exposes both `public_ssh_host` and `tailscale_ssh_host`, and `group_vars/all.yml` selects the target based on `EDGE_CONNECTION_MODE` (default: `tailscale`).

- **Tailscale mode** (default): Ansible targets the MagicDNS hostname `x86-vps-node-01`. GitHub Actions joins Headscale before running playbooks.
- **Public mode**: Set `EDGE_CONNECTION_MODE=public` to target the Vultr public IP instead. GitHub Actions workflows offer a `connectivity-mode` dropdown for manual runs; automated workflows have a commented toggle at the top of the file.

To rebuild the node from scratch, temporarily re-enable public SSH in the Vultr firewall (`src/tf/main.tf`) and switch GitHub Actions to public mode until the node is enrolled in Headscale again.

## Local cluster access
```bash
make cluster-access
make kubectl ARGS='get nodes'
make k9s
```

- `make cluster-access` fetches `/etc/rancher/k3s/k3s.yaml`, writes it to `.local/kube/infra-public-edge.yaml`, and stages the upstream `derailed/k9s` Flux plugin in `.local/k9s/plugins/flux.yaml`.
- The generated kubeconfig rewrites the API server endpoint to `https://x86-vps-node-01:6443` and sets `tls-server-name: x86-vps-node-01` so it works over Tailscale MagicDNS.
- `make kubectl` and `make k9s` use the staged files in `.local/`; run `make cluster-access` once first and again when you want to refresh them.

## Restore
```bash
make cluster-access
make restore APP=headscale SNAPSHOT=162e7a85
make restore APP=uptime-kuma DATE='2026-05-18'
```

- `make restore` suspends the single Flux `public-edge-apps` kustomization, scales the target deployment down, applies the app's manual restore Job, waits for completion, then scales the deployment back up and resumes Flux.
- Set either `SNAPSHOT=<id>` or `DATE='<UTC prefix>'`. If neither is set, the latest snapshot is restored.
- Manual GitHub Actions restores use the same `scripts/restore-app.sh` entrypoint as the local command.
