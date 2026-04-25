locals {
  backup_bucket_name = "levizitting-public-edge-backups"
  backup_ssm_prefix  = "/homelab/public-edge/backups"
  backup_apps        = toset(["headscale", "headplane"])
}

resource "b2_bucket" "backups" {
  bucket_name = local.backup_bucket_name
  bucket_type = "allPrivate"
}

resource "aws_ssm_parameter" "backup_bucket_name" {
  name  = "${local.backup_ssm_prefix}/bucket-name"
  type  = "String"
  value = local.backup_bucket_name
}

resource "aws_ssm_parameter" "b2_account_id" {
  name             = "${local.backup_ssm_prefix}/b2-account-id"
  type             = "SecureString"
  value_wo         = "CHANGEME"
  value_wo_version = 1
}

resource "aws_ssm_parameter" "b2_account_key" {
  name             = "${local.backup_ssm_prefix}/b2-account-key"
  type             = "SecureString"
  value_wo         = "CHANGEME"
  value_wo_version = 1
}

ephemeral "random_password" "restic_password" {
  for_each = local.backup_apps

  length  = 32
  special = false
}

resource "aws_ssm_parameter" "restic_password" {
  for_each = local.backup_apps

  name             = "${local.backup_ssm_prefix}/${each.key}/restic-password"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.restic_password[each.key].result
  value_wo_version = 1
}
