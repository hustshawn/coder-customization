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
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size"
  description  = "How much disk space should your workspace have?"
  default      = "20"
  mutable      = false
  option {
    name  = "20 GiB"
    value = "20"
  }
  option {
    name  = "50 GiB"
    value = "50"
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
}



provider "aws" {
  region = data.coder_parameter.region.value
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
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
    values = ["Deep Learning Base GPU AMI (Ubuntu 20.04)*"]
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
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

locals {
  # Define GPU instance types
  gpu_instance_types = ["g6e.12xlarge", "p5.4xlarge"]

  # Check if selected instance type is a GPU instance
  is_gpu_instance = contains(local.gpu_instance_types, data.coder_parameter.instance_type.value)

  # Define GPU instances that need RAID0 setup (exclude p5.4xlarge)
  gpu_instances_needing_raid = ["g6e.12xlarge"]

  # Check if selected instance type needs RAID0 setup
  needs_nvme_raid = contains(local.gpu_instances_needing_raid, data.coder_parameter.instance_type.value)

  # Try to use GPU-optimized AMI, fallback to regular Ubuntu if not available
  selected_ami_id = local.is_gpu_instance ? (
    try(data.aws_ami.gpu_optimized.id, data.aws_ami.gpu_fallback.id)
  ) : data.aws_ami.ubuntu.id

  # Use consistent user for all instances to avoid confusion
  # GPU AMIs typically use ec2-user, but we'll standardize on coder
  use_gpu_ami = local.is_gpu_instance && can(data.aws_ami.gpu_optimized.id)
}

resource "coder_agent" "dev" {
  count               = data.coder_workspace.me.start_count
  arch                = "amd64"
  auth                = "aws-instance-identity"
  os                  = "linux"
  connection_timeout  = 900 # 15 minutes for P5 instances
  troubleshooting_url = "https://coder.com/docs/coder-oss/latest/templates/troubleshooting"

  startup_script = <<-EOT
    set -e
    
    # Log everything for debugging
    exec > >(tee -a /tmp/coder-agent-startup.log) 2>&1
    
    echo "=== Coder Agent Startup $(date) ==="
    echo "User: $(whoami)"
    echo "Home: $HOME"
    echo "PATH: $PATH"
    
    # Get instance type
    INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
    echo "Instance Type: $INSTANCE_TYPE"
    
    # Check if this is a P5.4xlarge and set environment variable
    if [[ "$INSTANCE_TYPE" == "p5.4xlarge" ]]; then
        echo "Setting P5.4xlarge workaround..."
        export FI_HMEM_DISABLE_P2P=1
        echo "export FI_HMEM_DISABLE_P2P=1" >> ~/.bashrc
    fi
    
    # Ensure pipx is in PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Check if pipx is available, install if not
    if ! command -v pipx &> /dev/null; then
        echo "pipx not found, installing..."
        python3 -m pip install --user pipx
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    if command -v pipx &> /dev/null; then
        echo "✅ pipx available: $(pipx --version)"
    else
        echo "❌ pipx still not available after installation"
    fi
    
    echo "=== Startup script completed ==="
  EOT

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

# See https://registry.coder.com/modules/coder/code-server
module "code-server" {
  count  = data.coder_workspace.me.start_count
  source = "registry.coder.com/modules/code-server/coder"

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

  agent_id = coder_agent.dev[0].id
  order    = 1
}


module "kiro" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/kiro/coder"
  version  = "1.0.0"
  agent_id = coder_agent.dev[0].id
  folder   = "/home/ubuntu"
}

module "jupyter-notebook" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/jupyter-notebook/coder"
  version  = "1.2.0"
  agent_id = coder_agent.dev[0].id
}

locals {
  hostname = lower(data.coder_workspace.me.name)
  # Use ubuntu user for GPU instances (Deep Learning AMI), coder for others
  linux_user = local.is_gpu_instance ? "ubuntu" : "coder"
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
      linux_user      = local.linux_user
      is_gpu_instance = local.is_gpu_instance
      needs_nvme_raid = local.needs_nvme_raid
      init_script     = try(coder_agent.dev[0].init_script, "")
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
  instance_type          = data.coder_parameter.instance_type.value
  vpc_security_group_ids = [aws_security_group.coder_workspace.id]
  iam_instance_profile   = aws_iam_instance_profile.coder_instance_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = data.coder_parameter.disk_size.value
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
    value = data.coder_parameter.region.value
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
      value = "RAID0 configured (available at ~/nvme-storage)"
    }
  }
}

resource "aws_ec2_instance_state" "dev" {
  instance_id = aws_instance.dev.id
  state       = data.coder_workspace.me.transition == "start" ? "running" : "stopped"
}
