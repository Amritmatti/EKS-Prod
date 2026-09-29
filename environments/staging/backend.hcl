# terraform init -backend-config=backend.hcl
bucket       = "cityfalcon-terraform-remote-state"
key          = "eks/staging/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
