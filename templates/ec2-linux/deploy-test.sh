#!/bin/bash

echo "=== Coder Template Deployment Test ==="
echo "This script helps test the template deployment process"
echo

# Check if we're in the right directory
if [[ ! -f "main.tf" ]]; then
    echo "❌ main.tf not found. Please run this script from the template directory."
    exit 1
fi

echo "✅ Found main.tf in current directory"

# Validate Terraform syntax
echo "=== Validating Terraform Syntax ==="
if terraform validate; then
    echo "✅ Terraform syntax is valid"
else
    echo "❌ Terraform validation failed"
    exit 1
fi

# Validate shell script syntax
echo "=== Validating Shell Script Syntax ==="
if bash -n cloud-init/userdata.sh.tftpl; then
    echo "✅ Userdata script syntax is valid"
else
    echo "❌ Userdata script syntax errors found"
    exit 1
fi

# Check for common template issues
echo "=== Checking Template Configuration ==="

# Check connection timeout
if grep -q "connection_timeout.*900" main.tf; then
    echo "✅ Connection timeout set to 900 seconds"
else
    echo "⚠️  Connection timeout not found or not set to 900 seconds"
fi

# Check IAM instance profile
if grep -q "iam_instance_profile" main.tf; then
    echo "✅ IAM instance profile configured"
else
    echo "⚠️  IAM instance profile not found"
fi

# Check P5.4xlarge workaround
if grep -q "FI_HMEM_DISABLE_P2P" cloud-init/userdata.sh.tftpl; then
    echo "✅ P5.4xlarge workaround present"
else
    echo "⚠️  P5.4xlarge workaround not found"
fi

# Check pipx installation
if grep -q "pipx" cloud-init/userdata.sh.tftpl; then
    echo "✅ Pipx installation configured"
else
    echo "⚠️  Pipx installation not found"
fi

echo
echo "=== Template Validation Complete ==="
echo "The template is ready for deployment."
echo
echo "Next steps:"
echo "1. Push template to Coder: coder templates push"
echo "2. Create workspace with P5.4xlarge instance type"
echo "3. Monitor connection in Coder dashboard"
echo "4. If issues occur, use SSM Session Manager to access instance"
echo "5. Run debug script: ./debug-coder-agent.sh"