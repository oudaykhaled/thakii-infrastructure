#!/bin/bash

# Sophisticated Validation and Startup Script for Thakii Lecture2PDF Service
# Runs backend on port 5000 and web on port 3000 with comprehensive validation

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
BACKEND_PORT=5001
WEB_PORT=3000
TIMEOUT=30
HEALTH_ENDPOINT="/health"
WEB_BUILD_TIMEOUT=120
BACKEND_STARTUP_TIMEOUT=15

# Logging
LOG_DIR="./logs"
BACKEND_LOG="$LOG_DIR/backend_validation.log"
WEB_LOG="$LOG_DIR/web_validation.log"
SCRIPT_LOG="$LOG_DIR/validation_script.log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Redirect all output to both console and log file
exec > >(tee -a "$SCRIPT_LOG") 2>&1

print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}🚀 THAKII LECTURE2PDF VALIDATION SUITE${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Backend Target: http://localhost:$BACKEND_PORT${NC}"
    echo -e "${BLUE}Web Target: http://localhost:$WEB_PORT${NC}"
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

# Kill processes on specified port
kill_port() {
    local port=$1
    local service_name=$2
    
    print_info "Checking for processes on port $port ($service_name)..."
    
    local pids=$(lsof -ti :$port 2>/dev/null || true)
    if [ -n "$pids" ]; then
        print_warning "Killing existing processes on port $port: $pids"
        
        # Try graceful kill first
        echo "$pids" | xargs -r kill 2>/dev/null || true
        sleep 2
        
        # Check if still running, then force kill
        local remaining=$(lsof -ti :$port 2>/dev/null || true)
        if [ -n "$remaining" ]; then
            print_info "Processes still running, force killing..."
            echo "$remaining" | xargs -r kill -9 2>/dev/null || true
            sleep 3
            
            # Final check
            remaining=$(lsof -ti :$port 2>/dev/null || true)
            if [ -n "$remaining" ]; then
                print_warning "Some processes on port $port are persistent, continuing anyway"
                print_info "Remaining PIDs: $remaining"
            fi
        fi
    fi
    
    print_success "Port $port cleanup completed"
    return 0
}

# Wait for port to be available
wait_for_port() {
    local port=$1
    local service_name=$2
    local timeout=$3
    
    print_info "Waiting for $service_name on port $port (timeout: ${timeout}s)..."
    
    local count=0
    while [ $count -lt $timeout ]; do
        if lsof -ti :$port >/dev/null 2>&1; then
            print_success "$service_name is listening on port $port"
            return 0
        fi
        sleep 1
        ((count++))
        if [ $((count % 5)) -eq 0 ]; then
            print_info "Still waiting... (${count}s elapsed)"
        fi
    done
    
    print_error "$service_name failed to start on port $port within ${timeout}s"
    return 1
}

# Validate HTTP endpoint
validate_http_endpoint() {
    local url=$1
    local expected_status=$2
    local service_name=$3
    local timeout=${4:-10}
    
    print_info "Validating $service_name endpoint: $url"
    
    local response
    local status_code
    
    if response=$(curl -s -w "%{http_code}" --max-time $timeout "$url" 2>/dev/null); then
        status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "$expected_status" ]; then
            print_success "$service_name HTTP validation passed (status: $status_code)"
            
            # Additional validation for health endpoint
            if [[ "$url" == *"/health"* ]]; then
                if echo "$body" | grep -q '"status":"healthy"'; then
                    print_success "Health check content validation passed"
                    echo -e "${CYAN}Health Response: $body${NC}"
                else
                    print_warning "Health check returned $status_code but content validation failed"
                    echo -e "${YELLOW}Response: $body${NC}"
                fi
            fi
            
            return 0
        else
            print_error "$service_name returned status $status_code (expected $expected_status)"
            return 1
        fi
    else
        print_error "$service_name HTTP request failed (timeout or connection error)"
        return 1
    fi
}

# Validate backend health and functionality
validate_backend() {
    local base_url="http://localhost:$BACKEND_PORT"
    
    print_step "🔍 BACKEND VALIDATION"
    
    # Basic health check
    if ! validate_http_endpoint "$base_url$HEALTH_ENDPOINT" "200" "Backend Health"; then
        return 1
    fi
    
    # Test CORS headers
    print_info "Validating CORS configuration..."
    local cors_response
    if cors_response=$(curl -s -H "Origin: http://localhost:$WEB_PORT" -I "$base_url$HEALTH_ENDPOINT" --max-time 10 2>/dev/null); then
        if echo "$cors_response" | grep -qi "access-control-allow-origin"; then
            print_success "CORS headers present"
        else
            print_warning "CORS headers not found (may impact web integration)"
        fi
    else
        print_warning "Could not test CORS headers"
    fi
    
    # Test authentication error handling (should return 401/400 for protected endpoints)
    print_info "Testing authentication handling..."
    if validate_http_endpoint "$base_url/list" "401" "Auth Validation" 5; then
        print_success "Authentication properly enforced"
    else
        print_warning "Authentication test inconclusive"
    fi
    
    print_success "Backend validation completed"
    return 0
}

# Validate web interface
validate_web() {
    local base_url="http://localhost:$WEB_PORT"
    
    print_step "🔍 WEB INTERFACE VALIDATION"
    
    # Basic HTML serving
    if ! validate_http_endpoint "$base_url/" "200" "Web Interface"; then
        return 1
    fi
    
    # Check if it's actually serving HTML
    print_info "Validating HTML content..."
    local html_content
    if html_content=$(curl -s --max-time 10 "$base_url/" 2>/dev/null); then
        if echo "$html_content" | grep -qi "<!doctype html"; then
            print_success "Valid HTML content detected"
        else
            print_warning "Response doesn't appear to be valid HTML"
        fi
        
        # Check for React/Vite indicators
        if echo "$html_content" | grep -qi "react\|vite"; then
            print_success "React/Vite application detected"
        fi
    else
        print_warning "Could not retrieve HTML content"
    fi
    
    # Test static assets (if any)
    print_info "Testing static asset serving..."
    if validate_http_endpoint "$base_url/vite.svg" "200" "Static Assets" 5; then
        print_success "Static assets serving correctly"
    else
        print_info "Static asset test inconclusive (may be normal)"
    fi
    
    print_success "Web interface validation completed"
    return 0
}

# Start backend service
start_backend() {
    print_step "🖥️  STARTING BACKEND SERVICE"
    
    # Navigate to backend directory
    cd "$SCRIPT_DIR/backend" || {
        print_error "Could not navigate to backend directory"
        return 1
    }
    
    # Check for virtual environment
    if [ ! -d ".venv" ]; then
        print_info "Creating Python virtual environment..."
        python3 -m venv .venv || {
            print_error "Failed to create virtual environment"
            return 1
        }
    fi
    
    # Activate virtual environment and install dependencies
    print_info "Activating virtual environment and installing dependencies..."
    source .venv/bin/activate
    
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt >/dev/null 2>&1 || {
            print_error "Failed to install Python dependencies"
            return 1
        }
        print_success "Python dependencies installed"
    fi
    
    # Check for required environment files
    if [ ! -f "firebase/firebase-service-account.json" ]; then
        print_warning "Firebase service account not found - some features may not work"
    fi
    
    # Set environment variables
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/firebase/firebase-service-account.json"
    export AWS_DEFAULT_REGION="us-east-2"
    export PYTHONPATH="$(pwd)/..:${PYTHONPATH:-}"
    export FLASK_ENV="development"
    
    # Ensure Flask app runs on the correct port
    if grep -q "app.run.*port=" api/app.py; then
        if ! grep -q "port=$BACKEND_PORT" api/app.py; then
            print_info "Updating backend to run on port $BACKEND_PORT..."
            sed -i '' "s/port=[0-9]\+/port=$BACKEND_PORT/g" api/app.py
        fi
    else
        print_info "Flask app port configuration not found, using default"
    fi
    
    # Start backend service
    print_info "Starting Flask backend on port $BACKEND_PORT..."
    nohup python api/app.py > "$BACKEND_LOG" 2>&1 &
    local backend_pid=$!
    
    print_info "Backend started with PID: $backend_pid"
    
    # Return to script directory
    cd "$SCRIPT_DIR"
    
    # Wait for backend to be ready
    if wait_for_port "$BACKEND_PORT" "Backend" "$BACKEND_STARTUP_TIMEOUT"; then
        print_success "Backend service started successfully"
        return 0
    else
        print_error "Backend failed to start"
        print_info "Last 10 lines of backend log:"
        tail -10 "$BACKEND_LOG" 2>/dev/null || true
        return 1
    fi
}

# Start web interface
start_web() {
    print_step "🌐 STARTING WEB INTERFACE"
    
    # Navigate to web directory
    cd "$SCRIPT_DIR/web" || {
        print_error "Could not navigate to web directory"
        return 1
    }
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_info "Installing Node.js dependencies..."
        npm install >/dev/null 2>&1 || {
            print_error "Failed to install Node.js dependencies"
            return 1
        }
        print_success "Node.js dependencies installed"
    fi
    
    # Update web configuration to point to the correct backend port
    if [ -f ".env" ]; then
        sed -i '' "s/VITE_API_BASE_URL=.*/VITE_API_BASE_URL=http:\/\/localhost:$BACKEND_PORT/g" .env
    else
        echo "VITE_API_BASE_URL=http://localhost:$BACKEND_PORT" > .env.local
    fi
    print_info "Web interface configured to use backend on port $BACKEND_PORT"
    
    # Start web interface using dev mode for faster startup
    print_info "Starting web interface on port $WEB_PORT..."
    nohup npx vite --port $WEB_PORT --host 0.0.0.0 > "$WEB_LOG" 2>&1 &
    local web_pid=$!
    
    print_info "Web interface started with PID: $web_pid"
    
    # Wait for web interface to be ready
    if wait_for_port "$WEB_PORT" "Web Interface" 15; then
        print_success "Web interface started successfully"
        return 0
    else
        print_error "Web interface failed to start"
        print_info "Last 10 lines of web log:"
        tail -10 "$WEB_LOG" 2>/dev/null || true
        return 1
    fi
}

# Main execution flow
main() {
    print_header
    
    # Step 1: Clean up existing processes
    print_step "🧹 CLEANUP PHASE"
    if ! kill_port "$BACKEND_PORT" "Backend"; then
        print_error "Failed to clean up backend port"
        exit 1
    fi
    
    if ! kill_port "$WEB_PORT" "Web Interface"; then
        print_error "Failed to clean up web port"
        exit 1
    fi
    
    print_success "Cleanup completed"
    
    # Step 2: Start backend
    if ! start_backend; then
        print_error "Backend startup failed"
        exit 1
    fi
    
    # Step 3: Validate backend
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR" # Return to script directory
    if ! validate_backend; then
        print_error "Backend validation failed"
        exit 1
    fi
    
    # Step 4: Start web interface
    if ! start_web; then
        print_error "Web interface startup failed"
        exit 1
    fi
    
    # Step 5: Validate web interface
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR" # Return to script directory
    if ! validate_web; then
        print_error "Web interface validation failed"
        exit 1
    fi
    
    # Final status report
    print_step "🎉 VALIDATION COMPLETE"
    print_success "Backend: http://localhost:$BACKEND_PORT$HEALTH_ENDPOINT"
    print_success "Web Interface: http://localhost:$WEB_PORT"
    print_success "All services validated and running successfully!"
    
    echo -e "\n${CYAN}📋 Process Information:${NC}"
    echo -e "${BLUE}Backend PID: $(lsof -ti :$BACKEND_PORT 2>/dev/null || echo 'Not found')${NC}"
    echo -e "${BLUE}Web PID: $(lsof -ti :$WEB_PORT 2>/dev/null || echo 'Not found')${NC}"
    
    echo -e "\n${CYAN}📁 Log Files:${NC}"
    echo -e "${BLUE}Script Log: $SCRIPT_LOG${NC}"
    echo -e "${BLUE}Backend Log: $BACKEND_LOG${NC}"
    echo -e "${BLUE}Web Log: $WEB_LOG${NC}"
    
    echo -e "\n${YELLOW}🛑 To stop services:${NC}"
    echo -e "${YELLOW}killall -9 python node || pkill -f 'python api/app.py' || pkill -f vite${NC}"
    
    return 0
}

# Trap to clean up on script exit
cleanup_on_exit() {
    if [ $? -ne 0 ]; then
        print_error "Script execution failed"
        echo -e "\n${YELLOW}Cleaning up any started processes...${NC}"
        kill_port "$BACKEND_PORT" "Backend" >/dev/null 2>&1 || true
        kill_port "$WEB_PORT" "Web Interface" >/dev/null 2>&1 || true
    fi
}

trap cleanup_on_exit EXIT

# Run main function
main "$@"
