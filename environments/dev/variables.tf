################################################################################
# General
################################################################################

variable "project" {
  description = "Project / product name. Used as the resource name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "allowed_account_ids" {
  description = "AWS account IDs this environment may be applied to. Strongly recommended."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags for all resources (e.g. Owner, CostCenter)."
  type        = map(string)
  default     = {}
}

################################################################################
# Network
################################################################################

variable "vpc_cidr" {
  description = "VPC CIDR. Must be a /16 for the default subnet layout, and unique across environments if you ever peer them."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid /16 IPv4 CIDR."
  }
}

variable "az_count" {
  description = "Number of AZs to use (2-3)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cost saving for non-prod). false = one NAT per AZ."
  type        = bool
  default     = false
}

variable "vpc_interface_endpoints" {
  description = "Interface VPC endpoints to create in the private subnets."
  type        = list(string)
  default     = []
}

variable "flow_logs_retention_days" {
  description = "VPC flow log retention."
  type        = number
  default     = 90
}

################################################################################
# EKS
################################################################################

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly (restricted to endpoint_public_access_cidrs)."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "Allow-list for the public API endpoint."
  type        = list(string)
  default     = []
}

variable "api_allowed_cidrs" {
  description = "Networks (VPN, bastion, CI) allowed to reach the private API endpoint."
  type        = list(string)
  default     = []
}

variable "cluster_log_retention_days" {
  description = "Control plane log retention."
  type        = number
  default     = 90
}

variable "kms_key_admin_arns" {
  description = "IAM principals that administer the cluster KMS key."
  type        = list(string)
  default     = []
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Give the Terraform caller cluster-admin. Changing this recreates the cluster."
  type        = bool
  default     = false
}

variable "access_entries" {
  description = "EKS access entries - see modules/eks/variables.tf for the shape."
  type = map(object({
    principal_arn     = string
    policy_arn        = string
    kubernetes_groups = optional(list(string))
    access_scope = optional(object({
      type       = string
      namespaces = optional(list(string))
    }), { type = "cluster" })
  }))
  default = {}
}

variable "node_groups" {
  description = "Managed node groups - see modules/eks/variables.tf for the shape."
  type = map(object({
    instance_types             = list(string)
    min_size                   = number
    max_size                   = number
    desired_size               = number
    capacity_type              = optional(string, "ON_DEMAND")
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    disk_size_gb               = optional(number, 50)
    max_unavailable_percentage = optional(number, 33)
    labels                     = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
}

variable "addon_versions" {
  description = "Optional pinned EKS add-on versions."
  type        = map(string)
  default     = {}
}
