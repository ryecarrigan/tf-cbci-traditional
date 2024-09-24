provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

locals {
  ami_id             = data.aws_ssm_parameter.this.value
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.zone_count)
  cluster_name       = "${var.cluster_name}${local.workspace_suffix}"
  workspace_suffix   = terraform.workspace == "default" ? "" : "-${terraform.workspace}"
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
data "aws_ssm_parameter" "this" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name                       = "${local.cluster_name}-vpc"
  azs                        = local.availability_zones
  cidr                       = var.cidr_block
  enable_dns_hostnames       = true
  enable_nat_gateway         = true
  manage_default_network_acl = false
  private_subnets            = [for i in range(0, var.zone_count) : cidrsubnet(var.cidr_block, 8, 100 + i)]
  public_subnets             = [for i in range(0, var.zone_count) : cidrsubnet(var.cidr_block, 8, 200 + i)]
  single_nat_gateway         = true
}

module "acm_certificate" {
  source = "../../modules/acm-certificate"

  domain_name = var.domain_name
  subdomain   = var.subdomain
}

module "cjoc" {
  depends_on = [module.efs]
  source = "../../modules/operations-center"

  acm_certificate_arn       = module.acm_certificate.certificate_arn
  ami_id                    = local.ami_id
  cluster_security_group_id = aws_security_group.cluster.id
  efs_file_system_id        = module.efs.file_system_id
  efs_iam_policy_arn        = module.efs.iam_policy_arn
  instance_type             = var.instance_type
  key_name                  = var.key_name
  private_subnets           = module.vpc.private_subnets
  public_subnets            = module.vpc.public_subnets
  resource_prefix           = var.cluster_name
  ssh_cidr_blocks           = var.ssh_cidr_blocks
  vpc_id                    = module.vpc.vpc_id
  domain_name               = var.domain_name
  subdomain                 = var.subdomain
}

module "bastion" {
  source = "../../modules/aws-bastion"

  ami_id                   = local.ami_id
  key_name                 = var.key_name
  resource_prefix          = var.cluster_name
  source_security_group_id = aws_security_group.cluster.id
  ssh_cidr_blocks          = var.ssh_cidr_blocks
  subnet_id                = coalesce(module.vpc.public_subnets...)
  vpc_id                   = module.vpc.vpc_id
}

module "efs" {
  depends_on = [module.vpc]
  source = "../../modules/efs"

  cluster_name              = var.cluster_name
  cluster_security_group_id = aws_security_group.cluster.id
  private_subnets           = module.vpc.private_subnets
  vpc_id                    = module.vpc.vpc_id
}

resource "aws_security_group" "cluster" {
  description = "Security group of instances for cluster: ${var.cluster_name}"
  name_prefix = var.cluster_name
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}
