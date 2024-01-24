locals {
  project_name = "marina"
  environment_name = "example"
  vpc_cidr = "10.0.0.0/16"
  region_name = "ap-northeast-2"
  availability_zones = ["a", "c"]

  key_pair_name = "example-bastion-key"
  ami = {
    amazon_linux: "ami-04ab8d3a67dfe6398"
  }
}

#######
# VPC #
#######
module "network" {
  source  = "cawcaw253/network/aws"
  version = "1.1.0"

  project_name     = local.project_name
  environment_name = local.environment_name

  vpc_cidr           = local.vpc_cidr
  region_name        = local.region_name
  availability_zones = local.availability_zones

  without_nat = true
  create_nat_per_az = false
  nat_deploy_module = "bastion"

  public_subnets = {
    front = ["10.0.0.0/21", /* "10.0.8.0/21", */ "10.0.16.0/21", /* "10.0.24.0/21" */]
    # front2  = ["10.0.32.0/21", "10.0.40.0/21", "10.0.48.0/21", "10.0.56.0/21"]
    bastion = ["10.0.62.0/26", /* "10.0.62.64/26", */ "10.0.62.128/26", /* "10.0.62.192/26" */]
  }

  public_subnets_tag = {
    front = {
      "kubernetes.io/role/elb" = 1
    }
  }

  private_subnets = {
    rest = ["10.0.64.0/20", /* "10.0.80.0/20", */ "10.0.96.0/20", /* "10.0.112.0/20" */]
    # rest     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20", "10.0.176.0/20"]
    private = ["10.0.192.0/21", /* "10.0.200.0/21", */ "10.0.208.0/21", /* "10.0.216.0/21" */]
  }

  private_subnets_tag = {
    eks = {
      "kubernetes.io/role/internal-elb" = 1
    }
  }
}

##################
# Security Group #
##################
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "allow-ssh"
  }
}

resource "aws_security_group" "vpc_endpoint" {
  name        = "vpc-endpoint"
  description = "Allow Access from vpc"
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.network.vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "vpc-endpoint"
  }
}

#################
# VPC Endpoints #
#################
resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.ec2"
  vpc_endpoint_type = "Interface"
  subnet_ids = module.network.private_subnet_ids.rest
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]

  tags = {
    "Name" = "interface-ec2"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids = module.network.private_subnet_ids.rest
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]

  tags = {
    "Name" = "interface-logs"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.s3"

  route_table_ids = module.network.private_route_table_ids.rest

  tags = {
    "Name" = "gateway-s3"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids = module.network.private_subnet_ids.rest
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]

  tags = {
    "Name" = "interface-ecr-api"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids = module.network.private_subnet_ids.rest
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]

  tags = {
    "Name" = "interface-ecr-dkr"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids = module.network.private_subnet_ids.rest
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]

  tags = {
    "Name" = "interface-sts"
  }
}

resource "aws_vpc_endpoint" "elasticloadbalancing" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.elasticloadbalancing"
  vpc_endpoint_type = "Interface"
  subnet_ids = module.network.private_subnet_ids.rest
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]

  tags = {
    "Name" = "interface-elasticloadbalancing"
  }
}
