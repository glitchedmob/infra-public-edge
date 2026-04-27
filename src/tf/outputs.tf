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

output "backup_bucket_name" {
  description = "Backblaze B2 bucket name for cluster backups"
  value       = b2_bucket.backups.bucket_name
}

output "backup_bucket_name_ssm_path" {
  description = "SSM Parameter Store path for the backup bucket name"
  value       = aws_ssm_parameter.backup_bucket_name.name
}

output "backup_b2_account_id_ssm_path" {
  description = "SSM Parameter Store path for the K8up B2 account ID"
  value       = aws_ssm_parameter.b2_account_id.name
}

output "backup_b2_account_key_ssm_path" {
  description = "SSM Parameter Store path for the K8up B2 account key"
  value       = aws_ssm_parameter.b2_account_key.name
}

output "backup_restic_password_ssm_paths" {
  description = "SSM Parameter Store paths for app restic repository passwords"
  value = {
    for app, param in aws_ssm_parameter.restic_password : app => param.name
  }
}

output "ssm_capacitor_admin_password_path" {
  description = "SSM Parameter Store path for Capacitor admin plaintext password"
  value       = aws_ssm_parameter.capacitor_admin_password.name
}

output "ssm_capacitor_admin_password_bcrypt_path" {
  description = "SSM Parameter Store path for Capacitor admin bcrypt users string"
  value       = aws_ssm_parameter.capacitor_admin_password_bcrypt.name
}
