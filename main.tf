provider "kubernetes" {
  # https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#authentication
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", local.name]
  }
}

provider "aws" {
  alias = "region"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [
    module.eks.cluster_name
  ]
}

data "aws_region" "current" {
  provider = aws.region
}

data "aws_availability_zones" "available" {}

locals {
  name     = basename(path.cwd)
  region   = data.aws_region.current.region
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.26.0"

  name                   = local.name
  kubernetes_version     = "1.34"
  endpoint_public_access = true                                                                # Backwards compat
  enabled_log_types      = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # Backwards compat

  iam_role_name            = "${local.name}-cluster-role" # Backwards compat
  iam_role_use_name_prefix = false                        # Backwards compat

  kms_key_aliases = [local.name] # Backwards compat

  addons = {
    vpc-cni = { # VPC dependency for Managed Node Group
      most_recent                 = true
      service_account_role_arn    = module.vpc_cni_irsa.arn
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true  # Backwards compat
  endpoint_private_access                  = false # Backwards compat

  eks_managed_node_groups = {
    managed_ondemand = {
      ami_type = "BOTTLEROCKET_x86_64"

      instance_types = ["t3.large"]

      min_size     = 1
      max_size     = 2
      desired_size = 2

      create_launch_template = true           # false will use the default launch template
      launch_template_os     = "bottlerocket" # amazonlinux2eks or bottlerocket
    }
  }
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.2"

  name                  = "${local.name}-vpc-cni-irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v5.21.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

}
