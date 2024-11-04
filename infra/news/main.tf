data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.prefix}/base/vpc_id"
}
data "aws_ssm_parameter" "subnet" {
  name = "/${var.prefix}/base/subnet/a/id"
}
data "aws_ssm_parameter" "ecr" {
  name = "/${var.prefix}/base/ecr"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  subnet_id = data.aws_ssm_parameter.subnet.value
  ecr_url = data.aws_ssm_parameter.ecr.value
}

module "alb-quotes" {
  source  = "../../infra-modules-alb"

  name     = "${var.prefix}-alb-quotes"
  vpc_id   = module.vpc.vpc_id
  subnets  = module.vpc.private_subnets
  internal = true

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 82
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 445
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  listeners = {
    ex_http_https_redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  target_groups = {
    asg_target_group = {
      name_prefix                       = "asg"
      protocol                          = "HTTP"
      port                              = 80
      target_type                       = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/healthz"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  }
}

module "asg-quotes" {
  source = "../../infra-modules/asg"

  name                  = "quotes-${var.prefix}"
  vpc_zone_identifier   = module.vpc.private_subnets
  target_group_arns     = [module.alb.target_groups["asg_target_group"].arn]

  # Launch template configuration
  image_id              = data.aws_ami.amazon_linux.id
  instance_type         = "t3.micro"
  user_data             = filebase64("${path.module}/scripts/provision-quotes.sh")
  desired_capacity      = 1
  min_size              = 1
  max_size              = 3
}

output "repository_urls" {
  description = "URLs of the created ECR repositories"
  value       = [for repo in module.ecr : repo.repository_url]
}


output "frontend_url" {
  value = "http://${aws_instance.front_end.public_ip}:8080"
}
