terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region                  = var.aws_region
  shared_credentials_file = var.aws_shared_credentials
}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                               = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Create a IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name                               = "${var.cluster_name}-igw"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Create a Public RT
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name                               = "${var.cluster_name}-public-rt"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Get Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr[(count.index + 1) % 2]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  # availability_zone       = data.aws_availability_zones.available.names[(count.index + 1) % 2] az 에서 특정 ami가 동작하지 않음

  tags = {
    Name                               = "${var.cluster_name}-public-${data.aws_availability_zones.available.zone_ids[0]}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Associate Public Subnets and Routing Table
resource "aws_route_table_association" "public_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[(count.index % 2)].id
  route_table_id = aws_route_table.public_rt.id
}

# Create a Key Pair
resource "aws_key_pair" "aws_key" {
  key_name   = element(split("/", var.ssh_key), length(split("/", var.ssh_key))) # split ssh key and get last element
  public_key = file(format("%s.pub", var.ssh_key))
}

# Create a Cluster Security Group
resource "aws_security_group" "cluster_security_group" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security Group for ${var.cluster_name} Cluster"
  vpc_id      = aws_vpc.vpc.id

  # --- SSH ---
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- Kubelet API ---
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- Kubernetes API server ---
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- HTTP Allow ---
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

  tags = {
    Name                               = "${var.cluster_name}-cluster-sg"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Create Master Node Instances
resource "aws_instance" "master" {
  count         = var.master_count
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = element(split("/", var.ssh_key), length(split("/", var.ssh_key))) # split ssh key and get last element

  associate_public_ip_address = true

  vpc_security_group_ids = ["${aws_security_group.cluster_security_group.id}"]
  subnet_id              = aws_subnet.public_subnet[(count.index % 2)].id

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "20"
    delete_on_termination = true
  }

  tags = {
    Name                               = "${var.cluster_name}-master-${count.index + 1}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Create Worker Node Instances
resource "aws_instance" "worker" {
  count         = var.worker_count
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = element(split("/", var.ssh_key), length(split("/", var.ssh_key))) # split ssh key and get last element

  associate_public_ip_address = true

  vpc_security_group_ids = ["${aws_security_group.cluster_security_group.id}"]
  subnet_id              = aws_subnet.public_subnet[(count.index % 2)].id

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "20"
    delete_on_termination = true
  }

  tags = {
    Name                               = "${var.cluster_name}-worker-${count.index + 1}"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Outputs
output "kubernetes_master_public_ip" {
  value = format("Master Nodes : %s", join(",", aws_instance.master.*.public_ip))
}
output "kubernetes_workers_public_ip" {
  value = format("Worker Nodes : %s", join(",", aws_instance.worker.*.public_ip))
}
output "master_ssh_command" {
  value = format("ssh -i %s ubuntu@%s", var.ssh_key, aws_instance.master.0.public_ip)
}

# Provision Ansible Inventory
resource "null_resource" "tc_instances" {
  provisioner "local-exec" {
    command = <<EOD
    echo "[kube_masters]" >> kube_hosts
    %{for index, ip in aws_instance.master.*.public_ip~}
    echo "master-${index} ansible_host="${ip}" ansible_user=ubuntu ansible_ssh_private_key_file=${var.ssh_key}" >> kube_hosts
    %{endfor~}
    echo "[kube_workers]" >> kube_hosts
    %{for index, ip in aws_instance.worker.*.public_ip~}
    echo "worker-${index} ansible_host="${ip}" ansible_user=ubuntu ansible_ssh_private_key_file=${var.ssh_key}" >> kube_hosts
    %{endfor~}
EOD
  }
}
