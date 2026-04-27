locals {
  vultr_2_cpu_2_gb_ram      = "vc2-2c-2gb"
  vultr_debian_12_x64_os_id = 2625
  firewall_rules = [
    { protocol = "tcp", port = "22", ip_types = ["v4", "v6"], notes = "Allow SSH" },
    { protocol = "tcp", port = "80", ip_types = ["v4", "v6"], notes = "Allow HTTP" },
    { protocol = "tcp", port = "443", ip_types = ["v4", "v6"], notes = "Allow HTTPS" },
    { protocol = "udp", port = "3478", ip_types = ["v4", "v6"], notes = "Allow DERP" },
    { protocol = "tcp", port = "3478", ip_types = ["v4", "v6"], notes = "Allow DERP" },
  ]
  user                                     = "admin"
  ipv6_normalized                          = cidrhost("${vultr_instance.this.v6_main_ip}/128", 0)
  headscale_hostname                       = "headscale"
  hostname                                 = "x86-vps-node-01"
  vps_fqdn                                 = "${local.hostname}.${data.cloudflare_zone.levizitting_com.name}"
  flux_access_key_id_ssm_path              = "/homelab/${local.hostname}/flux-ssm-access-key-id"
  flux_secret_access_key_ssm_path          = "/homelab/${local.hostname}/flux-ssm-secret-access-key"
  github_status_token_ssm_path             = "/homelab/${local.hostname}/flux-github-status-token"
  capacitor_admin_password_ssm_path        = "/homelab/${local.hostname}/capacitor-admin-password"
  capacitor_admin_password_bcrypt_ssm_path = "/homelab/${local.hostname}/capacitor-admin-password-bcrypt"
  capacitor_password_version               = 1
}

module "ssh_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = local.hostname
  key_version          = 2
  ssm_private_key_path = "/homelab/${local.hostname}/ssh-private-key"
}

module "flux_deploy_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = "flux-${local.hostname}"
  ssm_private_key_path = "/homelab/${local.hostname}/flux-git-private-key"
  ssm_public_key_path  = "/homelab/${local.hostname}/flux-git-public-key"
  key_version          = 2
}

ephemeral "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "cookie_secret" {
  name             = "/homelab/${local.hostname}/headplane-cookie-secret"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.cookie_secret.result
  value_wo_version = 1
}

resource "aws_ssm_parameter" "github_status_token" {
  name             = local.github_status_token_ssm_path
  type             = "SecureString"
  value_wo         = "CHANGEME"
  value_wo_version = 1
}

ephemeral "random_password" "capacitor_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "capacitor_admin_password" {
  name             = local.capacitor_admin_password_ssm_path
  type             = "SecureString"
  value_wo         = ephemeral.random_password.capacitor_admin.result
  value_wo_version = local.capacitor_password_version
}

resource "aws_ssm_parameter" "capacitor_admin_password_bcrypt" {
  name             = local.capacitor_admin_password_bcrypt_ssm_path
  type             = "SecureString"
  value_wo         = "me@levizitting.com:${ephemeral.random_password.capacitor_admin.bcrypt_hash}"
  value_wo_version = local.capacitor_password_version
}

resource "vultr_firewall_group" "this" {
  description = "${local.hostname} firewall group"
}

resource "vultr_firewall_rule" "fw_rules" {
  for_each = {
    for rule in flatten([
      for idx, rule in local.firewall_rules : [
        for ip_type in rule.ip_types : {
          key         = "${idx}-${ip_type}-${rule.protocol}-${rule.port}"
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

  firewall_group_id = vultr_firewall_group.this.id
  protocol          = each.value.protocol
  port              = each.value.port
  ip_type           = each.value.ip_type
  notes             = each.value.notes
  subnet            = each.value.subnet
  subnet_size       = each.value.subnet_size
}

resource "vultr_instance" "this" {
  plan              = local.vultr_2_cpu_2_gb_ram
  region            = var.vultr_region
  os_id             = local.vultr_debian_12_x64_os_id
  label             = local.hostname
  hostname          = local.hostname
  enable_ipv6       = true
  backups           = "disabled"
  ddos_protection   = false
  firewall_group_id = vultr_firewall_group.this.id
  user_data = templatefile("${path.module}/cloud-config.yml.tftpl", {
    ssh_keys = [module.ssh_key.public_key]
    user     = local.user
  })
}

resource "ansible_host" "this" {
  name = local.hostname
  variables = {
    ansible_user                    = local.user
    ansible_host                    = vultr_instance.this.main_ip
    public_ipv4                     = vultr_instance.this.main_ip
    public_ipv6                     = vultr_instance.this.v6_main_ip
    ssm_private_key_path            = module.ssh_key.ssm_path
    ssm_cookie_secret_path          = aws_ssm_parameter.cookie_secret.name
    ssm_flux_access_key_id_path     = local.flux_access_key_id_ssm_path
    ssm_flux_secret_access_key_path = local.flux_secret_access_key_ssm_path
    ssm_flux_git_private_key_path   = module.flux_deploy_key.ssm_path
    ssm_github_status_token_path    = aws_ssm_parameter.github_status_token.name
    domain                          = data.cloudflare_zone.levizitting_com.name
    headscale_hostname              = "${local.headscale_hostname}.${data.cloudflare_zone.levizitting_com.name}"
    tailscale_login_server          = "https://${local.headscale_hostname}.${data.cloudflare_zone.levizitting_com.name}"
    ssm_tailscale_authkey_path      = "/homelab/headscale/infra-public-edge/${local.hostname}-auth-key"
  }
}
