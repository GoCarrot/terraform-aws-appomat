terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.22, < 6"

      configuration_aliases = [aws.meta]
    }
  }
}

terraform {
  required_version = ">= 1.8.0"
}

### BASELINE CONFIGURATION
data "aws_caller_identity" "current" {}

module "account-info" {
  providers = {
    aws = aws.meta
  }

  source  = "GoCarrot/accountomat_read/aws"
  version = "~> 0.0.5"

  account_id = data.aws_caller_identity.current.account_id
}

data "aws_ssm_parameters_by_path" "core-config" {
  provider = aws.meta

  path      = local.core_config_prefix
  recursive = true
}

locals {
  account_info        = module.account-info.account_info
  param_prefix        = local.account_info["prefix"]
  organization_prefix = module.account-info.organization_prefix
  canonical_slug      = local.account_info["canonical_slug"]
  core_config_prefix  = "${local.param_prefix}/config/core"
}
###

### Tagging configuration
data "aws_default_tags" "tags" {}

locals {
  tags = { for key, value in var.tags : key => value if lookup(data.aws_default_tags.tags.tags, key, null) != value }
}

### BUILD TRIGGER
locals {
  # circleci_slug_base = "gh/GoCarrot"
  # computed_circleci_slug = join("/", [circleci_slug_base, var.name])
  # circleci_project_slug = coalesce(var.automatic_build["circleci_project_slug"], computed_circleci_slug)
  # TODO: Make this optional, infer it from name and a config var
  circleci_project_slug = var.automatic_build != null ? var.automatic_build["circleci_project_slug"] : null
}

module "build-trigger" {
  count = var.automatic_build != null ? 1 : 0

  providers = {
    aws = aws.meta
  }

  source = "GoCarrot/declare-ami-dependency/aws"

  branch                 = var.automatic_build["branch"]
  build_from_account     = var.automatic_build["build_from_account"]
  deploy_to_account      = var.automatic_build["automatic_deploy"] ? local.canonical_slug : null
  circleci_project_slug  = local.circleci_project_slug
  source_ami_name_prefix = var.automatic_build["inherit_from"]
}
###

### Logging
locals {
  environment = module.account-info.environment

  ancillary_log_groups = var.ancillary_log_groups
  log_group_names      = toset(concat([var.name], formatlist("${var.name}/%s", local.ancillary_log_groups)))
  log_environments     = toset(concat(try(coalescelist(var.log_environments, []), []), [local.environment]))

  log_groups = [
    for pair in setproduct(local.log_environments, local.log_group_names) : "/${local.organization_prefix}/server/${pair[0]}/service/${pair[1]}"
  ]
}

resource "aws_cloudwatch_log_group" "logs" {
  for_each = toset(local.log_groups)

  name              = each.value
  retention_in_days = var.log_retention_days

  tags = local.tags
}

data "aws_cloudwatch_log_groups" "ancillary" {
  for_each = local.log_environments

  log_group_name_prefix = "/${local.organization_prefix}/server/${each.key}/ancillary"
}

data "aws_cloudwatch_log_groups" "service" {
  for_each = local.log_environments

  log_group_name_prefix = "/${local.organization_prefix}/server/${each.key}/service/${var.name}"

  depends_on = [
    aws_cloudwatch_log_group.logs
  ]
}

resource "aws_cloudwatch_query_definition" "unified-logs" {
  for_each = local.log_environments

  name = "${local.organization_prefix}/${each.key}/${var.name}/UnifiedLogs"

  query_string = <<-EOT
  fields @timestamp, @message
  | parse @logStream "${var.name}.*" as host
  | parse @log /[0-9]*:.*\/(?<group>[a-zA-Z0-9-_]+$)/
  | filter @logStream like /${var.name}\..*/
  | sort @timestamp desc
  | display @timestamp, group, host, @message
EOT

  log_group_names = setunion(
    data.aws_cloudwatch_log_groups.ancillary[each.key].log_group_names,
    data.aws_cloudwatch_log_groups.service[each.key].log_group_names
  )
}
###

### Security Group (for tagging)
locals {
  vpc_id = nonsensitive(data.aws_ssm_parameters_by_path.core-config.values[index(data.aws_ssm_parameters_by_path.core-config.names, "${local.core_config_prefix}/vpc_id")])
}

resource "aws_security_group" "tag-sg" {
  name        = var.name
  description = "Group for tagging and allows egress because hey."
  vpc_id      = local.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}
###

### Security Group (for dev access to tasks)
locals {
  needs_dev_access    = anytrue([for _k, entry in var.tasks : entry.permit_dev_access])
  maybe_group_id      = try(nonsensitive(data.aws_ssm_parameters_by_path.core-config.values[index(data.aws_ssm_parameters_by_path.core-config.names, "${local.core_config_prefix}/dev_access_security_group_id")]), null)
  dev_access_group_id = local.needs_dev_access ? coalesce(local.maybe_group_id, null) : local.maybe_group_id
}
###

### Break Glass Key
locals {
  maybe_break_glass_key = try(nonsensitive(data.aws_ssm_parameters_by_path.core-config.values[index(data.aws_ssm_parameters_by_path.core-config.names, "${local.core_config_prefix}/break_glass_key_name")]), null)
  break_glass_key_name  = coalesce(var.break_glass_key_name, local.maybe_break_glass_key)
}

### Baseline IAM role
locals {
  default_role_policies = toset(["ServiceomatBase"])
}

data "aws_iam_policy_document" "allow_ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name = "${title(var.name)}Role"
  path = "/${local.organization_prefix}/service-role/"

  description = "Default role assumed by servers running the ${var.name} application."

  assume_role_policy = data.aws_iam_policy_document.allow_ec2_assume.json

  tags = local.tags
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = "${title(var.name)}InstanceProfile"
  path = "/${local.organization_prefix}/service-role/"
  role = aws_iam_role.role.name

  tags = local.tags
}

data "aws_iam_policy" "default-policies" {
  for_each = local.default_role_policies

  name = each.key
}

resource "aws_iam_role_policy_attachment" "default-policies" {
  for_each = data.aws_iam_policy.default-policies

  role       = aws_iam_role.role.name
  policy_arn = each.value.arn
}
###

### Extended IAM roles
locals {
  services_to_polices    = { for n, service in var.services : n => service.iam_policy_arns if service.iam_policy_arns != null }
  tasks_to_policies      = { for n, task in var.tasks : n => task.iam_policy_arns if task.iam_policy_arns != null }
  components_to_policies = merge(local.services_to_polices, local.tasks_to_policies)

  policy_arn_pairs = flatten([for n, arns in local.components_to_policies :
    [for pair in concat(
      setproduct([n], arns),
      setproduct([n], [for key, resource in data.aws_iam_policy.default-policies : resource.arn])
      ) : { key = pair[0], arn = pair[1] }
    ]
  ])

  policy_arn_groups = { for entry in local.policy_arn_pairs : join("-", [entry.key, entry.arn]) => entry }
}

resource "aws_iam_role" "extended" {
  for_each = local.components_to_policies

  name = "${title(var.name)}${title(each.key)}Role"
  path = "/${local.organization_prefix}/service-role/"

  description = "Default role assumed by servers running the ${var.name} application - ${each.key} component."

  assume_role_policy = data.aws_iam_policy_document.allow_ec2_assume.json

  tags = local.tags
}

resource "aws_iam_instance_profile" "extended" {
  for_each = local.components_to_policies
  name     = "${title(var.name)}${title(each.key)}InstanceProfile"
  path     = "/${local.organization_prefix}/service-role/"
  role     = aws_iam_role.role.name

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "extended" {
  for_each = local.policy_arn_groups

  role       = aws_iam_role.extended[each.value.key].name
  policy_arn = each.value.arn
}
###

### Services
locals {
  # We can't use coalesce below -- it will also coalesce away empty string, which we explicitly
  # want to support as a component name (mostly for migration purposes)
  component_names = { for key, entry in merge(var.services, var.tasks) : key => try(entry.component_name, null) == null ? key : entry.component_name }
  component_tags = { for key, name in local.component_names : key => name != "" ? { Component = "${var.name}-${name}" } : { Component = var.name }}
}

module "services" {
  for_each = var.services

  source  = "GoCarrot/serviceomat/aws"
  version = "~> 0.5.3"

  providers = {
    aws.meta = aws.meta
  }

  service_name   = var.name
  component_name = local.component_names[each.key]
  network_level  = coalesce(each.value["network_level"], var.network_level)
  instance_type  = coalesce(each.value["instance_type"], var.instance_type)
  volume_size    = coalesce(each.value["volume_size"], var.volume_size)

  placement_strategy = try(coalesce(each.value["placement_strategy"], var.placement_strategy), null)
  min_instances      = coalesce(each.value["min_size"], var.min_size, 2)
  max_instances      = coalesce(each.value["max_size"], var.max_size, 4)

  detailed_instance_monitoring = each.value["detailed_instance_monitoring"]

  create_role          = false
  iam_instance_profile = try(aws_iam_instance_profile.extended[each.key].arn, aws_iam_instance_profile.instance-profile.arn)

  instance_security_group_ids = concat(try(coalescelist(each.value["instance_security_group_ids"], var.instance_security_group_ids), []), [aws_security_group.tag-sg.id])

  additional_tags_for_asg_instances = merge(local.component_tags[each.key], each.value["additional_tags_for_asg_instances"])

  key_name = coalesce(each.value["break_glass_key_name"], local.break_glass_key_name)

  lb_conditions                 = each.value["lb_conditions"]
  health_check                  = each.value["health_check"]
  port                          = each.value["port"]
  load_balancing_algorithm_type = each.value["load_balancing_algorithm_type"]

  dropins            = each.value["dropins"]
  packages           = each.value["packages"]
  enabled_services   = each.value["enabled_services"]
  firstboot_services = each.value["firstboot_services"]
  boot_scripts       = each.value["boot_scripts"]

  tags = merge(local.component_tags[each.key], each.value["tags"])
}

module "tasks" {
  for_each = var.tasks

  source  = "GoCarrot/serviceomat/aws"
  version = "~> 0.5.3"

  providers = {
    aws.meta = aws.meta
  }

  service_name   = var.name
  component_name = each.key
  network_level  = coalesce(each.value["network_level"], var.network_level)
  instance_type  = coalesce(each.value["instance_type"], var.instance_type)
  volume_size    = coalesce(each.value["volume_size"], var.volume_size)

  placement_strategy = try(coalesce(each.value["placement_strategy"], var.placement_strategy), null)
  min_instances      = 0
  max_instances      = 0

  create_role          = false
  iam_instance_profile = try(aws_iam_instance_profile.extended[each.key].arn, aws_iam_instance_profile.instance-profile.arn)

  instance_security_group_ids = concat(try(coalescelist(each.value["instance_security_group_ids"], var.instance_security_group_ids), []), compact([aws_security_group.tag-sg.id, each.value.permit_dev_access ? local.dev_access_group_id : null]))

  additional_tags_for_asg_instances = merge(local.component_tags[each.key], each.value["additional_tags_for_asg_instances"])

  key_name = coalesce(each.value["break_glass_key_name"], local.break_glass_key_name)

  dropins            = each.value["dropins"]
  packages           = each.value["packages"]
  enabled_services   = each.value["enabled_services"]
  firstboot_services = each.value["firstboot_services"]
  boot_scripts       = each.value["boot_scripts"]

  tags = merge(local.component_tags[each.key], each.value["tags"])
}
