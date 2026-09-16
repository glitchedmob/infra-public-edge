locals {
  node_02_hostname = "x86-vps-node-02"
  node_02_plan     = "vc2-2c-2gb"
  node_02_os_id    = 2625 # Debian 13 x64
  node_02_firewall_rules = [
    { protocol = "tcp", port = "80", ip_types = ["v4", "v6"], notes = "Allow HTTP" },
    { protocol = "tcp", port = "443", ip_types = ["v4", "v6"], notes = "Allow HTTPS" },
    { protocol = "udp", port = "3478", ip_types = ["v4", "v6"], notes = "Allow DERP" },
    { protocol = "tcp", port = "3478", ip_types = ["v4", "v6"], notes = "Allow DERP" },
  ]
  ssh_user           = "admin"
  dns_record_comment = "managedBy=tf,repo=glitchedmob/infra-public-edge"
  headscale_hostname = "headscale"
}

# Node 02 uses this existing key. Preserve its name and SSM path to avoid
# rotating the key or changing the instance's cloud-init user data.
module "ssh_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = "x86-vps-node-01"
  key_version          = 2
  ssm_private_key_path = "/homelab/x86-vps-node-01/ssh-private-key"
}

ephemeral "random_password" "headplane_cookie_secret" {
  length  = 32
  special = false
}

# This application secret survives node replacements; retain its existing path.
resource "aws_ssm_parameter" "headplane_cookie_secret" {
  name             = "/homelab/x86-vps-node-01/headplane-cookie-secret"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.headplane_cookie_secret.result
  value_wo_version = 1
}

moved {
  from = aws_ssm_parameter.cookie_secret
  to   = aws_ssm_parameter.headplane_cookie_secret
}

resource "vultr_firewall_group" "node_02" {
  description = "${local.node_02_hostname} firewall group"
}

resource "vultr_firewall_rule" "node_02" {
  for_each = {
    for rule in flatten([
      for rule in local.node_02_firewall_rules : [
        for ip_type in rule.ip_types : {
          key         = "${ip_type}-${rule.protocol}-${rule.port}"
          protocol    = rule.protocol
          port        = rule.port
          ip_type     = ip_type
          notes       = rule.notes
          subnet      = ip_type == "v4" ? "0.0.0.0" : "::"
          subnet_size = 0
        }
      ]
    ]) : rule.key => rule
  }

  firewall_group_id = vultr_firewall_group.node_02.id
  protocol          = each.value.protocol
  port              = each.value.port
  ip_type           = each.value.ip_type
  notes             = each.value.notes
  subnet            = each.value.subnet
  subnet_size       = each.value.subnet_size
}

resource "vultr_instance" "node_02" {
  plan              = local.node_02_plan
  region            = var.vultr_region
  os_id             = local.node_02_os_id
  label             = local.node_02_hostname
  hostname          = local.node_02_hostname
  enable_ipv6       = true
  backups           = "disabled"
  ddos_protection   = false
  firewall_group_id = vultr_firewall_group.node_02.id
  user_data = templatefile("${path.module}/cloud-config.yml.tftpl", {
    ssh_keys = [module.ssh_key.public_key]
    user     = local.ssh_user
  })
}

resource "ansible_host" "node_02" {
  name = local.node_02_hostname
  variables = {
    ansible_user               = local.ssh_user
    public_ssh_host            = vultr_instance.node_02.main_ip
    tailscale_ssh_host         = local.node_02_hostname
    public_ipv4                = vultr_instance.node_02.main_ip
    public_ipv6                = vultr_instance.node_02.v6_main_ip
    ssm_private_key_path       = module.ssh_key.ssm_path
    tailscale_login_server     = "https://${local.headscale_hostname}.${data.cloudflare_zone.levizitting_com.name}"
    ssm_tailscale_authkey_path = "/homelab/headscale/infra-public-edge/${local.node_02_hostname}-auth-key"
  }
}
