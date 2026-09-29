terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial config - supply per-env values with:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {}
}
