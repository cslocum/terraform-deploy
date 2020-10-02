resource "aws_efs_file_system" "home_dirs" {
  tags = {
    Name = "${var.cluster_name}-home-dirs"
  }
}


resource "aws_security_group" "home_dirs_sg" {
  name   = "${var.cluster_name}-home_dirs_sg"
  vpc_id = local.vpc_id

  # NFS
  ingress {
    security_groups = [ module.eks.worker_security_group_id ]
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
  }
}


# XXXX should the EFS subnets be public or private?
resource "aws_efs_mount_target" "home_dirs_targets" {
  count = length(local.private_subnet_ids)
  file_system_id = aws_efs_file_system.home_dirs.id
  subnet_id = local.private_subnet_ids[count.index]
  security_groups = [ aws_security_group.home_dirs_sg.id ]
}

data "helm_repository" "stable" {
  name = "stable"
  url = "https://kubernetes-charts.storage.googleapis.com"
}

resource "kubernetes_namespace" "support" {
  metadata {
    name = "support"
  }
}

resource "helm_release" "efs-provisioner" {
  name = "${var.cluster_name}-efs-provisioner"
  namespace = kubernetes_namespace.support.metadata.0.name
  repository = data.helm_repository.stable.metadata[0].name
  chart = "efs-provisioner"
  version = "0.11.0"

  set{
    name = "efsProvisioner.efsFileSystemId"
    value = aws_efs_file_system.home_dirs.id
  }

  set {
      name = "efsProvisioner.awsRegion"
      value = var.region
  }

  set {
      # We don't entirely know the effects of dynamic gid allocation,
      # particularly on the ability to re-use EFS when we recreate
      # clusters. Turn it off for now.
      name = "efsProvisioner.storageClass.gidAllocate.enabled"
      value = false
  }

  set {
    name = "efsProvisioner.path"
    value = "/"
  }

  set {
    name = "efsProvisioner.provisionerName"
    value = "aws.amazon.com/efs"
  }
}

