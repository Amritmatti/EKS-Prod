# terraform init -backend-config=backend.hcl
# Create the bucket first with ../../bootstrap. Ideally prod state lives in the prod account.
bucket       = "cityfalcon-terraform-remote-state"
key          = "eks/prod/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true # native S3 state locking (Terraform >= 1.10), no DynamoDB table needed
