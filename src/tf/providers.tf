provider "vultr" {
  api_key = var.vultr_api_token
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
