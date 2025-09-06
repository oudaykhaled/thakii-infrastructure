#!/bin/bash

# Full Stack Runner and Tester for Thakii Lecture2PDF Service
# This script runs both backend and frontend, then tests them

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKEND_HOST="thakii-02.fanusdigital.site"
BACKEND_PORT="5001"
FRONTEND_PORT="3000"
SSH_KEY="thakii-02-deploy-key"

echo -e "${BLUE}🚀 Thakii Full Stack Runner${NC}"
echo "=================================="
echo

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to check if a port is free
check_port() {
    local port=$1
    if lsof -i:$port >/dev/null 2>&1; then
        return 1  # Port is occupied
    else
        return 0  # Port is free
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_info "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" >/dev/null 2>&1; then
            print_status "$service_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Function to test backend
test_backend() {
    print_info "Testing backend API endpoints..."
    
    # Test health endpoint
    echo -n "  Health check: "
    if response=$(curl -s -f "http://$BACKEND_HOST:$BACKEND_PORT/health" 2>/dev/null); then
        if echo "$response" | grep -q '"status":"healthy"'; then
            print_status "PASSED"
        else
            print_error "FAILED - Invalid response"
            return 1
        fi
    else
        print_error "FAILED - No response"
        return 1
    fi
    
    # Test protected endpoints (should return 401)
    echo -n "  Authentication check: "
    if curl -s "http://$BACKEND_HOST:$BACKEND_PORT/list" | grep -q "Authentication required"; then
        print_status "PASSED"
    else
        print_error "FAILED - Authentication not working"
        return 1
    fi
    
    # Test upload endpoint (should return 401)
    echo -n "  Upload endpoint: "
    if curl -s -X POST "http://$BACKEND_HOST:$BACKEND_PORT/upload" | grep -q "Authentication required"; then
        print_status "PASSED"
    else
        print_error "FAILED - Upload endpoint not protected"
        return 1
    fi
    
    print_status "Backend tests completed successfully!"
    return 0
}

# Function to test frontend
test_frontend() {
    print_info "Testing frontend..."
    
    # Test if frontend is accessible
    echo -n "  Frontend accessibility: "
    if curl -s -f "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
        print_status "PASSED"
    else
        print_error "FAILED - Frontend not accessible"
        return 1
    fi
    
    # Test if frontend serves HTML
    echo -n "  HTML content: "
    if curl -s "http://localhost:$FRONTEND_PORT" | grep -q "<html\|<!DOCTYPE"; then
        print_status "PASSED"
    else
        print_error "FAILED - No HTML content"
        return 1
    fi
    
    print_status "Frontend tests completed successfully!"
    return 0
}

# Function to check backend status
check_backend_status() {
    print_info "Checking backend status on $BACKEND_HOST:$BACKEND_PORT..."
    
    # Test backend health (this is the primary check)
    if curl -s -f "http://$BACKEND_HOST:$BACKEND_PORT/health" >/dev/null 2>&1; then
        print_status "Backend is running on remote server"
        print_status "Backend is responding to health checks"
        return 0
    else
        print_error "Backend is not responding to health checks"
        print_info "You may need to deploy the backend first using: gh workflow run 'Deploy Thakii Backend (Native - No Docker)'"
        return 1
    fi
}

# Function to start frontend
start_frontend() {
    print_info "Starting frontend on port $FRONTEND_PORT..."
    
    # Check if we're in the right directory
    if [ ! -f "web/package.json" ]; then
        print_error "web/package.json not found. Please run this script from the project root."
        return 1
    fi
    
    # Kill any existing processes on the frontend port
    if ! check_port $FRONTEND_PORT; then
        print_warning "Port $FRONTEND_PORT is occupied. Killing existing processes..."
        lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Navigate to web directory and start frontend
    cd web
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_info "Installing frontend dependencies..."
        npm install
    fi
    
    # Configure environment
    print_info "Configured API endpoint: http://$BACKEND_HOST:$BACKEND_PORT"
    echo "VITE_API_BASE_URL=http://$BACKEND_HOST:$BACKEND_PORT" > .env
    echo "VITE_FIREBASE_API_KEY=AIzaSyBBPh9nAptY_J8i0z87YUCIXEEUc8GbVpg" >> .env
    echo "VITE_FIREBASE_AUTH_DOMAIN=thakii-973e3.firebaseapp.com" >> .env
    echo "VITE_FIREBASE_PROJECT_ID=thakii-973e3" >> .env
    echo "VITE_FIREBASE_STORAGE_BUCKET=thakii-973e3.firebasestorage.app" >> .env
    echo "VITE_FIREBASE_MESSAGING_SENDER_ID=258632915594" >> .env
    echo "VITE_FIREBASE_APP_ID=1:258632915594:web:0910d1ad68ea361e912b73" >> .env
    
    # Start frontend in background
    print_info "Starting Vite development server..."
    npm run dev > ../frontend.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > ../frontend.pid
    
    cd ..
    
    # Wait for frontend to be ready
    if wait_for_service "http://localhost:$FRONTEND_PORT" "Frontend"; then
        print_status "Frontend started successfully (PID: $FRONTEND_PID)"
        return 0
    else
        print_error "Frontend failed to start"
        return 1
    fi
}

# Function to show running services
show_services() {
    echo
    print_info "Running Services:"
    echo "=================="
    
    # Backend status
    if curl -s -f "http://$BACKEND_HOST:$BACKEND_PORT/health" >/dev/null 2>&1; then
        print_status "Backend: http://$BACKEND_HOST:$BACKEND_PORT (Remote)"
    else
        print_error "Backend: Not responding"
    fi
    
    # Frontend status
    if [ -f "frontend.pid" ] && kill -0 $(cat frontend.pid) 2>/dev/null; then
        print_status "Frontend: http://localhost:$FRONTEND_PORT (Local)"
        print_status "Network: http://$(hostname -I | awk '{print $1}'):$FRONTEND_PORT"
    else
        print_error "Frontend: Not running"
    fi
    
    echo
    print_info "Logs:"
    echo "- Frontend: tail -f frontend.log"
    echo "- Backend: SSH to server and check logs"
    echo
}

# Function to stop services
stop_services() {
    print_info "Stopping services..."
    
    # Stop frontend
    if [ -f "frontend.pid" ]; then
        FRONTEND_PID=$(cat frontend.pid)
        if kill -0 $FRONTEND_PID 2>/dev/null; then
            kill $FRONTEND_PID
            print_status "Frontend stopped (PID: $FRONTEND_PID)"
        fi
        rm -f frontend.pid
    fi
    
    # Kill any remaining processes on frontend port
    lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null || true
    
    print_status "Services stopped"
}

# Function to run full test suite
run_tests() {
    print_info "Running full test suite..."
    echo
    
    # Test backend
    if test_backend; then
        BACKEND_TESTS="PASSED"
    else
        BACKEND_TESTS="FAILED"
    fi
    
    echo
    
    # Test frontend
    if test_frontend; then
        FRONTEND_TESTS="PASSED"
    else
        FRONTEND_TESTS="FAILED"
    fi
    
    echo
    print_info "Test Results Summary:"
    echo "===================="
    echo -e "Backend Tests:  ${BACKEND_TESTS}"
    echo -e "Frontend Tests: ${FRONTEND_TESTS}"
    echo
    
    if [ "$BACKEND_TESTS" = "PASSED" ] && [ "$FRONTEND_TESTS" = "PASSED" ]; then
        print_status "All tests passed! 🎉"
        return 0
    else
        print_error "Some tests failed!"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            print_info "Starting full stack application..."
            
            # Check backend
            if ! check_backend_status; then
                print_error "Backend check failed. Please ensure backend is deployed and running."
                exit 1
            fi
            
            # Start frontend
            if ! start_frontend; then
                print_error "Failed to start frontend"
                exit 1
            fi
            
            # Show services
            show_services
            
            print_status "Full stack application is running!"
            print_info "Open your browser and go to: http://localhost:$FRONTEND_PORT"
            ;;
            
        "test")
            print_info "Running tests only..."
            if ! run_tests; then
                exit 1
            fi
            ;;
            
        "stop")
            stop_services
            ;;
            
        "status")
            show_services
            ;;
            
        "restart")
            stop_services
            sleep 2
            main start
            ;;
            
        "logs")
            print_info "Showing frontend logs (Ctrl+C to exit):"
            tail -f frontend.log 2>/dev/null || echo "No frontend logs found"
            ;;
            
        *)
            echo "Usage: $0 {start|test|stop|status|restart|logs}"
            echo
            echo "Commands:"
            echo "  start   - Start both backend check and frontend server"
            echo "  test    - Run comprehensive tests on both services"
            echo "  stop    - Stop all local services"
            echo "  status  - Show status of all services"
            echo "  restart - Restart all services"
            echo "  logs    - Show frontend logs"
            echo
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

# Only trap for interrupt signals, not normal exit
if [ "${1:-start}" = "start" ]; then
    # Keep the script running and trap only interrupt signals
    trap 'stop_services; exit' INT TERM
    
    print_info "Services are running. Press Ctrl+C to stop all services."
    
    # Keep script alive
    while true; do
        sleep 10
        # Check if frontend is still running
        if [ -f "frontend.pid" ] && ! kill -0 $(cat frontend.pid) 2>/dev/null; then
            print_error "Frontend process died unexpectedly"
            break
        fi
    done
fi
