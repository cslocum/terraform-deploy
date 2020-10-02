terraform {
  required_version = ">= 0.12.6"
}

provider "aws" {
  version = ">= 2.28.1"
  region  = var.region
}

provider "template" {
  version = "~> 2.1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11.1"
}

data "aws_availability_zones" "available" {
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = var.cluster_name

  subnets      = local.private_subnet_ids

  cluster_endpoint_public_access = false
  cluster_endpoint_private_access = true

  # Sets additional worker security groups on console.
  cluster_create_security_group = false
  cluster_security_group_id = local.cluster_sg_id

  worker_create_security_group = false
  worker_security_group_id = local.worker_sg_id
  
  vpc_id       = local.vpc_id
  enable_irsa  = true
  
  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 50
  }

  node_groups = {
    core = {
      desired_capacity = 1
      max_capacity     = 3
      min_capacity     = 1

      instance_type = "t3.small"
      k8s_labels    = {
        "hub.jupyter.org/node-purpose" =  "core"
      }
      additional_tags = {
      }
    }
    notebook = {
     desired_capacity = 1
     max_capacity     = 10
     min_capacity     = 1

     instance_type = "t3.medium"
     k8s_labels = {
       "hub.jupyter.org/node-purpose" =  "user"
     }
     additional_tags = {
     }
    }
  }

  map_accounts = var.map_accounts
  map_users = var.map_users

  map_roles = concat([{
    rolearn  = aws_iam_role.hubploy_eks.arn
    username = aws_iam_role.hubploy_eks.name
    # FIXME: Narrow these permissions down?
    groups   = ["system:masters"]
  }], var.map_roles)

}


provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
