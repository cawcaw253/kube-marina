# AWS ----------------------------------------
variable "aws_region" {}
variable "aws_shared_credentials" {
  default = "aws.credentials"
}
variable "aws_vpc_cidr" {}
variable "aws_vpc_subnet_cidrs" {}

# SSH ----------------------------------------
variable "ssh_key_path" {}
variable "ssh_key_name" {}

# Instances ----------------------------------------
variable "instance_ami" {
  description = "ami of instances"
  default     = "ami-0454bb2fefc7de534"
}

variable "instance_type" {
  default = "t2.medium"
}

variable "owner" {
  default = "Kubernetes"
}