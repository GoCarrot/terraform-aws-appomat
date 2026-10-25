mock_provider "aws" {
  override_data {
    target = module.app.module.tasks["db_migrate"].data.aws_ec2_instance_type.instance-info
    values = {
      "supported_architectures" = ["arm64"]
    }
  }

  override_data {
    target = module.app.module.tasks["db_migrate"].data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = module.app.module.services["sidekiq"].data.aws_ec2_instance_type.instance-info
    values = {
      "supported_architectures" = ["arm64"]
    }
  }

  override_data {
    target = module.app.module.services["sidekiq"].data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = module.app.module.services["sidekiq-beta"].data.aws_ec2_instance_type.instance-info
    values = {
      "supported_architectures" = ["arm64"]
    }
  }

  override_data {
    target = module.app.module.services["sidekiq-beta"].data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = module.app.data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = module.app.data.aws_iam_policy.default-policies["ServiceomatBase"]
    values = {
      arn = "arn:aws:iam::123456789012:policy/ServiceomatBase"
    }
  }
}

mock_provider "aws" {
  alias = "meta"

  override_data {
    target = module.app.data.aws_ssm_parameters_by_path.core-config
    values = {
      names = [
        "/teak/production/workload-prod/config/core/vpc_id",
        "/teak/production/workload-prod/config/core/dev_access_security_group_id",
        "/teak/production/workload-prod/config/core/break_glass_key_name"
      ]
      values = ["vpc-1230914", "sg-123456", "break-glass"]
    }
  }

  override_data {
    target = module.app.module.tasks["db_migrate"].data.aws_ssm_parameter.account-info
    values = {
      value = "{\"prefix\":\"/test\"}"
    }
  }

  override_data {
    target = module.app.module.tasks["db_migrate"].data.aws_ssm_parameter.organization-prefix
    values = {
      value = "test"
    }
  }

  override_data {
    target = module.app.module.tasks["db_migrate"].data.aws_ssm_parameters_by_path.core-config
    values = {
      names  = ["/test/config/core/config_backup_bucket", "/test/config/core/public_service_subnet_ids"]
      values = ["configbucket", "subnet-1234"]
    }
  }

  override_data {
    target = module.app.module.services["sidekiq"].data.aws_ssm_parameter.account-info
    values = {
      value = "{\"prefix\":\"/test\"}"
    }
  }

  override_data {
    target = module.app.module.services["sidekiq"].data.aws_ssm_parameter.organization-prefix
    values = {
      value = "test"
    }
  }

  override_data {
    target = module.app.module.services["sidekiq"].data.aws_ssm_parameters_by_path.core-config
    values = {
      names  = ["/test/config/core/config_backup_bucket", "/test/config/core/public_service_subnet_ids"]
      values = ["configbucket", "subnet-1234"]
    }
  }

  override_data {
    target = module.app.module.services["sidekiq-beta"].data.aws_ssm_parameter.account-info
    values = {
      value = "{\"prefix\":\"/test\"}"
    }
  }

  override_data {
    target = module.app.module.services["sidekiq-beta"].data.aws_ssm_parameter.organization-prefix
    values = {
      value = "test"
    }
  }

  override_data {
    target = module.app.module.services["sidekiq-beta"].data.aws_ssm_parameters_by_path.core-config
    values = {
      names  = ["/test/config/core/config_backup_bucket", "/test/config/core/public_service_subnet_ids"]
      values = ["configbucket", "subnet-1234"]
    }
  }
}

override_module {
  target = module.app.module.account-info
  outputs = {
    organization_prefix = "teak"
    environment         = "test"
    account_info = {
      prefix         = "/teak/production/workload-prod"
      canonical_slug = "workload-prod"
    }
  }
}

variables {
  name               = "testapp"
  network_level      = "public"
  instance_type      = "t4g.micro"
  volume_size        = 4
  log_retention_days = 7
}


run "named_policy_with_unknown_arn_plans" {
  command = plan

  module {
    source = "./tests/unknown_arn"
  }

  variables {
    use_named = true
  }

  assert {
    condition     = length(module.app.extended_iam_roles) == 1
    error_message = "Expected the db_migrate extended role"
  }
}
