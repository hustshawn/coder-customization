# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Terraform-based templates for provisioning cloud development workspaces using [Coder](https://coder.com/). Templates define infrastructure (AWS EC2 instances, Kubernetes namespaces) that become developer workspaces with pre-installed tools.

## Commands

```bash
# Push a specific template to Coder
./push-templates.sh ec2-linux

# Push all templates
./push-templates.sh

# Manual push with icon
coder templates push ec2-linux
coder templates edit "<template-name>" --icon /icon/aws.svg
```

## Architecture

### Workspace Provisioning Flow

1. User selects template parameters (region, instance type, disk size) via Coder UI
2. Terraform provisions AWS resources (EC2, IAM role, security group)
3. CloudInit executes userdata scripts to install development tools
4. Coder agent connects back to Coder server for workspace management
5. IDEs (Code Server, Kiro, Jupyter) become available via Coder dashboard

### Template Structure

Each template follows this pattern:

- `main.tf` - Terraform configuration with Coder data sources, parameters, and resources
- `cloud-init/` - User data scripts (cloud-config.yaml.tftpl, userdata.sh.tftpl)
- `README.md` - Template-specific documentation

### Key Terraform Patterns

**Coder Data Sources:**

- `coder_workspace` and `coder_workspace_owner` - Workspace context
- `coder_parameter` - User-selectable options (region, instance type, disk size)

**Coder Resources:**

- `coder_agent` - Manages workspace connectivity and IDE apps
- `coder_app` - Defines accessible applications (Code Server, Jupyter, etc.)

**AWS Resources (ec2-linux):**

- EC2 instance with CloudInit user data
- Security group (egress-only by default)
- IAM role with instance profile for AWS access

### Architecture-Aware Installations
The userdata script detects CPU architecture (`x86_64` vs `aarch64`) to install correct binaries for AWS CLI, UV package manager, and Node.js.

## Templates

| Template        | Purpose                                               |
|-----------------|-------------------------------------------------------|
| `ec2-linux`     | AWS EC2 instances with Ubuntu, supports GPU instances |
| `kubernetes-ns` | Kubernetes namespaces with service accounts           |

## Environment Variables in Workspaces

Templates configure Claude Code for AWS Bedrock:

- `CLAUDE_CODE_USE_BEDROCK=1`
- `AWS_REGION=us-east-1`
- `ANTHROPIC_MODEL` and `ANTHROPIC_SMALL_FAST_MODEL` for model selection

## File Locations

- Templates: `templates/<template-name>/main.tf`
- Cloud-init scripts: `templates/ec2-linux/cloud-init/`
- Deployment script: `push-templates.sh`
