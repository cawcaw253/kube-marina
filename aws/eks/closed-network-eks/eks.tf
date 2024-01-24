#######
# EKS #
#######
resource "aws_eks_cluster" "example" {
  name     = "example"
  version = "1.28"
  role_arn = aws_iam_role.eks_cluster_service_role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    subnet_ids = module.network.private_subnet_ids.rest
    security_group_ids = [aws_security_group.eks_control_plane.id]
  }

  # access_config {
  #   authentication_mode = "API_AND_CONFIG_MAP"
  # }

  enabled_cluster_log_types = ["api", "audit"]

  depends_on = [
    aws_cloudwatch_log_group.example,
    aws_iam_role.eks_cluster_service_role,
  ]
}

##############
# Node Group #
##############
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = module.network.private_subnet_ids.rest

  ami_type = "AL2_x86_64"
  instance_types = ["t3.large"]
  capacity_type = "ON_DEMAND"
  disk_size = 20

  remote_access {
    # Recommand to use different key pair.
    ec2_ssh_key = local.key_pair_name
  }

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role.eks_node_group_role,
    aws_vpc_endpoint.ec2,
    aws_eks_addon.eks_pod_identity_agent,
    aws_eks_addon.vpc_cni,
  ]
}

###########
# Add-ons #
###########
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.example.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.16.0-eksbuild.1"
  # resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.example.name
  addon_name                  = "coredns"
  addon_version               = "v1.10.1-eksbuild.4"
  # resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.example
  ]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name                = aws_eks_cluster.example.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = "v1.1.0-eksbuild.1"
  # resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.example.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.28.2-eksbuild.2"
  # resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.example
  ]
}

##################
# Security Group #
##################
resource "aws_security_group" "eks_control_plane" {
  name        = "eks-cluster-control-plane"
  description = "Security Group for Control Plane"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.network.vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "eks-cluster-control-plane"
  }
}

###############
# Cloud Watch #
###############
resource "aws_cloudwatch_log_group" "example" {
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/example/cluster"
  retention_in_days = 7
}

########
# OIDC #
########
data "tls_certificate" "eks_cluster_tls_certificate" {
  url = aws_eks_cluster.example.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_tls_certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.example.identity[0].oidc[0].issuer
}
