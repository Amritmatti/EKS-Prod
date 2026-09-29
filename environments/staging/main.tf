data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = local.name
  azs          = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # From a /16: private /19 per AZ (8k IPs each - pods consume VPC IPs),
  # public /24 per AZ carved from the top of the range (LBs + NAT only).
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 3, i)]
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 240 + i)]

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

module "vpc" {
  source = "../../modules/vpc"

  name         = local.name
  cluster_name = local.cluster_name
  cidr         = var.vpc_cidr
  azs          = local.azs

  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_flow_logs         = true
  flow_logs_retention_days = var.flow_logs_retention_days

  enable_s3_gateway_endpoint = true
  interface_endpoints        = var.vpc_interface_endpoints

  private_subnet_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.private_subnet_ids
  node_subnet_ids          = module.vpc.private_subnet_ids

  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  api_allowed_cidrs            = var.api_allowed_cidrs

  cluster_log_retention_days = var.cluster_log_retention_days
  kms_key_admin_arns         = var.kms_key_admin_arns

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  access_entries                           = var.access_entries

  node_groups    = var.node_groups
  addon_versions = var.addon_versions

  tags = local.tags
}
