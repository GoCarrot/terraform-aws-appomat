# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform Registry module (`GoCarrot/appomat/aws`) that configures AWS infrastructure for deploying applications using EC2 Auto Scaling Groups. Users consume this module by referencing it in their Terraform configurations. The module provides a unified interface for deploying services and tasks with consistent naming, IAM roles, security groups, and CloudWatch log groups. It works in conjunction with Deployomat for actual deployments.

## Repository Information

- **GitHub**: `github.com/GoCarrot/terraform-aws-appomat`
- **Terraform Registry**: Published as `GoCarrot/appomat/aws`
- **Purpose**: Module development and maintenance (not direct infrastructure deployment)

## Key Architecture

### Module Structure
- **Main Module**: Orchestrates all resources and sub-modules
- **Account Info Module** (`GoCarrot/accountomat_read/aws`): Retrieves account metadata and configuration from SSM parameters
- **Serviceomat Module** (`GoCarrot/serviceomat/aws`): Creates EC2 Auto Scaling Groups, Launch Templates, Target Groups, and Load Balancer rules
- **Build Trigger Module** (`GoCarrot/declare-ami-dependency/aws`): Manages AMI dependencies and CircleCI build triggers

### Core Components
1. **Services** (`var.services`): Long-running services with:
   - EC2 Auto Scaling Groups and Launch Templates
   - Optional Application Load Balancer integration (Target Groups, Listener Rules)
   - Health checks and auto-scaling configuration
   - Instance profiles and IAM roles

2. **Tasks** (`var.tasks`): One-off or periodic tasks:
   - Same infrastructure as services but with min/max instances set to 0
   - Used as templates by Deployomat for task execution
   - Optional developer SSH access via security groups

3. **IAM Roles**: 
   - Default role for all components
   - Extended roles created when components have custom tags or additional IAM policies

4. **Security Groups**: 
   - Default security group for application tagging
   - Additional security groups for load balancer ingress (when using ALB)

5. **CloudWatch Log Groups**: 
   - Hierarchical structure: `/<org_prefix>/server/<environment>/service/<app_name>`
   - Support for ancillary log groups and multiple environments

### Configuration Hierarchy
Variables follow a precedence hierarchy:
1. Component-specific value (service/task level)
2. Application default (module-level variable)  
3. Module default value

## Module Development Commands

### Code Quality
```bash
# Format Terraform files
terraform fmt -recursive

# Validate module syntax
terraform validate

# Run module tests
terraform test

# Run specific test file
terraform test -filter=tests/basic_app.tftest.hcl
```

### Module Usage Example
Users consume this module from the Terraform Registry:
```hcl
module "my_app" {
  source  = "GoCarrot/appomat/aws"
  version = "~> 0.1.2"
  
  providers = {
    aws.meta = aws.meta
  }
  
  name          = "myapp"
  network_level = "public"
  instance_type = "t4g.micro"
  
  services = {
    web = {
      min_size = 2
      max_size = 4
    }
  }
}
```

## Key Variables

### Required Variables
- `name`: Application name (base for all resource names)
- `network_level`: Network isolation level (`public`, `protected`, or `private`)
- `instance_type`: Default EC2 instance type

### Important Optional Variables
- `services`: Map of service configurations with load balancing, auto-scaling, and health checks
- `tasks`: Map of task configurations for one-off or scheduled jobs
- `automatic_build`: CircleCI integration for AMI build automation
- `log_environments`: Additional log environments beyond account default
- `ancillary_log_groups`: Additional log groups under application namespace
- `volume_size`: EBS volume size for instances
- `min_size`/`max_size`: Default auto-scaling limits
- `placement_strategy`: EC2 placement strategy
- `iam_policy_arns`: Additional IAM policies to attach

## Module Dependencies

External modules from GoCarrot organization:
- `GoCarrot/accountomat_read/aws` (~> 0.0.5): Account metadata retrieval
- `GoCarrot/serviceomat/aws` (~> 0.5.3): EC2 ASG and ALB management
- `GoCarrot/declare-ami-dependency/aws`: AMI dependency and build triggers

## SSM Parameter Dependencies

The module reads configuration from AWS Systems Manager Parameter Store:
- Account info: `/omat/account_registry/<account_slug>`
- Core config: `<prefix>/config/core/*`
  - `vpc_id`: VPC for resources
  - `dev_access_security_group_id`: Security group for developer access
  - `break_glass_key_name`: EC2 key pair for emergency access
  - Subnet IDs based on network level
- Organization config: `/omat/org_registry/CI-CD/<environment>/`

## IAM Policy Patterns

Default policies attached to all roles:
- `ServiceomatBase`: Base permissions for EC2 instances

Extended IAM roles created when:
- Custom tags specified for a service/task
- Additional IAM policy ARNs provided via `iam_policy_arns`

## Naming Conventions

- **IAM Roles**: `<AppName>Role` or `<AppName><ComponentName>Role`
- **Instance Profiles**: `<AppName>InstanceProfile` or `<AppName><ComponentName>InstanceProfile`  
- **Security Groups**: `<app_name>`
- **Log Groups**: `/<org_prefix>/server/<environment>/service/<app_name>[/<ancillary>]`
- **ASG Names**: `<app_name>-<component>-template`
- **Target Groups**: `<app_name>-<component>`

## User Data and Dropins

The module supports customizing instance initialization through:
- **Dropins**: Configuration files copied to instances
- **Packages**: Additional packages to install
- **Enabled Services**: Systemd services to enable
- **Firstboot Services**: Services to run on first boot only
- **Boot Scripts**: Custom scripts to run during boot

## Network Levels

The module supports three network isolation levels:
- `public`: Instances in public subnets with direct internet access
- `protected`: Instances in protected subnets with NAT gateway access
- `private`: Instances in private subnets with no internet access

## Provider Requirements

- Terraform >= 1.8.0
- AWS Provider >= 4.22, < 6
- Two AWS provider configurations required:
  - Default provider for target account resources
  - `aws.meta` provider for metadata and SSM parameter access

## Module Versioning and Release Process

### Version Numbering
The module follows semantic versioning (MAJOR.MINOR.PATCH):
- **PATCH** (0.1.x): Bug fixes, documentation updates
- **MINOR** (0.x.0): New features, backwards-compatible changes
- **MAJOR** (x.0.0): Breaking changes

### Making Changes
1. Create feature branch from `main`
2. Make changes and update tests as needed
3. Update CHANGELOG.md with description of changes
4. Run `terraform fmt -recursive` and `terraform test`
5. Create pull request to `main`

### Publishing to Terraform Registry
The module is automatically published to the Terraform Registry when:
1. Changes are merged to `main` branch
2. A new Git tag is created following the version format (e.g., `v0.1.3`)

The Registry will read the module from the GitHub repository at `github.com/GoCarrot/terraform-aws-appomat`

## Git Commit Guidelines

**CRITICAL**: When creating git commits, Claude MUST include ALL user prompts verbatim in the commit message. This is vitally important for tracking and understanding changes.

### Commit Message Format
```
<Brief summary of changes>

User prompt 1: "<FULL VERBATIM TEXT of first user prompt>"
Claude's response: <Explanation of what Claude did in response to this specific prompt>

User prompt 2: "<FULL VERBATIM TEXT of second user prompt>"
Claude's response: <Explanation of what Claude did in response to this specific prompt>

User prompt 3: "<FULL VERBATIM TEXT of third user prompt>"
Claude's response: <Explanation of what Claude did in response to this specific prompt>

[Continue for ALL user prompts in the conversation]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Important Rules
1. **ALWAYS include EVERY user prompt in FULL** - do not summarize, paraphrase, or omit any user messages
2. **Do NOT determine relevance** - ALL user prompts are always relevant and must be included
3. **Include prompts verbatim** - copy the exact text, including typos, formatting, etc.
4. **Explain response to EACH prompt** - describe what Claude did in response to each individual user prompt
5. **Maintain chronological order** - list prompts and responses in the order they occurred
6. **Use clear labeling** - label each prompt as "User prompt N:" and each response as "Claude's response:"