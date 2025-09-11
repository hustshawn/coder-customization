# P5.4xlarge Coder Agent Connection Fixes

## Issues Addressed

### 1. Shell Syntax Error (Line 73)
**Problem**: Template interpolation in heredoc causing shell syntax errors
**Solution**: Split heredoc creation to avoid interpolation conflicts
- Separated init script content into multiple heredoc blocks
- Added proper error handling and logging

### 2. P5.4xlarge Specific Workaround
**Problem**: P5.4xlarge instances require FI_HMEM_DISABLE_P2P=1 environment variable
**Solution**: Automatic detection and application of workaround
- Instance type detection with retry logic
- Environment variable set in multiple locations (system, user, init script)
- Persistent configuration in ~/.bashrc

### 3. User Configuration Mismatch
**Problem**: Deep Learning AMI uses "ubuntu" user, not "coder"
**Solution**: Template uses configurable linux_user variable
- Proper user creation and sudo permissions
- Correct home directory ownership

### 4. Pip/Pipx Installation Issues
**Problem**: Missing pip module and pipx installation failures
**Solution**: Enhanced installation with fallbacks
- Multiple pip installation methods (pip, ensurepip)
- Retry logic for package installations
- Global pipx linking for system access

### 5. Connection Timeout Issues
**Problem**: Default timeouts too short for P5 instances
**Solution**: Extended timeouts
- Connection timeout: 900 seconds (15 minutes)
- Init script timeout: 1800 seconds (30 minutes)

### 6. Debugging and Troubleshooting
**Problem**: Limited visibility into connection failures
**Solution**: Comprehensive logging and debug tools
- Enhanced userdata logging
- Debug script for system analysis
- Connection test script
- IAM instance profile for SSM access

## Files Modified

1. **templates/ec2-linux/cloud-init/userdata.sh.tftpl**
   - Fixed shell syntax errors
   - Added P5.4xlarge workaround
   - Enhanced error handling and logging
   - Improved pip/pipx installation

2. **templates/ec2-linux/main.tf**
   - Extended connection timeout to 900 seconds
   - Added IAM instance profile for SSM access
   - Maintained existing configuration

3. **templates/ec2-linux/debug-coder-agent.sh** (New)
   - Comprehensive system diagnostics
   - Environment validation
   - Network connectivity tests

4. **templates/ec2-linux/test-coder-connection.sh** (New)
   - End-to-end connection testing
   - Environment setup validation
   - Pipx functionality testing

## Testing

Run the following scripts to validate the fixes:

```bash
# Test shell syntax
bash -n templates/ec2-linux/cloud-init/userdata.sh.tftpl

# Test connection setup (run on instance)
./templates/ec2-linux/test-coder-connection.sh

# Debug system issues (run on instance)
./templates/ec2-linux/debug-coder-agent.sh
```

## Key Environment Variables

For P5.4xlarge instances:
- `FI_HMEM_DISABLE_P2P=1` - Required workaround for networking issues
- `PATH="$HOME/.local/bin:$PATH"` - Ensures pipx is accessible

## Expected Behavior

1. Instance launches with proper user configuration
2. P5.4xlarge workaround applied automatically if needed
3. Pip and pipx installed successfully with fallbacks
4. Init script runs with comprehensive logging
5. Connection established within 15-minute timeout
6. SSM access available for troubleshooting if needed

## Troubleshooting

If connection still fails:
1. Check `/var/log/user-data.log` for userdata execution
2. Run debug script: `./debug-coder-agent.sh`
3. Use SSM Session Manager for instance access
4. Verify init script content in logs
5. Check network connectivity and security groups