# Coder Templates Collection

Production-ready [Coder](https://coder.com/) workspace templates for cloud development environments.

## Overview

This repository contains Coder templates that help you quickly provision development workspaces in the cloud. Each template is designed to be a starting point that you can customize for your specific needs.

## Available Templates

| Template                                   | Description                               |
|--------------------------------------------|-------------------------------------------|
| [ec2-linux](templates/ec2-linux/)          | AWS EC2 Linux workspaces with GPU support |
| [kubernetes-ns](templates/kubernetes-ns/)  | Kubernetes namespace-based workspaces     |

## Repository Structure

```text
templates/
├── ec2-linux/
│   ├── README.md           # Template documentation
│   ├── main.tf             # Terraform configuration
│   └── cloud-init/         # Cloud-init scripts
└── kubernetes-ns/
    ├── README.md
    └── main.tf
```

## Quick Start

1. Install the [Coder CLI](https://coder.com/docs/install)
2. Push a template to your Coder deployment:

```bash
./push-templates.sh ec2-linux
```

Or manually:

```bash
coder templates push <template-name> --directory templates/<template-name>
```

See individual template READMEs for detailed configuration options and prerequisites.

## Contributing

1. Fork this repository
2. Create a new directory under `templates/`
3. Follow the existing template structure
4. Include a comprehensive README
5. Submit a pull request
