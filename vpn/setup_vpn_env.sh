#!/bin/bash

# Script to securely set up VPN environment file
# This prompts for credentials instead of storing them in plain text

echo "🔐 Secure VPN Environment Setup"
echo "================================"

# Check if .env.vpn already exists
if [ -f ".env.vpn" ]; then
    echo "⚠️  .env.vpn already exists!"
    read -p "Do you want to overwrite it? (y/N): " overwrite
    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Prompt for credentials securely
echo "Enter your PIA credentials:"
read -p "Username: " username
read -s -p "Password: " password
echo

# Create .env.vpn file with proper permissions
cat > .env.vpn << EOF
# PIA VPN Configuration
# Generated on $(date)
# KEEP THIS FILE SECURE AND PRIVATE!

PIA_USERNAME=$username
PIA_PASSWORD=$password

# VPN Configuration
VPN_SERVER=us-east.privateinternetaccess.com
VPN_PORT=1198
VPN_PROTOCOL=udp
EOF

# Set secure permissions
chmod 600 .env.vpn

# Add to gitignore if not already there
if [ -f ".gitignore" ]; then
    if ! grep -q ".env.vpn" .gitignore; then
        echo ".env.vpn" >> .gitignore
        echo "✅ Added .env.vpn to .gitignore"
    fi
else
    echo ".env.vpn" > .gitignore
    echo "✅ Created .gitignore with .env.vpn"
fi

echo "✅ VPN environment file created securely"
echo "🔒 File permissions set to 600 (owner read/write only)"
echo "⚠️  Remember to change your password if it was previously exposed!"
