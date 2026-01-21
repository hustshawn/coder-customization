terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Last updated 2025-09-11
# aws ec2 describe-regions | jq -r '[.Regions[].RegionName] | sort'
data "coder_parameter" "region" {
  name         = "region"
  display_name = "Region"
  description  = "The region to deploy the workspace in."
  default      = "us-west-2"
  mutable      = false
  option {
    name  = "Asia Pacific (Tokyo)"
    value = "ap-northeast-1"
    icon  = "/emojis/1f1ef-1f1f5.png"
  }
  option {
    name  = "Asia Pacific (Jakarta)"
    value = "ap-southeast-3"
    icon  = "/emojis/1f1ee-1f1e9.png"
  }
  option {
    name  = "Asia Pacific (Hong Kong)"
    value = "ap-east-1"
    icon  = "/emojis/1f1ed-1f1f0.png"
  }
  # option {
  #   name  = "Asia Pacific (Seoul)"
  #   value = "ap-northeast-2"
  #   icon  = "/emojis/1f1f0-1f1f7.png"
  # }
  # option {
  #   name  = "Asia Pacific (Osaka)"
  #   value = "ap-northeast-3"
  #   icon  = "/emojis/1f1ef-1f1f5.png"
  # }
  option {
    name  = "Asia Pacific (Mumbai)"
    value = "ap-south-1"
    icon  = "/emojis/1f1ee-1f1f3.png"
  }
  option {
    name  = "Asia Pacific (Singapore)"
    value = "ap-southeast-1"
    icon  = "/emojis/1f1f8-1f1ec.png"
  }
  option {
    name  = "Asia Pacific (Sydney)"
    value = "ap-southeast-2"
    icon  = "/emojis/1f1e6-1f1fa.png"
  }
  # option {
  #   name  = "Canada (Central)"
  #   value = "ca-central-1"
  #   icon  = "/emojis/1f1e8-1f1e6.png"
  # }
  # option {
  #   name  = "EU (Frankfurt)"
  #   value = "eu-central-1"
  #   icon  = "/emojis/1f1ea-1f1fa.png"
  # }
  # option {
  #   name  = "EU (Stockholm)"
  #   value = "eu-north-1"
  #   icon  = "/emojis/1f1ea-1f1fa.png"
  # }
  option {
    name  = "EU (Ireland)"
    value = "eu-west-1"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
  # option {
  #   name  = "EU (London)"
  #   value = "eu-west-2"
  #   icon  = "/emojis/1f1ea-1f1fa.png"
  # }
  # option {
  #   name  = "EU (Paris)"
  #   value = "eu-west-3"
  #   icon  = "/emojis/1f1ea-1f1fa.png"
  # }
  # option {
  #   name  = "South America (São Paulo)"
  #   value = "sa-east-1"
  #   icon  = "/emojis/1f1e7-1f1f7.png"
  # }
  option {
    name  = "US East (N. Virginia)"
    value = "us-east-1"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "US East (Ohio)"
    value = "us-east-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  # option {
  #   name  = "US West (N. California)"
  #   value = "us-west-1"
  #   icon  = "/emojis/1f1fa-1f1f8.png"
  # }
  option {
    name  = "US West (Oregon)"
    value = "us-west-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
}

data "coder_parameter" "use_custom_region" {
  name         = "use_custom_region"
  display_name = "[Optional] Use Custom Region"
  description  = "Enable to specify a custom AWS region not in the dropdown list."
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 1
}

data "coder_parameter" "custom_region" {
  count        = data.coder_parameter.use_custom_region.value == "true" ? 1 : 0
  name         = "custom_region"
  display_name = "Custom Region"
  description  = "Enter any valid AWS region code (e.g., eu-central-1, ap-northeast-2)"
  type         = "string"
  mutable      = false
  order        = 2
}

data "coder_parameter" "use_custom_az" {
  name         = "use_custom_az"
  display_name = "[Optional] Specify Availability Zone"
  description  = "Enable to specify a specific availability zone. If disabled, AWS will select one automatically."
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 3
}

data "coder_parameter" "custom_az" {
  count        = data.coder_parameter.use_custom_az.value == "true" ? 1 : 0
  name         = "custom_az"
  display_name = "Availability Zone Suffix"
  description  = "Enter the AZ suffix (e.g., 'a', 'b', 'c'). The full AZ will be region + suffix (e.g., us-west-2a)."
  type         = "string"
  default      = "a"
  mutable      = false
  order        = 4
}

data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "What instance type should your workspace use?"
  default      = "t3.micro"
  mutable      = false
  option {
    name  = "t3.micro(2 vCPU, 1 GiB RAM)"
    value = "t3.micro"
  }
  option {
    name  = "t3.small(2 vCPU, 2 GiB RAM)"
    value = "t3.small"
  }
  option {
    name  = "t3.medium(2 vCPU, 4 GiB RAM)"
    value = "t3.medium"
  }
  option {
    name  = "t3.large(2 vCPU, 8 GiB RAM)"
    value = "t3.large"
  }
  option {
    name  = "t3.xlarge(4 vCPU, 16 GiB RAM)"
    value = "t3.xlarge"
  }
  option {
    name  = "t3.2xlarge (8 vCPU, 32 GiB RAM)"
    value = "t3.2xlarge"
  }
  option {
    name  = "c7i.2xlarge (8 vCPU, 16 GiB RAM)"
    value = "c7i.2xlarge"
  }
  option {
    name  = "c8i.2xlarge (8 vCPU, 16 GiB RAM)"
    value = "c8i.2xlarge"
  }
  option {
    name  = "c7g.2xlarge (8 vCPU, 16 GiB RAM)"
    value = "c7g.2xlarge"
  }
  option {
    name  = "c8g.2xlarge (8 vCPU, 16 GiB RAM)"
    value = "c8g.2xlarge"
  }
  option {
    name  = "x8aedz.3xlarge (12 vCPU, 384 GiB)"
    value = "x8aedz.3xlarge"
  }
  option {
    name  = "g6e.12xlarge - 4xL40S"
    value = "g6e.12xlarge"
  }
  option {
    name  = "p5.4xlarge - 1xH100"
    value = "p5.4xlarge"
  }
  option {
    name  = "p5.48xlarge - 8xH100"
    value = "p5.48xlarge"
  }
  option {
    name  = "p5en.48xlarge - 8xH200"
    value = "p5en.48xlarge"
  }

}

data "coder_parameter" "use_custom_instance_type" {
  name         = "use_custom_instance_type"
  display_name = "[Optional] Use Custom Instance Type"
  description  = "Enable to specify a custom EC2 instance type not in the dropdown list."
  type         = "bool"
  default      = "false"
  mutable      = false
  order        = 5
}

data "coder_parameter" "custom_instance_type" {
  count        = data.coder_parameter.use_custom_instance_type.value == "true" ? 1 : 0
  name         = "custom_instance_type"
  display_name = "Custom Instance Type"
  description  = "Enter any valid EC2 instance type (e.g., m6i.xlarge, r6g.2xlarge)"
  type         = "string"
  mutable      = false
  order        = 6
}

data "coder_parameter" "custom_architecture" {
  count        = data.coder_parameter.use_custom_instance_type.value == "true" ? 1 : 0
  name         = "custom_architecture"
  display_name = "[Optional] Instance Architecture"
  description  = "Select the CPU architecture for your custom instance type. ARM64 (Graviton) instance types typically have 'g' in the name (e.g., m6g, c7g, r6g)."
  default      = "x86_64"
  mutable      = false
  order        = 7
  option {
    name  = "x86_64 (Intel/AMD)"
    value = "x86_64"
  }
  option {
    name  = "ARM64 (Graviton)"
    value = "arm64"
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size"
  description  = "How much disk space should your workspace have?"
  default      = "100"
  mutable      = false
  option {
    name  = "75 GiB (Minimum for GPU AMIs)"
    value = "75"
  }
  option {
    name  = "100 GiB"
    value = "100"
  }
  option {
    name  = "200 GiB"
    value = "200"
  }
  option {
    name  = "500 GiB"
    value = "500"
  }
  option {
    name  = "1000 GiB (1 TiB)"
    value = "1000"
  }
  option {
    name  = "2000 GiB (2 TiB)"
    value = "2000"
  }
}

data "coder_parameter" "spot_instance" {
  name         = "spot_instance"
  display_name = "Spot Instance"
  description  = "Use spot instances for up to 90% cost savings. Spot instances may be interrupted when AWS needs capacity."
  default      = "false"
  mutable      = false
  option {
    name  = "On-Demand (Guaranteed availability)"
    value = "false"
  }
  option {
    name  = "Spot (Up to 90% savings, may be interrupted)"
    value = "true"
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  # Effective region, AZ, and instance type (custom or predefined)
  use_custom_region        = data.coder_parameter.use_custom_region.value == "true"
  use_custom_az            = data.coder_parameter.use_custom_az.value == "true"
  use_custom_instance_type = data.coder_parameter.use_custom_instance_type.value == "true"

  effective_region = (
    local.use_custom_region
    ? data.coder_parameter.custom_region[0].value
    : data.coder_parameter.region.value
  )

  # AZ is null when not specified (AWS picks automatically)
  effective_az = (
    local.use_custom_az
    ? "${local.effective_region}${data.coder_parameter.custom_az[0].value}"
    : null
  )

  effective_instance_type = (
    local.use_custom_instance_type
    ? data.coder_parameter.custom_instance_type[0].value
    : data.coder_parameter.instance_type.value
  )

  # Architecture and instance type configuration
  # GPU instance families (p = GPU training, g = GPU graphics/inference, dl = deep learning)
  gpu_instance_families      = ["p3", "p4d", "p4de", "p5", "p5e", "p5en", "g4dn", "g5", "g5g", "g6", "g6e", "g7i", "dl1", "dl2q", "inf1", "inf2", "trn1", "trn1n", "trn2"]
  arm64_instance_types       = ["c7g.2xlarge", "c8g.2xlarge"]
  gpu_instances_needing_raid = ["g6e.12xlarge", "p5.48xlarge", "p5en.48xlarge"]

  # Extract instance family from instance type (e.g., "p5en" from "p5en.48xlarge")
  instance_family = split(".", local.effective_instance_type)[0]

  # GPU detection: check if instance family is in the GPU families list
  is_gpu_instance = contains(local.gpu_instance_families, local.instance_family)

  is_arm64_instance = (
    local.use_custom_instance_type
    ? data.coder_parameter.custom_architecture[0].value == "arm64"
    : contains(local.arm64_instance_types, local.effective_instance_type)
  )

  is_spot_instance = data.coder_parameter.spot_instance.value == "true"
  needs_nvme_raid  = contains(local.gpu_instances_needing_raid, local.effective_instance_type)
  architecture     = local.is_arm64_instance ? "arm64" : "amd64"

  # AMI selection
  selected_ami_id = local.is_gpu_instance ? (
    try(data.aws_ami.gpu_optimized.id, data.aws_ami.gpu_fallback.id)
  ) : data.aws_ami.ubuntu.id

  # Disk and user configuration
  disk_size  = local.is_gpu_instance ? max(75, tonumber(data.coder_parameter.disk_size.value)) : tonumber(data.coder_parameter.disk_size.value)
  hostname   = lower(data.coder_workspace.me.name)
  linux_user = local.is_gpu_instance ? "ubuntu" : "coder"
}

provider "aws" {
  region = local.effective_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-${local.architecture}-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "aws_ami" "gpu_optimized" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI*Ubuntu*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  owners = ["amazon"]
}

# Fallback to regular Ubuntu AMI if Deep Learning AMI is not available
data "aws_ami" "gpu_fallback" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-${local.architecture}-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "coder_agent" "dev" {
  count               = data.coder_workspace.me.start_count
  arch                = local.architecture
  auth                = "aws-instance-identity"
  os                  = "linux"
  connection_timeout  = 120
  troubleshooting_url = "https://coder.com/docs/coder-oss/latest/templates/troubleshooting"

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat cpu"
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat mem"
  }
  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 600 # every 10 minutes
    timeout      = 30  # df can take a while on large filesystems
    script       = "coder stat disk --path $HOME"
  }
}

# Working modules ✅
module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.dev[0].id
  order    = 1
}

# Kiro CLI installation
resource "coder_script" "kiro_cli" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.dev[0].id
  display_name       = "Kiro CLI"
  icon               = "/icon/aws.svg"
  script             = <<-EOT
    #!/bin/bash
    set -e

    if ! command -v kiro-cli &>/dev/null; then
      echo "Installing Kiro CLI..."
      curl -fsSL https://cli.kiro.dev/install | bash
      echo "✅ Kiro CLI installed successfully!"
    else
      echo "Kiro CLI already installed"
    fi
  EOT
  run_on_start       = true
  run_on_stop        = false
  start_blocks_login = false
  timeout            = 300
}

module "kiro" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/kiro/coder"
  version  = "1.1.0"
  agent_id = coder_agent.dev[0].id
  folder   = "/home/${local.linux_user}"
}

# Claude Code environment variables for AWS Bedrock
# Note: Claude Code module removed due to curl compatibility issues with Ubuntu 20.04
# Claude Code is installed via npm in userdata.sh instead

resource "coder_env" "bedrock_use" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.dev[0].id
  name     = "CLAUDE_CODE_USE_BEDROCK"
  value    = "1"
}
resource "coder_env" "aws_region" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.dev[0].id
  name     = "AWS_REGION"
  value    = "us-east-1"
}
resource "coder_env" "anthropic_model" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.dev[0].id
  name     = "ANTHROPIC_MODEL"
  value    = "global.anthropic.claude-sonnet-4-5-20250929-v1:0"
}
resource "coder_env" "anthropic_small_fast_model" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.dev[0].id
  name     = "ANTHROPIC_SMALL_FAST_MODEL"
  value    = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
}

# JupyterLab module with pipx properly installed in userdata
module "jupyterlab" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/jupyterlab/coder"
  version  = "~> 1.2"
  agent_id = coder_agent.dev[0].id
  config = jsonencode({
    ServerApp = {
      # Required for Coder Tasks iFrame embedding - do not remove
      tornado_settings = {
        headers = {
          "Content-Security-Policy" = "frame-ancestors 'self' ${data.coder_workspace.me.access_url}"
        }
      }
      # Your additional configuration here
      root_dir = "/home/${local.linux_user}"
    }
  })
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  boundary = "//"

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"

    content = templatefile("${path.module}/cloud-init/cloud-config.yaml.tftpl", {
      hostname   = local.hostname
      linux_user = local.linux_user
    })
  }

  part {
    filename     = "userdata.sh"
    content_type = "text/x-shellscript"

    content = templatefile("${path.module}/cloud-init/userdata.sh.tftpl", {
      linux_user  = local.linux_user
      init_script = try(coder_agent.dev[0].init_script, "")
    })
  }
}

# IAM role for SSM access
resource "aws_iam_role" "coder_instance_role" {
  name_prefix = "coder-instance-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.coder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "administrator_access" {
  role       = aws_iam_role.coder_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "coder_instance_profile" {
  name_prefix = "coder-instance-profile-"
  role        = aws_iam_role.coder_instance_role.name
}

# Security group for Coder workspace
resource "aws_security_group" "coder_workspace" {
  name_prefix = "coder-workspace-"
  description = "Security group for Coder workspace"

  # Allow outbound internet access (required for Coder agent)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH (optional, for debugging)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "coder-workspace-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  }
}

resource "aws_instance" "dev" {
  ami                    = local.selected_ami_id
  availability_zone      = local.effective_az
  instance_type          = local.effective_instance_type
  vpc_security_group_ids = [aws_security_group.coder_workspace.id]
  iam_instance_profile   = aws_iam_instance_profile.coder_instance_profile.name

  # Spot instance configuration (only when spot is selected)
  dynamic "instance_market_options" {
    for_each = local.is_spot_instance ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type             = "persistent"
        instance_interruption_behavior = "stop"
      }
    }
  }

  # Fix IMDSv2 configuration for agent authentication
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2 only
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = local.disk_size
    encrypted   = true
  }

  user_data = data.cloudinit_config.user_data.rendered
  tags = {
    Name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    # Required if you are using our example policy, see template README
    Coder_Provisioned = "true"
  }
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "coder_metadata" "workspace_info" {
  resource_id = aws_instance.dev.id
  item {
    key   = "region"
    value = local.effective_region
  }
  dynamic "item" {
    for_each = local.use_custom_az ? [1] : []
    content {
      key   = "AZ"
      value = local.effective_az
    }
  }
  item {
    key   = "instance type"
    value = aws_instance.dev.instance_type
  }
  item {
    key   = "disk"
    value = "${aws_instance.dev.root_block_device[0].volume_size} GiB"
  }
  dynamic "item" {
    for_each = local.needs_nvme_raid ? [1] : []
    content {
      key   = "nvme storage"
      value = "RAID0(~/nvme-storage)"
    }
  }
  dynamic "item" {
    for_each = local.is_spot_instance ? [1] : []
    content {
      key   = "purchase option"
      value = "Spot"
    }
  }
}

resource "aws_ec2_instance_state" "dev" {
  instance_id = aws_instance.dev.id
  state       = data.coder_workspace.me.transition == "start" ? "running" : "stopped"
}
