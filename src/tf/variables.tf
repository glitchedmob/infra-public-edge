variable "vultr_api_token" {
  description = "Vultr API token"
  type        = string
  sensitive   = true
}

variable "vultr_region" {
  description = "Vultr region for VPS"
  type        = string
  default     = "ord"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "b2_application_key_id" {
  description = "Backblaze B2 application key ID for Terraform bucket management"
  type        = string
  sensitive   = true
}

variable "b2_application_key" {
  description = "Backblaze B2 application key for Terraform bucket management"
  type        = string
  sensitive   = true
}
