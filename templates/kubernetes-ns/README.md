---
display_name: Kubernetes (Namespace per Workspace)
description: Run each Coder workspace as a pod in its own namespace on EKS, with AWS access via Pod Identity
icon: ../../../site/static/icon/k8s.png
maintainer_github: coder
verified: false
tags: [container, kubernetes, aws, eks]
---

# Kubernetes workspaces, one namespace each

Each workspace gets its own namespace on the EKS cluster Coder runs on, with a ServiceAccount that is admin in that
namespace and an IAM role bound to it through [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html).

## What you get

- Image `bencdr/devops-tools` (kubectl, helm, ...), amd64 only
- Resource size Small to Memory Optimized (2–16 vCPU, 4–64 GB), requests = limits
- Persistent `/home/coder` on a `gp3` PVC (50–500 GB), kept across stop/start
- VS Code Web (code-server), AWS CLI v2, Python 3.13 via uv, Node.js 24 via fnm, Claude Code on Bedrock
  (`CLAUDE_CODE_USE_BEDROCK=1`; no model is pinned, set it in `~/.claude/settings.json`)
- `cc` = `claude --dangerously-skip-permissions`

## Prerequisites

- Coder runs inside the target EKS cluster; the provider uses the in-cluster ServiceAccount token
- The Coder ServiceAccount can create namespaces and RBAC: `kubectl apply -f coder-rbac.yaml` (cluster-admin)
- The provisioner has AWS credentials to create IAM roles and Pod Identity associations
- The EKS Pod Identity Agent add-on is installed
- Cluster name and region are set in `locals` (`cluster_name`, `cluster_region`); change them for another cluster

## Design notes

- **Deployment, not a bare Pod**: the workspace pod runs through `kubernetes_deployment_v1` (1 replica, `Recreate`
  because the home PVC is ReadWriteOnce). EKS Auto Mode expires nodes (every 14 days here), and a bare pod is not
  rescheduled when its node goes away, leaving the workspace "Started" with a disconnected agent. Stopping the
  workspace deletes the Deployment; the PVC stays
- **Pod Identity propagation**: credentials are injected at pod admission, so a 30s `time_sleep` after creating the
  association runs before the first pod is created
- **IAM**: the workspace role has `AdministratorAccess` (TODO: least privilege)
- Tool setup scripts write a marker under `~/.setup_done/` and skip on later starts
