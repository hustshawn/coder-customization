cho "Setting up NVMe RAID0 configuration..."
    
    # Wait for system to be ready
    sleep 10
    
    # Install mdadm if not present
    if ! command -v mdadm &> /dev/null; then
        echo "Installing mdadm..."
        if command -v yum &> /dev/null; then
            yum update -y || echo "Warning: yum update failed, continuing..."
            yum install -y mdadm || { echo "Error: Failed to install mdadm"; return 1; }
        elif command -v apt-get &> /dev/null; then
            apt-get update || echo "Warning: apt-get update failed, continuing..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y mdadm || { echo "Error: Failed to install mdadm"; return 1; }
        else
            echo "Error: Neither yum nor apt-get found"
            return 1
        fi
    fi
    
    # Wait for devices to be available
    sleep 5
    
    # Find NVMe drives (excluding root device)
    echo "Detecting NVMe drives..."
    ROOT_DEVICE=""
    if ROOT_SOURCE=$(findmnt -n -o SOURCE / 2>/dev/null); then
        ROOT_DEVICE=$(lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null || echo "")
    fi
    
    # Get all NVMe drives
    ALL_NVME=$(lsblk -dpno NAME 2>/dev/null | grep nvme || echo "")
    
    if [ -z "$ALL_NVME" ]; then
        echo "No NVMe drives found at all"
        return 0
    fi
    
    # Filter out root device if found
    NVME_DRIVES=""
    if [ -n "$ROOT_DEVICE" ]; then
        NVME_DRIVES=$(echo "$ALL_NVME" | grep -v "$ROOT_DEVICE" | head -4 || echo "")
    else
        # If we can't determine root device, skip the first NVMe drive as safety measure
        NVME_DRIVES=$(echo "$ALL_NVME" | tail -n +2 | head -4 || echo "")
    fi
    
    if [ -z "$NVME_DRIVES" ]; then
        echo "No additional NVMe drives found for RAID setup (root device: $ROOT_DEVICE)"
        return 0
    fi
    
    DRIVE_COUNT=$(echo "$NVME_DRIVES" | wc -l)
    echo "Found $DRIVE_COUNT NVMe drives for RAID0:"
    echo "$NVME_DRIVES"
    
    # Ensure user home directory exists
    if [ ! -d "/home/ubuntu" ]; then
        echo "Creating user home directory..."
        mkdir -p "/home/ubuntu"
        chown "ubuntu:ubuntu" "/home/ubuntu"
    fi
    
    # Only proceed if we have multiple drives
    if [ "$DRIVE_COUNT" -gt 1 ]; then
        echo "Creating RAID0 array with $DRIVE_COUNT drives..."
        
        # Create RAID0 array with force flag to avoid prompts
        if mdadm --create --verbose /dev/md0 --level=0 --raid-devices="$DRIVE_COUNT" --force $NVME_DRIVES; then
            echo "RAID array created successfully"
            
            # Wait for array to be ready
            sleep 10
            
            # Create filesystem
            echo "Creating ext4 filesystem on RAID array..."
            if mkfs.ext4 -F /dev/md0; then
                echo "Filesystem created successfully"
                
                # Create mount point
                mkdir -p /mnt/nvme-raid
                
                # Mount the array
                if mount /dev/md0 /mnt/nvme-raid; then
                    echo "RAID array mounted successfully"
                    
                    # Add to fstab for persistence
                    echo "/dev/md0 /mnt/nvme-raid ext4 defaults,nofail 0 2" >> /etc/fstab
                    
                    # Set permissions
                    chown "ubuntu:ubuntu" /mnt/nvme-raid
                    chmod 755 /mnt/nvme-raid
                    
                    # Create a symlink in user's home directory
                    sudo -u "ubuntu" ln -sf /mnt/nvme-raid "/home/ubuntu/nvme-storage" || echo "Warning: Failed to create symlink"
                    
                    echo "RAID0 setup complete. Available at /mnt/nvme-raid and ~/nvme-storage"
                    
                    # Save RAID configuration
                    mkdir -p /etc/mdadm
                    mdadm --detail --scan >> /etc/mdadm/mdadm.conf 2>/dev/null || mdadm --detail --scan >> /etc/mdadm.conf 2>/dev/null || echo "Warning: Could not save RAID config"
                else
                    echo "Error: Failed to mount RAID array"
                fi
            else
                echo "Error: Failed to create filesystem on RAID array"
            fi
        else
            echo "Error: Failed to create RAID array"
        fi
        
    else
        echo "Only one NVMe drive found, mounting directly without RAID"
        SINGLE_DRIVE=$(echo "$NVME_DRIVES" | head -1)
        
        # Create filesystem on single drive
        if mkfs.ext4 -F "$SINGLE_DRIVE"; then
            echo "Filesystem created on single drive"
            
            # Create mount point and mount
            mkdir -p /mnt/nvme-storage
            if mount "$SINGLE_DRIVE" /mnt/nvme-storage; then
                echo "Single drive mounted successfully"
                
                # Add to fstab
                echo "$SINGLE_DRIVE /mnt/nvme-storage ext4 defaults,nofail 0 2" >> /etc/fstab
                
                # Set permissions
                chown "ubuntu:ubuntu" /mnt/nvme-storage
                chmod 755 /mnt/nvme-storage
                
                # Create symlink
                sudo -u "ubuntu" ln -sf /mnt/nvme-storage "/home/ubuntu/nvme-storage" || echo "Warning: Failed to create symlink"
                
                echo "Single NVMe drive mounted at /mnt/nvme-storage and ~/nvme-storage"
            else
                echo "Error: Failed to mount single drive"
            fi
        else
            echo "Error: Failed to create filesystem on single drive"
        fi
    fi
}

# Run RAID setup with error handling
if ! setup_nvme_raid; then
    echo "Warning: RAID setup failed, but continuing with instance setup..."
fi


# Get instance type with retries
INSTANCE_TYPE="unknown"
for i in {1..10}; do
    INSTANCE_TYPE=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
    if [[ "$INSTANCE_TYPE" != "unknown" ]]; then
        break
    fi
    echo "Retrying metadata service (attempt $i/10)..."
    sleep 5
done
echo "Instance Type: $INSTANCE_TYPE"

# P5.4xlarge specific handling
if [[ "$INSTANCE_TYPE" == "p5.4xlarge" ]]; then
    echo "Applying P5.4xlarge workaround..."
    echo "export FI_HMEM_DISABLE_P2P=1" >> /etc/environment
    export FI_HMEM_DISABLE_P2P=1
fi

# Setup user
if ! id "ubuntu" &>/dev/null; then
    useradd -m -s /bin/bash "ubuntu"
    usermod -aG sudo "ubuntu"
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

chown "ubuntu:ubuntu" "/home/ubuntu"

# Install pip and pipx with better error handling
echo "Installing pip and pipx..."
apt-get update || yum update -y || true
apt-get install -y python3-pip || yum install -y python3-pip || true

sudo -u "ubuntu" bash -c '
    # Try different ways to install pipx
    if python3 -m pip install --user pipx; then
        echo "pipx installed via pip"
    elif python3 -m ensurepip --user && python3 -m pip install --user pipx; then
        echo "pipx installed after ensurepip"
    else
        echo "Failed to install pipx"
        exit 1
    fi
    
    export PATH="$HOME/.local/bin:$PATH"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.profile
'

# Create global pipx link
if [ -f "/home/ubuntu/.local/bin/pipx" ]; then
    ln -sf "/home/ubuntu/.local/bin/pipx" "/usr/local/bin/pipx"
    echo "pipx linked globally"
fi

# Run Coder agent init
echo "=== Starting Coder Agent Init $(date) ==="
if [ -n "test_init_script" ]; then
    # Set P5.4xlarge environment for init script
    if [[ "$INSTANCE_TYPE" == "p5.4xlarge" ]]; then
        export FI_HMEM_DISABLE_P2P=1
        echo "Set FI_HMEM_DISABLE_P2P=1 for P5.4xlarge"
    fi
    
    echo "Running init script as user ubuntu..."
    # Create a temporary script file to avoid shell interpolation issues
    cat > /tmp/coder_init.sh << 'INIT_EOF'
export PATH="$HOME/.local/bin:$PATH"
cd ~
INIT_EOF
    
    # Append the init script content safely
    cat >> /tmp/coder_init.sh << 'SCRIPT_CONTENT'
echo "Test init script content"
SCRIPT_CONTENT
    
    # Set P5.4xlarge environment in the script
    if [[ "$INSTANCE_TYPE" == "p5.4xlarge" ]]; then
        sed -i '1a export FI_HMEM_DISABLE_P2P=1' /tmp/coder_init.sh
        sed -i '2a echo "export FI_HMEM_DISABLE_P2P=1" >> ~/.bashrc' /tmp/coder_init.sh
    fi
    
    chmod +x /tmp/coder_init.sh
    sudo -u "ubuntu" /tmp/coder_init.sh || {
        echo "❌ Init script failed with exit code $?"
        echo "Init script content:"
        cat /tmp/coder_init.sh
        exit 1
    }
    rm -f /tmp/coder_init.sh
else
    echo "⚠️  No init script provided"
fi

echo "=== User Data Script Completed $(date) ==="
EOF

echo "Checking shell syntax..."
if bash -n /tmp/test_userdata.sh; then
    echo "✅ Shell syntax is valid"
else
    echo "❌ Shell syntax errors found"
    exit 1
fi

echo "Checking for common issues..."
if grep -n "INIT_EOF" /tmp/test_userdata.sh; then
    echo "⚠️  Found INIT_EOF markers in script"
fi

if grep -n "SCRIPT_CONTENT" /tmp/test_userdata.sh; then
    echo "⚠️  Found SCRIPT_CONTENT markers in script"
fi

echo "Template validation complete"
rm -f /tmp/test_userdata.sh