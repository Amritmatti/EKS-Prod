################################################################################
# Launch templates - hardened defaults for every managed node group
################################################################################

resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix            = "${var.cluster_name}-${each.key}-"
  description            = "EKS ${var.cluster_name} node group ${each.key}"
  update_default_version = true

  # No image_id / user_data: EKS selects the AMI for ami_type and bootstraps the node.

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = each.value.disk_size_gb
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      kms_key_id            = var.node_ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = var.node_metadata_hop_limit
    instance_metadata_tags      = "disabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.cluster_name}-${each.key}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.cluster_name}-${each.key}" })
  }

  tag_specifications {
    resource_type = "network-interface"
    tags          = merge(var.tags, { Name = "${var.cluster_name}-${each.key}" })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Managed node groups - private subnets only
################################################################################

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name           = aws_eks_cluster.this.name
  node_group_name_prefix = "${each.key}-"
  node_role_arn          = aws_iam_role.node.arn
  subnet_ids             = var.node_subnet_ids
  version                = aws_eks_cluster.this.version

  ami_type       = each.value.ami_type
  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  update_config {
    max_unavailable_percentage = each.value.max_unavailable_percentage
  }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  node_repair_config {
    enabled = true
  }

  labels = merge({ "node-group" = each.key }, each.value.labels)

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
    # Let Cluster Autoscaler / Karpenter own the running size.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    # Nodes can't become Ready until the CNI is running.
    aws_eks_addon.before_compute,
  ]
}
