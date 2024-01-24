
################
# EC2 Instance #
################
resource "aws_instance" "example_bastion" {
  ami = local.ami.amazon_linux
  instance_type = "t3.large"
  key_name = local.key_pair_name
  subnet_id = module.network.public_subnet_ids.bastion[0]
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "example-bastion"
  }
}

resource "aws_eip" "example_bastion" {
  instance = aws_instance.example_bastion.id
}

output "example_bastion_public_ip" {
  value = aws_eip.example_bastion.public_ip
}

############
# Key Pair #
############
resource "tls_private_key" "example_bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "example_bastion_key" {
  key_name   = local.key_pair_name
  public_key = tls_private_key.example_bastion_key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.example_bastion_key.private_key_pem}' > ./${local.key_pair_name}.pem"
  }
}
