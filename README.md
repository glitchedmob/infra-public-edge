# infra-public-edge

Provisions and operates the LZ public edge platform, including the VPS and Kubernetes resources that route public traffic and run edge-hosted services.

## Scope
- Owns: public edge VPS provisioning, cluster bootstrap, and edge-cluster Kubernetes resources.
- Owns: public DNS entrypoint and edge forwarding paths for `levizitting.com` and `sgf.dev` traffic.

## Structure
- `src/tf/`: Provisions Vultr compute/firewall, Cloudflare DNS records, and AWS SSM parameters.
- `src/ansible/`: Bootstraps host and k3s, then applies base cluster configuration.
- `src/k8s/`: Kubernetes manifests for edge services and domain forwarding behavior.

## Edge routing model
- Public hostnames resolve to the edge node (`x86-vps-node-01.levizitting.com`).
- Traefik on the edge cluster forwards zone traffic to internal workload clusters.
- HTTPS for forwarded zones uses TCP passthrough at the edge; TLS terminates on destination clusters.
- Destination app ingresses are defined in [`glitchedmob/infra-k8s-apps`](https://github.com/glitchedmob/infra-k8s-apps) and [`sgfdevs/infra-k8s-apps`](https://github.com/sgfdevs/infra-k8s-apps).

## Run
```bash
make help
make tf-init
make tf-plan
make ansible-install
make ansible PLAYBOOK=bootstrap.yml
make ansible PLAYBOOK=apply.yml
```

## Local cluster access
```bash
make kubeconfig
make kubectl ARGS='get nodes'
make k9s
```

- `make kubeconfig` fetches `/etc/rancher/k3s/k3s.yaml` from `x86-vps-node-01` and writes a local kubeconfig to `~/.kube/infra-public-edge.yaml`.
- The generated kubeconfig rewrites the API server endpoint to `https://x86-vps-node-01:6443` and sets `tls-server-name: x86-vps-node-01` so it works over Tailscale MagicDNS.
- `make kubectl` and `make k9s` use `~/.kube/infra-public-edge.yaml`; run `make kubeconfig` once first and again when you want to refresh it.
