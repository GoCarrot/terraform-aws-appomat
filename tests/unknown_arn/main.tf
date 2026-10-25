# Test harness: a policy created in the same apply, so its ARN is unknown at plan time.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.meta]
    }
  }
}

variable "use_named" {
  type = bool
}

resource "aws_iam_policy" "created" {
  name   = "created"
  policy = "{}"
}

module "app" {
  source = "../.."

  providers = {
    aws      = aws
    aws.meta = aws.meta
  }

  name               = "testapp"
  network_level      = "public"
  instance_type      = "t4g.micro"
  volume_size        = 4
  log_retention_days = 7

  tasks = {
    db_migrate = {
      iam_policy_arns = var.use_named ? null : [aws_iam_policy.created.arn]
      iam_policies    = var.use_named ? { created = aws_iam_policy.created.arn } : null
      dropins = {
        "31_db_logs.conf" = { environment = "test", region = "us-east-1" }
      }
      enabled_services = ["teak-testapp@db_migrate"]
    }
  }
}
