locals {
  backup_bucket_name = "levizitting-public-edge-backups"
}

resource "b2_bucket" "backups" {
  bucket_name = local.backup_bucket_name
  bucket_type = "allPrivate"
}
