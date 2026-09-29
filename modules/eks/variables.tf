################################################################################
# Cluster
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g. \"1.34\"). Upgrade one minor version at a time."
  type        = string
}

variable "vpc_id" {
  description = "VPC the cluster runs in."
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "Private subnets for the control plane cross-account ENIs (spread across AZs)."
  type        = list(string)

  validation {
    condition     = length(var.control_plane_subnet_ids) >= 2
    error_message = "EKS requires subnets in at least 2 AZs."
  }
}

variable "node_subnet_ids" {
  description = "Private subnets worker nodes are launched in."
  type        = list(string)

  validation {
    condition     = length(var.node_subnet_ids) >= 2
    error_message = "Provide at least 2 private subnets (different AZs) for worker nodes."
  }
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Keep false in prod and reach the API over VPN / Direct Connect / bastion."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (only used when endpoint_public_access = true)."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.endpoint_public_access || (length(var.endpoint_public_access_cidrs) > 0 && !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0"))
    error_message = "When endpoint_public_access is true, endpoint_public_access_cidrs must be a non-empty allow-list and must not contain 0.0.0.0/0."
  }
}

variable "api_allowed_cidrs" {
  description = "CIDRs (VPN, bastion, CI runners, peered VPCs) allowed to reach the PRIVATE API endpoint on 443."
  type        = list(string)
  default     = []
}

variable "service_ipv4_cidr" {
  description = "CIDR for Kubernetes service IPs. Must not overlap the VPC or peered networks. null = EKS default."
  type        = string
  default     = null
}

variable "support_type" {
  description = "EKS upgrade policy: STANDARD (auto-upgrade at end of standard support) or EXTENDED (paid extended support)."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.support_type)
    error_message = "support_type must be STANDARD or EXTENDED."
  }
}

################################################################################
# Logging / encryption
################################################################################

variable "cluster_log_types" {
  description = "Control plane log types to ship to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Retention for control plane logs."
  type        = number
  default     = 90
}

variable "kms_key_deletion_window_in_days" {
  description = "Waiting period before the secrets KMS key is deleted."
  type        = number
  default     = 30
}

variable "kms_key_admin_arns" {
  description = "IAM principals allowed to administer (but not use) the cluster KMS key, in addition to the account root."
  type        = list(string)
  default     = []
}

################################################################################
# Access
################################################################################

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the identity running Terraform cluster-admin via an access entry. Prefer explicit access_entries in prod. Changing this recreates the cluster."
  type        = bool
  default     = false
}

variable "access_entries" {
  description = <<-EOT
    EKS access entries, keyed by a friendly name. Example:
      platform-admins = {
        principal_arn = "arn:aws:iam::111111111111:role/PlatformAdmin"
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      }
      team-a-readonly = {
        principal_arn = "arn:aws:iam::111111111111:role/TeamA"
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        access_scope  = { type = "namespace", namespaces = ["team-a"] }
      }
  EOT
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

################################################################################
# Node groups
################################################################################

variable "node_groups" {
  description = "Managed node groups, keyed by name. All nodes are placed in node_subnet_ids (private)."
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

  validation {
    condition     = alltrue([for ng in var.node_groups : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size])
    error_message = "Each node group needs min_size <= desired_size <= max_size."
  }

  validation {
    condition     = alltrue([for ng in var.node_groups : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_metadata_hop_limit" {
  description = "IMDSv2 hop limit on nodes. 1 blocks pods (non-hostNetwork) from stealing the node role via IMDS; pods should use IRSA / Pod Identity instead."
  type        = number
  default     = 1
}

variable "node_ebs_kms_key_arn" {
  description = "Optional CMK for node root volumes. null = AWS-managed aws/ebs key. A CMK must allow the AWSServiceRoleForAutoScaling service-linked role."
  type        = string
  default     = null
}

################################################################################
# Add-ons
################################################################################

variable "addon_versions" {
  description = "Pin specific add-on versions, e.g. { \"vpc-cni\" = \"v1.20.0-eksbuild.1\" }. Unpinned add-ons use the default version for the cluster's Kubernetes version."
  type        = map(string)
  default     = {}
}

variable "vpc_cni_enable_prefix_delegation" {
  description = "Assign /28 prefixes to nodes to raise pod density and reduce EC2 API calls (Nitro instances only)."
  type        = bool
  default     = true
}

variable "vpc_cni_enable_network_policy" {
  description = "Enable Kubernetes NetworkPolicy enforcement in the VPC CNI."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
