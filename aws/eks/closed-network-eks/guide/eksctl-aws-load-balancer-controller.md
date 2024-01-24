
# AWS Load Balancer Controller 설정

## 개요
eks를 생성하고 aws-load-balancer-controller를 설치하고자하면 보통 아래와 같은 두가지 방식으로 설치를 진행합니다.
첫째는 IRSA(IAM Role for Service Accounts)를 이용하여 aws-load-balancer-controller에 적절한 권한을 가진 Service Account를 설정하는 방법
둘째로는 노드 자체에 IAM Role을 설정하여 적절한 권한을 부여하는 방법

본 문서에서는 가이드에 작성된 내용대로 eksctl을 이용해 필요한 리소스를 생성하는 방법에 대해 서술했습니다.

## 작업

### OIDC, Service Account 생성

1. IAM OIDC Provider 생성 (이전에 실행했다면 스킵해도 무관)
```bash
eksctl utils associate-iam-oidc-provider \
  --region <region-code> \
  --cluster <your-cluster-name> \
  --approve

> 2024-01-19 06:12:07 [ℹ]  will create IAM Open ID Connect provider for cluster "<your-cluster-name>" in "<region-code>"
> 2024-01-19 06:12:07 [✔]  created IAM Open ID Connect provider for cluster "<your-cluster-name>" in "<region-code>"
```

2. Load Balancer Controller에 사용할 Policy를 가져와서 이를 기반으로 iam policy 생성
```bash
# not US Gov Cloud, China
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json

# !!! 중요 !!! 현재 해당 policy는 문제가 있는 상황, 다음 링크를 참고해서 내용을 추가해야 함-> https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2692#issuecomment-1602615427
```

3. `eksctl`을 이용하여 쿠벝네티스 `ServiceAccount` 생성
```bash
eksctl create iamserviceaccount \
  --cluster=YOUR_CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region <region-code> \
  --approve

> 2024-01-19 06:16:58 [ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included (based on the include/exclude rules)
> 2024-01-19 06:16:58 [!]  metadata of serviceaccounts that exist in Kubernetes will be updated, as --override-existing-serviceaccounts was set
> 2024-01-19 06:16:58 [ℹ]  1 task: { 
>     2 sequential sub-tasks: { 
>         create IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
>         create serviceaccount "kube-system/aws-load-balancer-controller",
>     } }2024-01-19 06:16:58 [ℹ]  building iamserviceaccount stack "eksctl-onboard-scenario-2-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
> 2024-01-19 06:16:58 [ℹ]  deploying stack "eksctl-onboard-scenario-2-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
> 2024-01-19 06:16:58 [ℹ]  waiting for CloudFormation stack "eksctl-onboard-scenario-2-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
> 2024-01-19 06:17:28 [ℹ]  waiting for CloudFormation stack "eksctl-onboard-scenario-2-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
> 2024-01-19 06:17:28 [ℹ]  created serviceaccount "kube-system/aws-load-balancer-controller"
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
  - with IRSA
    ```bash
    helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=<cluster-name> \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller \
      --set image.repository=602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller \
      --set region=<region-code>
    ```
  - not using IRSA
    ```
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=<cluster-name>
    ```

## Refer
- [Installation Guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/deploy/installation/#option-b-attach-iam-policies-to-nodes)
