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
