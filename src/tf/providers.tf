provider "vultr" {
  api_key = var.vultr_api_token
}

provider "aws" {
  region = var.aws_region
}

provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
