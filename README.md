# infra-public-edge

Provisions and operates the LZ public edge platform.

## Scope
- Owns: public edge VPS provisioning, host bootstrap, and edge-hosted services.
- Owns: public DNS entrypoint and edge forwarding paths for `levizitting.com` and `sgf.dev` traffic.

## Structure
- `src/tf/`: Provisions Vultr compute/firewall, Cloudflare DNS records, and AWS SSM parameters.
- `src/ansible/`: Host configuration, application deployment, and Compose service definitions.

## Edge routing model
- Public hostnames use `public-edge.levizitting.com`, which points to `x86-vps-node-02.levizitting.com`.
- Traefik on the edge node forwards zone traffic to internal workload clusters.
- HTTPS for forwarded zones uses TCP passthrough at the edge; TLS terminates on destination clusters.
- Destination app ingresses are defined in [`glitchedmob/infra-k8s-apps`](https://github.com/glitchedmob/infra-k8s-apps) and [`sgfdevs/infra-k8s-apps`](https://github.com/sgfdevs/infra-k8s-apps).

## DNS model
- Two DNS paths exist for `*.levizitting.com`: **public** (Cloudflare, for internet clients) and **Tailscale split-DNS** (edge CoreDNS, for tailnet clients).
- Public records are managed in [`glitchedmob/infra-dns`](https://github.com/glitchedmob/infra-dns); this repo owns the edge node A/AAAA records and the `public-edge` and `headscale` CNAMEs in `src/tf/domains.tf`.
- Tailscale split-DNS is served by edge CoreDNS at `10.255.255.1` (reachable only over Tailscale). Records are managed in `src/ansible/playbooks/compose/coredns/Corefile`. Bootstrap persists the private loopback address in `/etc/network/interfaces.d/private-dns`. Traefik publishes TCP/UDP port 53 on that address only and forwards to CoreDNS inside Docker. The Tailscale playbook advertises `10.255.255.1/32`.

## Run
Deployments require `rsync` on the control machine.

Per-app Resticprofile backup configuration lives beside the [Compose definitions](src/ansible/playbooks/compose).

```bash
make help
make tf-init
make tf-plan
make ansible-install
make ansible PLAYBOOK=bootstrap.yml
make ansible PLAYBOOK=deploy.yml
make ansible PLAYBOOK=tailscale-headscale.yml
```

## Connectivity

Ansible and manual GitHub Actions runs reach the edge node over Tailscale by default. Automated deployments always use Tailscale. The Terraform inventory exposes both `public_ssh_host` and `tailscale_ssh_host`, and `group_vars/all.yml` selects the target based on `EDGE_CONNECTION_MODE` (default: `tailscale`).

- **Tailscale mode** (default): Ansible uses the inventory's Tailscale hostname. GitHub Actions joins Headscale before running playbooks.
- **Public mode**: Set `EDGE_CONNECTION_MODE=public` to target the Vultr public IP instead. Manual GitHub Actions runs retain a `connectivity-mode` dropdown for bootstrap or recovery.

The node-02 Vultr firewall blocks public SSH for both IPv4 and IPv6. Selecting public mode does not open the firewall. For a fresh rebuild, temporarily add a TCP port 22 rule to `local.node_02_firewall_rules` in `src/tf/main.tf` and apply it. Run bootstrap, deployment, and Tailscale enrollment in public mode, verify SSH over Tailscale, then remove the temporary rule and apply again.

Automated deployments require a valid `HEADSCALE_AUTH_KEY` GitHub Actions secret and a reachable Headscale server.

## Node and credential naming

Terraform keeps `node_02` in the instance, firewall, inventory, and DNS resource names so a future replacement can run alongside it. The public node outputs are `node_02_fqdn` and `node_02_tailscale_host`.

The SSH key and Headplane cookie secret remain shared credentials. Their SSM paths still contain `x86-vps-node-01` because node 02 uses the existing values. Removing node 01 must not delete or rotate them. The cookie secret resource is renamed to `headplane_cookie_secret` with a Terraform `moved` block; its SSM path and value stay unchanged.

Backups remain in the existing B2 bucket and per-application Restic repositories. Their SSM paths under `/homelab/public-edge/backups` are independent of node names.
