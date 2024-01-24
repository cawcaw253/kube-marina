#######
# ECR #
#######
resource "aws_ecr_repository" "example_private_ecr" {
  name                 = "example-private-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
