terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Explicit in-cluster configuration for Coder provisioner
provider "kubernetes" {
  host                   = "https://kubernetes.default.svc"
  cluster_ca_certificate = file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
  token                  = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "node_instance_type" {
  name         = "node_instance_type"
  display_name = "Node Instance Type"
  description  = "EC2 instance type for the Kubernetes node"
  default      = "c7i.xlarge"
  mutable      = false
  option {
    name  = "c7i.xlarge (4 vCPU, 8 GB) - Intel"
    value = "c7i.xlarge"
  }
  option {
    name  = "c7i.2xlarge (8 vCPU, 16 GB) - Intel"
    value = "c7i.2xlarge"
  }
  option {
    name  = "c7i.4xlarge (16 vCPU, 32 GB) - Intel"
    value = "c7i.4xlarge"
  }
  option {
    name  = "c8g.xlarge (4 vCPU, 8 GB) - Graviton4"
    value = "c8g.xlarge"
  }
  option {
    name  = "c8g.2xlarge (8 vCPU, 16 GB) - Graviton4"
    value = "c8g.2xlarge"
  }
  option {
    name  = "c8g.4xlarge (16 vCPU, 32 GB) - Graviton4"
    value = "c8g.4xlarge"
  }
  option {
    name  = "m7i.xlarge (4 vCPU, 16 GB) - Intel"
    value = "m7i.xlarge"
  }
  option {
    name  = "m7i.2xlarge (8 vCPU, 32 GB) - Intel"
    value = "m7i.2xlarge"
  }
  option {
    name  = "r7i.xlarge (4 vCPU, 32 GB) - Intel Memory"
    value = "r7i.xlarge"
  }
  option {
    name  = "r7i.2xlarge (8 vCPU, 64 GB) - Intel Memory"
    value = "r7i.2xlarge"
  }
}

data "coder_parameter" "storage_size" {
  name         = "storage_size"
  display_name = "Storage Size"
  description  = "Persistent storage size for your workspace"
  default      = "20"
  mutable      = true
  option {
    name  = "10 GB"
    value = "10"
  }
  option {
    name  = "20 GB"
    value = "20"
  }
  option {
    name  = "50 GB"
    value = "50"
  }
  option {
    name  = "100 GB"
    value = "100"
  }
  option {
    name  = "200 GB"
    value = "200"
  }
  option {
    name  = "500 GB"
    value = "500"
  }
}

# Used for all resources created by this template
locals {
  name = "coder-ws-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  labels = {
    "app.kubernetes.io/managed-by" = "coder"
  }

  # Map node instance type to pod resources (leaving ~0.5 CPU and ~0.5Gi for system)
  instance_resources = {
    "c7i.xlarge"   = { cpu = "3500m", memory = "7Gi" }
    "c7i.2xlarge"  = { cpu = "7500m", memory = "15Gi" }
    "c7i.4xlarge"  = { cpu = "15500m", memory = "31Gi" }
    "c8g.xlarge"   = { cpu = "3500m", memory = "7Gi" }
    "c8g.2xlarge"  = { cpu = "7500m", memory = "15Gi" }
    "c8g.4xlarge"  = { cpu = "15500m", memory = "31Gi" }
    "m7i.xlarge"   = { cpu = "3500m", memory = "15Gi" }
    "m7i.2xlarge"  = { cpu = "7500m", memory = "31Gi" }
    "r7i.xlarge"   = { cpu = "3500m", memory = "31Gi" }
    "r7i.2xlarge"  = { cpu = "7500m", memory = "63Gi" }
  }
  resources = local.instance_resources[data.coder_parameter.node_instance_type.value]

  # Detect architecture based on instance type (c8g, m8g, r8g are ARM/Graviton)
  is_arm64 = can(regex("^[a-z][0-9]g\\.", data.coder_parameter.node_instance_type.value))
  arch     = local.is_arm64 ? "arm64" : "amd64"
}

resource "kubernetes_namespace" "workspace" {
  metadata {
    name   = local.name
    labels = local.labels
  }
}

resource "coder_metadata" "namespace-info" {
  resource_id = kubernetes_namespace.workspace.id
  icon        = "https://svgur.com/i/qsx.svg"
  item {
    key   = "name in cluster"
    value = local.name
  }
}

# ServiceAccount for the workspace
resource "kubernetes_service_account" "workspace_service_account" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
}

# Gives the ServiceAccount admin access to the
# namespace created for this workspace
resource "kubernetes_role_binding" "set_workspace_permissions" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.workspace_service_account.metadata[0].name
    namespace = kubernetes_namespace.workspace.metadata[0].name
  }
}

# The Coder agent allows the workspace owner
# to connect to the pod from a web or local IDE
resource "coder_agent" "primary" {
  os   = "linux"
  arch = local.arch
}

resource "coder_script" "code_server" {
  agent_id           = coder_agent.primary.id
  display_name       = "Code Server"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = false
  timeout            = 180
  script             = <<-EOT
    #!/bin/bash
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.8.3
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT
}

resource "coder_script" "python_uv" {
  agent_id           = coder_agent.primary.id
  display_name       = "Python (UV)"
  icon               = "/icon/python.svg"
  run_on_start       = true
  start_blocks_login = false
  timeout            = 300
  script             = <<-EOT
    #!/bin/bash
    set -e

    # Install UV if not already installed
    if ! command -v uv &>/dev/null; then
      echo "Installing UV..."
      curl -LsSf https://astral.sh/uv/install.sh | sh
      echo "✅ UV installed successfully!"
    else
      echo "UV already installed"
    fi

    # Add UV to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"

    # Ensure PATH is set in shell profiles (create if needed)
    for profile in ~/.bashrc ~/.zshrc ~/.profile; do
      touch "$profile"
      if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$profile" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile"
      fi
    done

    # Install Python 3.13 using UV
    if ! uv python list --only-installed 2>/dev/null | grep -q "3.13"; then
      echo "Installing Python 3.13..."
      uv python install 3.13
      echo "✅ Python 3.13 installed!"
    else
      echo "Python 3.13 already installed"
    fi

    # Set Python 3.13 as global default
    echo "Setting Python 3.13 as default..."

    # Create symlinks for python and python3 to use UV-managed Python 3.13
    ln -sf ~/.local/bin/python3.13 ~/.local/bin/python
    ln -sf ~/.local/bin/python3.13 ~/.local/bin/python3

    # Pin Python version globally
    echo "3.13" > ~/.python-version

    echo "Python environment ready!"
    uv --version
    python --version
  EOT
}

# Adds the "VS Code Web" icon to the dashboard
# and proxies code-server running on the workspace
resource "coder_app" "code-server" {
  agent_id     = coder_agent.primary.id
  display_name = "VS Code Web"
  slug         = "code-server"
  url          = "http://localhost:13337/"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

# Creates a pod on the workspace namepace, allowing
# the developer to connect.
resource "kubernetes_pod" "primary" {

  # Pod is ephemeral. Re-created when a workspace starts/stops.
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "primary"
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
  spec {
    service_account_name = kubernetes_service_account.workspace_service_account.metadata[0].name

    # Select node based on instance type
    node_selector = {
      "node.kubernetes.io/instance-type" = data.coder_parameter.node_instance_type.value
    }

    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }
    container {

      # Basic image with helm, kubectl, etc
      # extend to add your own tools!
      image = "bencdr/devops-tools"

      image_pull_policy = "Always"
      name              = "dev"

      # Resource requests and limits based on instance type
      resources {
        requests = {
          cpu    = local.resources.cpu
          memory = local.resources.memory
        }
        limits = {
          cpu    = local.resources.cpu
          memory = local.resources.memory
        }
      }

      # Starts the Coder agent
      command = ["sh", "-c", coder_agent.primary.init_script]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.primary.token
      }

      # Mounts /home/coder. Developers should keep
      # their files here!
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
    }
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }
  }
}

# Creates a persistent volume for developers
# to store their repos/files
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "primary-disk"
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.storage_size.value}Gi"
      }
    }
  }
}

# Metadata for resources

resource "coder_metadata" "primary_metadata" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_pod.primary[0].id
  icon        = "https://svgur.com/i/qrK.svg"
  item {
    key   = "node type"
    value = data.coder_parameter.node_instance_type.value
  }
  item {
    key   = "arch"
    value = local.arch
  }
  item {
    key   = "cpu"
    value = local.resources.cpu
  }
  item {
    key   = "memory"
    value = local.resources.memory
  }
}

resource "coder_metadata" "pvc_metadata" {
  resource_id = kubernetes_persistent_volume_claim.home.id
  icon        = "https://svgur.com/i/qt5.svg"
  item {
    key   = "size"
    value = "${data.coder_parameter.storage_size.value} GB"
  }
  item {
    key   = "mounted dir"
    value = "/home/coder"
  }
}

resource "coder_metadata" "service_account_metadata" {
  resource_id = kubernetes_service_account.workspace_service_account.id
  icon        = "https://svgur.com/i/qrv.svg"
  hide        = true
}


resource "coder_metadata" "role_binding_metadata" {
  resource_id = kubernetes_role_binding.set_workspace_permissions.id
  icon        = "https://svgur.com/i/qs7.svg"
  hide        = true
}
