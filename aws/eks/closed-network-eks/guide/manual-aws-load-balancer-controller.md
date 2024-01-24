# AWS Load Balancer Controller 설정

## 개요
eks를 생성하고 aws-load-balancer-controller를 설치하고자하면 보통 아래와 같은 두가지 방식으로 설치를 진행합니다.
첫째는 IRSA(IAM Role for Service Accounts)를 이용하여 aws-load-balancer-controller에 적절한 권한을 가진 Service Account를 설정하는 방법
둘째로는 노드 자체에 IAM Role을 설정하여 적절한 권한을 부여하는 방법

보통은 첫번째 방법이 권장되는 방법입니다. 하지만 가이드 되는 방법은 eksctl을 이용해 cloudformation 스택으로 aws 리소스나 kubernetes 리소스를 만들게 됩니다.
```bash
eksctl create iamserviceaccount \
--cluster=<cluster-name> \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region <region-code> \
--approve
```
이는 다른 IaC를 이용하여 리소스를 관리하고자 하는 사람들에게는 불만일 수 있을 것입니다.

본 문서에서는 eksctl 없이 terraform 및 kubernetes 리소스를 직접 생성하여 이를 구현하는 방법에 대해 서술했습니다.

## 작업 개요
eksctl에서 만들어주는 리소스를 직접 구현하려면 아래와 같은 작업이 필요합니다.

1. EKS OIDC 생성 - terraform
2. AWS IAM Role, Policy 생성 - terraform
3. Kubernetes Service Account 생성 - kubectl command가 필요함, terraform의 kubernetes 리소스를 이용해서도 가능 
4. Service Account와 IAM Role 연결

이 설정이 끝나면 k8s Service Account에는 Cluster Role과 Cluster Role Binding(해당 서비스 계정이 k8s 내에서 작업을 수행할 수 있도록 함)이 적용되고,
k8s Service Account에는 IAM Role이 연결되어 클러스터 외부에서 작업(예: aws 리소스 생성)을 수행할 수 있게 됩니다.

## 작업

### OIDC, Service Account 설정

1. Create EKS OIDC

```hcl
data "tls_certificate" "eks_cluster_tls_certificate" {
  url = aws_eks_cluster.example.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_tls_certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.example.identity[0].oidc[0].issuer
}
```

2. Create IAM Role and Policy

```hcl
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
```

Policy는 [aws-load-balancer-controller.json](../policy/iam-role-for-service-accounts/aws-load-balancer-controller.json)에서 확인 할 수 있습니다.


3. Creating cluster role, cluster role binding and service account

아래의 링크에서 제공하는 Yaml을 참고하여 생성해주면 됩니다. 본 예시에서는 [aws-load-balancer-controller.md](../kubernetes/aws-load-balancer-controller.yaml)를 사용합니다.

https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/rbac-role.yaml


4. 확인

위의 과정을 거쳤다면 아래의 kubectl 명령어를 통해서 결과를 확인할 수 있습니다.

```bash
kubectl get sa -n kube-system
kubectl describe sa aws-load-balancer-controller -n kube-system
```

정상적으로 설정 되었다면 아래와 비슷한 결과를 볼 수 있을 겁니다.
```bash
Name:                aws-load-balancer-controller
Namespace:           kube-system
Labels:              app.kubernetes.io/managed-by=Helm
                     app.kubernetes.io/name=aws-load-balancer-controller
Annotations:         eks.amazonaws.com/role-arn: <YOUR ANR WILL BE HERE>
                     meta.helm.sh/release-name: testrelease
                     meta.helm.sh/release-namespace: default
Image pull secrets:  <none>
Mountable secrets:   aws-load-balancer-controller-token-l4pd8
Tokens:              aws-load-balancer-controller-token-l4pd8
Events:              <none>
```

### Add controller to cluster

1. EKS Helm chart 추가
```
helm repo add eks https://aws.github.io/eks-charts
```

2. If upgrading the chart via helm upgrade, install the TargetGroupBinding CRDs
```
wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
kubectl apply -f crds.yaml
```

3. Helm install command for clusters

```bash
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.repository=602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller \
  --set region=<region-code>
```

## Refer
- [what-does-eksctl-create-iamserviceaccount-do-under-the-hood-on-an-eks-cluster](https://stackoverflow.com/questions/65934606/what-does-eksctl-create-iamserviceaccount-do-under-the-hood-on-an-eks-cluster)
- [aws-load-balancer-controller private ecr 1](https://zigispace.net/1160)
- [aws-load-balancer-controller private ecr 2](https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/1694#issuecomment-822854710)
