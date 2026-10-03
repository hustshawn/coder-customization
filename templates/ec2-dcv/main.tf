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
    random = {
      source = "hashicorp/random"
    }
  }
}

# Last updated 2025-09-11
# aws ec2 describe-regions | jq -r '[.Regions[].RegionName] | sort'
data "coder_parameter" "region" {
  name         = "region"
  display_name = "Region"
  description  = "The region to deploy the workspace in."
  default      = "ap-east-1"
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


# x86_64 only: Google Chrome has no Linux arm64 build.
data "coder_parameter" "instance_type" {
  name         = "instance_type"
  display_name = "Instance type"
  description  = "What instance type should your workspace use? A GNOME desktop + Chrome needs at least 4 vCPU / 16 GiB to feel smooth."
  default      = "m7i.xlarge"
  mutable      = false
  option {
    name  = "t3.xlarge (4 vCPU, 16 GiB RAM)"
    value = "t3.xlarge"
  }
  option {
    name  = "m7i.xlarge (4 vCPU, 16 GiB RAM)"
    value = "m7i.xlarge"
  }
  option {
    name  = "m7i.2xlarge (8 vCPU, 32 GiB RAM)"
    value = "m7i.2xlarge"
  }
  option {
    name  = "c7i.2xlarge (8 vCPU, 16 GiB RAM)"
    value = "c7i.2xlarge"
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
  description  = "Enter any valid x86_64 EC2 instance type (e.g., m7i.4xlarge). ARM64 (Graviton) is not supported."
  type         = "string"
  mutable      = false
  order        = 6
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size"
  description  = "How much disk space should your workspace have?"
  default      = "50"
  mutable      = false
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

  is_spot_instance = data.coder_parameter.spot_instance.value == "true"
  hostname         = lower(data.coder_workspace.me.name)
  linux_user       = "coder"
  dcv_port         = 8443
  cdp_port         = 9222

  # Claude Code and Codex both call Bedrock here, independent of the workspace region.
  bedrock_region = "us-east-1"
  codex_model    = "global.openai.gpt-6-sol"
}

provider "aws" {
  region = local.effective_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# DCV login for the linux user. Kept in workspace state, so it survives stop/start.
# Passed to the DCV web client in the app URL, so clicking the app logs straight in.
resource "random_password" "dcv" {
  length  = 24
  special = false
}

resource "coder_agent" "dev" {
  count               = data.coder_workspace.me.start_count
  arch                = "amd64"
  auth                = "aws-instance-identity"
  os                  = "linux"
  connection_timeout  = 120
  troubleshooting_url = "https://coder.com/docs/coder-oss/latest/templates/troubleshooting"

  env = {
    CLAUDE_CODE_USE_BEDROCK = "1"
    AWS_REGION              = local.bedrock_region
  }

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
    key          = "chrome"
    display_name = "Chrome CDP"
    interval     = 30
    timeout      = 5
    script       = "curl -sf -m 3 http://127.0.0.1:${local.cdp_port}/json/version >/dev/null && echo up || echo down"
  }
}

# Desktop + DCV + Chrome. Idempotent: the heavy install runs once, the rest is re-applied on every start.
resource "coder_script" "desktop" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.dev[0].id
  display_name       = "DCV Desktop"
  icon               = "/icon/dcv.svg"
  run_on_start       = true
  start_blocks_login = false
  timeout            = 1800
  script = templatefile("${path.module}/scripts/desktop.sh.tftpl", {
    linux_user   = local.linux_user
    dcv_password = random_password.dcv.result
    cdp_port     = local.cdp_port
  })
}

resource "coder_script" "claude_code" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.dev[0].id
  display_name       = "Claude Code"
  icon               = "/icon/claude.svg"
  run_on_start       = true
  start_blocks_login = false
  timeout            = 2400
  script = templatefile("${path.module}/scripts/claude-code.sh.tftpl", {
    cdp_port = local.cdp_port
  })
}

resource "coder_script" "codex" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.dev[0].id
  display_name       = "Codex CLI"
  icon               = "/icon/openai.svg"
  run_on_start       = true
  start_blocks_login = false
  timeout            = 2700
  script = templatefile("${path.module}/scripts/codex.sh.tftpl", {
    codex_model    = local.codex_model
    bedrock_region = local.bedrock_region
    cdp_port       = local.cdp_port
  })
}

# Ships the Mac installer inside the workspace; the command to run it is shown on the workspace page.
resource "coder_script" "mac_setup" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.dev[0].id
  display_name       = "Mac setup script"
  icon               = "/icon/apple-black.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/bin/bash
    set -e
    mkdir -p "$HOME/.local/share/coder-dcv"
    echo "${base64encode(file("${path.module}/scripts/mac-setup.sh"))}" | base64 -d > "$HOME/.local/share/coder-dcv/mac-setup.sh"
  EOT
}

resource "coder_app" "dcv" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.dev[0].id
  slug         = "dcv"
  display_name = "Desktop (DCV)"
  url          = "https://localhost:${local.dcv_port}/?username=${local.linux_user}&password=${random_password.dcv.result}"
  icon         = "/icon/dcv.svg"
  subdomain    = true
  share        = "owner"
  order        = 1
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

# Minimal role: this box holds a browser full of logged-in sessions, so it gets no AWS admin.
resource "aws_iam_role" "coder_instance_role" {
  name_prefix = "coder-dcv-role-"

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

resource "aws_iam_role_policy" "dcv_and_bedrock" {
  name = "dcv-license-and-bedrock"
  role = aws_iam_role.coder_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-license.html
        Sid      = "DcvLicense"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::dcv-license.${local.effective_region}/*"
      },
      {
        Sid    = "ClaudeCodeBedrock"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListInferenceProfiles",
          "bedrock:GetInferenceProfile",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "coder_instance_profile" {
  name_prefix = "coder-dcv-profile-"
  role        = aws_iam_role.coder_instance_role.name
}

# No ingress: DCV and CDP are only reached through the Coder agent tunnel.
resource "aws_security_group" "coder_workspace" {
  name_prefix = "coder-dcv-"
  description = "Coder DCV workspace (egress only)"

  # Allow outbound internet access (required for Coder agent)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "coder-dcv-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  }
}

resource "aws_instance" "dev" {
  ami                    = data.aws_ami.ubuntu.id
  availability_zone      = local.effective_az
  instance_type          = local.effective_instance_type
  vpc_security_group_ids = [aws_security_group.coder_workspace.id]
  iam_instance_profile   = aws_iam_instance_profile.coder_instance_profile.name

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

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2 only
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = tonumber(data.coder_parameter.disk_size.value)
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
  item {
    key   = "instance type"
    value = aws_instance.dev.instance_type
  }
  item {
    key   = "disk"
    value = "${aws_instance.dev.root_block_device[0].volume_size} GiB"
  }
  item {
    key   = "mac setup (run once on your Mac)"
    value = "coder ssh ${data.coder_workspace_owner.me.name}/${data.coder_workspace.me.name} -- cat /home/${local.linux_user}/.local/share/coder-dcv/mac-setup.sh | tr -d '\\r' | bash"
  }
  item {
    key   = "mac endpoints"
    value = "DCV https://localhost:18443 · Chrome CDP http://localhost:19222"
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
