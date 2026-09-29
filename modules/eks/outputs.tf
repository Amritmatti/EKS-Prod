output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_version" {
  description = "Kubernetes version of the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster CA certificate."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group (attached to control plane ENIs and managed nodes)."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_additional_security_group_id" {
  description = "Additional security group controlling private API access."
  value       = aws_security_group.cluster_additional.id
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN, for building IRSA roles for workloads."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "Cluster OIDC issuer URL."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_role_arn" {
  description = "IAM role ARN used by managed node groups (reuse for Karpenter nodes)."
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "IAM role name used by managed node groups."
  value       = aws_iam_role.node.name
}

output "kms_key_arn" {
  description = "KMS key used for secrets and control plane log encryption."
  value       = aws_kms_key.cluster.arn
}

output "node_groups" {
  description = "Managed node group names and their autoscaling group names."
  value = {
    for k, ng in aws_eks_node_group.this : k => {
      node_group_name    = ng.node_group_name
      autoscaling_groups = ng.resources[0].autoscaling_groups[*].name
    }
  }
}
