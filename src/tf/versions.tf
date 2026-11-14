terraform {
  required_version = ">= 1.12"

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.33"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.14"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.29"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.5"
    }
    writeonly = {
      source  = "glitchedmob/writeonly"
      version = "~> 1.0"
    }
  }
}
