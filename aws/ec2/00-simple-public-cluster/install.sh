# 필요 요소 설치
sudo yum install -y yum-utils epel-release

# 테라폼 레포지토리 추가
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# 테라폼, 앤서블 설치
sudo yum -y install terraform ansible
