variable "name" {
  description = "Name prefix for all VPC resources (e.g. myapp-prod)."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name. Used for the kubernetes.io/cluster/<name> subnet discovery tags."
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. Use at least 2 (3 recommended for prod)."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 availability zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (one per AZ). Only load balancers and NAT gateways live here."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "All public_subnet_cidrs must be valid IPv4 CIDR blocks."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs must contain exactly one CIDR per AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (one per AZ). Worker nodes and pods live here, so size generously (e.g. /19)."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "All private_subnet_cidrs must be valid IPv4 CIDR blocks."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs must contain exactly one CIDR per AZ."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets have outbound internet access."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cheaper, not AZ-resilient). Set false in prod for one NAT per AZ."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention in days for VPC flow logs."
  type        = number
  default     = 90
}

variable "flow_logs_kms_key_arn" {
  description = "Optional KMS key ARN to encrypt the flow logs log group. The key policy must allow the CloudWatch Logs service."
  type        = string
  default     = null
}

variable "enable_s3_gateway_endpoint" {
  description = "Create a (free) S3 gateway endpoint for the private route tables. ECR image layers are pulled from S3."
  type        = bool
  default     = true
}

variable "interface_endpoints" {
  description = "AWS services to create interface VPC endpoints for (e.g. ecr.api, ecr.dkr, sts). Keeps traffic private and reduces NAT cost, but each endpoint is billed per AZ."
  type        = list(string)
  default     = []
}

variable "public_subnet_tags" {
  description = "Extra tags for public subnets."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags for private subnets (e.g. karpenter.sh/discovery)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
