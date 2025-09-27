output "security_group" {
  value = aws_security_group.tag-sg
}

output "vpc_id" {
  value = local.vpc_id
}

output "services" {
  value = module.services
}

output "tasks" {
  value = module.tasks
}

output "iam_role" {
  value = aws_iam_role.role
}

output "log_groups" {
  value = aws_cloudwatch_log_group.logs
}
