data "aws_caller_identity" "current" {}

locals {
  ecr_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.prefix}-"
  services = ["quotes", "newsfeed", "front_end"]
}

module "ecr" {
  source = "../../infra-modules/ecr"

  count = length(var.repository_names)
  for_each = toset(local.services)

  repository_name = "${var.prefix}-${var.each.key}"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    env   = "prod"
    owner = "infra team"
  }
}


resource "aws_ssm_parameter" "ecr" {
  name = "/${var.prefix}/base/ecr"
  value = local.ecr_url
  type  = "String"
}

resource "local_file" "ecr" {
  filename = "${path.module}/../ecr-url.txt"
  content = local.ecr_url
}
