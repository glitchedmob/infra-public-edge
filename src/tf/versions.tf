terraform {
  required_version = ">= 1.11"

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.29"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.33"
    }
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.12"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.17"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
    writeonly = {
      source  = "glitchedmob/writeonly"
      version = "~> 1.0"
    }
  }
}
