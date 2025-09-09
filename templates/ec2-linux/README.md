---
display_name: AWS EC2 (Linux)
description: Provision AWS EC2 VMs as Coder workspaces
icon: ../../../site/static/icon/aws.svg
maintainer_github: coder
verified: true
tags: [vm, linux, aws, persistent-vm]
---

# Remote Development on AWS EC2 VMs (Linux)

Provision AWS EC2 VMs as [Coder workspaces](https://coder.com/docs/workspaces) with this example template.

## Prerequisites

### Authentication

By default, this template authenticates to AWS using the provider's default [authentication methods](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration).

The simplest way (without making changes to the template) is via environment variables (e.g. `AWS_ACCESS_KEY_ID`) or a [credentials file](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-format). If you are running Coder on a VM, this file must be in `/home/coder/aws/credentials`.

To use another [authentication method](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication), edit the template.

## Required permissions / policy

The following sample policy allows Coder to create EC2 instances and modify
instances provisioned by Coder:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "VisualEditor0",
			"Effect": "Allow",
			"Action": [
				"ec2:GetDefaultCreditSpecification",
				"ec2:DescribeIamInstanceProfileAssociations",
				"ec2:DescribeTags",
				"ec2:DescribeInstances",
				"ec2:DescribeInstanceTypes",
				"ec2:DescribeInstanceStatus",
				"ec2:CreateTags",
				"ec2:RunInstances",
				"ec2:DescribeInstanceCreditSpecifications",
				"ec2:DescribeImages",
				"ec2:ModifyDefaultCreditSpecification",
				"ec2:DescribeVolumes"
			],
			"Resource": "*"
		},
		{
			"Sid": "CoderResources",
			"Effect": "Allow",
			"Action": [
				"ec2:DescribeInstanceAttribute",
				"ec2:UnmonitorInstances",
				"ec2:TerminateInstances",
				"ec2:StartInstances",
				"ec2:StopInstances",
				"ec2:DeleteTags",
				"ec2:MonitorInstances",
				"ec2:CreateTags",
				"ec2:RunInstances",
				"ec2:ModifyInstanceAttribute",
				"ec2:ModifyInstanceCreditSpecification"
			],
			"Resource": "arn:aws:ec2:*:*:instance/*",
			"Condition": {
				"StringEquals": {
					"aws:ResourceTag/Coder_Provisioned": "true"
				}
			}
		}
	]
}
```

## Architecture

This template provisions the following resources:

- AWS EC2 Instance with configurable instance types and storage
- Cloud-init configuration for automated setup
- Smart AMI selection (standard Ubuntu or GPU-optimized based on instance type)

Coder uses `aws_ec2_instance_state` to start and stop the VM. This template is fully persistent, meaning the full filesystem is preserved when the workspace restarts.

## Features

### Multi-Region Support
The template supports deployment across multiple AWS regions with intuitive country flag icons:
- **Asia Pacific**: Tokyo 🇯🇵, Jakarta 🇮🇩, Mumbai 🇮🇳, Singapore 🇸🇬, Sydney 🇦🇺
- **Europe**: Ireland 🇪🇺  
- **US**: N. Virginia, Ohio, Oregon 🇺🇸

### Instance Types
- **General Purpose**: t3.micro (2 vCPU, 1GB) to t3.2xlarge (8 vCPU, 32GB)
- **GPU Instances**: g6e.12xlarge (4xL40S), p5.4xlarge (1xH100)

### Storage Options
Configurable EBS storage from 20GB to 1TB with GP3 volumes and encryption enabled by default.

### Pre-installed Development Tools
- **Code Server**: Web-based VS Code accessible through the dashboard
- **Kiro IDE**: Advanced AI-powered development environment
- **Jupyter Notebook**: For data science and machine learning workflows

> **Note**
> This template is designed to be a starting point! Edit the Terraform to extend the template to support your use case.
