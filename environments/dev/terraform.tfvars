project     = "myapp"
environment = "dev"
region      = "us-east-1"

# CHANGE-ME: your dev AWS account ID.
allowed_account_ids = ["222222222222"]

tags = {
  Owner      = "platform-team"
  CostCenter = "engineering"
}

################################################################################
# Network - cost-optimised: 2 AZs, single NAT, no interface endpoints
################################################################################

vpc_cidr                 = "10.10.0.0/16"
az_count                 = 2
single_nat_gateway       = true
flow_logs_retention_days = 14
vpc_interface_endpoints  = []

################################################################################
# EKS
################################################################################

kubernetes_version = "1.34"

# Public API, but only from your office / VPN egress IPs.
endpoint_public_access       = true
endpoint_public_access_cidrs = ["203.0.113.0/24"] # CHANGE-ME
api_allowed_cidrs            = []

cluster_log_retention_days = 14

enable_cluster_creator_admin_permissions = true

access_entries = {}

node_groups = {
  general = {
    instance_types = ["m7i.large", "m6i.large", "m5.large"]
    capacity_type  = "SPOT"
    min_size       = 2
    max_size       = 5
    desired_size   = 2
  }
}
