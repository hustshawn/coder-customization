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

data "coder_parameter" "resource_size" {
  name         = "resource_size"
  display_name = "Resource Size"
  description  = "CPU and memory resources for your workspace"
  default      = "medium"
  mutable      = false
  option {
    name  = "Small (2 vCPU, 4 GB)"
    value = "small"
  }
  option {
    name  = "Medium (4 vCPU, 8 GB)"
    value = "medium"
  }
  option {
    name  = "Large (8 vCPU, 16 GB)"
    value = "large"
  }
  option {
    name  = "XLarge (16 vCPU, 32 GB)"
    value = "xlarge"
  }
  option {
    name  = "Memory Optimized (8 vCPU, 64 GB)"
    value = "memory"
  }
}

data "coder_parameter" "storage_size" {
  name         = "storage_size"
  display_name = "Storage Size"
  description  = "Persistent storage size for your workspace"
  default      = "50"
  mutable      = true
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

  # Map resource size to pod resources
  size_resources = {
    "small"  = { cpu = "2", memory = "4Gi" }
    "medium" = { cpu = "4", memory = "8Gi" }
    "large"  = { cpu = "8", memory = "16Gi" }
    "xlarge" = { cpu = "16", memory = "32Gi" }
    "memory" = { cpu = "8", memory = "64Gi" }
  }
  resources = local.size_resources[data.coder_parameter.resource_size.value]
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
resource "coder_agent" "k8s-dev" {
  os   = "linux"
  arch = "amd64"
}

resource "coder_script" "code_server" {
  agent_id           = coder_agent.k8s-dev.id
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
  agent_id           = coder_agent.k8s-dev.id
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

resource "coder_script" "nodejs" {
  agent_id           = coder_agent.k8s-dev.id
  display_name       = "Node.js"
  icon               = "/icon/nodejs.svg"
  run_on_start       = true
  start_blocks_login = false
  timeout            = 300
  script             = <<-EOT
    #!/bin/bash
    set -e

    # Install Node.js v24 using fnm (Fast Node Manager)
    if ! command -v fnm &>/dev/null; then
      echo "Installing fnm..."
      curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
      echo "✅ fnm installed!"
    else
      echo "fnm already installed"
    fi

    # Add fnm to PATH for this session
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"

    # Ensure fnm is set in shell profiles (create if needed)
    for profile in ~/.bashrc ~/.zshrc ~/.profile; do
      touch "$profile"
      if ! grep -q 'fnm env' "$profile" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/share/fnm:$PATH"' >> "$profile"
        echo 'eval "$(fnm env)"' >> "$profile"
      fi
    done

    # Install Node.js v24
    if ! fnm list 2>/dev/null | grep -q "v24"; then
      echo "Installing Node.js v24..."
      fnm install 24
      echo "✅ Node.js v24 installed!"
    else
      echo "Node.js v24 already installed"
    fi

    # Set Node.js v24 as default
    fnm default 24
    fnm use 24

    echo "Node.js environment ready!"
    node --version
    npm --version
  EOT
}

# Adds the "VS Code Web" icon to the dashboard
# and proxies code-server running on the workspace
resource "coder_app" "code-server" {
  agent_id     = coder_agent.k8s-dev.id
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

    # Force amd64 nodes since the image doesn't support ARM
    node_selector = {
      "kubernetes.io/arch" = "amd64"
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
      command = ["sh", "-c", coder_agent.k8s-dev.init_script]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.k8s-dev.token
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
    key   = "size"
    value = data.coder_parameter.resource_size.value
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
