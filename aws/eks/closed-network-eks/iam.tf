##########
# Policy #
##########
data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_node_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com",
      ]
    }
  }
}

# For AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"

  policy = file("./policy/iam-role-for-service-accounts/aws-load-balancer-controller.json")
}

resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name = "AWSLoadBalancerControllerRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.eks_cluster_oidc.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(aws_iam_openid_connect_provider.eks_cluster_oidc.url, "https://", "")}:sub": "system:serviceaccount:kube-system:alb-ingress-controller",
          "${replace(aws_iam_openid_connect_provider.eks_cluster_oidc.url, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY

  depends_on = [aws_iam_openid_connect_provider.eks_cluster_oidc]
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_role_default" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller_role.name
  depends_on = [aws_iam_role.aws_load_balancer_controller_role]
}

########
# Role #
########
resource "aws_iam_role" "eks_cluster_service_role" {
  name = "EKSClusterServiceRole"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ]
}

resource "aws_iam_role" "eks_node_group_role" {
  name = "EKSNodeGroupRole"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role_policy.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    aws_iam_policy.aws_load_balancer_controller.arn,
  ]
}
