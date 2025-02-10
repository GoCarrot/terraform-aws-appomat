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
  type        = list(string)
  default     = []
  description = <<-EOM
  A list of additional log environments to configure, within the account environment. For example a "staging"
  environment of the application could be present within a production workload account.
  EOM
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
    warm_pool                         = optional(bool, false)
    kms_key_id                        = optional(string)
    asg_metrics                       = optional(list(string))
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
    kms_key_id                        = optional(string)
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
  type        = string
  description = "The default network isolation level the application runs in. One of 'public', 'protected', 'private'"
}

variable "instance_type" {
  type = string
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "min_size" {
  type        = number
  description = "The default minimum number of instances to run for services in this application"
  default     = null
}

variable "max_size" {
  type        = number
  description = "The default maximum number of instances to run for services in this application"
  default     = null
}

variable "volume_size" {
  type        = number
  description = <<-EOM
  The default size of the root volume for application instances in GiB. This must be greater than or equal to
  the volume size of the AMI for this application.
  EOM
}

variable "placement_strategy" {
  type        = string
  description = <<-EOT
  Sets the default placement strategy for components of the application.

  Determines how instances for this service are distributed within AZs. One of null, "spread", "cluster", or "1"-"7".

  If null, instances will deploy using AWSs default spread strategy, which I _suspect_ is equivalent to "7" applied to
  all EC2 instances.

  If "spread", will launch EC2 instances on distinct racks with separate network and power source. This minimizes
  correlated failures across service instances. A maximum of 7 instances per AZ can be launched with this configuration.

  If "cluster", will attempt to colocate instances as much as possible. This may include colocating instances on the
  same underlying server. This may interfere with autoscaling.

  If "1"-"7", will partition each AZ the service is deployed to into the given number. EC2 will attempt to distribute
  instances across partitions to reduce correlated failures, while still potentially colocating instances. There are
  no limits to the number of running instances except those imposed by your account.

  It is not possible to change this variable from a set value to null. If you must change this variable from a previously
  set value to null, you must manually destroy the AutoScaling Group created by this module. Note that this is a safe operation,
  the AutoScaling Group managed by this module is exclusively used during service deployments. When a service is not
  actively in the process of being deployed the AutoScaling Group may be modified, destroyed, or recreated without consequence.

  Defaults to "7".
EOT
  default     = null
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
