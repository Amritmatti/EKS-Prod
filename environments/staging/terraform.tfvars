project     = "myapp"
environment = "staging"
region      = "us-east-1"

# CHANGE-ME: your staging AWS account ID.
allowed_account_ids = ["333333333333"]

tags = {
  Owner      = "platform-team"
  CostCenter = "engineering"
}

################################################################################
# Network - prod-like topology (3 AZs, NAT per AZ) to catch AZ issues before prod
################################################################################

vpc_cidr                 = "10.20.0.0/16"
az_count                 = 3
single_nat_gateway       = false
flow_logs_retention_days = 30

vpc_interface_endpoints = [
  "ecr.api",
  "ecr.dkr",
  "sts",
]

################################################################################
# EKS
################################################################################

kubernetes_version = "1.34"

endpoint_public_access = false
api_allowed_cidrs      = ["10.0.0.0/8"] # CHANGE-ME

cluster_log_retention_days = 30

enable_cluster_creator_admin_permissions = false

access_entries = {
  platform-admins = {
    principal_arn = "arn:aws:iam::333333333333:role/PlatformAdmin" # CHANGE-ME
    policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  }
}

node_groups = {
  system = {
    instance_types = ["m7i.large", "m6i.large"]
    min_size       = 2
    max_size       = 4
    desired_size   = 2
    labels         = { workload = "system" }
  }

  general = {
    instance_types = ["m7i.large", "m6i.large", "m5.large"]
    capacity_type  = "SPOT"
    min_size       = 2
    max_size       = 8
    desired_size   = 2
    labels         = { workload = "general" }
  }
}
