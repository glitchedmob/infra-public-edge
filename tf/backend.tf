# Backend configuration - values provided via CLI or environment variables
# Example: terraform init -backend-config="bucket=mybucket" -backend-config="region=us-east-1"
terraform {
  backend "s3" {
    bucket         = "levizitting-infra-tf-state"
    key            = "public-vps/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
