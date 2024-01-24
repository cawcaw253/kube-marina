terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region  = var.aws_region
  shared_credentials_file = var.aws_shared_credentials
}

# ---------- VPC ----------
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Owner   = "${var.owner}"
    Name    = "k8s_vpc"
    Service = "k8s_example"
  }
}

# ---------- IGW ----------
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Owner   = "${var.owner}"
    Name    = "k8s_igw"
    Service = "k8s_example"
  }
}

# ---------- RT ----------
resource "aws_route_table" "k8s_public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Owner   = "${var.owner}"
    Name    = "k8s_public_rt"
    Service = "k8s_example"
  }
}

# ---------- Subnets ----------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "k8s_public_subnet_1" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.aws_vpc_subnet_cidrs["public_1"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Owner   = "${var.owner}"
    Name    = "k8s_public_subnet_1"
    Service = "k8s_example"
  }
}

resource "aws_subnet" "k8s_public_subnet_2" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.aws_vpc_subnet_cidrs["public_2"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Owner   = "${var.owner}"
    Name    = "k8s_public_subnet_2"
    Service = "k8s_example"
  }
}

resource "aws_route_table_association" "k8s_public1_association" {
  subnet_id      = aws_subnet.k8s_public_subnet_1.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

resource "aws_route_table_association" "k8s_public2_association" {
  subnet_id      = aws_subnet.k8s_public_subnet_2.id
  route_table_id = aws_route_table.k8s_public_rt.id
}

# ---------- Security Group ----------
resource "aws_security_group" "k8s_kubeadm_sg" {
  name        = "k8s_kubeadm_sg"
  description = "Security Group for the Kube Admin"
  vpc_id      = aws_vpc.k8s_vpc.id

  #---- Kube Logs ----
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---- Kube Connect Allow ----
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---- Octant Access ----
  ingress {
    from_port   = 8900
    to_port     = 8900
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---- Ingress nodePort for http ----
  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---- SSH ----
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---- HTTP Allow ----
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- Key Pair ----------
resource "aws_key_pair" "aws_key" {
  key_name   = var.ssh_key_name
  public_key = file(format("%s/%s.pub",var.ssh_key_path,var.ssh_key_name))
}

# ---------- EC2 Spot Instance Requests ----------

# ----- Kube Master -----
resource "aws_spot_instance_request" "master" {
  count         = 1
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  associate_public_ip_address = true # Instances have public, dynamic IP

  # ----- VPC -----
  vpc_security_group_ids = ["${aws_security_group.k8s_kubeadm_sg.id}"]
  subnet_id              = aws_subnet.k8s_public_subnet_1.id

  # ----- Spot Instance -----
  wait_for_fulfillment = true
  spot_type            = "one-time"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "20"
    delete_on_termination = true
  }

  tags = {
    Owner                               = "${var.owner}"
    Name                                = "master-${count.index}"
    Service                             = "k8s_example"
    "kubernetes.io/cluster/k8s-cluster" = "k8s-cluster"
  }
}

# ----- Kube Workers -----
resource "aws_spot_instance_request" "worker" {
  count         = 2
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  associate_public_ip_address = true # Instances have public, dynamic IP

  # ----- VPC -----
  vpc_security_group_ids = ["${aws_security_group.k8s_kubeadm_sg.id}"]
  subnet_id              = aws_subnet.k8s_public_subnet_1.id

  # ----- Spot Instance -----
  wait_for_fulfillment = true
  spot_type            = "one-time"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }

  tags = {
    Owner                               = "${var.owner}"
    Name                                = "worker-${count.index}"
    Service                             = "k8s_example"
    "kubernetes.io/cluster/k8s-cluster" = "k8s-cluster"
  }
}

# ---------- Outputs ----------
output "kubernetes_master_public_ip" {
  value = join(",", aws_spot_instance_request.master.*.public_ip)
}
output "kubernetes_workers_public_ip" {
  value = join(",", aws_spot_instance_request.worker.*.public_ip)
}
output "master_ssh_command" {
  value = format("ssh -i %s/%s ubuntu@%s", var.ssh_key_path, var.ssh_key_name, aws_spot_instance_request.master.0.public_ip)
}

# ---------- Provision Ansible Inventory ---------- 
resource "null_resource" "tc_instances" {
  provisioner "local-exec" {
    command = <<EOD
    cat <<EOF > kube_hosts
[kubemaster]
master ansible_host="${aws_spot_instance_request.master.0.public_ip}" ansible_user=ubuntu ansible_ssh_private_key_file=${format("%s/%s",var.ssh_key_path,var.ssh_key_name)}
[kubeworkers]
worker1 ansible_host="${aws_spot_instance_request.worker.0.public_ip}" ansible_user=ubuntu ansible_ssh_private_key_file=${format("%s/%s",var.ssh_key_path,var.ssh_key_name)}
EOF
EOD
  }
}
