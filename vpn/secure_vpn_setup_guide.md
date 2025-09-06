# Secure VPN Setup Guide

## ⚠️ SECURITY WARNING
Never store VPN credentials in plain text files or scripts!

## Recommended Secure Approaches

### 1. Official PIA Client
```bash
# Download and install the official PIA client
# macOS: Download from https://www.privateinternetaccess.com/download/mac-vpn
# The official client handles authentication securely
```

### 2. OpenVPN Configuration (Secure Method)
```bash
# Use OpenVPN with PIA's configuration files
# Store credentials in a separate, protected file with restricted permissions

# Create secure credential file (do this manually, don't script it)
sudo touch /etc/openvpn/pia-credentials
sudo chmod 600 /etc/openvpn/pia-credentials
# Then manually edit this file to contain:
# username
# password
```

### 3. Environment Variables (Better than JSON)
```bash
# Set credentials as environment variables (still not ideal)
export PIA_USERNAME="your_username"
export PIA_PASSWORD="your_password"

# Use in scripts without exposing credentials
echo "Connecting with user: $PIA_USERNAME"
```

### 4. macOS Keychain (Most Secure)
```bash
# Store credentials in macOS Keychain
security add-internet-password -a "your_username" -s "privateinternetaccess.com" -w "your_password"

# Retrieve from keychain in scripts
PIA_PASSWORD=$(security find-internet-password -a "your_username" -s "privateinternetaccess.com" -w)
```

## Connection Testing Script (Without Stored Credentials)
```bash
#!/bin/bash
# vpn_test.sh - Test VPN connection status

check_vpn_status() {
    echo "Checking current IP and location..."
    
    # Get current IP
    CURRENT_IP=$(curl -s https://ipinfo.io/ip)
    echo "Current IP: $CURRENT_IP"
    
    # Get location info
    LOCATION_INFO=$(curl -s https://ipinfo.io/json)
    echo "Location Info: $LOCATION_INFO"
    
    # Check if VPN is active (basic check)
    if pgrep -f "openvpn\|pia" > /dev/null; then
        echo "✅ VPN process detected"
    else
        echo "❌ No VPN process detected"
    fi
}

check_vpn_status
```

## Security Recommendations

1. **Change Your Password**: Since credentials were exposed, change them immediately
2. **Use Official Clients**: Always prefer official VPN applications
3. **Enable 2FA**: If PIA supports it, enable two-factor authentication
4. **Monitor Usage**: Check your PIA account for unauthorized access

## Next Steps

1. Change your PIA password immediately
2. Download the official PIA client for your OS
3. Set up the VPN connection through the official app
4. Use the testing script above to verify connectivity

Remember: Security should always come before convenience!
