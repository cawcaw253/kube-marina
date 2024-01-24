# 01_single_public_private_cluster_with_bastion

## 구성
- vpc
    - private subnet 1
        - master node (ec2)
        - worker node 1 (ec2)
        - worker node 2 (ec2)
    - public subnet 1
        - bastion (ec2)
        - nat gateway

## 테라폼 실행

1. 실행 필요요소 설치
    - terraform


2. aws.credentails 생성

    ```
    cp terraform/aws.credentials.example terraform/aws.credentials
    ```

    클러스터를 생성할 aws 계정에서 iam 을 생성하여 `access key`, `secret access key` 를 `terraform/aws.credentials` 에 입력

3. terraform.tfvars 생성

    ```
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    ```
    필요시 `terraform/variables.tf` 파일을 참고하여 `terraform/terraform.tfvars` 의 내용을 수정

4. 클러스터 접속을 위한 ssh key 생성

    아래의 명령어로 ssh key를 생성
    
    ```
    ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/cluster-builder-key
    ```

## 접속

### 접속 방법
- Bastion Host 에 접속
    ```
    ssh ubuntu@[bastion ip] -i [ssh_key_path]/[ssh_key_name]
    ```
- Bastion Host에 key 파일 복사
- Node에 접속
    ```
    ssh ubuntu@[node ip] -i [ssh_key_path]/[ssh_key_name]
    ```

### 에러 대응
- WARNING: UNPROTECTED PRIVATE KEY FILE!
    ```
    # 다음과 같이 group 과 other 의 모든 권한을 막아주면 됨.

    chmod 0400 [ssh_key_path]/[ssh_key_name]
    ```

## 참고

- [Terraform AWS Registry] https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- [Cloud Resource Naming Conventions] https://confluence.huit.harvard.edu/display/CLA/Cloud+Resource+Naming+Conventions
