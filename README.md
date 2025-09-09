# Coder Templates Collection

A curated collection of [Coder](https://coder.com/) workspace templates for various cloud platforms and development environments.

## Overview

This repository contains production-ready Coder templates that help you quickly provision development workspaces in the cloud. Each template is designed to be a starting point that you can customize for your specific needs.

## Available Templates

### 🖥️ AWS EC2 Linux Template

**Location:** `templates/ec2-linux/`

Provision AWS EC2 instances as persistent Coder workspaces with the following features:

- **Multi-region support** - Deploy in multiple AWS regions with country flag icons
- **Flexible instance types** - From t3.micro to GPU instances (g6e.12xlarge, p5.4xlarge)
- **Configurable storage** - 20GB to 1TB disk options
- **Smart AMI selection** - Automatically uses GPU-optimized AMIs for GPU instances
- **Pre-installed tools** - Code Server, Kiro IDE, and Jupyter Notebook
- **Persistent workspaces** - Full filesystem preservation across restarts

**Supported Regions:**
- Asia Pacific: Tokyo 🇯🇵, Jakarta 🇮🇩, Mumbai 🇮🇳, Singapore 🇸🇬, Sydney 🇦🇺
- Europe: Ireland 🇪🇺
- US: N. Virginia, Ohio, Oregon 🇺🇸

**Supported Instance Types:**
- General purpose: t3.micro to t3.2xlarge
- GPU instances: g6e.12xlarge (4xL40S), p5.4xlarge (1xH100)

## Quick Start

### Prerequisites

1. **Coder deployment** - You need a running Coder instance
2. **AWS credentials** - Configured via environment variables, credentials file, or IAM roles
3. **Required AWS permissions** - See individual template documentation

### Using a Template

1. Clone this repository or download the template you want to use
2. In your Coder dashboard, create a new template
3. Upload the template directory or point to this repository
4. Configure the template parameters according to your needs
5. Create workspaces from the template

### AWS Authentication

Templates use the AWS provider's default authentication methods:

- Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- AWS credentials file (`~/.aws/credentials`)
- IAM instance profiles (when running Coder on EC2)
- AWS SSO

## Template Structure

Each template follows this structure:

```
templates/
├── template-name/
│   ├── README.md              # Template-specific documentation
│   ├── main.tf                # Main Terraform configuration
│   └── cloud-init/            # Cloud-init scripts (if applicable)
│       ├── cloud-config.yaml.tftpl
│       └── userdata.sh.tftpl
```

## Contributing

We welcome contributions! To add a new template:

1. Fork this repository
2. Create a new directory under `templates/`
3. Follow the existing template structure
4. Include comprehensive documentation
5. Test your template thoroughly
6. Submit a pull request

### Template Guidelines

- Include a detailed README with prerequisites and usage instructions
- Use parameterized configurations for flexibility
- Follow Terraform best practices
- Include proper resource tagging
- Document required permissions/policies
- Test across different regions and instance types

## Security Best Practices

- All templates use encrypted storage by default
- Resources are properly tagged for identification
- IAM permissions follow the principle of least privilege
- Templates include security group configurations where applicable

## Support

- **Issues:** Report bugs or request features via GitHub Issues
- **Documentation:** Each template includes detailed setup instructions
- **Community:** Join the [Coder Discord](https://discord.gg/coder) for community support

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Coder](https://coder.com/) for the amazing platform
- [Official Coder templates](https://github.com/coder/coder/tree/main/examples/templates) for inspiration
- [Community templates](https://github.com/bpmct/coder-templates) for additional examples

---

**Note:** These templates are designed to be starting points. Customize them according to your organization's requirements and security policies.