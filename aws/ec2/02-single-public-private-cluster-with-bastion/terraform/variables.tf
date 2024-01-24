# AWS
variable "aws_region" {}
variable "aws_shared_credentials" {
  default = "aws.credentials"
}

# ETC
variable "cluster_name" {
  default = "example"
}

# VPC & Subnets
variable "vpc_cidr" {}
variable "public_subnet_cidr" {}
variable "private_subnet_cidr" {}

# SSH
variable "ssh_key_path" {}
variable "ssh_key_name" {}

# Instances
variable "instance_ami" {
  description = "ami of instances"
  default     = "ami-0454bb2fefc7de534"
}

variable "instance_type" {
  default = "t2.medium"
}

variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 2
}

variable "owner" {
  default = "Kubernetes"
}