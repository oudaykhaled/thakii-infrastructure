#!/bin/bash

# Simple service starter that doesn't hang
# This script starts services and exits immediately

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
BACKEND_HOST="thakii-02.fanusdigital.site"
BACKEND_PORT="5001"
FRONTEND_PORT="3000"

print_info "Starting Thakii Services..."

# Check backend
print_info "Checking backend health..."
if curl -s -f "http://$BACKEND_HOST:$BACKEND_PORT/health" >/dev/null 2>&1; then
    print_status "Backend is healthy"
else
    print_error "Backend is not responding"
    exit 1
fi

# Clean up any existing processes
print_info "Cleaning up existing processes..."
pkill -f "npm run dev" 2>/dev/null || true
pkill -f vite 2>/dev/null || true
lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null || true
sleep 2

# Navigate to web directory
cd web

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    print_info "Installing dependencies..."
    npm install
fi

# Configure environment
print_info "Configuring environment..."
echo "VITE_API_BASE_URL=http://$BACKEND_HOST:$BACKEND_PORT" > .env
echo "VITE_FIREBASE_API_KEY=AIzaSyBBPh9nAptY_J8i0z87YUCIXEEUc8GbVpg" >> .env
echo "VITE_FIREBASE_AUTH_DOMAIN=thakii-973e3.firebaseapp.com" >> .env
echo "VITE_FIREBASE_PROJECT_ID=thakii-973e3" >> .env
echo "VITE_FIREBASE_STORAGE_BUCKET=thakii-973e3.firebasestorage.app" >> .env
echo "VITE_FIREBASE_MESSAGING_SENDER_ID=258632915594" >> .env
echo "VITE_FIREBASE_APP_ID=1:258632915594:web:0910d1ad68ea361e912b73" >> .env

# Start frontend in background
print_info "Starting frontend..."
nohup npm run dev > ../frontend.log 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > ../frontend.pid

cd ..

# Wait a moment for startup
sleep 5

# Test frontend
if curl -s -f "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
    print_status "Frontend started successfully (PID: $FRONTEND_PID)"
    print_status "Backend: http://$BACKEND_HOST:$BACKEND_PORT"
    print_status "Frontend: http://localhost:$FRONTEND_PORT"
    print_info "Frontend logs: tail -f frontend.log"
else
    print_error "Frontend failed to start"
    exit 1
fi

print_status "Services started successfully!"
