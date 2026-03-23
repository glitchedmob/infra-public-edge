output "ssm_cookie_secret_path" {
  description = "SSM Parameter Store path for headplane cookie secret"
  value       = aws_ssm_parameter.cookie_secret.name
}

output "ssm_private_key_path" {
  description = "SSM Parameter Store path for SSH private key"
  value       = module.ssh_key.ssm_path
}

output "vps_hostname" {
  description = "DNS hostname for the VPS"
  value       = local.vps_fqdn
}

output "ansible_user" {
  description = "Ansible SSH user for the VPS"
  value       = local.user
}
