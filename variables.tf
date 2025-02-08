variable "name" {
  type        = string
  description = "The name of the application being provisioned. Will be used as the base name for all components, log groups, and other resources."
}

variable "automatic_build" {
  type = object({
    branch                = string
    build_from_account    = string
    automatic_deploy      = optional(bool, true)
    inherit_from          = string
    circleci_project_slug = string
  })
  default     = null
  description = <<-EOM
  Configuration for triggering automatic image builds when the upstream image is updated.

  branch: The name of the branch in the _current_ repo to build on a change.
  build_from_account: The accountomat canonical slug of the account to build the new AMI in.
  automatic_deploy: Set to true to initiate the deployment process after an automatic image update. Deployments may still require manual approval.
  circle_ci_project_slug: The CircleCI project slug, e.g. gh/ExampleOrg/ExampleRepo, for the _current_ project. This is the
                          CircleCI project that will be triggered when an AMI update is required for the _current_ project.
  inhert_from: The AMI name prefix of the AMI that the _current_ project's AMI is built from.
EOM
}

variable "ancillary_log_groups" {
  type        = list(string)
  default     = []
  description = <<-EOM
  A list of additional application log groups to create, under <organizaton prefix>/<environment>/server/<name>
EOM
}

variable "log_environments" {
  type    = list(string)
  default = []
}

variable "services" {
  type = map(object({
    network_level                     = optional(string)
    iam_policy_arns                   = optional(list(string))
    instance_type                     = optional(string)
    min_size                          = optional(number)
    max_size                          = optional(number)
    volume_size                       = optional(number)
    component_name                    = optional(string)
    placement_strategy                = optional(string)
    instance_security_group_ids       = optional(list(string))
    additional_tags_for_asg_instances = optional(map(string), {})
    lb_conditions = optional(
      map(
        object({
          priority = number,
          conditions = list(
            object({
              host_headers         = optional(list(string)),
              http_headers         = optional(list(object({ http_header_name = string, values = list(string) }))),
              http_request_methods = optional(list(string)),
              path_patterns        = optional(list(string)),
              query_string         = optional(list(object({ key = optional(string), value = string }))),
              source_ips           = optional(list(string))
            })
          )
        })
      ),
      {}
    )
    health_check = optional(
      object({
        enabled             = optional(bool, true)
        healthy_threshold   = optional(number, 3)
        interval            = optional(number, 30)
        matcher             = optional(string, "200")
        path                = optional(string, "/")
        port                = optional(string, "traffic-port")
        protocol            = optional(string, "HTTP")
        timeout             = optional(number, 30)
        unhealthy_threshold = optional(number, 3)
      }),
      {}
    )
    detailed_instance_monitoring  = optional(bool, false)
    port                          = optional(number, 80)
    load_balancing_algorithm_type = optional(string, "round_robin")
    break_glass_key_name          = optional(string, )
    dropins                       = optional(map(any), {})
    packages                      = optional(list(string), [])
    enabled_services              = optional(list(string), [])
    firstboot_services            = optional(list(string), [])
    boot_scripts                  = optional(map(map(any)), {})
    tags                          = optional(map(string), {})
  }))
  default = {}
}

variable "tasks" {
  type = map(object({
    network_level                     = optional(string)
    iam_policy_arns                   = optional(list(string))
    instance_type                     = optional(string)
    volume_size                       = optional(number)
    placement_strategy                = optional(string)
    break_glass_key_name              = optional(string)
    instance_security_group_ids       = optional(list(string))
    additional_tags_for_asg_instances = optional(map(string), {})
    dropins                           = optional(map(any), {})
    packages                          = optional(list(string), [])
    enabled_services                  = optional(list(string), [])
    firstboot_services                = optional(list(string), [])
    boot_scripts                      = optional(map(any), {})
    permit_dev_access                 = optional(bool, true)
    tags                              = optional(map(string), {})
  }))
  default = {}
}

variable "network_level" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "min_size" {
  type    = number
  default = null
}

variable "max_size" {
  type    = number
  default = null
}

variable "volume_size" {
  type = number
}

variable "placement_strategy" {
  type    = string
  default = null
}

variable "instance_security_group_ids" {
  type    = list(string)
  default = null
}

variable "break_glass_key_name" {
  type    = string
  default = null
}

variable "log_retention_days" {
  type = number
}

variable "tags" {
  type        = map(string)
  description = <<-EOT
  Tags to attach to created sources. WILL NOT BE ATTACHED TO ASG INSTANCES. Use additional_tags_for_asg_instances to
  control tags assigned to ASG instances. Tags here will override default tags in the event of a conflict.
  EOT
  default     = {}
}
