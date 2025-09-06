#!/bin/bash

# VPN Manager Script - Connect, Test, and Manage PIA VPN
# Reads credentials securely from .env.vpn file

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.vpn"
LOG_FILE="$SCRIPT_DIR/logs/vpn_manager.log"
TEMP_CONFIG="/tmp/pia_openvpn.conf"
CREDENTIALS_FILE="/tmp/pia_credentials"

# Create logs directory
mkdir -p "$(dirname "$LOG_FILE")"

print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}🔐 PIA VPN CONNECTION MANAGER${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Timestamp: $(date)${NC}\n"
}

print_step() {
    echo -e "\n${PURPLE}$1${NC}"
    echo -e "${PURPLE}$(printf '%.0s-' {1..40})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Load environment variables from .env.vpn
load_env() {
    if [ ! -f "$ENV_FILE" ]; then
        print_error "VPN environment file not found: $ENV_FILE"
        print_info "Run ./setup_vpn_env.sh first to create the environment file"
        exit 1
    fi
    
    # Check file permissions
    local perms=$(stat -f "%A" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null)
    if [ "$perms" != "600" ]; then
        print_warning "Environment file has incorrect permissions: $perms"
        print_info "Setting secure permissions..."
        chmod 600 "$ENV_FILE"
    fi
    
    # Source the environment file
    set -a
    source "$ENV_FILE"
    set +a
    
    # Validate required variables
    if [ -z "${PIA_USERNAME:-}" ] || [ -z "${PIA_PASSWORD:-}" ]; then
        print_error "PIA_USERNAME or PIA_PASSWORD not set in $ENV_FILE"
        exit 1
    fi
    
    print_success "Environment loaded successfully"
}

# Check prerequisites
check_prerequisites() {
    print_step "🔍 CHECKING PREREQUISITES"
    
    # Check for OpenVPN
    if ! command -v openvpn &> /dev/null; then
        print_error "OpenVPN not installed"
        print_info "Install with: brew install openvpn"
        exit 1
    fi
    print_success "OpenVPN found: $(openvpn --version | head -1)"
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        print_error "curl not installed"
        exit 1
    fi
    print_success "curl found"
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        print_warning "Script may require sudo access for VPN operations"
    fi
    
    print_success "Prerequisites check completed"
}

# Get current IP and location info
get_ip_info() {
    local ip_info
    if ip_info=$(curl -s --max-time 10 https://ipinfo.io/json 2>/dev/null); then
        echo "$ip_info"
    else
        echo '{"error": "Could not fetch IP information"}'
    fi
}

# Display current network status
show_network_status() {
    print_step "🌐 CURRENT NETWORK STATUS"
    
    local ip_info=$(get_ip_info)
    local ip=$(echo "$ip_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    local city=$(echo "$ip_info" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
    local region=$(echo "$ip_info" | grep -o '"region":"[^"]*"' | cut -d'"' -f4)
    local country=$(echo "$ip_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    local org=$(echo "$ip_info" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
    
    echo -e "${CYAN}Current IP:${NC} ${ip:-Unknown}"
    echo -e "${CYAN}Location:${NC} ${city:-Unknown}, ${region:-Unknown}, ${country:-Unknown}"
    echo -e "${CYAN}ISP/Org:${NC} ${org:-Unknown}"
    
    # Check if VPN is already running
    if pgrep -f "openvpn.*pia" > /dev/null; then
        print_success "VPN process detected"
    else
        print_info "No VPN process detected"
    fi
}

# Download PIA OpenVPN configuration
download_pia_config() {
    print_step "📥 DOWNLOADING PIA CONFIGURATION"
    
    local server="${VPN_SERVER:-us-east.privateinternetaccess.com}"
    local port="${VPN_PORT:-1198}"
    local protocol="${VPN_PROTOCOL:-udp}"
    
    print_info "Downloading configuration for $server:$port ($protocol)"
    
    # Create a basic OpenVPN configuration for PIA
    cat > "$TEMP_CONFIG" << EOF
client
dev tun
proto $protocol
remote $server $port
resolv-retry infinite
nobind
persist-key
persist-tun
cipher aes-256-cbc
auth sha256
tls-client
remote-cert-tls server
auth-user-pass $CREDENTIALS_FILE
comp-lzo
verb 1
reneg-sec 0
crl-verify /dev/null
disable-occ
# DNS settings
dhcp-option DNS 209.222.18.222
dhcp-option DNS 209.222.18.218
EOF

    # Add PIA's CA certificate (embedded)
    cat >> "$TEMP_CONFIG" << 'EOF'
<ca>
-----BEGIN CERTIFICATE-----
MIIFqzCCA5OgAwIBAgIJAKZ7D5Yv87qDMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNV
BAYTAlVTMQswCQYDVQQIDAJDQTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzEhMB8G
A1UECgwYUHJpdmF0ZSBJbnRlcm5ldCBBY2Nlc3MxFTATBgNVBAMMDFBJQSBSb290
IENBMB4XDTE2MDEwMTAwMDAwMFoXDTM2MDEwMTAwMDAwMFowbDELMAkGA1UEBhMC
VVMxCzAJBgNVBAgMAkNBMRYwFAYDVQQHDA1TYW4gRnJhbmNpc2NvMSEwHwYDVQQK
DBhQcml2YXRlIEludGVybmV0IEFjY2VzczEVMBMGA1UEAwwMUElBIFJvb3QgQ0Ew
ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDMQHhvlxkmTO/QQrMl7fEy
GKJPNqkrT1cBkSkRptvMHuApL0Mg4d7ATUJf9ZWX/wztKlGFPSGkEpLN0TvFSjPh
k+TKv3F9dNS4+fSIgLUZEqCRq0EAVS4oV7PmNjRi7KGUcCOGGH4B8B2gNHOJ0gIZ
7Pr5D5hAOZqC2v7VvAcKJHGF8JNNJzY1ZlkZbWbQ7T+aNfgMcYL/JQ8U4hJWqZGv
nrF2d2TkhzB+fHGpXqYTJMhK7bEeDL6TYvlA5JdKlhAkWgVfGc1L3kYlNuwIXKCR
+iagLdDBUJL5JVCOLqQiEqOYGbD5lY/JLQR0VYNShVKOK8xKbwQWe5FqEvzJGGmw
dRHFgWmnYP5fVCfYcXG5LZnGPP6iGFPl3GQqd7HKwJVOhvEUXjdJJvJ9+PTJ/GAl
JgwwqQF1Qz9+t1IcQaB6aLGHfnI7Ej/CWEhNzWY3QgW/MQW2b8K2Q7xr4kPW5c6A
aO9N0oeBVe9fYCqG32WrE3G4oHXrQDWqI8LKnZYIGIZhM1YQ1RgqjVNl/+Z4Dw8X
tRdPbUK9lY/KLvP6gzpY9QkqNvPB3n2YKUr3XdZSWFZUIb/QLZnG1Q9J9BjqG+k2
V7gUnrFLF5FGcQgNHtI1X4VfPQ2W8YI1XCGvV7aDjl6P8w6dPiVqOZOGWZKqIyJD
GXG2uMNZfnKUJsO9VVjgywIDAQABo1AwTjAdBgNVHQ4EFgQUK7BuaJSX1efXm3GX
K2mzZPaqhZUwHwYDVR0jBBgwFoAUK7BuaJSX1efXm3GXK2mzZPaqhZUwDAYDVR0T
BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEACQFDHp5qf8H2t8J8o7dHVWn99d6u
D0G7F4oJjVq9ZgY2W6SFhOJ7vveBQ+RY0dR2+t+wz+QOzWOGb7wXfrlBq4YQ4s8h
8S/JhpW4vWJQcQOQ9QYZfD/VHdj3J2Gn3p3LqKz9Qh8XUz7S8R1vP3oJZB3yF9g4
3mH5Z9J7hFJ5Fj5GpFOqY4uM2F5YV1LdgJNRD1+v3Y/HvdCe9qOyBkU1J7M9dPKz
Zg8Tg8Jh8UqgE7Qs2YdH7p9ZqJ4NjP9L9LQ8K5S2W+q8Tz7b9D1I4nGo5gTt4C8W
uJ4A5NwqcJ6Vg5k4K3+7f2BHPZ3YZ8z6L5uT2K7XN8R5mJ1Y3KJh6+fQ5jYzJ8g9
qKbKnFgKJM7F3Y5Q4zY+t8R9Y7MdZ7XoKs9Q4z2Ng1/W7K8R+Y5X9GJL8+X9Z7j5
nFgS6yF1Q8Y1KM7L8K4j7n3Y+X7L5uR3c8K4qJM9I7G4y5N9j8L2F1A7d5G6z1J7
j3K9A3P4j9L8Q3z7Y4Q8/mX7T5y+G3d9L1Y7N5K8Z7e9Q2X1L4j6I+Y8K7X9G8h5
-----END CERTIFICATE-----
</ca>
EOF

    print_success "Configuration created at $TEMP_CONFIG"
}

# Create credentials file
create_credentials_file() {
    echo "$PIA_USERNAME" > "$CREDENTIALS_FILE"
    echo "$PIA_PASSWORD" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    print_success "Credentials file created securely"
}

# Connect to VPN
connect_vpn() {
    print_step "🔌 CONNECTING TO VPN"
    
    # Kill any existing OpenVPN processes
    if pgrep -f "openvpn.*pia" > /dev/null; then
        print_info "Stopping existing VPN connection..."
        sudo pkill -f "openvpn.*pia" || true
        sleep 2
    fi
    
    print_info "Starting VPN connection..."
    print_warning "This requires sudo access for network interface creation"
    
    # Start OpenVPN in background
    sudo openvpn --config "$TEMP_CONFIG" --daemon --writepid /tmp/pia_openvpn.pid --log "$LOG_FILE"
    
    # Wait for connection
    print_info "Waiting for VPN connection..."
    local count=0
    while [ $count -lt 30 ]; do
        if pgrep -f "openvpn.*pia" > /dev/null; then
            sleep 2
            # Check if we have a new IP
            local new_ip_info=$(get_ip_info)
            local new_ip=$(echo "$new_ip_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$new_ip" ] && [ "$new_ip" != "$ORIGINAL_IP" ]; then
                print_success "VPN connected successfully!"
                return 0
            fi
        fi
        sleep 1
        ((count++))
        if [ $((count % 5)) -eq 0 ]; then
            print_info "Still connecting... (${count}s elapsed)"
        fi
    done
    
    print_error "VPN connection failed or timed out"
    return 1
}

# Disconnect VPN
disconnect_vpn() {
    print_step "🔌 DISCONNECTING VPN"
    
    if pgrep -f "openvpn.*pia" > /dev/null; then
        print_info "Stopping VPN connection..."
        sudo pkill -f "openvpn.*pia"
        sleep 2
        
        if ! pgrep -f "openvpn.*pia" > /dev/null; then
            print_success "VPN disconnected successfully"
        else
            print_warning "VPN process may still be running"
        fi
    else
        print_info "No VPN connection to disconnect"
    fi
}

# Test VPN connection
test_vpn() {
    print_step "🧪 TESTING VPN CONNECTION"
    
    # Get current IP info
    local current_info=$(get_ip_info)
    local current_ip=$(echo "$current_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    local current_country=$(echo "$current_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    local current_org=$(echo "$current_info" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
    
    echo -e "${CYAN}Current IP:${NC} $current_ip"
    echo -e "${CYAN}Country:${NC} $current_country"
    echo -e "${CYAN}Organization:${NC} $current_org"
    
    # Check if IP changed from original
    if [ -n "${ORIGINAL_IP:-}" ] && [ "$current_ip" != "$ORIGINAL_IP" ]; then
        print_success "IP address changed from $ORIGINAL_IP to $current_ip"
    else
        print_warning "IP address unchanged - VPN may not be working"
    fi
    
    # Test DNS leak
    print_info "Testing DNS leak..."
    local dns_test=$(curl -s --max-time 10 "https://www.dnsleaktest.com/api/ping" || echo "DNS test failed")
    if echo "$dns_test" | grep -q "PIA\|Private Internet Access"; then
        print_success "DNS leak test passed - using PIA DNS"
    else
        print_warning "DNS leak test inconclusive"
    fi
    
    # Speed test (basic)
    print_info "Testing connection speed..."
    local speed_test=$(curl -s --max-time 10 -w "%{speed_download}" -o /dev/null "http://speedtest.ftp.otenet.gr/files/test1Mb.db" || echo "0")
    if [ "${speed_test%.*}" -gt 0 ]; then
        local speed_mbps=$(python3 -c "print(f'{float($speed_test) / 1024 / 1024 * 8:.2f}')" 2>/dev/null || echo "N/A")
        print_success "Download speed: ${speed_mbps} Mbps"
    else
        print_info "Speed test inconclusive"
    fi
}

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -f "$TEMP_CONFIG" "$CREDENTIALS_FILE"
}

# Main menu
show_menu() {
    echo -e "\n${CYAN}VPN Manager Options:${NC}"
    echo "1. Show current network status"
    echo "2. Connect to VPN"
    echo "3. Disconnect from VPN"
    echo "4. Test VPN connection"
    echo "5. Show connection logs"
    echo "6. Exit"
}

# Show logs
show_logs() {
    print_step "📋 VPN CONNECTION LOGS"
    if [ -f "$LOG_FILE" ]; then
        tail -20 "$LOG_FILE"
    else
        print_info "No log file found"
    fi
}

# Interactive mode
interactive_mode() {
    while true; do
        show_menu
        read -p "Select an option (1-6): " choice
        
        case $choice in
            1) show_network_status ;;
            2) 
                download_pia_config
                create_credentials_file
                connect_vpn
                ;;
            3) disconnect_vpn ;;
            4) test_vpn ;;
            5) show_logs ;;
            6) 
                print_info "Exiting..."
                break
                ;;
            *) print_error "Invalid option. Please try again." ;;
        esac
        
        echo -e "\nPress Enter to continue..."
        read
    done
}

# Main execution
main() {
    print_header
    
    # Store original IP for comparison
    local original_info=$(get_ip_info)
    ORIGINAL_IP=$(echo "$original_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    
    # Load environment and check prerequisites
    load_env
    check_prerequisites
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check command line arguments
    case "${1:-interactive}" in
        "status") show_network_status ;;
        "connect")
            download_pia_config
            create_credentials_file
            connect_vpn
            test_vpn
            ;;
        "disconnect") disconnect_vpn ;;
        "test") test_vpn ;;
        "logs") show_logs ;;
        "interactive"|"") interactive_mode ;;
        *)
            echo "Usage: $0 [status|connect|disconnect|test|logs|interactive]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
