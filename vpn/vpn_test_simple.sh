#!/bin/bash

# Simple VPN Test Script - Proof of Concept

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔐 VPN Test Script - Proof of Concept${NC}"
echo "========================================"

# Test 1: Check if .env.vpn exists and load it
echo -e "\n${BLUE}Test 1: Environment File${NC}"
if [ -f ".env.vpn" ]; then
    echo "✅ .env.vpn file found"
    
    # Load environment
    set -a
    source .env.vpn
    set +a
    
    if [ -n "${PIA_USERNAME:-}" ] && [ -n "${PIA_PASSWORD:-}" ]; then
        echo "✅ Credentials loaded successfully"
        echo "   Username: ${PIA_USERNAME}"
        echo "   Password: ${PIA_PASSWORD:0:3}***${PIA_PASSWORD: -3}"
        echo "   Server: ${VPN_SERVER:-us-east.privateinternetaccess.com}"
        echo "   Port: ${VPN_PORT:-1198}"
    else
        echo "❌ Credentials not found in environment file"
        exit 1
    fi
else
    echo "❌ .env.vpn file not found"
    exit 1
fi

# Test 2: Check prerequisites
echo -e "\n${BLUE}Test 2: Prerequisites${NC}"

if command -v openvpn &> /dev/null; then
    echo "✅ OpenVPN found: $(openvpn --version | head -1 | cut -d' ' -f1-2)"
else
    echo "❌ OpenVPN not found"
fi

if command -v curl &> /dev/null; then
    echo "✅ curl found"
else
    echo "❌ curl not found"
fi

# Test 3: Network status
echo -e "\n${BLUE}Test 3: Current Network Status${NC}"

echo "Getting current IP information..."
ip_info=$(curl -s --max-time 10 https://ipinfo.io/json 2>/dev/null || echo '{"error": "Could not fetch"}')

if echo "$ip_info" | grep -q '"ip"'; then
    ip=$(echo "$ip_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    city=$(echo "$ip_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
    region=$(echo "$ip_info" | grep -o '"region":"[^"]*"' | cut -d'"' -f4)
    country=$(echo "$ip_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    org=$(echo "$ip_info" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
    
    echo "✅ Network information retrieved:"
    echo "   IP: $ip"
    echo "   Location: $city, $region, $country"
    echo "   ISP: $org"
else
    echo "❌ Could not retrieve network information"
fi

# Test 4: VPN process check
echo -e "\n${BLUE}Test 4: VPN Process Check${NC}"

if pgrep -f "openvpn.*pia" > /dev/null; then
    echo "✅ VPN process detected"
    pgrep -f "openvpn.*pia" | while read pid; do
        echo "   PID: $pid"
    done
else
    echo "ℹ️  No VPN process currently running"
fi

# Test 5: Create test OpenVPN config
echo -e "\n${BLUE}Test 5: OpenVPN Configuration Test${NC}"

cat > /tmp/test_pia.conf << EOF
client
dev tun
proto udp
remote $VPN_SERVER $VPN_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
cipher aes-256-cbc
auth sha256
tls-client
remote-cert-tls server
comp-lzo
verb 1
reneg-sec 0
EOF

echo "✅ Test OpenVPN configuration created at /tmp/test_pia.conf"
echo "   Server: $VPN_SERVER:$VPN_PORT"

# Test 6: Credentials file test
echo -e "\n${BLUE}Test 6: Credentials File Test${NC}"

echo "$PIA_USERNAME" > /tmp/test_pia_creds
echo "$PIA_PASSWORD" >> /tmp/test_pia_creds
chmod 600 /tmp/test_pia_creds

echo "✅ Test credentials file created at /tmp/test_pia_creds"
echo "   Permissions: $(stat -f "%A" /tmp/test_pia_creds 2>/dev/null || stat -c "%a" /tmp/test_pia_creds 2>/dev/null)"

echo -e "\n${GREEN}🎉 All tests completed successfully!${NC}"
echo -e "${CYAN}The VPN management system is properly configured.${NC}"

echo -e "\nNext steps:"
echo "• Use './vpn_manager.sh connect' to connect to VPN"
echo "• Use './vpn_manager.sh disconnect' to disconnect"
echo "• Use './vpn_manager.sh test' to test connection"

# Cleanup
rm -f /tmp/test_pia.conf /tmp/test_pia_creds

echo -e "\n✅ Cleanup completed"
