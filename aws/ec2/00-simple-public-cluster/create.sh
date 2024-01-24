# 디렉토리 변경
cd ./terraform

# 테라폼 Init
terraform init

# 인프라 구축을 위한 인스턴스 생성
terraform apply -auto-approve -lock=false

# 대기 해당 시간 동안 인스턴스가 올라가지 않을 수도 있음
sleep 20

# 디렉토리 변경
cd ../ansible

# 키 확인 무시하도록 설정
export ANSIBLE_HOST_KEY_CHECKING=false

# dependency 설치
ansible-playbook -i ../terraform/kube_hosts kube_dependencies.yaml

# 마스터 노드에 Initialize
ansible-playbook -i ../terraform/kube_hosts kube_master.yaml

# 워커 노드를 클러스터에 Join
ansible-playbook -i ../terraform/kube_hosts kube_workers.yaml