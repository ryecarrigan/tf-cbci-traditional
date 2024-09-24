locals {
  protection = (var.replication_protection) ? "ENABLED" : "DISABLED"
}

resource "aws_efs_file_system" "this" {
  encrypted = var.encrypt_file_system
  tags = {
    Name = var.cluster_name
  }

  protection {
    replication_overwrite = local.protection
  }

  lifecycle {
    ignore_changes = [protection]
  }
}

resource "aws_iam_policy" "this" {
  name_prefix = "${var.cluster_name}_efs"
  policy      = templatefile("${path.module}/policy.json.tftpl", {file_system_arn: aws_efs_file_system.this.arn})
}

resource "aws_efs_mount_target" "this" {
  count = length(var.private_subnets)

  file_system_id  = aws_efs_file_system.this.id
  security_groups = [aws_security_group.this.id]
  subnet_id       = var.private_subnets[count.index]
}

resource "aws_security_group" "this" {
  description = "Security group for EFS mount targets for file system: ${var.cluster_name}"
  name_prefix = var.cluster_name
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "egress" {
  from_port                = 2049
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.this.id
  to_port                  = 2049
  type                     = "egress"
}

resource "aws_security_group_rule" "ingress" {
  from_port                = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.cluster_security_group_id
  to_port                  = 2049
  type                     = "ingress"
}
