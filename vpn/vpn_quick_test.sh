#!/bin/bash

# Quick VPN Test Script - Simple wrapper for common operations

print_info() {
    echo "ℹ️  $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

# Check if .env.vpn exists
if [ ! -f ".env.vpn" ]; then
    print_error "VPN environment file not found!"
    print_info "Run the following commands first:"
    echo "  ./setup_vpn_env.sh    # Set up credentials securely"
    echo "  ./vpn_manager.sh      # Full VPN management"
    exit 1
fi

# Quick status check
echo "🔐 Quick VPN Status Check"
echo "========================="

# Current IP
current_ip=$(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
echo "Current IP: $current_ip"

# VPN process check
if pgrep -f "openvpn.*pia" > /dev/null; then
    print_success "VPN process is running"
else
    print_info "No VPN process detected"
fi

echo ""
echo "Available commands:"
echo "  ./vpn_manager.sh status      # Detailed network status"
echo "  ./vpn_manager.sh connect     # Connect to VPN"
echo "  ./vpn_manager.sh disconnect  # Disconnect VPN"
echo "  ./vpn_manager.sh test        # Test VPN connection"
echo "  ./vpn_manager.sh             # Interactive mode"
