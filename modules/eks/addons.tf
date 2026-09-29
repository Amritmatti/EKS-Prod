locals {
  vpc_cni_configuration = jsonencode({
    enableNetworkPolicy = tostring(var.vpc_cni_enable_network_policy)
    env = {
      ENABLE_PREFIX_DELEGATION = tostring(var.vpc_cni_enable_prefix_delegation)
      WARM_PREFIX_TARGET       = "1" # ignored when prefix delegation is off
    }
  })

  # Installed before node groups: nodes need networking to become Ready.
  before_compute_addons = {
    vpc-cni = {
      service_account_role_arn = aws_iam_role.irsa["vpc-cni"].arn
      configuration_values     = local.vpc_cni_configuration
    }
    kube-proxy = {
      service_account_role_arn = null
      configuration_values     = null
    }
    eks-pod-identity-agent = {
      service_account_role_arn = null
      configuration_values     = null
    }
  }

  # Installed after node groups: these run as Deployments and need nodes to schedule on.
  after_compute_addons = {
    coredns = {
      service_account_role_arn = null
      configuration_values     = null
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.irsa["ebs-csi"].arn
      configuration_values     = null
    }
  }

  addon_names = toset(concat(keys(local.before_compute_addons), keys(local.after_compute_addons)))
}

data "aws_eks_addon_version" "this" {
  for_each = local.addon_names

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = false # the version EKS marks as default for this Kubernetes version
}

resource "aws_eks_addon" "before_compute" {
  for_each = local.before_compute_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = lookup(var.addon_versions, each.key, data.aws_eks_addon_version.this[each.key].version)
  service_account_role_arn    = each.value.service_account_role_arn
  configuration_values        = each.value.configuration_values
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.irsa]
}

resource "aws_eks_addon" "after_compute" {
  for_each = local.after_compute_addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = lookup(var.addon_versions, each.key, data.aws_eks_addon_version.this[each.key].version)
  service_account_role_arn    = each.value.service_account_role_arn
  configuration_values        = each.value.configuration_values
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.irsa,
  ]
}
