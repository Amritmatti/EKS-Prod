project     = "myapp"
environment = "prod"
region      = "us-east-1"

# CHANGE-ME: your prod AWS account ID - protects against applying with the wrong credentials.
allowed_account_ids = ["111111111111"]

tags = {
  Owner      = "platform-team"
  CostCenter = "engineering"
}

################################################################################
# Network - 3 AZs, NAT per AZ, private endpoints for AWS APIs
################################################################################

vpc_cidr                 = "10.30.0.0/16"
az_count                 = 3
single_nat_gateway       = false
flow_logs_retention_days = 365

vpc_interface_endpoints = [
  "ecr.api",
  "ecr.dkr",
  "sts",
  "logs",
  "ec2",
  "elasticloadbalancing",
  "autoscaling",
  "eks-auth", # EKS Pod Identity
  "ssm",
  "ssmmessages",
  "ec2messages",
]

################################################################################
# EKS
################################################################################

# CHANGE-ME: check supported versions: aws eks describe-cluster-versions
kubernetes_version = "1.34"

# Private API only. kubectl access goes over VPN / Direct Connect / bastion in these CIDRs.
endpoint_public_access = false
api_allowed_cidrs      = ["10.0.0.0/8"] # CHANGE-ME: narrow to your VPN / CI runner CIDRs

cluster_log_retention_days = 365

# Keep false in prod - grant access explicitly below.
enable_cluster_creator_admin_permissions = false

access_entries = {
  # CHANGE-ME: role(s) that administer the cluster (include the role your CI/Terraform uses if it needs kubectl).
  platform-admins = {
    principal_arn = "arn:aws:iam::111111111111:role/PlatformAdmin"
    policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  }
  # read-only = {
  #   principal_arn = "arn:aws:iam::111111111111:role/Developers"
  #   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  # }
}

node_groups = {
  # Cluster-critical components (CoreDNS, controllers, autoscaler, ingress).
  system = {
    instance_types = ["m7i.large", "m6i.large"]
    min_size       = 3
    max_size       = 6
    desired_size   = 3
    labels         = { workload = "system" }
  }

  # Application workloads.
  general = {
    instance_types = ["m7i.xlarge", "m6i.xlarge"]
    min_size       = 3
    max_size       = 15
    desired_size   = 3
    disk_size_gb   = 100
    labels         = { workload = "general" }
  }
}
