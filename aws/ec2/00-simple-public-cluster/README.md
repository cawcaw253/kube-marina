# 00-simple-public-cluster

## 구성
- vpc
    - public subnet 1, 2
        - master node n (ec2)
        - worker node n (ec2)

## 실행 전 기본 설정

1. 실행 필요요소 설치
    ```
    sh install.sh
    ```

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

### 클러스터 생성 및 삭제

- 클러스터 생성

    ```
    sh create.sh
    ```

    해당 커맨드에서 인스턴스 생성중에 앤서블 커맨드가 실행되면 에러가 발생함, 이럴 시에는 다시 위의 커맨드를 실행하면 문제없이 생성됨 

- 클러스터 삭제

    ```
    sh destroy.sh
    ```

## 참고

- [Terraform AWS Registry] https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- [Cloud Resource Naming Conventions] https://confluence.huit.harvard.edu/display/CLA/Cloud+Resource+Naming+Conventions
