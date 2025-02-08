mock_provider "aws" {
  override_data {
    target = module.tasks["db_migrate"].data.aws_ec2_instance_type.instance-info
    values = {
      "supported_architectures" = ["arm64"]
    }
  }

  override_data {
    target = module.tasks["db_migrate"].data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = module.services["sidekiq"].data.aws_ec2_instance_type.instance-info
    values = {
      "supported_architectures" = ["arm64"]
    }
  }

  override_data {
    target = module.services["sidekiq"].data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.allow_ec2_assume
    values = {
      "json" = "{}"
    }
  }

  override_data {
    target = data.aws_iam_policy.default-policies["ServiceomatBase"]
    values = {
      arn = "arn:aws:iam::123456789012:policy/ServiceomatBase"
    }
  }
}

mock_provider "aws" {
  alias = "meta"

  override_data {
    target = data.aws_ssm_parameters_by_path.core-config
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
    target = module.tasks["db_migrate"].data.aws_ssm_parameter.account-info
    values = {
      value = "{\"prefix\":\"/test\"}"
    }
  }

  override_data {
    target = module.tasks["db_migrate"].data.aws_ssm_parameter.organization-prefix
    values = {
      value = "test"
    }
  }

  override_data {
    target = module.tasks["db_migrate"].data.aws_ssm_parameters_by_path.core-config
    values = {
      names = ["/test/config/core/config_backup_bucket", "/test/config/core/public_service_subnet_ids"]
      values = ["configbucket", "subnet-1234"]
    }
  }

  override_data {
    target = module.services["sidekiq"].data.aws_ssm_parameter.account-info
    values = {
      value = "{\"prefix\":\"/test\"}"
    }
  }

  override_data {
    target = module.services["sidekiq"].data.aws_ssm_parameter.organization-prefix
    values = {
      value = "test"
    }
  }

  override_data {
    target = module.services["sidekiq"].data.aws_ssm_parameters_by_path.core-config
    values = {
      names = ["/test/config/core/config_backup_bucket", "/test/config/core/public_service_subnet_ids"]
      values = ["configbucket", "subnet-1234"]
    }
  }
}

override_module {
  target = module.account-info
  outputs = {
    organization_prefix = "teak"
    environment = "test"
    account_info = {
      prefix = "/teak/production/workload-prod"
      canonical_slug = "workload-prod"
    }
  }
}

variables {
  name = "testapp"
  network_level = "public"
  instance_type = "t4g.micro"
  volume_size = 4
  log_retention_days = 7
}

run "baseline" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.logs["/teak/server/test/service/testapp"].name == "/teak/server/test/service/testapp"
    error_message = "Expected application log group to be created"
  }

  assert {
    condition = aws_iam_role.role.name == "TestappRole"
    error_message = "Expected default role to have name TestappRole"
  }

  assert {
    condition = aws_iam_role.role.path == "/teak/service-role/"
    error_message = "Expected default role to be in the /teak/service-role/ path"
  }

  assert {
    condition = aws_iam_role_policy_attachment.default-policies["ServiceomatBase"].role == aws_iam_role.role.name && aws_iam_role_policy_attachment.default-policies["ServiceomatBase"].policy_arn == "arn:aws:iam::123456789012:policy/ServiceomatBase"
    error_message = "Expected default role to be assigned the ServiceomatBase policy"
  }

  assert {
    condition = aws_security_group.tag-sg.name == "testapp"
    error_message = "Expected default security group to be created with the name testapp"
  }
}

run "with_task" {
  command = plan

  variables {
    tasks = {
      db_migrate = {
        dropins = {
          "31_db_logs.conf" = { environment = "test", region = "us-east-1" }
        }

        enabled_services = [
          "teak-testapp@db_migrate"
        ]
      }
    }
  }

  assert {
    condition = module.tasks["db_migrate"].asg.name == "testapp-db_migrate-template"
    error_message = "Expected task ASG to be named testapp-db_migrate-template"
  }

  assert {
    condition = tolist([for tag in module.tasks["db_migrate"].asg.tag : tag if tag.key == "test:min_size"])[0].value == "0"
    error_message = "Expected test:min_size tag to be 0"
  }

  assert {
    condition = tolist([for tag in module.tasks["db_migrate"].asg.tag : tag if tag.key == "test:max_size"])[0].value == "0"
    error_message = "Expected test:max_size tag to be 0"
  }
}

run "with_custom_role" {
  command = plan

  variables {
    services = {
      sidekiq = {
        iam_policy_arns = ["arn:aws:iam::123456789012:policy/test"]
        dropins = {
          "31_db_logs.conf" = { environment = "test", region = "us-east-1" }
        }

        enabled_services = [
          "teak-testapp@sidekiq"
        ]
      }
    }
    tasks = {
      db_migrate = {
        iam_policy_arns = ["arn:aws:iam::123456789012:policy/task-test"]
        dropins = {
          "31_db_logs.conf" = { environment = "test", region = "us-east-1" }
        }

        enabled_services = [
          "teak-testapp@db_migrate"
        ]
      }
    }
  }

  assert {
    condition = aws_iam_role.extended["sidekiq"].name == "TestappSidekiqRole"
    error_message = "Expected an IAM role named TestappSidekiqRole"
  }

  assert {
    condition = aws_iam_role_policy_attachment.extended["sidekiq-arn:aws:iam::123456789012:policy/test"].policy_arn == "arn:aws:iam::123456789012:policy/test"
    error_message = "Expected an attachment to our given policy"
  }

  assert {
    condition = aws_iam_role_policy_attachment.extended["sidekiq-arn:aws:iam::123456789012:policy/ServiceomatBase"].policy_arn == "arn:aws:iam::123456789012:policy/ServiceomatBase"
    error_message = "Expected an attachment to default given policy"
  }

  assert {
    condition = aws_iam_role.extended["db_migrate"].name == "TestappDb_migrateRole"
    error_message = "Expected an IAM role named TestappDb_MigrateRole"
  }

  assert {
    condition = aws_iam_role_policy_attachment.extended["db_migrate-arn:aws:iam::123456789012:policy/task-test"].policy_arn == "arn:aws:iam::123456789012:policy/task-test"
    error_message = "Expected an attachment to our given policy"
  }

  assert {
    condition = aws_iam_role_policy_attachment.extended["db_migrate-arn:aws:iam::123456789012:policy/ServiceomatBase"].policy_arn == "arn:aws:iam::123456789012:policy/ServiceomatBase"
    error_message = "Expected an attachment to default given policy"
  }
}
